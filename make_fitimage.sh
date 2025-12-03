#!/bin/bash

###############################################################################
# make_fitimage.sh - FIT image packaging script for Qualcomm Linux development
#
# Usage:
#   ./make_fitimage.sh --metadata <metadata_dts> --its <fitimage_its> \
#       [--kobj <kernel_build_artifacts>] [--output <output_dir>]
#
# Options:
#   --metadata  Path to metadata DTS file (default: ../artifacts/qcom-dtb-metadata/qcom-metadata.dts)
#   --its       Path to FIT image ITS file (default: ../artifacts/qcom-dtb-metadata/qcom-fitimage.its)
#   --kobj      Path to kernel build artifacts directory (default: ../kobj)
#   --output    Output directory for generated FIT image (default: ../images)
#   --help      Show this help message and exit
#
# Description:
#   This script generates a FIT image using Qualcomm metadata and ITS files.
#   It compiles the metadata DTS to DTB, creates the FIT image using mkimage,
#   and packages the final image using generate_boot_bins.sh.
###############################################################################

set -e

# Default paths
KERNEL_BUILD_ARTIFACTS="../kobj"
OUTPUT_DIR="../images"
METADATA_DTS_PATH="../artifacts/qcom-dtb-metadata/qcom-metadata.dts"
FIT_IMAGE_ITS_PATH="../artifacts/qcom-dtb-metadata/qcom-fitimage.its"

# Help message
function show_help() {
    cat <<EOF
Usage:
  ./make_fitimage.sh [OPTIONS]

Options:
  --metadata <path>  Path to metadata DTS file (default: $METADATA_DTS_PATH)
  --its <path>       Path to FIT image ITS file (default: $FIT_IMAGE_ITS_PATH)
  --kobj <path>      Path to kernel build artifacts directory (default: $KERNEL_BUILD_ARTIFACTS)
  --output <path>    Output directory for generated FIT image (default: $OUTPUT_DIR)
  --help             Show this help message and exit

Description:
  This script generates a FIT image using Qualcomm metadata and ITS files.
  It compiles the metadata DTS to DTB, creates the FIT image using mkimage,
  and packages the final image using generate_boot_bins.sh.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kobj) KERNEL_BUILD_ARTIFACTS="$2"; shift 2 ;;
        --metadata) METADATA_DTS_PATH="$2"; shift 2 ;;
        --its) FIT_IMAGE_ITS_PATH="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Resolve paths
KERNEL_BUILD_ARTIFACTS="$(realpath "$KERNEL_BUILD_ARTIFACTS")"
OUTPUT_DIR="$(realpath "$OUTPUT_DIR")"
METADATA_DTS_PATH="$(realpath "$METADATA_DTS_PATH")"
FIT_IMAGE_ITS_PATH="$(realpath "$FIT_IMAGE_ITS_PATH")"

# Function to create FIT image
function create_fit_image() {
    # Cleaning previous FIT image artifacts
    rm -f "${OUTPUT_DIR}/fit_dtb.bin"
    rm -rf "${OUTPUT_DIR}/fit_dir"
    rm -f "${KERNEL_BUILD_ARTIFACTS}/qcom-fitimage.its"
    rm -f "${KERNEL_BUILD_ARTIFACTS}/qcom-metadata.dtb"

    # Creating output directory
    mkdir -p "$OUTPUT_DIR/fit_dir"

    # Copying ITS file to kernel build artifacts path
    cp "$FIT_IMAGE_ITS_PATH" "$KERNEL_BUILD_ARTIFACTS/qcom-fitimage.its"

    #Compiling metadata DTS to DTB
    dtc -I dts -O dtb -o "${KERNEL_BUILD_ARTIFACTS}/qcom-metadata.dtb" "${METADATA_DTS_PATH}"

    echo "Generating FIT image..."
    mkimage -f "${KERNEL_BUILD_ARTIFACTS}/qcom-fitimage.its" "${OUTPUT_DIR}/fit_dir/qclinux_fit.img" -E -B 8

    echo "Packing final image into fit_dtb.bin..."
    SELF_DIR="$(dirname "$(realpath "$0")")"
    # Call generate_boot_bins.sh from the same directory
    "${SELF_DIR}/generate_boot_bins.sh" bin --input "${OUTPUT_DIR}/fit_dir" --output "${OUTPUT_DIR}/dtb.bin"

}

echo "Starting FIT image creation..."
create_fit_image
echo "FIT image created at ${OUTPUT_DIR}/dtb.bin"
