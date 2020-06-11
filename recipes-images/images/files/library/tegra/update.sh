#!/bin/sh
# Prepare files needed for flashing an Apalis/Colibri T20/T30/TK1 module and
# copy them to a convenient location for using from a running U-Boot

SUDO=`which sudo`

# exit on error
set -e

Flash()
{
	echo "To flash the Apalis/Colibri T20/T30/TK1 module a running U-Boot is required. Boot"
	echo "the module to the U-Boot prompt and"
	echo ""
	echo "insert the SD card, USB flash drive or when using TFTP connect Ethernet only"
	echo "and enter:"
	echo "'run setupdate'"
	echo ""
	echo "then to update all components enter:"
	echo "'run update'"
	echo ""
	echo "Alternatively, to update U-Boot enter:"
	echo "'run update_uboot'"
	echo "to update a component stored in UBI enter:"
	echo "'run prepare_ubi' (for Colibri T20)"
	echo "followed by one of:"
	echo "'run update_kernel'"
	echo "'run update_fdt' (for device tree enabled kernels)"
	echo "'run update_rootfs'"
	echo ""
	echo ""
	echo "If you don't have a working U-Boot anymore, connect your PC to the module's USB"
	echo "client port, bring the module into the recovery mode and start the update.sh"
	echo "script with the -d option. This will copy U-Boot into the module's RAM and"
	echo "execute it."
}

Usage()
{
	echo ""
	echo "Prepares and copies files for flashing internal eMMC/NAND of Apalis T30/TK1 and"
	echo "Colibri T20/T30"
	echo ""
	echo "Will require a running U-Boot on the target. Either one already flashed on the"
	echo "eMMC/NAND or one copied over USB into the module's RAM"
	echo ""
	echo "-b           : T20: selects boot device (hsmmc/nand) (default: nand)"
	echo "-d           : use USB recovery mode to copy/execute U-Boot to/from module's RAM"
	echo "-f           : flash instructions"
	echo "-h           : prints this message"
	echo "-m           : module type: 0: autodetect from ./rootfs/etc/issues (default)"
	echo "                            1: Apalis T30"
	echo "                            2: Apalis TK1"
	echo "                            3: Colibri T20"
	echo "                            4: Colibri T30"
	echo "-o directory : output directory"
	echo "-r           : T20 recovery mode: select RAM size (256 | 512)"
	echo "-s           : T20: optimise file system for V1.1 or 256MB V1.2 modules,"
	echo "               increases usable space a little, but limits 512MB V1.2 modules"
	echo "               to 512MB usable NAND space"
	echo "-v           : T20 recovery mode: select Colibri version (V1_1 | V1_2)"
	echo ""
	echo "Example \"./update.sh -o /srv/tftp/\" copies the required files to /srv/tftp/"
	echo ""
	echo "*** For detailed recovery/update procedures, refer to the following website: ***"
        echo "http://developer.toradex.com/knowledge-base/flashing-linux-on-tegra-modules"
	echo ""
}

# initialise options
BOOT_DEVICE=nand
EMMC_PARTS="mbr.bin boot.vfat" 
# no devicetree by default
KERNEL_DEVICETREE=""
KERNEL_IMAGETYPE="zImage"
MIN_PARTITION_FREE_SIZE=300
MODTYPE_DETECT=0

# NAND parameters
BLOCK="248KiB 504KiB"
MAXLEB=4084
PAGE="4KiB"

OUT_DIR=""
ROOTFSPATH=rootfs
SPLIT=1
UBOOT_RECOVERY=0

# don't provide working defaults which may lead to wrong HW/SW combination
MODVERSION=Add_Version_-v
RAM_SIZE=Add_RAMsize_-r

while getopts "b:dfhm:o:r:sv:" Option ; do
	case $Option in
		b)	BOOT_DEVICE=$OPTARG
			;;
		d)	UBOOT_RECOVERY=1
			;;
		f)	Flash
			exit 0
			;;
		h)	Usage
			exit 0
			;;
		m)	MODTYPE_DETECT=$OPTARG
			;;
		o)	OUT_DIR=$OPTARG
			;;
		r)	RAM_SIZE=$OPTARG
			;;
		s)	MAXLEB=2042
			;;
		v)	if [ "${OPTARG}" = "V1_1" ] ; then MODVERSION=v11; fi
			if [ "${OPTARG}" = "V1_2" ] ; then MODVERSION=v12; fi
			;;
	esac
done

if [ "$OUT_DIR" = "" ] && [ "$UBOOT_RECOVERY" = "0" ] ; then
	Usage
	exit 1
fi

# is OUT_DIR an existing directory?
if [ ! -d "$OUT_DIR" ] && [ "$UBOOT_RECOVERY" = "0" ] ; then
	echo "$OUT_DIR" "does not exist, exiting"
	exit 1
fi

case $MODTYPE_DETECT in
	0)	# auto detect MODTYPE from rootfs directory
		if [ -f rootfs/etc/issue ] ; then
			CNT=`grep -ic "apalis" rootfs/etc/issue || true`
			if [ "$CNT" -ge 1 ] ; then
				CNT=`grep -ic "t30" rootfs/etc/issue || true`
				if [ "$CNT" -ge 1 ] ; then
					echo "Apalis T30 rootfs detected"
					MODTYPE=apalis-t30
				else
					CNT=`grep -ic "tk1" rootfs/etc/issue || true`
					if [ "$CNT" -ge 1 ] ; then
						echo "Apalis TK1 rootfs detected"
						MODTYPE=apalis-tk1

						CNT=`grep -ic "mainline" rootfs/etc/issue || true`
						if [ "$CNT" -ge 1 ] ; then
							echo "Mainline variant"
							MODTYPE=apalis-tk1-mainline
						fi

						CNT=`grep -ic "b205" rootfs/etc/issue || true`
						if [ "$CNT" -ge 1 ] ; then
							echo "B205 variant"
							MODTYPE=apalis-tk1-b205
						fi
					fi

				fi
			else
				CNT=`grep -ic "colibri" rootfs/etc/issue || true`
				if [ "$CNT" -ge 1 ] ; then
					CNT=`grep -ic "t20" rootfs/etc/issue || true`
					if [ "$CNT" -ge 1 ] ; then
						echo "Colibri T20 rootfs detected"
						MODTYPE=colibri-t20
					else
						CNT=`grep -ic "t30" rootfs/etc/issue || true`
						if [ "$CNT" -ge 1 ] ; then
							echo "Colibri T30 rootfs detected"
							MODTYPE=colibri-t30
						fi
					fi
				fi
			fi
		fi
		if [ -e $MODTYPE ] ; then
			echo "can not detect module type from ./rootfs/etc/issue"
			echo "please specify the module type with the -m parameter"
			echo "see help: '$ ./update.sh -h'"
			echo "exiting"
			exit 1
		fi
		;;
	1)	MODTYPE=apalis-t30
		echo "Apalis T30 rootfs specified"
		;;
	2)	MODTYPE=apalis-tk1
		echo "Apalis TK1 rootfs specified"
		;;
	3)	MODTYPE=colibri-t20
		echo "Colibri T20 rootfs specified"
		;;
	4)	MODTYPE=colibri-t30
		echo "Colibri T30 rootfs specified"
		;;
	*)	echo "-m paramter specifies an unknown value"
		exit 1
		;;
esac

case "$MODTYPE" in
	"apalis-t30")
                # note: requires changing apalis-t30_bin/apalis_t30.img.cfg as well
#		BCT=apalis_t30_12MHz_MT41K512M8RH-125_533MHz.bct
		BCT=Apalis_T30_2GB_800Mhz.bct
		CBOOT_IMAGE=apalis_t30.img
		CBOOT_IMAGE_TARGET=tegra30
		# assumed minimal eMMC size [in sectors of 512]
		EMMC_SIZE=$(expr 1024 \* 7450 \* 2)
		IMAGEFILE=root.ext3
		KERNEL_DEVICETREE="tegra30-apalis-eval.dtb"
		LOCPATH="tegra-uboot-flasher"
		OUT_DIR="$OUT_DIR/apalis_t30"
		U_BOOT_BINARY=u-boot-dtb-tegra.bin
		;;
    "apalis-tk1" | "apalis-tk1-mainline" | "apalis-tk1-b205")
		BCT=PM375_Hynix_2GB_H5TC4G63AFR_RDA_924MHz.bct
		CBOOT_IMAGE=apalis-tk1.img
		CBOOT_IMAGE_TARGET=tegra124
		# assumed minimal eMMC size [in sectors of 512]
		EMMC_SIZE=$(expr 1024 \* 15020 \* 2)
		IMAGEFILE=root.ext4
		KERNEL_DEVICETREE="tegra124-apalis-eval.dtb tegra124-apalis-v1.2-eval.dtb"
		LOCPATH="tegra-uboot-flasher"
		OUT_DIR="$OUT_DIR/apalis-tk1"
		U_BOOT_BINARY=u-boot-dtb-tegra.bin
		;;
	"colibri-t20")
		BCT=colibri_t20-${RAM_SIZE}-${MODVERSION}-${BOOT_DEVICE}.bct
		CBOOT_IMAGE="colibri_t20-256-v11-nand.img colibri_t20-256-v12-nand.img colibri_t20-512-v11-nand.img colibri_t20-512-v12-nand.img"
		CBOOT_IMAGE_TARGET=tegra20
		EMMC_PARTS=""
		IMAGEFILE=ubifs
		KERNEL_DEVICETREE="tegra20-colibri-eval-v3.dtb"
		KERNEL_IMAGETYPE="zImage"
		LOCPATH="tegra-uboot-flasher"
		OUT_DIR="$OUT_DIR/colibri_t20"
		U_BOOT_BINARY=u-boot-dtb-tegra.bin
		;;
	"colibri-t30")
		# with new kernel, boot with 400MHz, then switch between 400 & 800
		# note: requires changing colibri-t30_bin/colibri_t30.img.cfg as well
		BCT=colibri_t30_12MHz_NT5CC256M16CP-DI_400MHz.bct
#		BCT=colibri_t30_12MHz_NT5CC256M16CP-DI_533MHz.bct
		CBOOT_IMAGE=colibri_t30.img
		CBOOT_IMAGE_TARGET=tegra30
		EMMC_SIZE=$(expr 1024 \* 3640 \* 2)
		IMAGEFILE=root.ext3
		KERNEL_DEVICETREE="tegra30-colibri-eval-v3.dtb"
		LOCPATH="tegra-uboot-flasher"
		OUT_DIR="$OUT_DIR/colibri_t30"
		U_BOOT_BINARY=u-boot-dtb-tegra.bin
		;;
	*)	echo "script internal error, unknown module type set"
		exit 1
		;;
esac

BINARIES=${MODTYPE}_bin

#is only U-Boot to be copied to RAM?
if [ "$UBOOT_RECOVERY" -eq 1 ] ; then
	if [ "${MODTYPE}" = "colibri-t20" ] ; then
		#some sanity test, we really need RAM_SIZE and MODVERSION set
		echo ""
		SANITY_CHECK=1
		if [ "256" != ${RAM_SIZE} ] && [ "512" != ${RAM_SIZE} ]; then
			printf "\033[1mplease specify your RAM size with the -r parameter\033[0m\n"
			SANITY_CHECK=0
		fi

		if [ "v11" != ${MODVERSION} ] && [ "v12" != ${MODVERSION} ]; then
			printf "\033[1mplease specify your module version with the -v parameter\033[0m\n"
			SANITY_CHECK=0
		fi

		if [ ${SANITY_CHECK} -eq 0 ] ; then
			Usage
			exit 1
		fi
	fi

	cd ${LOCPATH}
	$SUDO ./tegrarcm --bct=../${BINARIES}/${BCT} --bootloader=../${BINARIES}/${U_BOOT_BINARY} --loadaddr=0x80108000 --usb-timeout=5000
	exit
fi

#sanity check for awk programs
AWKTEST=`echo 100000000 | awk -v min=100 -v f=10000 '{rootfs_size=$1+f*512;rootfs_size=int(rootfs_size/1024/985); print (rootfs_size+min) }'` || true
[ "${AWKTEST}x" = "204x" ] || { echo >&2 "Program awk not available.  Aborting."; exit 1; }

#sanity check for correct untared rootfs
DEV_OWNER=`ls -ld rootfs/dev | awk '{print $3}'`
if [ "${DEV_OWNER}x" != "rootx" ]
then
	printf "rootfs/dev is not owned by root, but it should!\n"
	printf "\033[1mPlease unpack the tarball with root rights.\033[0m\n"
	printf "e.g. sudo tar xjvf Apalis_T30_LinuxImageV2.6Beta1_20160331.tar.bz2\n"
	exit 1
fi

#sanity check for existence of U-Boot and kernel
[ -e ${BINARIES}/${U_BOOT_BINARY} ] || { echo "${BINARIES}/${U_BOOT_BINARY} does not exist"; exit 1; }
[ -e ${BINARIES}/${KERNEL_IMAGETYPE} ] || { echo "${BINARIES}/${KERNEL_IMAGETYPE} does not exist"; exit 1; }

#Sanity check for some programs. Some distros have fs tools only in root's path
MCOPY=`command -v mcopy` || { echo >&2 "Program mcopy not available.  Aborting."; exit 1; }
PARTED=`command -v parted` || PARTED=`sudo -s command -v parted` || { echo >&2 "Program parted not available.  Aborting."; exit 1; }
MKFSVFAT=`command -v mkfs.fat` || MKFSVFAT=`sudo -s command -v mkfs.fat` || { echo >&2 "Program mkfs.fat not available.  Aborting."; exit 1; }
MKFSEXT3=`command -v mkfs.ext3` || MKFSEXT3=`sudo -s command -v mkfs.ext3` || { echo >&2 "Program mkfs.ext3 not available.  Aborting."; exit 1; }
MKFSEXT4=`command -v mkfs.ext4` || MKFSEXT4=`sudo -s command -v mkfs.ext4` || { echo >&2 "Program mkfs.ext4 not available.  Aborting."; exit 1; }
dd --help >/dev/null 2>&1 || { echo >&2 "Program dd not available.  Aborting."; exit 1; }

CBOOT_CNT=`tegra-uboot-flasher/cbootimage -h | grep -c outputimage || true`
[ "$CBOOT_CNT" -gt 0 ] || { echo >&2 "Program cbootimage not available. 32bit compatibility libs?  Aborting."; exit 1; }

if [ "${MODTYPE}" = "colibri-t20" ] ; then
	#sanity check, can we execute mkfs.ubifs, e.g. see the help text?
	CNT=`$SUDO $LOCPATH/mkfs.ubifs -h | grep -c space-fixup || true`
	if [ "$CNT" -eq 0 ] ; then
		echo "The program mkfs.ubifs can not be executed or does not provide --space-fixup"
		echo "option."
		echo "Are you on a 64-bit Linux host without installed 32-bit execution environment?"
		printf "\033[1mPlease install e.g. ia32-libs on 64-bit Ubuntu\033[0m\n"
		printf "\033[1mMaybe others are needed e.g. liblzo2:i386 on 64-bit Ubuntu\033[0m\n"
		exit 1
	fi
fi

#Install trap to write a sensible message in case any of the commands below
#exit premature...
trap '{ printf "\033[31mScript aborted unexpectedly...\033[0m\n"; }' EXIT

#make the directory with the outputfiles writable
$SUDO chown $USER: ${BINARIES}

#make a file with the used versions for U-Boot, kernel and rootfs
$SUDO touch ${BINARIES}/versions.txt
$SUDO chmod ugo+w ${BINARIES}/versions.txt
echo "Component Versions" > ${BINARIES}/versions.txt
basename "`readlink -e ${BINARIES}/${U_BOOT_BINARY}`" >> ${BINARIES}/versions.txt
basename "`readlink -e ${BINARIES}/${KERNEL_IMAGETYPE}`" >> ${BINARIES}/versions.txt
ROOTFSVERSION=`egrep -i 't([2-3]0|k1)' rootfs/etc/issue || echo "Version Unknown"`
echo "Rootfs ${ROOTFSVERSION}" >> ${BINARIES}/versions.txt

#create subdirectory for this module type
$SUDO mkdir -p "$OUT_DIR"

# The eMMC layout used is:
#
# boot area partition 1 aka primary eMMC boot sector:
# with cbootimage containing BCT and U-Boot boot loader and the U-Boot
# environment before the configblock at the end of that boot area partition
#
# boot area partition 2 aka secondary eMMC boot sector:
# reserved
#
# user area aka general purpose eMMC region:
#
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - reserved (not partitioned)
#    IMAGE_ROOTFS_ALIGNMENT -> BOOT_SPACE                     - kernel and other data
#    BOOT_SPACE             -> SDIMG_SIZE                     - rootfs
#
#            4MiB               16MiB           SDIMG_ROOTFS
# <-----------------------> <----------> <---------------------->
#  ------------------------ ------------ ------------------------
# | IMAGE_ROOTFS_ALIGNMENT | BOOT_SPACE | ROOTFS_SIZE            |
#  ------------------------ ------------ ------------------------
# ^                        ^            ^                        ^
# |                        |            |                        |
# 0                      4MiB      4MiB + 16MiB              EMMC_SIZE

# generate cbootimage(s) containing BCT(s) and U-Boot boot loader
cd ${BINARIES}
for cbootimage in ${CBOOT_IMAGE}; do
	$SUDO ../${LOCPATH}/cbootimage -s ${CBOOT_IMAGE_TARGET} ${cbootimage}.cfg ${cbootimage}
done
cd ..

if [ "${MODTYPE}" = "colibri-t20" ] ; then
	# Prepare full flashing
	#build ${IMAGEFILE} if it does not exist
	for blocksize in ${BLOCK}; do
		$SUDO $LOCPATH/mkfs.ubifs --space-fixup -c ${MAXLEB} -e ${blocksize} -m ${PAGE} -o ${BINARIES}/${IMAGEFILE}_${blocksize}.img -r rootfs/ -v
	done

	echo ""
	echo "UBI image of root file system generated, copying data to target folder..."
else
	if [ "${MODTYPE}" = "apalis-t30" ] || [ "${MODTYPE}" = "apalis-tk1" ] || [ "${MODTYPE}" = "apalis-tk1-mainline" ] || [ "${MODTYPE}" = "apalis-tk1-b205" ] || [ "${MODTYPE}" = "colibri-t30" ] ; then
		# Boot partition [in sectors of 512]
		BOOT_START=$(expr 4096 \* 2)
		# Rootfs partition [in sectors of 512]
		ROOTFS_START=$(expr 20480 \* 2)
		# Boot partition volume id
		BOOTDD_VOLUME_ID="boot"

		echo ""
		echo "Creating MBR file and do the partitioning"
		# Initialize a sparse file
		dd if=/dev/zero of=${BINARIES}/mbr.bin bs=512 count=0 seek=${EMMC_SIZE}
		${PARTED} -s ${BINARIES}/mbr.bin mklabel msdos
		${PARTED} -a none -s ${BINARIES}/mbr.bin unit s mkpart primary fat32 ${BOOT_START} $(expr ${ROOTFS_START} - 1 )
		# the partition spans to the end of the disk, even though the fs size will be smaller
		# on the target the fs is then grown to the full size
		if [ "${IMAGEFILE}" = "root.ext3" ] ; then
			${PARTED} -a none -s ${BINARIES}/mbr.bin unit s mkpart primary ext3 ${ROOTFS_START} $(expr ${EMMC_SIZE} \- ${ROOTFS_START} \- 1)
		else
			${PARTED} -a none -s ${BINARIES}/mbr.bin unit s mkpart primary ext4 ${ROOTFS_START} $(expr ${EMMC_SIZE} \- ${ROOTFS_START} \- 1)
		fi
		${PARTED} -s ${BINARIES}/mbr.bin unit s print 
		# get the size of the VFAT partition
		BOOT_BLOCKS=$(LC_ALL=C ${PARTED} -s ${BINARIES}/mbr.bin unit b print \
			| awk '/ 1 / { print int(substr($4, 1, length($4 -1)) / 1024) }')
		# now crop the file to only the MBR size
		IMG_SIZE=512
		truncate -s $IMG_SIZE ${BINARIES}/mbr.bin


		echo ""
		echo "Creating VFAT partition image with the kernel"
		rm -f ${BINARIES}/boot.vfat
		${MKFSVFAT} -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${BINARIES}/boot.vfat $BOOT_BLOCKS 
		export MTOOLS_SKIP_CHECK=1
		mcopy -i ${BINARIES}/boot.vfat -s ${BINARIES}/${KERNEL_IMAGETYPE} ::/${KERNEL_IMAGETYPE}

		# Copy device tree file
		COPIED=false
		if test -n "${KERNEL_DEVICETREE}"; then
			for DTS_FILE in ${KERNEL_DEVICETREE}; do
				DTS_BASE_NAME=`basename ${DTS_FILE} .dtb`
				if [ -e "${BINARIES}/${KERNEL_IMAGETYPE}-${DTS_BASE_NAME}.dtb" ]; then
					kernel_bin="`readlink ${BINARIES}/${KERNEL_IMAGETYPE}`"
					kernel_bin_for_dtb="`readlink ${BINARIES}/${KERNEL_IMAGETYPE}-${DTS_BASE_NAME}.dtb | sed "s,$DTS_BASE_NAME,${MODTYPE},g;s,\.dtb$,.bin,g"`"
					if [ "$kernel_bin" = "$kernel_bin_for_dtb" ]; then
						mcopy -i ${BINARIES}/boot.vfat -s ${BINARIES}/${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${DTS_BASE_NAME}.dtb ::/${DTS_BASE_NAME}.dtb
						#copy also to out_dir
						$SUDO cp ${BINARIES}/${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${DTS_BASE_NAME}.dtb "$OUT_DIR/${DTS_BASE_NAME}.dtb"
						COPIED=true
					fi
				fi
			done
            ([ "${MODTYPE}" = "apalis-tk1" ] || [ "${MODTYPE}" = "apalis-tk1-mainline" ] || [ "${MODTYPE}" = "apalis-tk1-b205" ]) && ([ $COPIED = true ] || { echo "Did not find the devicetrees from KERNEL_DEVICETREE, ${KERNEL_DEVICETREE}.  Aborting."; exit 1; })
		fi

		echo ""
		echo "Creating rootfs partition image"
		#make the partition size size(rootfs used + MIN_PARTITION_FREE_SIZE)
		#add about 4% to the rootfs to account for fs overhead. (/1024/985 instead of /1024/1024).
		#add 512 bytes per file to account for small files
		#(resize it later on target to fill the size of the partition it lives in)
		NUMBER_OF_FILES=`$SUDO find ${ROOTFSPATH} | wc -l`
		EXT_SIZE=`$SUDO du -DsB1 ${ROOTFSPATH} | awk -v min=$MIN_PARTITION_FREE_SIZE -v f=${NUMBER_OF_FILES} \
				'{rootfs_size=$1+f*512;rootfs_size=int(rootfs_size/1024/985); print (rootfs_size+min) }'`

		rm -f ${BINARIES}/${IMAGEFILE}
		if [ "${IMAGEFILE}" = "root.ext3" ] ; then
			$SUDO $LOCPATH/genext3fs.sh -d rootfs -b ${EXT_SIZE} ${BINARIES}/${IMAGEFILE} || exit 1
		else
			$SUDO $LOCPATH/genext4fs.sh -d rootfs -b ${EXT_SIZE} ${BINARIES}/${IMAGEFILE} || exit 1
		fi
	fi
fi

#copy to $OUT_DIR
OUT_DIR=`readlink -f $OUT_DIR`
cd ${BINARIES}
$SUDO cp ${CBOOT_IMAGE} ${KERNEL_IMAGETYPE} ${EMMC_PARTS} flash*.img versions.txt "$OUT_DIR"
$SUDO cp fwd_blk.img "$OUT_DIR/../flash_blk.img"
$SUDO cp fwd_eth.img "$OUT_DIR/../flash_eth.img"
$SUDO cp fwd_mmc.img "$OUT_DIR/../flash_mmc.img"

if [ "${IMAGEFILE}" = "root.ext3" ] || [ "${IMAGEFILE}" = "root.ext4" ] ; then
	if [ "$SPLIT" -ge 1 ] ; then
		$SUDO split -a 3 -b `expr 64 \* 1024 \* 1024` --numeric-suffixes=100 ${IMAGEFILE} "${OUT_DIR}/${IMAGEFILE}-"
	fi
else
	$SUDO cp ${IMAGEFILE}* "$OUT_DIR"
fi

#cleanup intermediate files
$SUDO rm ${CBOOT_IMAGE} ${EMMC_PARTS} ${IMAGEFILE}* versions.txt
cd ..
sync

#Remove trap and report success!
trap - EXIT
printf "\033[32mSuccessfully copied data to target folder.\033[0m\n\n"

Flash
