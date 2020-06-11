#!/usr/bin/env bash
#
# Flash the uboot, kernel, dtb, boot partition and rootfs of apalis-tk1 using DFU.
#
# Before using this tool, make sure the device is ready to receive data: In uboot issue
#
#   $ dfu 0 mmc 0
#
# to enter DFU mode, then you should see a new USB device when doing lsusb on your host.
#
# Note: the uboot variable dfu_alt_info should look like this:
#
#   dfu_alt_info=apalis-tk1.img raw 0x0 0x500 mmcpart 1;boot part 0 1 mmcpart 0;rootfs part 0 2 mmcpart 0;zImage fat 0 1 mmcpart 0;tegra124-apalis-eval.dtb fat 0 1 mmcpart 0
#
# especially without whitespace after the semicolon, older versions of uboot may have whitespaces in this variable.
#
# To run this tool, unpack the archive Apalis_TK1_LinuxConsoleImageV2.7_20170207.tar.bz2 which was created during
# the build process. The directory structure will be like the following:
#
#     Apalis_TK1_LinuxConsoleImageV2.7
#     |
#     |__ apalis-tk1_bin/
#     |__ rootfs/
#     |__ tegra-uboot-flasher/
#     |__ dfu_fw_update.sh
#     |__ update.sh
#
# Run this tool inside the folder or use -p to point it to the folder. Please, have a look at the help message
# for further details. Note, this tool will ensure that the directory "rootfs/" inside the archive is owned by root,
# otherwise update.sh would complain. This way, you don't have to be root when unpacking the archive.
#
# The tool will not reset the target device after successful flashing. Do it manually by issuing
#
#   $ reset
#
# at the uboot prompt.
#
# Author: Robert Noack (robert.noack@u-blox.com)
#
# Copyright (C) 2017 u-blox AG
#

set -e

function print_help() {
    cat << EOF
Usage: $0 [options] target

Ensure that the target has loaded U-Boot and DFU mode is enabled
before the script is executed.

Arguments
    target: Image to replace (altsetting in DFU terms)
            One of [all, kernel, uboot, bootpart, dtb, rootfs]

Optional Arguments
    -n             Dry-run. Execute without effecting the board.
    -o <PATH>      Output directory for prepared files.
    -p <PATH>      Path to the unpacked archive. Default is the current directory.
    -t             Don't run update.sh to prepare image files. Assume they have been created.
    -h             Show this message and exit.
EOF
}

# print the number of elements in the first argument. The argument must be a string.
function howmany() {
    input=( $1 )
    echo ${#input[@]}
}

# used for dry run. print all arguments as a string.
function echo_cmd() {
    echo "$@"
}

# print an error message and exit
function on_error() {
    local error_msg=$1
    echo -e ${error_msg} 1>&2
    exit 1
}

# default parameters
fw_path="."
do_prepare=1
out_dir="./out"

function parse_args() {
    while getopts ":hno:p:rt" opt; do
        case ${opt} in
            n)
                dry_run=1
                ;;
            o)
                out_dir=${OPTARG}
                ;;
            p)
                fw_path=${OPTARG}
                ;;
            h)
                print_help
                exit 0
                ;;
            t)
                do_prepare=0
                ;;
            \?)
                on_error "Error: Invalid option: -${OPTARG}\n"
                ;;
        esac
    done

    shift $((OPTIND-1))
    [[ $# -eq 1 ]] || on_error "Error: Missing arguments.\n"
    [[ -d ${fw_path} ]] || on_error "Error: Directory not found: ${fw_path}\n"
    [[ -f ${fw_path}/update.sh ]] || on_error "Error: No update.sh in the target directory\n"

    fw_path=$(realpath ${fw_path})
    out_dir=$(readlink -m ${out_dir})
    target=$1
}

function check_file() {
    local path=$1
    local name=$2
    local label=$3
    local filename=${path}/${name}

    [[ -f ${filename} ]] || on_error "Error: Could not find ${filename}. Label: ${label}"
    echo "${label}: ${filename}" 1>&2
    echo "${filename}"
}

function get_rootfs() {
    local path="$1"
    local rootfs_name="root.ext4"
    local filename="${path}/${rootfs_name}"

    if ! [[ -f ${filename} ]]; then
        # update.sh splits the rootfs into multiple files.
        # we have to concatenate them first.
        local match=$(find "${path}" -name "${rootfs_name}-*" -type f)
        [[ $(howmany "${match}") -ge 1 ]] || \
            on_error "Error: Could not find rootfs. Was looking in ${path}"
        ${dry_echo} cat ${path}/${rootfs_name}* > "${path}/${rootfs_name}" || \
            on_error "Error: Could not create rootfs"
    fi

    echo "ROOTFS: ${filename}" 1>&2
    echo "${filename}"
}

function prepare_files() {
    # after unpacking Apalis_TK1_LinuxConsoleImageV2.7_20170207.tar.bz2
    # we need to run update.sh to create the needed images
    local update="$1"
    local where="$2"

    echo "Preparing image files by executing update.sh"
    echo "Output directory will be ${where}"

    ${dry_echo} mkdir -vp ${where}
    pushd ${fw_path}
    # make sure the rootfs is owned by the root user, update.sh will complain otherwise.
    ${dry_echo} chown -R root:root rootfs/
    ${dry_echo} ${update} -o ${where}
    popd
}

# MAIN
echo -e "DFU Firmware Updater\n"
parse_args $@

dry_echo=
if [[ ${dry_run} -eq 1 ]]; then
    echo -e "Dry run enabled.\n"
    dry_echo=echo_cmd
fi

[[ ${do_prepare} -eq 1 ]] && prepare_files "${fw_path}/update.sh" "${out_dir}"

image_dir="$out_dir/apalis-tk1"

[[ ${target} == "all" || ${target} == "uboot" ]] && \
    UBOOT=$(check_file ${image_dir} "apalis-tk1.img" "UBOOT") \

[[ ${target} == "all" || ${target} == "bootpart" ]] && \
    BOOTPART=$(check_file ${image_dir} "boot.vfat" "BOOTPART")

[[ ${target} == "all" || ${target} == "dtb" ]] && \
    DTB=$(check_file ${image_dir} "tegra124-apalis-eval.dtb" "DTB")

[[ ${target} == "all" || ${target} == "kernel" ]] && \
    KERNEL=$(check_file ${image_dir} "zImage" "KERNEL")

[[ ${target} == "all" || ${target} == "rootfs" ]] && \
    ROOTFS=$(get_rootfs ${image_dir})

echo -e "\nImage files have been prepared and the selected parts were found in the output directory."
echo "Press return to continue."
read
echo -e "Running upgrade now!\n"

uboot_tgt=apalis-tk1.img
bootpart_tgt=boot
dtb_tgt=tegra124-apalis-eval.dtb
kernel_tgt=zImage
rootfs_tgt=rootfs

[[ -z "${UBOOT}" ]] || ${dry_echo} dfu-util -va ${uboot_tgt} -D ${UBOOT}
[[ -z "${BOOTPART}" ]] || ${dry_echo} dfu-util -va ${bootpart_tgt} -D ${BOOTPART}
[[ -z "${DTB}" ]] || ${dry_echo} dfu-util -va ${dtb_tgt} -D ${DTB}
[[ -z "${KERNEL}" ]] || ${dry_echo} dfu-util -va ${kernel_tgt} -D ${KERNEL}
[[ -z "${ROOTFS}" ]] || ${dry_echo} dfu-util -va ${rootfs_tgt} -D ${ROOTFS}

exit 0
