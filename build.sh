#!/bin/bash

###############################################################################
# build.sh - Kernel image packaging script for Qualcomm Linux development
#
# Usage:
#   ./build.sh --dtb <your.dtb> [--out <kernel_dir>] [--systemd <systemd_boot_dir>]
#              [--ramdisk <ramdisk_path>] [--images <output_dir>] [--cmdline <cmdline>] [--no-debug]
#
# Options:
#   --dtb       Name of the DTB file to use (required)
#   --out       Path to kernel build artifacts directory (default: ../kobj)
#   --systemd   Path to systemd boot binaries directory (default: ../artifacts/systemd/usr/lib/systemd/boot/efi)
#   --ramdisk   Path to ramdisk image (default: ../artifacts/ramdisk.gz)
#   --images    Output directory for generated images (default: ../images)
#   --cmdline   Append arguments to Default Kernel command line (default: predefined string)
#   --no-debug  Skip adding debug.config to kernel build
#
# Description:
#   This script builds the kernel, packages modules into a ramdisk, and generates
#   bootable images including `efi.bin`, `dtb.bin`, and `boot.img`. It uses the
#   `generate_boot_bins.sh` and `mkbootimg` tools for image creation.
#
# Notes:
#   - Run this script from within the kernel source directory.
#   - DTB file must exist in the kernel build artifacts directory.
###############################################################################

set -euo pipefail

# Default values
DTB_FILENAME="${1:-}"
KERNEL_BUILD_ARTIFACTS="$(realpath ../kobj)"
SYSTEMD_BOOT_DIR="$(realpath ../artifacts/systemd/usr/lib/systemd/boot/efi)"
RAMDISK="$(realpath ../artifacts/ramdisk.gz)"
IMAGES_OUTPUT="$(realpath ../images)"
KERNEL_CMDLINE="console=ttyMSM0,115200n8 earlycon qcom_geni_serial.con_enabled=1 qcom_scm.download_mode=1 reboot=panic_warm panic=-1 mitigations=auto"
NO_DEBUG=false

# Parse long options
eval set -- "$(getopt -n "$0" -o "" \
    --long dtb:,out:,systemd:,ramdisk:,images:,cmdline: -- "$@")"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dtb) DTB_FILENAME="$2"; shift 2 ;;
        --out) KERNEL_BUILD_ARTIFACTS="$(realpath "$2")"; shift 2 ;;
        --systemd) SYSTEMD_BOOT_DIR="$(realpath "$2")"; shift 2 ;;
        --ramdisk) RAMDISK="$(realpath "$2")"; shift 2 ;;
        --images) IMAGES_OUTPUT="$(realpath "$2")"; shift 2 ;;
        --cmdline) KERNEL_CMDLINE="$KERNEL_CMDLINE $2"; shift 2 ;;
        --no-debug) NO_DEBUG=true; shift ;;
        --) shift; break ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Check input dtb
if [[ -z "$DTB_FILENAME" ]]; then
    echo "Error: No DTB file provided."
    echo "Usage: $0 --dtb your.dtb [--out kernel_dir] [--systemd systemd_boot_dir] [--ramdisk ramdisk_path] [--images output_dir] [--cmdline cmdline] [--no-debug]"
    exit 1
fi

# Check ramdisk
if [[ ! -f "$RAMDISK" ]]; then
    echo "[ERROR] Ramdisk file not found at $RAMDISK"
    exit 1
fi

# Check systemd boot files
if [[ ! -f "$SYSTEMD_BOOT_DIR/systemd-bootaa64.efi" ]] || [[ ! -f "$SYSTEMD_BOOT_DIR/linuxaa64.efi.stub" ]]; then
    echo "[ERROR] Missing systemd boot files in $SYSTEMD_BOOT_DIR"
    exit 1
fi

mkdir -p "$IMAGES_OUTPUT"

# Build the kernel using Docker
echo "Building kernel..."

# Check if we are in the kernel source directory
if [ ! -f "Makefile" ] || [ ! -d "arch" ]; then
    echo "Error: This script must be run from the kernel source directory."
    exit 1
fi

# Check for each config fragment and append if present
CONFIG_FRAGMENTS=""
[[ -f "arch/arm64/configs/prune.config" ]] && CONFIG_FRAGMENTS+=" arch/arm64/configs/prune.config"
[[ -f "arch/arm64/configs/qcom.config" ]] && CONFIG_FRAGMENTS+=" arch/arm64/configs/qcom.config"
[[ "$NO_DEBUG" = false && -f "kernel/configs/debug.config" ]] && CONFIG_FRAGMENTS+=" kernel/configs/debug.config"

# Create build artifacts directory
mkdir -p "$KERNEL_BUILD_ARTIFACTS"

# Merge configs fragments
if [[ -n "$CONFIG_FRAGMENTS" ]]; then
env -u KCONFIG_CONFIG ./scripts/kconfig/merge_config.sh -m \
    -O "$KERNEL_BUILD_ARTIFACTS" \
	arch/arm64/configs/defconfig "$CONFIG_FRAGMENTS"
else
    cp arch/arm64/configs/defconfig "$KERNEL_BUILD_ARTIFACTS/.config"
fi
make O="$KERNEL_BUILD_ARTIFACTS" olddefconfig
make O="$KERNEL_BUILD_ARTIFACTS" -j$(nproc)
make O="$KERNEL_BUILD_ARTIFACTS" -j$(nproc) dir-pkg INSTALL_MOD_STRIP=1

# Locate DTB in kernel build artifacts
DTB_PATH=$(find "$KERNEL_BUILD_ARTIFACTS" -name "$DTB_FILENAME" -print -quit)
if [[ -z "$DTB_PATH" ]];  then
    echo "Error: DTB file '$DTB_FILENAME' not found in $KERNEL_BUILD_ARTIFACTS."
    exit 1
fi

# Package DLKMs into ramdisk
CONCATENATE_RAMDISK="$IMAGES_OUTPUT/$(basename "$RAMDISK" .gz)_$(date +"%Y%m%d_%H%M%S").gz"
cp "$RAMDISK" "$CONCATENATE_RAMDISK"
(
    cd "$KERNEL_BUILD_ARTIFACTS/tar-install"
    find lib/modules | cpio -o -H newc -R +0:+0 | gzip -9 >> "$CONCATENATE_RAMDISK"
)

# Package kernel image into EFI binary
echo "Creating efi.bin..."
KERNEL_IMAGE="$KERNEL_BUILD_ARTIFACTS"/arch/arm64/boot/Image
generate_boot_bins.sh efi \
    --ramdisk "$CONCATENATE_RAMDISK" \
    --systemd-boot "$SYSTEMD_BOOT_DIR/systemd-bootaa64.efi" \
    --stub "$SYSTEMD_BOOT_DIR/linuxaa64.efi.stub" \
    --linux "$KERNEL_IMAGE" \
    --cmdline "${KERNEL_CMDLINE:-}" \
    --output "$IMAGES_OUTPUT"

echo "Creating efi_with_dtb.bin..."
KERNEL_IMAGE="$KERNEL_BUILD_ARTIFACTS"/arch/arm64/boot/Image
generate_boot_bins.sh efi \
    --ramdisk "$CONCATENATE_RAMDISK" \
    --systemd-boot "$SYSTEMD_BOOT_DIR/systemd-bootaa64.efi" \
    --stub "$SYSTEMD_BOOT_DIR/linuxaa64.efi.stub" \
    --linux "$KERNEL_IMAGE" \
    --devicetree "$DTB_PATH" \
    --cmdline "${KERNEL_CMDLINE:-}" \
    --output "$IMAGES_OUTPUT"

# Generate dtb.bin
echo "Creating dtb.bin..."
generate_boot_bins.sh dtb \
    --input "$DTB_PATH" \
    --output "$IMAGES_OUTPUT"

# Package kernel image into boot binary
echo "Creating boot.img..."
mkbootimg --header_version 2 \
    --kernel "$KERNEL_IMAGE" \
    --dtb "$DTB_PATH" \
    --cmdline "${KERNEL_CMDLINE:-}" \
    --ramdisk "$CONCATENATE_RAMDISK" \
    --base 0x80000000 \
    --pagesize 2048 \
    --output "$IMAGES_OUTPUT/boot.img"

echo "Build completed successfully. Images are in $IMAGES_OUTPUT."