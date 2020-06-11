FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

SRC_URI_append_apalis-tk1 += " \
    file://0001-mmc-tegra-add-signal-voltage-override.patch \
    file://0002-apalis-tk1-set-1.8-V-signal-level-for-SDMMC1.patch \
    file://0003-apalis-tk1-disable-lvds-and-disable-dc-warnings.patch \
    file://defconfig \
"

SRC_URI_append_apalis-tk1-b205 += " \
    file://0001-mmc-tegra-add-signal-voltage-override.patch \
    file://0002-mmc-tegra-signal-voltage-and-CD.patch \
    file://0003-pci-tegra-ignore-link-state-when-enabling-ports.patch \
    file://0004-apalis-tk1-disable-lvds-and-disable-dc-warnings.patch \
    file://defconfig \
"

COMPATIBLE_MACHINE = "apalis-tk1|apalis-tk1-b205"

# Make sure replicated baseline defconfig exists for the selected machine
do_configure_prepend() {
    test -f ${S}/arch/arm/configs/${MACHINE}_defconfig || \
        cp -f ${S}/arch/arm/configs/apalis-tk1_defconfig ${S}/arch/arm/configs/${MACHINE}_defconfig
}

# Provide possibility to override kernel config from recipe
config_script_prepend() {
    test -s ${WORKDIR}/defconfig && \
        cp -f ${WORKDIR}/defconfig ${B}/.config
}
