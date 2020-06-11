SRC_URI += "file://LICENCE"

do_fix_lic() {
    cp -f ${WORKDIR}/LICENCE ${WORKDIR}/tdx-k20-fw-1.0/LICENCE
}

addtask do_fix_lic before do_populate_lic after do_unpack
