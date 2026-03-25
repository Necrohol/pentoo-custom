#!/usr/bin/env bash
# generate-pentoo-arm64.sh
# Fully automated ARM64 Pentoo kernel config generator

set -euo pipefail

# -----------------------------
# Detect latest Pentoo kernel version via GitHub API + jq
# -----------------------------
OVERLAY_JSON="https://api.github.com/repos/pentoo/pentoo-overlay/contents/sys-kernel/pentoo-sources"

echo "Fetching latest Pentoo kernel version from overlay..."
PVR=$(curl -sSL "$OVERLAY_JSON" \
    | jq -r '.[] | select(.name|test("^pentoo-sources-[0-9]+\\.[0-9]+\\.[0-9]+\\.ebuild$")) | .name' \
    | sed -E 's/pentoo-sources-([0-9]+\.[0-9]+\.[0-9]+)\.ebuild/\1/' \
    | sort -V \
    | tail -n1)

if [[ -z "$PVR" ]]; then
    echo "ERROR: Could not detect latest Pentoo version."
    exit 1
fi
echo "Latest Pentoo kernel version: $PVR"

# -----------------------------
# Paths
# -----------------------------
FILESDIR=$(dirname "$0")        # assume script is in ebuild FILESDIR
SHARE_DIR="/usr/share/pentoo-sources"

# -----------------------------
# AMD64 base config -> ARM64 base
# -----------------------------
BASE_AMD64="$SHARE_DIR/config-amd64-${PVR}"
BASE_ARM64="${FILESDIR}/pentoo-arm64-base.config"

if [[ ! -f "$BASE_AMD64" ]]; then
    echo "ERROR: AMD64 base config not found at $BASE_AMD64"
    exit 1
fi

echo "Copying AMD64 config to ARM64 base..."
cp "$BASE_AMD64" "$BASE_ARM64"

# Replace architecture strings for ARM64
sed -i 's/x86_64/arm64/g; s/amd64/arm64/g' "$BASE_ARM64"

echo "ARM64 base config created at $BASE_ARM64"

# -----------------------------
# Upstream device config URLs
# Add more devices here as needed
# -----------------------------
declare -A DEVICE_URI_MAP=(
    [rpi4]="https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.1.y/arch/arm64/configs/bcm2711_defconfig"
    [rpi5]="https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.1.y/arch/arm64/configs/bcm2712_defconfig"
    [orangepi5]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5/linux-rk3588-current.config"
    [orangepi5_plus]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5_plus/linux-rk3588-current.config"
    [orangepi6]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi6/linux-rk3588-current.config"
    [orangepi6_plus]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi6_plus/linux-rk3588-current.config"
    [apple_m1]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m2]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m3]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m4]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [pine64]="https://raw.githubusercontent.com/pine64/linux/pine64-kernel/arch/arm64/configs/pine64_defconfig"
    [khadas_ampere_altra]="https://raw.githubusercontent.com/khadas/linux/khadas-vims-5.15/arch/arm64/configs/ampere_defconfig"
)

# -----------------------------
# Fetch upstream device configs
# -----------------------------
echo "Fetching device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    dest="${FILESDIR}/config-${device}-${PVR}"
    url="${DEVICE_URI_MAP[$device]}"
    echo "Fetching $device config -> $dest"
    curl -sSL "$url" -o "$dest" || echo "WARN: Failed to fetch $device config"
done

# -----------------------------
# Generate per-device merged configs
# -----------------------------
echo "Generating per-device merged configs..."
for cfg_file in "${FILESDIR}"/config-*-"${PVR}"; do
    device=$(basename "$cfg_file" | cut -d'-' -f2)
    merged="${FILESDIR}/pentoo-${device}.config"
    cp "$BASE_ARM64" "$merged"
    cat "$cfg_file" >> "$merged"
    # Append localversion
    echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-arm64-${device}\"" >> "$merged"
done

# -----------------------------
# Generate kitchen-sink merged config
# -----------------------------
KITCHEN_SINK="${FILESDIR}/pentoo-arm64-all.config"
cp "$BASE_ARM64" "$KITCHEN_SINK"
for cfg_file in "${FILESDIR}"/config-*-"${PVR}"; do
    [[ -f "$cfg_file" ]] && cat "$cfg_file" >> "$KITCHEN_SINK"
done
echo "Kitchen-sink ARM64 config created: $KITCHEN_SINK"

# -----------------------------
# Copy all configs to /usr/share/pentoo-sources/
# -----------------------------
echo "Copying configs to $SHARE_DIR"
mkdir -p "$SHARE_DIR"
do_cp() { cp -v "$1" "$SHARE_DIR/"; }

do_cp "$BASE_ARM64"
for merged_cfg in "${FILESDIR}"/pentoo-*.config; do
    [[ -f "$merged_cfg" ]] && do_cp "$merged_cfg"
done
do_cp "$KITCHEN_SINK"

echo "All ARM64 configs are ready in $SHARE_DIR"
