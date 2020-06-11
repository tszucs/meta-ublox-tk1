SUMMARY = "U-blox Laboratory Linux with LXDE "
SUMMARY_append_apalis-tk1-mainline = " (Mainline)"

LICENSE = "MIT"

#start of the resulting deployable tarball name
export IMAGE_BASENAME = "Lab-Image"
IMAGE_NAME_apalis-tk1 = "Apalis-TK1_${IMAGE_BASENAME}"
IMAGE_NAME_apalis-tk1-b205 = "Apalis_TK1_B205_${IMAGE_BASENAME}"
IMAGE_NAME_apalis-tk1-mainline = "Apalis-TK1-Mainline_${IMAGE_BASENAME}"
IMAGE_NAME = "${MACHINE}_${IMAGE_BASENAME}"

SYSTEMD_DEFAULT_TARGET = "graphical.target"

#create the deployment directory-tree
require recipes-images/images/ublox-image-fstype.inc


IMAGE_LINGUAS = "en-us"
#IMAGE_LINGUAS = "de-de fr-fr en-gb en-us pt-br es-es kn-in ml-in ta-in"
#ROOTFS_POSTPROCESS_COMMAND += 'install_linguas; '

DISTRO_UPDATE_ALTERNATIVES ??= ""
ROOTFS_PKGMANAGE_PKGS ?= '${@oe.utils.conditional("ONLINE_PACKAGE_MANAGEMENT", "none", "", "${ROOTFS_PKGMANAGE} ${DISTRO_UPDATE_ALTERNATIVES}", d)}'

CONMANPKGS ?= "connman connman-plugin-loopback connman-plugin-ethernet connman-plugin-wifi connman-client"
CONMANPKGS_libc-uclibc = ""

#deploy the OpenGL ES headers to the sysroot
DEPENDS_append_tegra = " nvsamples"


IMAGE_INSTALL_append_tegra = " \
    gpio-tool \
    tegrastats-gtk \
    gnome-disk-utility \
    mime-support \
    eglinfo-x11 \
    xvinfo \
"
IMAGE_INSTALL_append_tegra124 = " \
    gpio-tool \
    gnome-disk-utility \
    libglu \
    mesa-demos \
    freeglut \
    mime-support \
    tiff \
    xvinfo \
"
IMAGE_INSTALL_append_tegra124m = " \
    gnome-disk-utility \
    libglu \
    mesa-demos \
    freeglut \
    mime-support \
    tiff \
    xvinfo \
"
IMAGE_INSTALL_append_vf = " \
    gpio-tool \
    xf86-video-modesetting \
"

# Packages which might be empty or no longer available
RRECOMMENDS_${PN} += " \
    xserver-xorg-multimedia-modules \
    xserver-xorg-extension-dbe \
    xserver-xorg-extension-extmod \
"

IMAGE_INSTALL += " \
    gconf \
    gnome-vfs \
    gnome-vfs-plugin-file \
    gvfs \
    gvfsd-trash \
    xdg-utils \
    \
    libgsf \
    libxres \
    makedevs \
    xcursor-transparent-theme \
    zeroconf \
    angstrom-packagegroup-boot \
    packagegroup-basic \
    udev-extra-rules \
    ${CONMANPKGS} \
    ${ROOTFS_PKGMANAGE_PKGS} \
    timestamp-service \
    packagegroup-base-extended \
    ${XSERVER} \
    xserver-common \
    xauth \
    xhost \
    xset \
    setxkbmap \
    \
    xrdb \
    xorg-minimal-fonts xserver-xorg-utils \
    scrot \
    unclutter \
    \
    libxdamage libxvmc libxinerama \
    libxcursor \
    \
    florence3 \
    bash \
    \
    v4l-utils \
    libpcre \
    libpcreposix \
    libxcomposite \
    alsa-states \
"
require recipes-images/images/lx.inc
require recipes-images/images/ublox-extra.inc

IMAGE_DEV_MANAGER   = "udev"
IMAGE_INIT_MANAGER  = "systemd"
IMAGE_INITSCRIPTS   = " "
IMAGE_LOGIN_MANAGER = "busybox shadow"

inherit core-image
