FILESEXTRAPATHS_prepend := "${THISDIR}/xinput-calibrator:"

# menu entry should make the calibration permanent instead of printing cal data into a terminal
do_install_append() {
    install -m 0755 ${D}/${datadir}/applications/xinput_calibrator.desktop ${D}/${datadir}/applications/xinput_calibrator.desktop.old
    sed -i -e 's/xinput_calibrator; cat/rm -f \/etc\/pointercal.xinput; xinput_calibrator_once.sh/' ${D}/${datadir}/applications/xinput_calibrator.desktop
    sed -i -e 's/Terminal\=true/Terminal=false/' ${D}/${datadir}/applications/xinput_calibrator.desktop
    sed -i -e 's/Terminal\=true/Terminal=false/' ${D}${sysconfdir}/xdg/autostart/xinput_calibrator.desktop
}
