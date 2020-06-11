FILESEXTRAPATHS_prepend := "${THISDIR}/linux-toradex-mainline-4.14:"

SRC_URI_append_apalis-tk1-mainline += " \
    file://0001-ARM-tegra-apalis-tk1-limit-sdmmc1-to-1.8V-signalling.patch \
    file://0002-mmc-tegra-enable-NVQUIRK_ENABLE_SDHCI_SPEC_300-for-t.patch \
    file://defconfig \
"
#    file://0003-ARM-tegra-apalis-tk1-limit-sdmmc1-f_max-to-200-MHz.patch

COMPATIBLE_MACHINE = "apalis-tk1-mainline"

# Provide possibility to override kernel config from recipe
config_script_prepend() {
    test -s ${WORKDIR}/defconfig && \
        cp -f ${WORKDIR}/defconfig ${B}/.config
}
