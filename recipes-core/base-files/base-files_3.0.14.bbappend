FILESEXTRAPATHS_prepend := "${THISDIR}/base-files:"

do_install_angstromissue_append() {
    echo ${UBLOX_HOSTNAME} > ${D}${sysconfdir}/hostname
}
