FILESEXTRAPATHS_prepend := "${THISDIR}/linux-driver-package:"

SRC_URI_append = " file://xorg.conf \
                              file://nvfb.service \
                              file://nv.service"

do_install_append () {
    cp ${WORKDIR}/xorg.conf ${D}/etc/X11/
    install -d ${D}${systemd_unitdir}/system/
    install -m 0755 ${WORKDIR}/nvfb.service ${D}${systemd_unitdir}/system
    install -m 0755 ${WORKDIR}/nv.service ${D}${systemd_unitdir}/system
}
