#!/usr/bin/env bash
# fetch-arm64-configs.sh
# Fetch upstream configs and store in FILESDIR for ebuild

set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
declare -A DEVICE_URI_MAP=(
    [rpi4]="https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.1.y/arch/arm64/configs/bcm2711_defconfig"
    [rpi5]="https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.1.y/arch/arm64/configs/bcm2712_defconfig"
    [orangepi5]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5/linux-rk3588-current.config"
    [orangepi5_plus]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5_plus/linux-rk3588-current.config"
    [orangepi6]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi6/linux-rk3588-current.config"
    [orangepi6_plus]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi6_plus/linux-rk3588-current.config"
    [apple_m1]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m2]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [pine64]="https://raw.githubusercontent.com/pine64/linux/pine64-kernel/arch/arm64/configs/pine64_defconfig"
    [khadas_ampere_altra]="https://raw.githubusercontent.com/khadas/linux/khadas-vims-5.15/arch/arm64/configs/ampere_defconfig"
)

for device in "${!DEVICE_URI_MAP[@]}"; do
    url="${DEVICE_URI_MAP[$device]}"
    dest="${WORKDIR}/config-${device}-6.6.15"
    echo "Fetching $device config -> $dest"
    curl -sSL "$url" -o "$dest"
done

echo "All upstream configs fetched to FILESDIR"
