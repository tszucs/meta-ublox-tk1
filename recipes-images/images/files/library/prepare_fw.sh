#!/usr/bin/env bash
#
# Prepare files needed for flashing an Apalis TK1 module and
# copy them to a specified location.
#
# This file is derived from update.sh made by toradex.
# Original file: meta-ublox-tk1/recipes-images/images/files/library/tegra/update.sh
#
# Author: Robert Noack (robert.noack@u-blox.com)
#

set -e
here="$(dirname $(readlink -m ${BASH_SOURCE[0]}))"

function print_help() {
    cat << EOF
Prepare files needed for flashing an Apalis TK1 module and
copy them to a specified location.

Usage: $0 [Options]

Optional Arguments
    -d PATH     Directory that contains the input files. Default: The directory
                which contains this script.
    -h          Print this message and exit.
    -o PATH     Output directory. Default: The current working directory.
                If it does not exist, it will be created.
    -s          Use forcecrc32.py to generate files that have a CRC32 checksum equal to 0xFFFFFFFF.
    -t CRC32    Same as -s but you can specify the checksum as a parameter. CRC32 should be without
                the "0x" prefix.
EOF
}


function on_error() {
    local error_msg=$1
    echo -e ${error_msg} 1>&2
    exit 1
}


function parse_args() {
    outdir=$(pwd)
    indir=${here}
    split_rootfs=0
    with_crc32=0
    checksum=FFFFFFFF

    while getopts "cd:ho:st:" opt; do
        case ${opt} in
            c)  split_rootfs=1
                ;;
            d)  indir=${OPTARG}
                ;;
            h)  print_help && exit 0
                ;;
            o)  outdir=${OPTARG}
                ;;
            s)  with_crc32=1
                ;;
            t)  with_crc32=1
                checksum=${OPTARG}
                ;;
        esac
    done

    [[ -d ${indir} ]] || on_error "Error: Directory with input files does not exist: ${indir}"

    outdir=$(readlink -m ${outdir})
    indir=$(readlink -m ${indir})
    rootfs="${indir}/rootfs"
    utils="${indir}/tegra-uboot-flasher"
}


function detect_module_type() {
    module_type=''
    if [[ -f ${rootfs}/etc/issue ]]; then
        local cnt=$(grep -ic "apalis" ${rootfs}/etc/issue || true)
        if [[ ${cnt} -ge 1 ]]; then
            cnt=$(grep -ic "tk1" ${rootfs}/etc/issue || true)
            if [[ ${cnt} -ge 1 ]]; then
                module_type="apalis-tk1"

                cnt=$(grep -ic "mainline" ${rootfs}/etc/issue || true)
                if [[ ${cnt} -ge 1 ]]; then
                    module_type="apalis-tk1-mainline"
                fi

                cnt=$(grep -ic "b205" ${rootfs}/etc/issue || true)
                if [[ ${cnt} -ge 1 ]]; then
                    module_type="apalis-tk1-b205"
                fi
            fi
        fi
    fi
    test -z "${module_type}" && on_error "Error: Could not detect module type."
    return 0
}


function find_filepath() {
    local file="$1"
    if command -v "${file}" > /dev/null; then
        echo "${file}"
    elif test -x "/sbin/${file}"; then
        echo "/sbin/${file}"
    else
        return 1
    fi
}


function append_crc32() {
    if [[ ${with_crc} -eq 1 ]]; then
        forcecrc32=${here}/forcecrc32.py
    fi
}


# MAIN
parse_args $@
echo -e "Preparing files for the firmware update."

detect_module_type && echo "Detected module type: ${module_type}"

case ${module_type} in
    apalis-tk1 | apalis-tk1-b205 | apalis-tk1-mainline)
        binaries="${indir}/${module_type}_bin"

        bct="${binaries}/PM375_Hynix_2GB_H5TC4G63AFR_RDA_924MHz.bct"
        dtb="${binaries}/zImage-tegra124-apalis-eval.dtb"
        uboot_binary="${binaries}/u-boot-dtb-tegra.bin"
        kernel_img_type="zImage"
        kernel="${binaries}/${kernel_img_type}"

        cboot_image="apalis-tk1.img"
        cboot_image_target="tegra124"
        rootfs_file="root.ext3"

        emmc_size=$(expr 1024 \* 15020 \* 2)
        ;;
    ?)
        on_error "Error: Unknown module type: ${module_type}"
        ;;
esac

# ensure that binary files exist
[[ -e "${bct}" ]] || on_error "Error: BCT file does not exist in '${indir}': ${bct}"
[[ -e "${uboot_binary}" ]] || on_error "Error: u-boot binary does not exist in '${indir}': ${uboot_binary}"
[[ -e "${kernel}" ]] || on_error "Error: kernel binary does not exist in '${indir}': ${kernel}"
[[ -e "${dtb}" ]] || on_error "Error: Device tree does not exist in '${indir}': ${dtb}"


# ensure tools in tegra-uboot-flasher exist
[[ -x "${utils}/cbootimage" ]] || on_error "Error: Utility cbootimage does not exist in '${utils}'"

# ensure certain tools exist on the host
mcopy=$(find_filepath "mcopy") || on_error "Error: Program mcopy is not available."
parted=$(find_filepath "parted") || on_error "Error: Program parted is not available."
mkfs_vfat=$(find_filepath "mkfs.fat") || on_error "Error: Program mkfs.fat is not available."
mkfs_ext3=$(find_filepath "mkfs.ext3") || on_error "Error: Program mkfs.ext3 is not available."
truncate=$(find_filepath "truncate") || on_error "Error: Program truncate is not available."
dd=$(find_filepath "dd") || on_error "Error: Program dd is not available."

# create output directories
mkdir -p ${outdir} && echo "Output directory will be '${outdir}'"
outdir_bin=${outdir}/apalis-tk1
mkdir -p ${outdir_bin}

echo -e "\nCreating boot image"

# generate cbootimage containing the BCT and the U-Boot boot loader
pushd ${binaries} > /dev/null
${utils}/cbootimage -s ${cboot_image_target} ${cboot_image}.cfg ${outdir_bin}/${cboot_image}
popd > /dev/null

# boot partition in sectors of 512
boot_start=$(expr 4096 \* 2)
# rootfs partition in sectors of 512
rootfs_start=$(expr 20480 \* 2)
# boot partition volume id
boot_volume_id="boot"

echo -e "\nCreating MBR file and partitions."

# initialize a sparse file
${dd} if=/dev/zero of=${outdir_bin}/mbr.bin bs=512 count=0 seek=${emmc_size}
${parted} -s ${outdir_bin}/mbr.bin mklabel msdos
${parted} -a none -s ${outdir_bin}/mbr.bin unit s mkpart primary fat32 ${boot_start} $(expr ${rootfs_start} - 1)
# the partition spans to the end of the disk, even though the fs size will be smaller.
# the fs will be expaned to full size on the first boot.
${parted} -a none -s ${outdir_bin}/mbr.bin unit s mkpart primary ext2 ${rootfs_start} $(expr ${emmc_size} - ${rootfs_start} - 1)
${parted} -s ${outdir_bin}/mbr.bin unit s print
# get the size of the VFAT partition
boot_blocks=$(LC_ALL=C ${parted} -s ${outdir_bin}/mbr.bin unit b print \
            | awk '/ 1 / { print int(substr($4, 1, length($4 -1)) / 1024) }')
# now crop the file to the size of the mbr
img_size=512
${truncate} -s ${img_size} ${outdir_bin}/mbr.bin

echo -e "\nCreating VFAT partition with the kernel and dtb"

rm -f ${outdir_bin}/boot.vfat
${mkfs_vfat} -n "${boot_volume_id}" -S 512 -C ${outdir_bin}/boot.vfat ${boot_blocks}
export MTOOLS_SKIP_CHECK=1
${mcopy} -vi ${outdir_bin}/boot.vfat -s ${kernel} ::/$(basename ${kernel})
${mcopy} -vi ${outdir_bin}/boot.vfat -s ${dtb} ::/$(basename ${dtb})

echo -e "\nCreating rootfs partition image"

# make the partition size be (rootfs used + 100)
# add about 4% to the rootfs to account for fs overhead. (/1024/985 instead of /1024/1024).
# add 512 bytes per file to account for small files
# (resize it later on target to fill the size of the partition it lives in)
number_of_files=$(find ${rootfs} | wc -l)
echo "There are ${number_of_files} in the root directory"
ext_size=$(du -DsB1 ${rootfs} | awk -v min=100 -v f=${number_of_files} \
         '{rootfs_size=$1+f*512;rootfs_size=int(rootfs_size/1024/985); print (rootfs_size+min) }')

rm -f ${outdir_bin}/${rootfs_file}
${utils}/make_rootfs.sh -s ${ext_size} ${outdir_bin}/${rootfs_file} ${rootfs} || on_error "Error: Could not create rootfs image."

# populate output directory
pushd ${binaries} > /dev/null
cp ${dtb} ${kernel} flash*.img ${outdir_bin}
cp fwd_blk.img "${outdir}/flash_blk.img"
cp fwd_eth.img "${outdir}/flash_eth.img"
cp fwd_mmc.img "${outdir}/flash_mmc.img"
cp tftp_fw_update.img ${outdir}
popd > /dev/null

echo -e "\nSuccessfully populated output directory"

# apply crc32 checksum if needed
if [[ ${with_crc32} -eq 1 ]]; then
    echo -e "\nApplying CRC32 checksum ${checksum}"
    forcecrc32=${here}/forcecrc32.py
    if [[ -x ${forcecrc32} ]]; then
        ${forcecrc32} -o ${outdir_bin} ${checksum} ${outdir_bin}/*
    else
        on_error "Error: Program forcecrc32.py does not exist or is not executable."
    fi
fi

exit 0
