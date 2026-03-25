#!/usr/bin/env bash
# generate-pentoo-arm64.sh
# Generate pentoo-arm64-base.config and device configs for ebuild

set -euo pipefail

# Configurable Pentoo version
PVR=${1:-"6.6.15"}       # kernel version
FILESDIR=$(dirname "$0")  # assume script lives in ebuild FILESDIR

echo "Generating ARM64 base config from AMD64 config..."
BASE_AMD64="/usr/share/pentoo-sources/config-amd64-${PVR}"

if [[ ! -f "$BASE_AMD64" ]]; then
    echo "ERROR: AMD64 base config not found at $BASE_AMD64"
    exit 1
fi

# 1️⃣ Copy AMD64 config to ARM64 base
cp "$BASE_AMD64" "${FILESDIR}/pentoo-arm64-base.config"

# 2️⃣ Transform for ARM64
sed -i \
    -e 's/CONFIG_X86=y/CONFIG_ARM64=y/' \
    -e 's/CONFIG_X86_64=y/CONFIG_ARM64=y/' \
    -e '/CONFIG_AMD64_ONLY_FEATURE/d' \
    "${FILESDIR}/pentoo-arm64-base.config"

echo "ARM64 base config generated: ${FILESDIR}/pentoo-arm64-base.config"

# 3️⃣ Fetch device-specific configs
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

echo "Fetching upstream device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    url="${DEVICE_URI_MAP[$device]}"
    dest="${FILESDIR}/config-${device}-${PVR}"
    echo "Fetching $device -> $dest"
    curl -sSL "$url" -o "$dest" || echo "Failed to fetch $device config, skipping"
done

# 4️⃣ Optional: kitchen-sink config (merge all devices + base)
KITCHEN_SINK="${FILESDIR}/pentoo-arm64-all.config"
cp "${FILESDIR}/pentoo-arm64-base.config" "$KITCHEN_SINK"

for cfg in "${FILESDIR}"/config-*-"${PVR}"; do
    [[ -f "$cfg" ]] && cat "$cfg" >> "$KITCHEN_SINK"
done

echo "Kitchen-sink ARM64 config created: $KITCHEN_SINK"
echo "All configs ready in $FILESDIR"
