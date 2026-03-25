#!/usr/bin/env bash
# generate-pentoo-arm64.sh
# Generate Pentoo ARM64 base and per-device configs
# UEFI preferred; U-Boot only for boards without EDK2

set -euo pipefail

# -----------------------------
# Detect / set kernel version
# -----------------------------
if [[ -n "${1:-}" ]]; then
    PVR="$1"
else
    echo "Probing Pentoo overlay for latest version..."
    PVR=$(curl -sSL "https://api.github.com/repos/pentoo/pentoo-overlay/contents/sys-kernel/pentoo-sources" \
        | jq -r '.[] | select(.name|test("^pentoo-sources-[0-9]+\\.[0-9]+\\.[0-9]+\\.ebuild$")) | .name' \
        | sed -E 's/pentoo-sources-([0-9]+\.[0-9]+\.[0-9]+)\.ebuild/\1/' \
        | sort -V | tail -n1)
    [[ -z "$PVR" ]] && { echo "ERROR: Could not detect Pentoo version"; exit 1; }
fi
echo "Kernel version: $PVR"

# -----------------------------
# Paths
# -----------------------------
FILESDIR="$(cd "$(dirname "$0")" && pwd)"
SHARE_DIR="/usr/share/pentoo-sources"
FRAG_DIR="${FILESDIR}/fragments"

BASE_AMD64="${SHARE_DIR}/config-amd64-${PVR}"
BASE_ARM64="${FILESDIR}/pentoo-arm64-base.config"

mkdir -p "$FRAG_DIR"

[[ ! -f "$BASE_AMD64" ]] && { echo "ERROR: AMD64 base config not found at $BASE_AMD64"; exit 1; }

# -----------------------------
# Transmogrify AMD64 -> ARM64
# -----------------------------
echo "Generating ARM64 base config..."
cp "$BASE_AMD64" "$BASE_ARM64"
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
    "$BASE_ARM64"

# -----------------------------
# Fragments
# -----------------------------
cat > "$FRAG_DIR/uefi-edk2.fragment" <<'EOF'
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

cat > "$FRAG_DIR/uboot-only.fragment" <<'EOF'
# CONFIG_EFI is not set
# CONFIG_EFIVAR_FS is not set
CONFIG_OF=y
CONFIG_OF_EARLY_FLATTREE=y
EOF

cat > "$FRAG_DIR/acpi-on.fragment" <<'EOF'
CONFIG_ACPI=y
CONFIG_ACPI_REDUCED_HARDWARE_ONLY=y
EOF

cat > "$FRAG_DIR/acpi-off.fragment" <<'EOF'
# CONFIG_ACPI is not set
EOF

# -----------------------------
# Device mapping
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

declare -A DEVICE_UEFI=(
    [rpi4]=1
    [rpi5]=1
    [orangepi5]=1
    [orangepi5_plus]=1
    [orangepi6]=1
    [orangepi6_plus]=1
    [apple_m1]=1
    [apple_m2]=1
    [apple_m3]=1
    [apple_m4]=1
    [pine64]=0
    [khadas_ampere_altra]=1
)

declare -A DEVICE_ACPI=(
    [rpi5]=1
    [apple_m1]=1
    [apple_m2]=1
    [apple_m3]=1
    [apple_m4]=1
    [khadas_ampere_altra]=1
)

# -----------------------------
# Fetch upstream device configs
# -----------------------------
echo "Fetching device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    dest="${FILESDIR}/config-${device}-${PVR}"
    url="${DEVICE_URI_MAP[$device]}"
    echo "  $device"
    curl -sSL "$url" -o "$dest" || echo "    WARN: failed to fetch $device"
done

# -----------------------------
# Generate per-device configs
# -----------------------------
echo "Generating per-device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    cfg="${FILESDIR}/config-${device}-${PVR}"
    [[ ! -f "$cfg" ]] && { echo "  SKIP: $device (no config)"; continue; }
    merged="${FILESDIR}/pentoo-arm64-${device}.config"
    cp "$BASE_ARM64" "$merged"
    cat "$cfg" >> "$merged"

    if [[ "${DEVICE_UEFI[$device]:-1}" == "1" ]]; then
        cat "$FRAG_DIR/uefi-edk2.fragment" >> "$merged"
    else
        cat "$FRAG_DIR/uboot-only.fragment" >> "$merged"
    fi

    if [[ "${DEVICE_ACPI[$device]:-0}" == "1" ]]; then
        cat "$FRAG_DIR/acpi-on.fragment" >> "$merged"
    else
        cat "$FRAG_DIR/acpi-off.fragment" >> "$merged"
    fi

    echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-arm64-${device}\"" >> "$merged"
done

# -----------------------------
# Kitchen-sink config
# -----------------------------
KITCHEN="${FILESDIR}/pentoo-arm64-all.config"
cp "$BASE_ARM64" "$KITCHEN"
cat "$FRAG_DIR/uefi-edk2.fragment" >> "$KITCHEN"
cat "$FRAG_DIR/acpi-on.fragment" >> "$KITCHEN"
for cfg in "${FILESDIR}"/config-*-"${PVR}"; do
    [[ -f "$cfg" ]] && cat "$cfg" >> "$KITCHEN"
done
echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-arm64-all\"" >> "$KITCHEN"
echo "Kitchen-sink config: $KITCHEN"

# -----------------------------
# Deploy configs
# -----------------------------
echo "Deploying to $SHARE_DIR..."
mkdir -p "$SHARE_DIR"
cp -v "$BASE_ARM64" "$SHARE_DIR/"
cp -v "${FILESDIR}"/pentoo-arm64-*.config "$SHARE_DIR/"
cp -v "$KITCHEN" "$SHARE_DIR/"

echo "Done. ARM64 configs ready in $SHARE_DIR"
# -----------------------------
# Transmogrify amd64 -> arm64 base
# Kill x86-specific only -- EFI/ACPI left to fragments
# -----------------------------
echo "Transmogrifying AMD64 -> ARM64 base..."
cp "$BASE_AMD64" "$BASE_ARM64"

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
    "$BASE_ARM64"

echo "ARM64 base config : ${BASE_ARM64}"

# -----------------------------
# UEFI/EDK2 fragment -- preferred default
# Boards with EDK2 get full grub2 + MOK chain
# If EDK2 arrives later for a board, this config will just work
# -----------------------------
cat > "${FRAG_DIR}/uefi-edk2.fragment" <<'EOF'

# UEFI/EDK2 -- grub2 + MOK Secure Boot chain
# Default preferred -- works with any EDK2 firmware fd
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

# -----------------------------
# U-Boot fragment -- only for boards confirmed no EDK2
# -----------------------------
cat > "${FRAG_DIR}/uboot-only.fragment" <<'EOF'

# U-Boot direct boot -- no EDK2 available
# CONFIG_EFI is not set
# CONFIG_EFIVAR_FS is not set
CONFIG_OF=y
CONFIG_OF_EARLY_FLATTREE=y
EOF

# -----------------------------
# ACPI fragment
# -----------------------------
cat > "${FRAG_DIR}/acpi-on.fragment" <<'EOF'
CONFIG_ACPI=y
CONFIG_ACPI_REDUCED_HARDWARE_ONLY=y
EOF

cat > "${FRAG_DIR}/acpi-off.fragment" <<'EOF'
# CONFIG_ACPI is not set
EOF

# -----------------------------
# Device URI map
# -----------------------------
declare -A DEVICE_URI_MAP=(
    [rpi4]="https://raw.githubusercontent.com/raspberrypi/linux/${RPI_BRANCH}/arch/arm64/configs/bcm2711_defconfig"
    [rpi5]="https://raw.githubusercontent.com/raspberrypi/linux/${RPI_BRANCH}/arch/arm64/configs/bcm2712_defconfig"
    [orangepi5]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5/linux-rk3588-current.config"
    [orangepi5_plus]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi5_plus/linux-rk3588-current.config"
    [orangepi6]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi6/linux-rk3588-current.config"
    [orangepi6_plus]="https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/main/external/config/orangepi6_plus/linux-rk3588-current.config"
    [apple_m1]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m2]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m3]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [apple_m4]="https://raw.githubusercontent.com/AsahiLinux/linux/asahi/arch/arm64/configs/asahi_defconfig"
    [pine64]="https://raw.githubusercontent.com/pine64/linux/pine64-kernel/arch/arm64/configs/pine64_defconfig"
    [rockchip_generic]="https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/configs/defconfig"
    [odroid_m1]="https://raw.githubusercontent.com/tobetter/linux/odroid-6.1.y/arch/arm64/configs/odroid_defconfig"
    [odroid_m2]="https://raw.githubusercontent.com/tobetter/linux/odroid-6.1.y/arch/arm64/configs/odroid_defconfig"
    [khadas_ampere_altra]="https://raw.githubusercontent.com/AmpereComputing/ampere-lts-kernel/linux-6.6.y/arch/arm64/configs/defconfig"
)

# -----------------------------
# UEFI preferred -- only explicitly off for confirmed no-EDK2 boards
# New/unknown boards default to UEFI on
# -----------------------------
declare -A DEVICE_UEFI=(
    [rpi4]=1
    [rpi5]=1
    [orangepi5]=0        # RK3588 -- U-Boot only currently
    [orangepi5_plus]=0
    [orangepi6]=0
    [orangepi6_plus]=0
    [apple_m1]=1         # Asahi has own EFI
    [apple_m2]=1
    [apple_m3]=1
    [apple_m4]=1
    [pine64]=0
    [rockchip_generic]=0
    [odroid_m1]=0
    [odroid_m2]=0
    [khadas_ampere_altra]=1
)

declare -A DEVICE_ACPI=(
    [rpi5]=1
    [apple_m1]=1
    [apple_m2]=1
    [apple_m3]=1
    [apple_m4]=1
    [khadas_ampere_altra]=1
)

# -----------------------------
# Fetch upstream device configs
# -----------------------------
echo ""
echo "Fetching upstream device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    dest="${FILESDIR}/config-${device}-${PVR}"
    url="${DEVICE_URI_MAP[$device]}"
    echo "  ${device}"
    curl -sSL "$url" -o "$dest" \
        || echo "  WARN: Failed to fetch ${device}, skipping"
done

# -----------------------------
# Per-device merged configs
# -----------------------------
echo ""
echo "Generating per-device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    cfg_file="${FILESDIR}/config-${device}-${PVR}"
    [[ ! -f "$cfg_file" ]] && { echo "  SKIP: ${device} (no config fetched)"; continue; }

    merged="${FILESDIR}/pentoo-arm64-${device}.config"
    cp "$BASE_ARM64" "$merged"
    cat "$cfg_file" >> "$merged"

    # UEFI preferred -- default 1 for unknown boards
    if [[ "${DEVICE_UEFI[$device]:-1}" == "1" ]]; then
        echo "  ${device}: UEFI/EDK2 + MOK"
        cat "${FRAG_DIR}/uefi-edk2.fragment" >> "$merged"
    else
        echo "  ${device}: U-Boot only"
        cat "${FRAG_DIR}/uboot-only.fragment" >> "$merged"
    fi

    # ACPI -- default off, explicitly on per board
    if [[ "${DEVICE_ACPI[$device]:-0}" == "1" ]]; then
        cat "${FRAG_DIR}/acpi-on.fragment" >> "$merged"
    else
        cat "${FRAG_DIR}/acpi-off.fragment" >> "$merged"
    fi

    echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-arm64-${device}\"" >> "$merged"
done

# -----------------------------
# Kitchen-sink -- UEFI on, ACPI on
# -----------------------------
echo ""
KITCHEN_SINK="${FILESDIR}/pentoo-arm64-all.config"
cp "$BASE_ARM64" "$KITCHEN_SINK"
cat "${FRAG_DIR}/uefi-edk2.fragment" >> "$KITCHEN_SINK"
cat "${FRAG_DIR}/acpi-on.fragment"   >> "$KITCHEN_SINK"
for cfg in "${FILESDIR}"/config-*-"${PVR}"; do
    [[ -f "$cfg" ]] && cat "$cfg" >> "$KITCHEN_SINK"
done
echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-arm64-all\"" >> "$KITCHEN_SINK"
echo "Kitchen-sink config : ${KITCHEN_SINK}"

# -----------------------------
# Deploy to SHARE_DIR
# -----------------------------
echo ""
echo "Deploying to ${SHARE_DIR}..."
mkdir -p "$SHARE_DIR"
cp -v "$BASE_ARM64" "$SHARE_DIR/"
for cfg in "${FILESDIR}"/pentoo-arm64-*.config; do
    [[ -f "$cfg" ]] && cp -v "$cfg" "$SHARE_DIR/"
done
cp -v "$KITCHEN_SINK" "$SHARE_DIR/"

echo ""
echo "Done. ARM64 configs ready in ${SHARE_DIR}"
echo "NOTE: olddefconfig pass required in ebuild src_configure to reconcile conflicts"
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
