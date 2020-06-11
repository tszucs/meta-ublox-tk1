#additional packages to include in our Toradex images

# Copy Licenses to image /usr/share/common-licenses, on vybrid for flash size reasons only the manifest
COPY_LIC_MANIFEST ?= "1"
#Bug with several MACHINES build, license files for all arch packages stored wrongly
COPY_LIC_DIRS ?= "0"
COPY_LIC_DIRS_colibri-vf = "0"

#build some ipk which are needed together with CAN, but do not yet install them
DEPENDS += "canutils libsocketcan iproute2"

add_rootfs_version () {
    echo -n "${IMAGE_NAME} ${PV}" >> ${IMAGE_ROOTFS}/etc/issue
    echo " ${TDX_VERDATE}" | sed 's/-//' >>${IMAGE_ROOTFS}/etc/issue
    echo "" >> ${IMAGE_ROOTFS}/etc/issue
}

# add the rootfs version to the welcome banner
ROOTFS_POSTPROCESS_COMMAND += " add_rootfs_version;"

IMAGE_INSTALL_append_tegra = " \
    u-boot-toradex-fw-utils \
    tegrastats \
    tdx-nv-binaries \
    tdx-nv-binaries-nv-gstapps \
    tdx-nv-binaries-restricted-codecs \
    usb-rndis-systemd \
    hdmi-hotplug \
    \
    curl \
    file \
    aspell \
    kernel-modules \
"

IMAGE_INSTALL_append_tegra124 = " \
    aspell \
    canutils \
    curl \
    e2fsprogs \
    e2fsprogs-mke2fs \
    e2fsprogs-tune2fs \
    file \
    fs-init \
    hdmi-hotplug \
    kernel-modules \
    linuxptp \
    lvds-tegra124 \
    pciutils \
    ptpd \
    tegrastats \
    u-boot-toradex-fw-utils \
    usb-rndis-systemd \
"
IMAGE_INSTALL_append_tegra124m = " \
    aspell \
    canutils \
    curl \
    e2fsprogs \
    e2fsprogs-mke2fs \
    e2fsprogs-tune2fs \
    file \
    fs-init \
    hdmi-hotplug \
    kernel-modules \
    linuxptp \
    lvds-tegra124 \
    pciutils \
    ptpd \
    u-boot-toradex-fw-utils \
"

IMAGE_INSTALL_append_apalis-t30 = " \
    linuxptp \
    pciutils \
    ptpd \
    iproute2 \
    canutils \
    lvds-ctrl \
"

IMAGE_INSTALL_append_apalis-tk1-b205 = " \
    b205 \
    python-pip \
"

IMAGE_INSTALL += " \
    packagegroup-dotnet-deps \
    \
    crda \
    linux-firmware-ralink \
    linux-firmware-rtl8192cu \
    \
    alsa-utils \
    alsa-utils-aplay \
    alsa-utils-amixer \
    \
    sqlite3 \
    \
    curl \
    nfs-utils-client \
    openssh-scp \
    openssh-sftp \
    \
    bzip2 \
    grep \
    joe \
    minicom \
    ldd \
    lsof \
    mtd-utils \
    dosfstools \
    util-linux-fstrim \
    \
    devmem2 \
    evtest \
    hdparm \
    iperf3 \
    i2c-tools \
    memtester \
    mmc-utils-cos \
    rt-tests \
    stress \
    lmbench \
    nbench-byte \
    tinymembench \
    ethtool \
    \
    bluez5 \
    bluez5-testtools \
    bluez-hcidump \
    bridge-utils \
    mc \
    python \
    python-json \
    python-pprint \
    python-argparse \
    python-subprocess \
    python-dbus \
    screen \
    hostapd \
"
