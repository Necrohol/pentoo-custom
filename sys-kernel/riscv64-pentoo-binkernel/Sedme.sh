# @SKEL@ -- do not emerge directly
# Generated ebuilds have versions sed-substituted by generator

EAPI=8
inherit kernel-build toolchain-funcs

# @SUBST@ by generate-pentoo-riscv64.sh
CURR_PV="@CURR_PV@"
LTS_PV="@LTS_PV@"
MIN_PV="@MIN_PV@"

# -----------------------------
# Write per-device ebuild from skel
# -----------------------------
SKEL="${FILESDIR}/riscv64-pentoo-binkernel-skel.0.ebuild"

write_ebuild() {
    local device="$1"
    local outdir="${FILESDIR}/../${PN_PREFIX}-${device}"
    local ebuild_name="${PN_PREFIX}-${device}-${PVR}.ebuild"

    mkdir -p "${outdir}/files"
    sed \
        -e "s/@CURR_PV@/${PVR}/g" \
        -e "s/@LTS_PV@/${LTS_PVR}/g" \
        -e "s/@MIN_PV@/${MIN_PVR}/g" \
        -e "s/@DEVICE@/${device}/g" \
        -e "s/\${SET_USE}/${DEVICE_USE[$device]}/g" \
        "${SKEL}" > "${outdir}/${ebuild_name}"

    # lts variant
    sed \
        -e "s/@CURR_PV@/${LTS_PVR}/g" \
        -e "s/@LTS_PV@/${LTS_PVR}/g" \
        -e "s/@MIN_PV@/${MIN_PVR}/g" \
        -e "s/@DEVICE@/${device}/g" \
        -e "s/\${SET_USE}/${DEVICE_USE[$device]}/g" \
        "${SKEL}" > "${outdir}/${PN_PREFIX}-${device}-lts-${LTS_PVR}.ebuild"

    einfo "Written: ${ebuild_name}"
}

PN_PREFIX="riscv64-pentoo-binkernel"
LTS_PVR="6.6.0"   # or probe separately
MIN_PVR="6.6.0"

for device in "${!DEVICE_URI_MAP[@]}"; do
    write_ebuild "${device}"
done
