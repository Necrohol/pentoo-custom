#!/usr/bin/env bash
# generate-pentoo-arm64.sh
# Generates a "kitchen sink" ARM64 Pentoo kernel config and prepares DTBs
# For use with your arm64 binary Pentoo kernel ebuild

set -euo pipefail

WORKDIR="${PWD}/work"
FILESDIR="${PWD}/files"
BASE_AMD64_CONFIG="${FILESDIR}/config-amd64-${PVR:-$(jq -r '.version' <<< '{"version":"6.1"}')}"
OUTPUT_CONFIG="${FILESDIR}/pentoo-arm64-all.config"
DTB_DIR="${FILESDIR}/dtb"

mkdir -p "$WORKDIR" "$DTB_DIR"

echo "[*] Copying base amd64 config and transmogrifying to arm64..."
cp "$BASE_AMD64_CONFIG" "$WORKDIR/pentoo-arm64-base.config"
sed -i 's/x86_64/arm64/g; s/amd64/arm64/g' "$WORKDIR/pentoo-arm64-base.config"

# List of device configs to merge
declare -A DEVICE_CONFIG_URIS=(
    [rpi4]="https://github.com/raspberrypi/linux/raw/rpi-6.1.y/arch/arm64/configs/bcm2711_defconfig"
    [rpi5]="https://github.com/raspberrypi/linux/raw/rpi-6.1.y/arch/arm64/configs/bcm2711_defconfig"
    [orangepi5]="https://github.com/orangepi-xunlong/orangepi-build/raw/main/external/config/orangepi5_defconfig"
    [orangepi5_plus]="https://github.com/orangepi-xunlong/orangepi-build/raw/main/external/config/orangepi5_plus_defconfig"
    [apple_m1]="https://github.com/AsahiLinux/linux/raw/asahi/arch/arm64/configs/apple_m1_defconfig"
    [apple_m2]="https://github.com/AsahiLinux/linux/raw/asahi/arch/arm64/configs/apple_m2_defconfig"
    [apple_m3]="https://github.com/AsahiLinux/linux/raw/asahi/arch/arm64/configs/apple_m3_defconfig"
    [apple_m4]="https://github.com/AsahiLinux/linux/raw/asahi/arch/arm64/configs/apple_m4_defconfig"
    [pine64]="https://github.com/pine64/linux/raw/pine64-kernel/arch/arm64/configs/pine64_defconfig"
    [khadas_ampere_altra]="https://github.com/khadas/linux/raw/khadas-vims-5.15/arch/arm64/configs/ampere_defconfig"
    [odroid_m1]="https://github.com/<community>/odroid_m1_defconfig"
    [odroid_m2]="https://github.com/<community>/odroid_m2_defconfig"
    [rockchip_generic]="https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/configs/rockchip_linux_defconfig"
)

echo "[*] Fetching and merging device configs..."
for device in "${!DEVICE_CONFIG_URIS[@]}"; do
    uri="${DEVICE_CONFIG_URIS[$device]}"
    dest="${WORKDIR}/pentoo-${device}.config"
    echo "Fetching $device config..."
    wget -q -O "$dest" "$uri" || echo "Warning: $device config not available, skipping..."
done

# Merge all device configs with base
cat "$WORKDIR/pentoo-arm64-base.config" "$WORKDIR"/pentoo-*.config > "$OUTPUT_CONFIG"

# Add localversion
echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR:-6.1}-arm64-all\"" >> "$OUTPUT_CONFIG"

echo "[*] Copying device trees..."
# User should manually place DTBs in FILESDIR/dtb or script can pull from repos
# Example: cp ~/dtbs/*.dtb "$DTB_DIR/"
mkdir -p "$DTB_DIR"
echo "[*] Device tree directory: $DTB_DIR"

echo "[*] Finished generating pentoo-arm64-all.config"
echo "[*] Copy this config to /usr/share/pentoo-sources/ and rebuild ebuild"
