# Copyright 1999-2026 Gentoo Authors / LWIS LLC
# Distributed under the terms of the GNU General Public License v2
# @SKEL@ -- do not emerge directly
# Tokens substituted by Sedme.sh
# @CURR_PV@ @LTS_PV@ @MIN_PV@ @DEVICE@

EAPI=8
inherit kernel-build toolchain-funcs

# -----------------------------
# Version tokens -- substituted by Sedme.sh
# -----------------------------
CURR_PV="@CURR_PV@"
LTS_PV="@LTS_PV@"
MIN_PV="@MIN_PV@"
DEVICE="@DEVICE@"

# LTS detection from package name -- no IUSE needed
if [[ ${PN} == *-lts ]]; then
	_KERNEL_PV="${LTS_PV}"
	_IS_LTS=1
else
	_KERNEL_PV="${CURR_PV}"
	_IS_LTS=0
fi

DESCRIPTION="Pentoo binary kernel for ARM64 -- ${DEVICE}"
HOMEPAGE="https://www.pentoo.ch"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# SET_USE substituted per device by Sedme.sh
IUSE="${SET_USE} experimental footgun clang"

REQUIRED_USE="
	footgun? ( experimental )
"

# -----------------------------
# Raw defconfig URIs -- Sedme.sh picks correct one per device
# RPi branch derived from kernel version
# -----------------------------
_RPI_BRANCH="rpi-${_KERNEL_PV%.*}.y"

URI_rpi4="https://raw.githubusercontent.com/raspberrypi/linux/${_RPI_BRANCH}/arch/arm64/configs/bcm2711_defconfig"
URI_rpi5="https://raw.githubusercontent.com/raspberrypi/linux/${_RPI_BRANCH}/arch/arm64/configs/bcm2712_defconfig"
URI_orangepi5="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5/linux-rk3588-current.config"
URI_orangepi5_plus="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5_plus/linux-rk3588-current.config"
URI_apple_m1="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
URI_apple_m2="${URI_apple_m1}"
URI_apple_m3="${URI_apple_m1}"
URI_apple_m4="${URI_apple_m1}"
URI_pine64="https://raw.githubusercontent.com/pine64/linux/pine64-kernel/arch/arm64/configs/pine64_defconfig"
URI_rockchip_generic="https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/configs/defconfig"
URI_odroid_m1="https://raw.githubusercontent.com/tobetter/linux/odroid-6.1.y/arch/arm64/configs/odroid_defconfig"
URI_odroid_m2="${URI_odroid_m1}"
URI_khadas_ampere_altra="https://raw.githubusercontent.com/AmpereComputing/ampere-lts-kernel/linux-6.6.y/arch/arm64/configs/defconfig"

# -----------------------------
# EDK2/UEFI + ACPI capability per device
# -----------------------------
declare -A _EDK2=(
	[rpi4]=1
	[rpi5]=1
	[orangepi5]=0
	[orangepi5_plus]=0
	[apple_m1]=1
	[apple_m2]=1
	[apple_m3]=1
	[apple_m4]=1
	[pine64]=0
	[rockchip_generic]=0
	[odroid_m1]=0
	[odroid_m2]=0
	[khadas_ampere_altra]=1
)

declare -A _ACPI=(
	[rpi5]=1
	[apple_m1]=1
	[apple_m2]=1
	[apple_m3]=1
	[apple_m4]=1
	[khadas_ampere_altra]=1
)

# -----------------------------
# SRC_URI
# -----------------------------
SRC_URI="
	${KERNEL_URI}
	https://raw.githubusercontent.com/pentoo/pentoo-overlay/master/sys-kernel/pentoo-sources/files/config-amd64-${_KERNEL_PV}
		-> pentoo-amd64-base-${_KERNEL_PV}.config
	$(eval echo \${URI_${DEVICE}}) -> config-${DEVICE}-${_KERNEL_PV}
"

# -----------------------------
# Dependencies
# -----------------------------
DEPEND="
	sys-apps/dtc[python,yaml]
	~sys-kernel/pentoo-sources-${_KERNEL_PV}
"

RDEPEND="
	~sys-kernel/pentoo-sources-${_KERNEL_PV}
	clang? (
		llvm-core/clang
		llvm-core/lld
	)
	!clang? (
		cross-aarch64-unknown-linux-gnu/gcc
		cross-aarch64-unknown-linux-gnu/binutils
	)
"

# -----------------------------
# pkg_setup
# -----------------------------
pkg_setup() {
	local ksrc="/usr/src/linux-${_KERNEL_PV}-pentoo"
	if [[ ! -d "${ksrc}" ]]; then
		ewarn "Sources not found at ${ksrc}, trying /usr/src/linux symlink"
		ksrc=$(readlink -f /usr/src/linux 2>/dev/null) \
			|| die "No kernel sources -- install pentoo-sources-${_KERNEL_PV}"
	fi
	export KERNEL_SOURCES="${ksrc}"

	export ARCH=arm64

	if use clang; then
		einfo "Toolchain: LLVM/Clang"
		export CROSS_COMPILE=aarch64-unknown-linux-gnu-
		export CC=clang
		export LD=ld.lld
		export LLVM=1
		export LLVM_IAS=1
	else
		einfo "Toolchain: GCC cross"
		export CROSS_COMPILE=aarch64-unknown-linux-gnu-
		tc-export CC CXX LD AR NM STRIP OBJCOPY OBJDUMP
	fi

	einfo "Device         : ${DEVICE}"
	einfo "Kernel sources : ${KERNEL_SOURCES}"
	einfo "LTS            : ${_IS_LTS}"

	kernel-build_pkg_setup
}

# -----------------------------
# src_prepare -- transmogrify amd64 base + merge device fragment
# -----------------------------
src_prepare() {
	default

	local base_cfg="${DISTDIR}/pentoo-amd64-base-${_KERNEL_PV}.config"
	local dev_cfg="${DISTDIR}/config-${DEVICE}-${_KERNEL_PV}"
	local out_cfg="${WORKDIR}/pentoo-arm64-${DEVICE}.config"

	# Transmogrify amd64 -> arm64
	if [[ -f "${base_cfg}" ]]; then
		cp "${base_cfg}" "${out_cfg}"
	else
		ewarn "Base config not found, using in-tree defconfig"
		cp "${KERNEL_SOURCES}/arch/arm64/configs/defconfig" "${out_cfg}"
	fi

	# Kill x86-specific, leave EFI/ACPI to fragments
	sed -i \
		-e 's/x86_64/arm64/g' \
		-e 's/amd64/arm64/g' \
		-e '/^CONFIG_X86/d' \
		-e '/^CONFIG_IA32/d' \
		-e '/^CONFIG_COMPAT_32/d' \
		-e '/^CONFIG_EFI_MIXED/d' \
		-e 's/CONFIG_MTRR=y/# CONFIG_MTRR is not set/' \
		-e 's/CONFIG_MICROCODE=y/# CONFIG_MICROCODE is not set/' \
		-e 's/CONFIG_X86_MSR=y/# CONFIG_X86_MSR is not set/' \
		-e 's/CONFIG_X86_CPUID=y/# CONFIG_X86_CPUID is not set/' \
		"${out_cfg}"

	# Merge device fragment
	if [[ -f "${dev_cfg}" ]]; then
		einfo "Merging device config: ${DEVICE}"
		cat "${dev_cfg}" >> "${out_cfg}"
	else
		ewarn "No device config for ${DEVICE}, using base only"
	fi

	# EDK2/UEFI fragment
	if [[ "${_EDK2[${DEVICE}]:-0}" == "1" ]]; then
		einfo "Fragment: EDK2/UEFI + MOK chain"
		cat >> "${out_cfg}" <<'EOF'
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFIVAR_FS=y
CONFIG_EFI_RUNTIME_WRAPPERS=y
CONFIG_EFI_CAPSULE_LOADER=y
CONFIG_FB_EFI=y
CONFIG_SYSFB_SIMPLEFB=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_SECURITYFS=y
CONFIG_INTEGRITY=y
CONFIG_INTEGRITY_SIGNATURE=y
CONFIG_INTEGRITY_ASYMMETRIC_KEYS=y
CONFIG_LOAD_UEFI_KEYS=y
CONFIG_SYSTEM_TRUSTED_KEYRING=y
CONFIG_SECONDARY_TRUSTED_KEYRING=y
CONFIG_IMA_ARCH_POLICY=y
EOF
	else
		einfo "Fragment: no-UEFI (U-Boot direct)"
		cat >> "${out_cfg}" <<'EOF'
# CONFIG_EFI is not set
# CONFIG_EFIVAR_FS is not set
CONFIG_OF=y
CONFIG_OF_EARLY_FLATTREE=y
EOF
	fi

	# ACPI fragment
	if [[ "${_ACPI[${DEVICE}]:-0}" == "1" ]]; then
		einfo "Fragment: ACPI"
		cat >> "${out_cfg}" <<'EOF'
CONFIG_ACPI=y
CONFIG_ACPI_REDUCED_HARDWARE_ONLY=y
EOF
	else
		echo "# CONFIG_ACPI is not set" >> "${out_cfg}"
	fi

	# Localversion
	echo "CONFIG_LOCALVERSION=\"-pentoo-${_KERNEL_PV}-arm64-${DEVICE}\"" \
		>> "${out_cfg}"

	# Save config for reference
	install -Dm644 "${out_cfg}" \
		"/etc/portage/kernels/${PN}-${_KERNEL_PV}-arm64-${DEVICE}.config"

	cp "${out_cfg}" "${BUILD_DIR}/.config"
}

# -----------------------------
# src_configure
# -----------------------------
src_configure() {
	export ARCH=arm64
	export CROSS_COMPILE="${CROSS_COMPILE}"

	emake -C "${KERNEL_SOURCES}" O="${BUILD_DIR}" \
		ARCH=arm64 \
		CROSS_COMPILE="${CROSS_COMPILE}" \
		olddefconfig

	kernel-build_src_configure
}

# -----------------------------
# src_compile
# -----------------------------
src_compile() {
	export ARCH=arm64
	export CROSS_COMPILE="${CROSS_COMPILE}"

	emake -C "${KERNEL_SOURCES}" O="${BUILD_DIR}" \
		ARCH=arm64 \
		CROSS_COMPILE="${CROSS_COMPILE}" \
		dtbs

	kernel-build_src_compile
}

# -----------------------------
# src_install
# -----------------------------
src_install() {
	if [[ -d "${BUILD_DIR}/arch/arm64/boot/dts" ]]; then
		insinto /boot/dtbs/${_KERNEL_PV}-pentoo-arm64-${DEVICE}
		find "${BUILD_DIR}/arch/arm64/boot/dts" \
			-name "*.dtb" -exec doins {} \;
	fi

	kernel-build_src_install
}

# -----------------------------
# pkg_postinst
# -----------------------------
pkg_postinst() {
	kernel-build_pkg_postinst
	einfo "Installed: pentoo arm64 kernel ${_KERNEL_PV} for ${DEVICE}"

	if [[ "${_EDK2[${DEVICE}]:-0}" == "1" ]]; then
		einfo ""
		einfo "EDK2/UEFI enabled -- GRUB2 + MOK Secure Boot chain available"
		einfo "To enroll MOK key:"
		einfo "  mokutil --import /etc/gentoo-keys/mok.der"
	else
		einfo ""
		einfo "U-Boot boot -- DTBs installed to:"
		einfo "  /boot/dtbs/${_KERNEL_PV}-pentoo-arm64-${DEVICE}/"
	fi
}
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
