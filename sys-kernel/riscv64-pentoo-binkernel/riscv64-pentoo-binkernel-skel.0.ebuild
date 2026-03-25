# Copyright 1999-2025 Gentoo Authors / LWIS LLC
# Distributed under the terms of the GNU General Public License v2
# @SKEL@ -- do not emerge directly
# Tokens substituted by generate-pentoo-riscv64.sh + sedme.sh
# CURR_PV=@CURR_PV@ LTS_PV=@LTS_PV@ MIN_PV=@MIN_PV@ DEVICE=@DEVICE@

EAPI=8
inherit kernel-build toolchain-funcs

DESCRIPTION="Pentoo binary kernel for RISC-V 64-bit -- @DEVICE@"
HOMEPAGE="https://www.pentoo.ch"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~riscv ~amd64"

# -----------------------------
# Version tokens -- substituted at ebuild write time
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

# -----------------------------
# USE flags -- SET_USE substituted per device by sedme.sh
# -----------------------------
IUSE="${SET_USE} experimental footgun clang"

REQUIRED_USE="
	footgun? ( experimental )
"

# -----------------------------
# Device URI map
# -----------------------------
URI_pentoo_base_config="https://raw.githubusercontent.com/pentoo/pentoo-overlay/master/sys-kernel/pentoo-sources/files/config-riscv64-${_KERNEL_PV}"
URI_sifive_unmatched="https://raw.githubusercontent.com/sifive/meta-sifive/master/recipes-kernel/linux/files/sifive-unmatched_defconfig"
URI_sifive_unleashed="https://raw.githubusercontent.com/sifive/meta-sifive/master/recipes-kernel/linux/files/sifive-unleashed_defconfig"
URI_starfive_visionfive2="https://raw.githubusercontent.com/starfive-tech/linux/JH7110_VisionFive2_upstream/arch/riscv/configs/starfive_visionfive2_defconfig"
URI_starfive_visionfive="https://raw.githubusercontent.com/starfive-tech/linux/visionfive-5.15.y/arch/riscv/configs/starfive_visionfive_defconfig"
URI_canaan_k210="https://raw.githubusercontent.com/kendryte/linux/k210-5.6/arch/riscv/configs/k210_defconfig"
URI_thead_c906="https://raw.githubusercontent.com/T-head-Semi/linux/linux-5.10.y/arch/riscv/configs/thead_c9xx_defconfig"
URI_milk_v_pioneer="https://raw.githubusercontent.com/milkv-community/linux/sg2042-dev/arch/riscv/configs/sg2042_defconfig"
URI_lichee_rv="https://raw.githubusercontent.com/smaeul/linux/d1-wip/arch/riscv/configs/allwinner_d1_defconfig"
URI_nezha_d1="https://raw.githubusercontent.com/smaeul/linux/d1-wip/arch/riscv/configs/allwinner_d1_defconfig"
URI_beaglev_ahead="https://raw.githubusercontent.com/beagleboard/linux/v6.1-BeagleV-Ahead/arch/riscv/configs/defconfig"
URI_banana_pi_f3="https://raw.githubusercontent.com/BPI-SINOVOIP/BPI-F3-BSP/main/linux-6.1/arch/riscv/configs/k1_defconfig"

# -----------------------------
# EDK2/UEFI + ACPI capability
# 1=yes 0=no
# -----------------------------
declare -A _EDK2=(
	[sifive_unmatched]=1
	[sifive_unleashed]=0
	[starfive_visionfive2]=1
	[starfive_visionfive]=0
	[canaan_k210]=0
	[thead_c906]=0
	[milk_v_pioneer]=1
	[lichee_rv]=0
	[nezha_d1]=0
	[beaglev_ahead]=0
	[banana_pi_f3]=0
)

declare -A _ACPI=(
	[sifive_unmatched]=1
	[starfive_visionfive2]=1
	[milk_v_pioneer]=1
)

# -----------------------------
# SRC_URI -- base config + device defconfig
# -----------------------------
SRC_URI="
	${KERNEL_URI}
	${URI_pentoo_base_config} -> pentoo-riscv64-base-${_KERNEL_PV}.config
	${URI_${DEVICE}} -> config-${DEVICE}-${_KERNEL_PV}
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
		cross-riscv64-unknown-linux-gnu/gcc
		cross-riscv64-unknown-linux-gnu/binutils
	)
"

# -----------------------------
# pkg_setup
# -----------------------------
pkg_setup() {
	# Locate kernel sources
	local ksrc="/usr/src/linux-${_KERNEL_PV}-pentoo"
	if [[ ! -d "${ksrc}" ]]; then
		ewarn "Sources not found at ${ksrc}, trying /usr/src/linux symlink"
		ksrc=$(readlink -f /usr/src/linux 2>/dev/null) \
			|| die "No kernel sources found -- install pentoo-sources-${_KERNEL_PV}"
	fi
	export KERNEL_SOURCES="${ksrc}"
	einfo "Kernel sources : ${KERNEL_SOURCES}"
	einfo "Device         : ${DEVICE}"
	einfo "LTS            : ${_IS_LTS}"

	# Correct kernel ARCH -- riscv not riscv64
	export ARCH=riscv

	if use clang; then
		einfo "Toolchain: LLVM/Clang"
		export CROSS_COMPILE=riscv64-unknown-linux-gnu-
		export CC=clang
		export LD=ld.lld
		export LLVM=1
		export LLVM_IAS=1
	else
		einfo "Toolchain: GCC cross"
		export CROSS_COMPILE=riscv64-unknown-linux-gnu-
		tc-export CC CXX LD AR NM STRIP OBJCOPY OBJDUMP
	fi

	kernel-build_pkg_setup
}

# -----------------------------
# src_prepare -- merge configs + fragments
# -----------------------------
src_prepare() {
	default

	local base_cfg="${DISTDIR}/pentoo-riscv64-base-${_KERNEL_PV}.config"
	local dev_cfg="${DISTDIR}/config-${DEVICE}-${_KERNEL_PV}"
	local out_cfg="${WORKDIR}/pentoo-${DEVICE}.config"

	# Base config -- fallback to in-tree defconfig
	if [[ -f "${base_cfg}" ]]; then
		cp "${base_cfg}" "${out_cfg}"
	else
		ewarn "Pentoo base config not found, falling back to upstream defconfig"
		cp "${KERNEL_SOURCES}/arch/riscv/configs/defconfig" "${out_cfg}"
	fi

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
# EDK2 UEFI -- grub2 + MOK Secure Boot chain
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
		einfo "Fragment: no-UEFI (U-Boot/OpenSBI direct)"
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

	# riscv64 base platform fragment
	cat >> "${out_cfg}" <<'EOF'
# RISC-V 64 base platform
CONFIG_RISCV=y
CONFIG_64BIT=y
CONFIG_RISCV_SBI=y
CONFIG_RISCV_SBI_V01=y
CONFIG_RISCV_M_MODE=n
CONFIG_RISCV_ISA_RV64I=y
CONFIG_RISCV_ISA_C=y
CONFIG_RISCV_ISA_A=y
CONFIG_RISCV_ISA_M=y
CONFIG_RISCV_ISA_F=y
CONFIG_RISCV_ISA_D=y
CONFIG_RISCV_ISA_V=y
CONFIG_FPU=y
CONFIG_SMP=y
CONFIG_HOTPLUG_CPU=y
CONFIG_SOC_SIFIVE=y
CONFIG_SOC_STARFIVE=y
CONFIG_SOC_THEAD=y
CONFIG_SOC_CANAAN=y
CONFIG_SOC_SPACEMIT=y
EOF

	# Localversion
	echo "CONFIG_LOCALVERSION=\"-pentoo-${_KERNEL_PV}-riscv64-${DEVICE}\"" \
		>> "${out_cfg}"

	# Save config for reference
	install -Dm644 "${out_cfg}" \
		"/etc/portage/kernels/${PN}-${_KERNEL_PV}-riscv64-${DEVICE}.config"

	# Drop into BUILD_DIR for kernel-build
	cp "${out_cfg}" "${BUILD_DIR}/.config"
}

# -----------------------------
# src_configure
# -----------------------------
src_configure() {
	export ARCH=riscv
	export CROSS_COMPILE="${CROSS_COMPILE}"

	# Reconcile config -- mandatory after cat merges
	emake -C "${KERNEL_SOURCES}" O="${BUILD_DIR}" \
		ARCH=riscv \
		CROSS_COMPILE="${CROSS_COMPILE}" \
		olddefconfig

	kernel-build_src_configure
}

# -----------------------------
# src_compile
# -----------------------------
src_compile() {
	export ARCH=riscv
	export CROSS_COMPILE="${CROSS_COMPILE}"

	# DTBs
	emake -C "${KERNEL_SOURCES}" O="${BUILD_DIR}" \
		ARCH=riscv \
		CROSS_COMPILE="${CROSS_COMPILE}" \
		dtbs

	kernel-build_src_compile
}

# -----------------------------
# src_install
# -----------------------------
src_install() {
	# DTBs -- arch/riscv not arch/riscv64
	if [[ -d "${BUILD_DIR}/arch/riscv/boot/dts" ]]; then
		insinto /boot/dtbs/${_KERNEL_PV}-pentoo-riscv64-${DEVICE}
		find "${BUILD_DIR}/arch/riscv/boot/dts" \
			-name "*.dtb" -exec doins {} \;
	fi

	kernel-build_src_install
}

# -----------------------------
# pkg_postinst
# -----------------------------
pkg_postinst() {
	kernel-build_pkg_postinst
	einfo "Installed: pentoo riscv64 kernel ${_KERNEL_PV} for ${DEVICE}"

	if [[ "${_EDK2[${DEVICE}]:-0}" == "1" ]]; then
		einfo ""
		einfo "EDK2/UEFI enabled -- GRUB2 + MOK Secure Boot chain available"
		einfo "To enroll MOK key:"
		einfo "  mokutil --import /etc/gentoo-keys/mok.der"
	else
		einfo ""
		einfo "U-Boot/OpenSBI boot -- no MOK chain"
		einfo "DTBs installed to /boot/dtbs/${_KERNEL_PV}-pentoo-riscv64-${DEVICE}/"
	fi
}
```

---

Key changes from your current skel: `ARCH=riscv` throughout, `BUILD_DIR` instead of `KERNEL_SOURCES` for build artifacts, `kernel-build` eclass replacing `riscvkernel`, `wget` replaced by `SRC_URI` fetching, DTB path corrected to `arch/riscv/boot/dts`, `jq`/`crossdev` dropped from `DEPEND`, and `@TOKEN@` markers ready for `sedme.sh` substitution.
pkg_setup() {
	# Set device-specific configurations
	if use sifive_unmatched; then
		set_device="sifive-unmatched"
	elif use sifive_unleashed; then
		set_device="sifive-unleashed"
	elif use starfive_visionfive2; then
		set_device="starfive-visionfive2"
	elif use starfive_visionfive; then
		set_device="starfive-visionfive"
	elif use canaan_k210; then
		set_device="canaan-k210"
	elif use thead_c906; then
		set_device="thead-c906"
	elif use milk_v_pioneer; then
		set_device="milk-v-pioneer"
	elif use lichee_rv; then
		set_device="lichee-rv"
	elif use nezha_d1; then
		set_device="nezha-d1"
	elif use beaglev_ahead; then
		set_device="beaglev-ahead"
	elif use banana_pi_f3; then
		set_device="banana-pi-f3"
	fi
	
	ARCH="riscv64"
	CROSS_COMPILE="riscv64-unknown-linux-gnu-"
	
	if use build; then
		if use lts; then
			KERNEL_SOURCES="/usr/src/pentoo-${minimum-pv}"
		else
			KERNEL_SOURCES="/usr/src/pentoo-${maximum-pv}"
		fi
	else
		KERNEL_SOURCES="/usr/src/linux"
	fi
	
	riscvkernel_pkg_setup
}

src_prepare() {
	default
	
	# Fetch the base Pentoo RISC-V config
	if [[ -n "${URI_pentoo_base_config}" ]]; then
		wget -O "${WORKDIR}/pentoo-base.config" "${URI_pentoo_base_config}" || \
		# Fallback to generic RISC-V defconfig if Pentoo-specific doesn't exist
		cp "${KERNEL_SOURCES}/arch/riscv/configs/defconfig" "${WORKDIR}/pentoo-base.config"
	else
		cp "${KERNEL_SOURCES}/arch/riscv/configs/defconfig" "${WORKDIR}/pentoo-base.config"
	fi
	
	if [[ "${set_device}" == "all" ]]; then
		# Combine all RISC-V device configs
		local config_files=(
			"${FILESDIR}/config-sifive-unmatched-${PV}"
			"${FILESDIR}/config-sifive-unleashed-${PV}"
			"${FILESDIR}/config-starfive-visionfive2-${PV}"
			"${FILESDIR}/config-starfive-visionfive-${PV}"
			"${FILESDIR}/config-canaan-k210-${PV}"
			"${FILESDIR}/config-thead-c906-${PV}"
			"${FILESDIR}/config-milk-v-pioneer-${PV}"
			"${FILESDIR}/config-lichee-rv-${PV}"
			"${FILESDIR}/config-nezha-d1-${PV}"
			"${FILESDIR}/config-beaglev-ahead-${PV}"
			"${FILESDIR}/config-banana-pi-f3-${PV}"
		)
		cat "${WORKDIR}/pentoo-base.config" "${config_files[@]}" > "${WORKDIR}/pentoo-${Devicename}.config"
	else
		cat "${WORKDIR}/pentoo-base.config" "${FILESDIR}/config-${set_device}-${PV}" > "${WORKDIR}/pentoo-${Devicename}.config"
	fi
	
	# Add RISC-V specific kernel configurations
	cat >> "${WORKDIR}/pentoo-${Devicename}.config" << EOF
# RISC-V specific configurations
CONFIG_RISCV=y
CONFIG_64BIT=y
CONFIG_RISCV_SBI=y
CONFIG_RISCV_SBI_V01=y
CONFIG_RISCV_M_MODE=n
CONFIG_RISCV_ISA_RV64I=y
CONFIG_RISCV_ISA_C=y
CONFIG_RISCV_ISA_A=y
CONFIG_RISCV_ISA_M=y
CONFIG_RISCV_ISA_F=y
CONFIG_RISCV_ISA_D=y
CONFIG_RISCV_ISA_V=y
CONFIG_FPU=y
CONFIG_SMP=y
CONFIG_HOTPLUG_CPU=y
CONFIG_SOC_SIFIVE=y
CONFIG_SOC_STARFIVE=y
CONFIG_SOC_THEAD=y
CONFIG_SOC_CANAAN=y
CONFIG_SOC_SPACEMIT=y
EOF
	
	# Insert CONFIG_LOCALVERSION into the config
	echo "CONFIG_LOCALVERSION=\"-pentoo-${PV}-riscv64-${Devicename}\"" >> "${WORKDIR}/pentoo-${Devicename}.config"
	
	# Copy config files
	cp "${WORKDIR}/pentoo-${Devicename}.config" "${KERNEL_SOURCES}/.config"
	cp "${WORKDIR}/pentoo-${Devicename}.config" "/etc/portage/kernels/sys-kernel-pentoo-${PV}-riscv64-${Devicename}.config"
	
	# Configure for RISC-V architecture and resolve config conflicts
	cd "${KERNEL_SOURCES}" || die
	make ARCH=riscv64 CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
}

src_configure() {
	# Set RISC-V specific environment variables
	export ARCH=riscv64
	export CROSS_COMPILE="${CROSS_COMPILE}"
	
	riscvkernel_src_configure
}

src_compile() {
	# Enable RISC-V specific compilation flags
	export ARCH=riscv64
	export CROSS_COMPILE="${CROSS_COMPILE}"
	
	# Build RISC-V device trees by default
	emake ARCH=riscv64 CROSS_COMPILE="${CROSS_COMPILE}" dtbs
	
	riscvkernel_src_compile
}

src_install() {
	# Install RISC-V device tree blobs
	if [[ -d "${KERNEL_SOURCES}/arch/riscv64/boot/dts" ]]; then
		insinto /boot/dtbs
		doins "${KERNEL_SOURCES}"/arch/riscv64/boot/dts/*/*.dtb
	fi
	
	riscvkernel_src_install
}
