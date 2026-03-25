#!/usr/bin/env bash
# Sedme.sh -- arm64-pentoo-binkernel
# Probes pentoo-overlay for current + LTS versions
# Writes per-device ebuilds from arm64-pentoo-binkernel-skel.0.ebuild
# No pkgdev, no manifest, no git

set -euo pipefail

# -----------------------------
# Config
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKEL="${SCRIPT_DIR}/arm64-pentoo-binkernel-skel.0.ebuild"
PN_PREFIX="arm64-pentoo-binkernel"
OUTPUT_BASE="${SCRIPT_DIR}/generated"
OVERLAY_JSON="https://api.github.com/repos/pentoo/pentoo-overlay/contents/sys-kernel/pentoo-sources"
LTS_SERIES="6.6"

# -----------------------------
# Probe overlay for versions
# -----------------------------
echo "Probing pentoo-overlay for kernel versions..."

ALL_VERSIONS=$(curl -sSL "${OVERLAY_JSON}" \
    | jq -r '.[] | select(.name|test("^pentoo-sources-[0-9]+\\.[0-9]+\\.[0-9]+\\.ebuild$")) | .name' \
    | sed -E 's/pentoo-sources-([0-9]+\.[0-9]+\.[0-9]+)\.ebuild/\1/' \
    | sort -V)

[[ -z "${ALL_VERSIONS}" ]] && { echo "ERROR: Could not probe overlay."; exit 1; }

CURR_PV=$(echo "${ALL_VERSIONS}" | tail -n1)
LTS_PV=$(echo "${ALL_VERSIONS}"  | grep "^${LTS_SERIES}\." | tail -n1)
MIN_PV=$(echo "${ALL_VERSIONS}"  | head -n1)

[[ -z "${LTS_PV}" ]] && {
    echo "WARN: No LTS ${LTS_SERIES}.x found, using CURR_PV for LTS"
    LTS_PV="${CURR_PV}"
}

echo "  CURR_PV : ${CURR_PV}"
echo "  LTS_PV  : ${LTS_PV}"
echo "  MIN_PV  : ${MIN_PV}"

# -----------------------------
# Sanity
# -----------------------------
[[ ! -f "${SKEL}" ]] && { echo "ERROR: Skel not found: ${SKEL}"; exit 1; }

# -----------------------------
# Devices
# -----------------------------
DEVICES=(
    rpi4
    rpi5
    orangepi5
    orangepi5_plus
    apple_m1
    apple_m2
    apple_m3
    apple_m4
    pine64
    rockchip_generic
    odroid_m1
    odroid_m2
    khadas_ampere_altra
)

# -----------------------------
# Write one ebuild
# $1 = device
# $2 = target PV
# $3 = name suffix (empty or -lts)
# -----------------------------
write_ebuild() {
    local device="$1"
    local target_pv="$2"
    local suffix="$3"

    local pkgname="${PN_PREFIX}-${device}${suffix}"
    local outdir="${OUTPUT_BASE}/${pkgname}"
    local ebuild="${outdir}/${pkgname}-${target_pv}.ebuild"

    mkdir -p "${outdir}/files"

    sed \
        -e "s/@CURR_PV@/${CURR_PV}/g" \
        -e "s/@LTS_PV@/${LTS_PV}/g" \
        -e "s/@MIN_PV@/${MIN_PV}/g" \
        -e "s/@DEVICE@/${device}/g" \
        -e "s/\${SET_USE}/${device}/g" \
        "${SKEL}" > "${ebuild}"

    echo "  ${ebuild}"
}

# -----------------------------
# Generate per-device current + lts
# -----------------------------
echo ""
echo "Writing ebuilds to ${OUTPUT_BASE}..."
mkdir -p "${OUTPUT_BASE}"

for device in "${DEVICES[@]}"; do
    write_ebuild "${device}" "${CURR_PV}" ""
    write_ebuild "${device}" "${LTS_PV}"  "-lts"
done

# -----------------------------
# Summary
# -----------------------------
echo ""
echo "Done."
echo "  Devices : ${#DEVICES[@]}"
echo "  Ebuilds : $(find "${OUTPUT_BASE}" -name '*.ebuild' | wc -l)"
echo ""
echo "Copy to overlay:"
echo "  cp -r ${OUTPUT_BASE}/* /path/to/overlay/sys-kernel/"
