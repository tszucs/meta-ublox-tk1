SUMMARY = "b205 board init"
LICENSE = "CLOSED"
PV = "1.0.0"
PR = "r0"

SRC_URI = " \
    file://b205.init \
    file://b205.conf \
    file://b205.service \
    file://setup.sh \
    file://spihost_write.py \
    file://spihost_write_ftdi.py \
"

COMPATIBLE_MACHINE = "apalis-tk1|apalis-tk1-b205"

inherit systemd

S = "${WORKDIR}"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install () {
    install -d ${D}/opt/b205/dev-tools ${D}/etc/default
    install -m 755 ${WORKDIR}/b205.init ${D}/opt/b205/
    install -m 644 ${WORKDIR}/b205.conf ${D}/etc/default/b205
    install -m 755 ${WORKDIR}/setup.sh ${D}/opt/b205/dev-tools/
    install -m 755 ${WORKDIR}/spihost_write.py ${D}/opt/b205/dev-tools/
    install -m 755 ${WORKDIR}/spihost_write_ftdi.py ${D}/opt/b205/dev-tools/

    install -d ${D}/${systemd_unitdir}/system
    install -m 644 ${WORKDIR}/b205.service ${D}/${systemd_unitdir}/system/
}

FILES_${PN} += " \
	/opt/b205/* \
	${systemd_unitdir}/system/* \
"

SYSTEMD_SERVICE_${PN} = "b205.service"

RDEPENDS_${PN} += "bash python"
