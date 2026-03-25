# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit pikernel-build

DESCRIPTION="Binary Pentoo kernel for ARM64 (kitchen sink for multiple devices)"
HOMEPAGE="https://www.pentoo.ch"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="${SET_USE} experimental footgun +lts"

DEPEND="
    sys-apps/dtc[python,yaml]
    app-misc/jq
"
RDEPEND="
    >=sys-kernel/pentoo-sources-${minimum-pv}
    <=sys-kernel/pentoo-sources-${maximum-pv}
"

# Base Pentoo amd64 config (to transmogrify to arm64)
URI_pentoo_base_config="https://raw.githubusercontent.com/pentoo/pentoo-overlay/master/sys-kernel/pentoo-sources/files/config-amd64-${PV}"

# Add URIs for boards as needed
URI_rpi4="https://github.com/raspberrypi/linux/tree/rpi-6.1.y/arch/arm64/configs"
URI_rpi5="https://github.com/raspberrypi/linux/tree/rpi-6.1.y/arch/arm64/configs"
URI_orangepi5="https://github.com/orangepi-xunlong/orangepi-build/tree/main/external/config/orangepi5"
URI_orangepi5_plus="https://github.com/orangepi-xunlong/orangepi-build/tree/main/external/config/orangepi5_plus"
URI_apple_m1="https://github.com/AsahiLinux/linux/tree/asahi/arch/arm64/configs"
URI_apple_m2="https://github.com/AsahiLinux/linux/tree/asahi/arch/arm64/configs"
URI_apple_m3="https://github.com/AsahiLinux/linux/tree/asahi/arch/arm64/configs"
URI_apple_m4="https://github.com/AsahiLinux/linux/tree/asahi/arch/arm64/configs"
URI_pine64="https://github.com/pine64/linux/tree/pine64-kernel/arch/arm64/configs"
URI_khadas_ampere_altra="https://github.com/khadas/linux/tree/khadas-vims-5.15/arch/arm64/configs"
URI_odroid_m1="https://github.com/<community>/odroid_m1_defconfig"
URI_odroid_m2="https://github.com/<community>/odroid_m2_defconfig"
URI_rockchip_generic="https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/configs/rockchip_linux_defconfig"

pkg_setup() {
    ARCH="arm64"

    if use build; then
        if use lts; then
            KERNEL_SOURCES="/usr/src/pentoo-${minimum-pv}"
        else
            KERNEL_SOURCES="/usr/src/pentoo-${maximum-pv}"
        fi
    else
        KERNEL_SOURCES="/usr/src/linux"
    fi

    pikernel-build_pkg_setup
}

src_prepare() {
    default

    # Fetch and transmogrify base amd64 config
    cp /usr/share/pentoo-sources/config-amd64-${PVR} "${WORKDIR}/pentoo-arm64-base.config"
    sed -i 's/x86_64/arm64/g; s/amd64/arm64/g' "${WORKDIR}/pentoo-arm64-base.config"

    # Merge all device configs for kitchen sink
    local config_files=(
        "${FILESDIR}/pentoo-rpi5.config"
        "${FILESDIR}/pentoo-orangepi5.config"
        "${FILESDIR}/pentoo-orangepi5-plus.config"
        "${FILESDIR}/pentoo-apple-m1.config"
        "${FILESDIR}/pentoo-apple-m2.config"
        "${FILESDIR}/pentoo-apple-m3.config"
        "${FILESDIR}/pentoo-apple-m4.config"
        "${FILESDIR}/pentoo-pine64.config"
        "${FILESDIR}/pentoo-khadas-ampere-altra.config"
        # Add more device configs as needed
    )

    cat "${WORKDIR}/pentoo-arm64-base.config" "${config_files[@]}" > "${WORKDIR}/pentoo-arm64-all.config"

    # Add local version
    echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-arm64-all\"" >> "${WORKDIR}/pentoo-arm64-all.config"

    # Copy to kernel sources and pentoo-sources for reference
    cp "${WORKDIR}/pentoo-arm64-all.config" "${KERNEL_SOURCES}/.config"
    cp "${WORKDIR}/pentoo-arm64-all.config" "/usr/share/pentoo-sources/pentoo-arm64-all.config"

    pikernel-build_src_prepare
}

src_configure() {
    pikernel-build_src_configure
}

src_compile() {
    pikernel-build_src_compile

    # Copy all DTBs into kernel tree
    mkdir -p "${KERNEL_SOURCES}/arch/arm64/boot/dts/custom"
    cp "${FILESDIR}/dtb/"*.dtb "${KERNEL_SOURCES}/arch/arm64/boot/dts/custom/"

    # Build all DTBs
    make -C "${KERNEL_SOURCES}" ARCH=arm64 dtbs
}

src_install() {
    pikernel-build_src_install

    # Install all DTBs
    insinto /boot/dtb
    doins "${KERNEL_SOURCES}/arch/arm64/boot/dts/custom/"*.dtb
}pkg_setup() {
	if use rpi4; then
		set-device="bcm2711"
	elif use rpi5; then
		set-device="bcm2711"
	elif use orangepi5; then
		set-device="rockchip"
	elif use orangepi5_plus; then
		set-device="rockchip"
	elif use apple_m1; then
		set-device="apple-m1"
	elif use apple_m2; then
		set-device="apple-m2"
	elif use apple_m3; then
		set-device="apple-m3"
	elif use apple_m4; then
		set-device="apple-m4"
	elif use pine64; then
		set-device="allwinner"
	elif use khadas_ampere_altra; then
		set-device="ampere"
	fi

	ARCH="arm64"

	if use build; then
		if use lts; then
			KERNEL_SOURCES="/usr/src/pentoo-${minimum-pv}"
		else
			KERNEL_SOURCES="/usr/src/pentoo-${maximum-pv}"
		fi
	else
		KERNEL_SOURCES="/usr/src/linux"
	fi

	pikernel-build_pkg_setup
}

src_prepare() {
	default

	# Fetch the base Pentoo amd64 config
	wget -O "${WORKDIR}/pentoo-base.config" "${URI_pentoo_base_config}"

	if [[ "${set-device}" == "all" ]]; then
		# Combine all device configs for arm64
		local config_files=(
			"${FILESDIR}/config-rpi5-${PV}"
			"${FILESDIR}/config-orangepi5-${PV}"
			"${FILESDIR}/config-orangepi5-plus-${PV}"
			"${FILESDIR}/config-apple-m1-${PV}"
			"${FILESDIR}/config-apple-m2-${PV}"
			"${FILESDIR}/config-apple-m3-${PV}"
			"${FILESDIR}/config-apple-m4-${PV}"
			"${FILESDIR}/config-pine64-${PV}"
			"${FILESDIR}/config-khadas-ampere-altra-${PV}"
			# Add more config files as needed
		)

		cat "${WORKDIR}/pentoo-base.config" "${config_files[@]}" > "${WORKDIR}/pentoo-${Devicename}.config"
	else
		cat "${WORKDIR}/pentoo-base.config" "${FILESDIR}/config-${set-device}-${PV}" > "${WORKDIR}/pentoo-${Devicename}.config"
	fi

	# Insert CONFIG_LOCALVERSION into the config
	echo "CONFIG_LOCALVERSION=\"pentoo-${PV}-arm64-${Devicename}\"" >> "${WORKDIR}/pentoo-${Devicename}.config"

	cp "${WORKDIR}/pentoo-${Devicename}.config" "${KERNEL_SOURCES}/.config"
	cp "${WORKDIR}/pentoo-${Devicename}.config" "/etc/portage/kernels/sys-kernel-pentoo-${PV}-arm64-${Devicename}.config"

	# Force combined configs to arm64 and fix any discrepancies
	make ARCH=arm64 silentoldconfig
}

src_configure() {
	pikernel-build_src_configure
}

src_compile() {
	# Enable newer kernel modules to auto build by default
	# Build arm64 device trees by default
	pikernel-build_src_compile
}

src_install() {
	pikernel-build_src_install
}
