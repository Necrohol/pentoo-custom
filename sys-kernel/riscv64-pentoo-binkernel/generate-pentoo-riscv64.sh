#!/usr/bin/env bash
# generate-pentoo-riscv64.sh
# Fully automated RISC-V 64-bit Pentoo kernel config generator
# EDK2/UEFI-aware per-board fragment merging

set -euo pipefail

# -----------------------------
# Detect latest Pentoo kernel version
# -----------------------------
OVERLAY_JSON="https://api.github.com/repos/pentoo/pentoo-overlay/contents/sys-kernel/pentoo-sources"

echo "Fetching latest Pentoo kernel version..."
PVR=$(curl -sSL "$OVERLAY_JSON" \
    | jq -r '.[] | select(.name|test("^pentoo-sources-[0-9]+\\.[0-9]+\\.[0-9]+\\.ebuild$")) | .name' \
    | sed -E 's/pentoo-sources-([0-9]+\.[0-9]+\.[0-9]+)\.ebuild/\1/' \
    | sort -V | tail -n1)

[[ -z "$PVR" ]] && { echo "ERROR: Could not detect version."; exit 1; }
echo "Latest Pentoo kernel version: $PVR"

# -----------------------------
# Paths
# -----------------------------
FILESDIR=$(dirname "$0")
SHARE_DIR="/usr/share/pentoo-sources"
FRAG_DIR="${FILESDIR}/fragments"
BASE_AMD64="${SHARE_DIR}/config-amd64-${PVR}"
BASE_RISCV64="${FILESDIR}/pentoo-riscv64-base.config"

[[ ! -f "$BASE_AMD64" ]] && { echo "ERROR: AMD64 base not found at $BASE_AMD64"; exit 1; }

mkdir -p "$FRAG_DIR"

# -----------------------------
# Transmogrify amd64 -> riscv64 base
# Kill x86-specific only -- leave EFI/ACPI to board fragments
# -----------------------------
echo "Transmogrifying AMD64 config to RISC-V 64 base..."
cp "$BASE_AMD64" "$BASE_RISCV64"

sed -i \
    -e 's/x86_64/riscv64/g' \
    -e 's/amd64/riscv64/g' \
    -e '/^CONFIG_X86/d' \
    -e '/^CONFIG_IA32/d' \
    -e '/^CONFIG_COMPAT_32/d' \
    -e '/^CONFIG_EFI_MIXED/d' \
    -e 's/CONFIG_MTRR=y/# CONFIG_MTRR is not set/' \
    -e 's/CONFIG_MICROCODE=y/# CONFIG_MICROCODE is not set/' \
    -e 's/CONFIG_X86_MSR=y/# CONFIG_X86_MSR is not set/' \
    -e 's/CONFIG_X86_CPUID=y/# CONFIG_X86_CPUID is not set/' \
    "$BASE_RISCV64"

# Append riscv64 base platform requirements
cat >> "$BASE_RISCV64" <<'EOF'

# RISC-V base platform
CONFIG_RISCV_SBI=y
CONFIG_RISCV_SBI_V01=y
CONFIG_RISCV_TIMER=y
CONFIG_CLINT_TIMER=y
CONFIG_PLIC=y
CONFIG_HVC_RISCV_SBI=y
CONFIG_SERIAL_EARLYCON_RISCV_SBI=y
EOF

echo "RISC-V 64 base config: $BASE_RISCV64"

# -----------------------------
# EDK2/UEFI fragment
# -----------------------------
cat > "${FRAG_DIR}/uefi-edk2.fragment" <<'EOF'

# EDK2 UEFI firmware -- full grub2 + MOK chain
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFIVAR_FS=y
CONFIG_EFI_RUNTIME_WRAPPERS=y
CONFIG_EFI_CAPSULE_LOADER=y
CONFIG_FB_EFI=y
CONFIG_SYSFB_SIMPLEFB=y
CONFIG_DRM_SIMPLEDRM=y
# MOK / Secure Boot chain
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
# No-UEFI fragment (U-Boot/OpenSBI direct)
# -----------------------------
cat > "${FRAG_DIR}/uefi-off.fragment" <<'EOF'

# No EDK2 -- U-Boot/OpenSBI direct boot
# CONFIG_EFI is not set
# CONFIG_EFIVAR_FS is not set
CONFIG_OF=y
CONFIG_OF_EARLY_FLATTREE=y
EOF

# -----------------------------
# ACPI fragments
# -----------------------------
cat > "${FRAG_DIR}/acpi-on.fragment" <<'EOF'
CONFIG_ACPI=y
CONFIG_ACPI_REDUCED_HARDWARE_ONLY=y
EOF

cat > "${FRAG_DIR}/acpi-off.fragment" <<'EOF'
# CONFIG_ACPI is not set
EOF

# -----------------------------
# Device config URIs
# -----------------------------
declare -A DEVICE_URI_MAP=(
    [visionfive2]="https://raw.githubusercontent.com/starfive-tech/linux/JH7110_VisionFive2_upstream/arch/riscv/configs/starfive_visionfive2_defconfig"
    [licheerv]="https://raw.githubusercontent.com/smaeul/linux/d1-wip/arch/riscv/configs/allwinner_d1_defconfig"
    [licheerv_nano]="https://raw.githubusercontent.com/milkv-duo/duo-buildroot-sdk/develop/linux_5.10/arch/riscv/configs/milkv-duo_defconfig"
    [milkv_pioneer]="https://raw.githubusercontent.com/milkv-community/linux/sg2042-dev/arch/riscv/configs/sg2042_defconfig"
    [beaglev_ahead]="https://raw.githubusercontent.com/beagleboard/linux/v6.1-BeagleV-Ahead/arch/riscv/configs/defconfig"
    [generic_rv64]="https://raw.githubusercontent.com/torvalds/linux/master/arch/riscv/configs/defconfig"
)

# -----------------------------
# EDK2 + ACPI capability per board
# -----------------------------
declare -A DEVICE_EDK2=(
    [visionfive2]=1
    [milkv_pioneer]=1
    [beaglev_ahead]=0
    [licheerv]=0
    [licheerv_nano]=0
    [generic_rv64]=1
)

declare -A DEVICE_ACPI=(
    [visionfive2]=1
    [milkv_pioneer]=1
    [beaglev_ahead]=0
    [licheerv]=0
    [licheerv_nano]=0
    [generic_rv64]=0
)

# -----------------------------
# Fetch upstream device configs
# -----------------------------
echo "Fetching RISC-V device configs..."
for device in "${!DEVICE_URI_MAP[@]}"; do
    dest="${FILESDIR}/config-${device}-${PVR}"
    url="${DEVICE_URI_MAP[$device]}"
    echo "  ${device} -> ${dest}"
    curl -sSL "$url" -o "$dest" \
        || echo "WARN: Failed to fetch ${device} config"
done

# -----------------------------
# Per-device merged configs
# -----------------------------
echo "Generating per-device merged configs..."
for cfg_file in "${FILESDIR}"/config-*-"${PVR}"; do
    [[ ! -f "$cfg_file" ]] && continue

    device=$(basename "$cfg_file" | sed -E 's/config-(.+)-[0-9].+/\1/')
    merged="${FILESDIR}/pentoo-riscv64-${device}.config"

    echo "  Merging: ${device}"
    cp "$BASE_RISCV64" "$merged"
    cat "$cfg_file" >> "$merged"

    # EDK2/UEFI fragment
    if [[ "${DEVICE_EDK2[$device]:-0}" == "1" ]]; then
        echo "    + EDK2/UEFI"
        cat "${FRAG_DIR}/uefi-edk2.fragment" >> "$merged"
    else
        echo "    + no-UEFI"
        cat "${FRAG_DIR}/uefi-off.fragment" >> "$merged"
    fi

    # ACPI fragment
    if [[ "${DEVICE_ACPI[$device]:-0}" == "1" ]]; then
        echo "    + ACPI"
        cat "${FRAG_DIR}/acpi-on.fragment" >> "$merged"
    else
        echo "    + no-ACPI"
        cat "${FRAG_DIR}/acpi-off.fragment" >> "$merged"
    fi

    # Localversion
    echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-riscv64-${device}\"" >> "$merged"
done

# -----------------------------
# Kitchen-sink config
# -----------------------------
echo "Generating kitchen-sink config..."
KITCHEN_SINK="${FILESDIR}/pentoo-riscv64-all.config"
cp "$BASE_RISCV64" "$KITCHEN_SINK"
cat "${FRAG_DIR}/uefi-edk2.fragment" >> "$KITCHEN_SINK"
cat "${FRAG_DIR}/acpi-on.fragment"   >> "$KITCHEN_SINK"
for cfg_file in "${FILESDIR}"/config-*-"${PVR}"; do
    [[ -f "$cfg_file" ]] && cat "$cfg_file" >> "$KITCHEN_SINK"
done
echo "CONFIG_LOCALVERSION=\"-pentoo-${PVR}-riscv64-all\"" >> "$KITCHEN_SINK"
echo "Kitchen-sink config: $KITCHEN_SINK"

# -----------------------------
# Deploy to SHARE_DIR
# -----------------------------
echo "Deploying to ${SHARE_DIR}..."
mkdir -p "$SHARE_DIR"
cp -v "$BASE_RISCV64" "$SHARE_DIR/"
for cfg in "${FILESDIR}"/pentoo-riscv64-*.config; do
    [[ -f "$cfg" ]] && cp -v "$cfg" "$SHARE_DIR/"
done
cp -v "$KITCHEN_SINK" "$SHARE_DIR/"

echo ""
echo "Done. RISC-V 64 configs ready in ${SHARE_DIR}"
echo "NOTE: olddefconfig pass required in ebuild src_configure to reconcile conflicts"
