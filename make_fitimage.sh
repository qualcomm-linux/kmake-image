#!/bin/bash

###############################################################################
# make_fitimage.sh - FIT image packaging script for Qualcomm Linux development
#
# Usage:
#   ./make_fitimage.sh [--out <kernel_build_artifacts>] [--input <metadata_its_dir>] [--images <output_dir>]
#
# Options:
#   --out     Path to kernel build artifacts directory (default: ../kobj)
#   --input   Path to input metadata and ITS file directory path (default: clone from qcom-dtb-metadata repo)
#   --images  Output directory for generated FIT image (default: ../images)
#
# Description:
#   This script generates a FIT image using Qualcomm metadata and ITS files.
#   It compiles the metadata DTS to DTB, creates the FIT image using mkimage,
#   and packages the final image using generate_boot_bins.sh
###############################################################################

set -e

# Default paths
KERNEL_BUILD_ARTIFACTS="$(realpath ../kobj)"
IMAGES_OUTPUT="$(realpath ../images)"

# Parse long options
eval set -- "$(getopt -n "$0" -o "" --long out:,input:,images: -- "$@")"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) KERNEL_BUILD_ARTIFACTS="$(realpath "$2")"; shift 2 ;;
        --input) INPUT_DIR_PATH="$(realpath "$2")"; shift 2 ;;
        --images) IMAGES_OUTPUT="$(realpath "$2")"; shift 2 ;;
        --) shift; break ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Set paths for ITS and DTS files
if [[ -n "$INPUT_DIR_PATH" ]]; then
    FIT_IMAGE_ITS_PATH="$INPUT_DIR_PATH/qcom-fitimage.its"
    METADATA_DTS_PATH="$INPUT_DIR_PATH/qcom-metadata.dts"
else
    echo "Cloning qcom-dtb-metadata repository..."
    git clone https://github.com/qualcomm-linux/qcom-dtb-metadata.git
    FIT_IMAGE_ITS_PATH="qcom-dtb-metadata/qcom-fitimage.its"
    METADATA_DTS_PATH="qcom-dtb-metadata/qcom-metadata.dts"
fi

# Validate required input files
if [[ ! -f "$FIT_IMAGE_ITS_PATH" || ! -f "$METADATA_DTS_PATH" ]]; then
    echo "Error: Required input files not found!"
    exit 1
fi

# Function to create FIT image
function create_fit_image() {
    # Cleaning previous FIT image artifacts
    rm -f "${IMAGES_OUTPUT}/fit_dtb.bin"
    rm -rf "${IMAGES_OUTPUT}/fit_dir"
    rm -f "${KERNEL_BUILD_ARTIFACTS}/qcom-fitimage.its"
    rm -f "${KERNEL_BUILD_ARTIFACTS}/qcom-metadata.dtb"

    # Creating output directory
    mkdir -p "$IMAGES_OUTPUT"/fit_dir

    # Copying ITS file to kernel build artifacts path
    cp "$FIT_IMAGE_ITS_PATH" "$KERNEL_BUILD_ARTIFACTS/qcom-fitimage.its"

    #Compiling metadata DTS to DTB
    dtc -I dts -O dtb -o "${KERNEL_BUILD_ARTIFACTS}/qcom-metadata.dtb" "${METADATA_DTS_PATH}"

    echo "Generating FIT image..."
    mkimage -f "${KERNEL_BUILD_ARTIFACTS}/qcom-fitimage.its" "${IMAGES_OUTPUT}/fit_dir/qcom_fit.img" -E -B 8

    echo "Packing final image into fit_dtb.bin..."
    generate_boot_bins.sh bin --input "${IMAGES_OUTPUT}/fit_dir" --output "${IMAGES_OUTPUT}/fit_dtb.bin"
}

echo "Starting FIT image creation..."
create_fit_image
echo "FIT image created at ${IMAGES_OUTPUT}/fit_dtb.bin"
