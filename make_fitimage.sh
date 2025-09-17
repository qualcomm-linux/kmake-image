#!/bin/bash

# Usage:
# make_fitimage.sh --out kernel_artifacts_dir --its its_file_path --metadata metadata_dts_path [--images output_dir]

set -e

# Default output directory
IMAGES_OUTPUT="$(realpath ../images)"

# Parse long options
eval set -- "$(getopt -n "$0" -o "" \
    --long out:,its:,metadata:,images: -- "$@")"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) KERNEL_ARTIFACTS_DIR="$(realpath "$2")"; shift 2 ;;
        --its) FIT_IMAGE_ITS_PATH="$(realpath "$2")"; shift 2 ;;
        --metadata) METADATA_DTS_PATH="$(realpath "$2")"; shift 2 ;;
        --images) IMAGES_OUTPUT="$(realpath "$2")"; shift 2 ;;
        --) shift; break ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate required inputs
if [ -n "$KERNEL_ARTIFACTS_DIR" ] && [ -z "$FIT_IMAGE_ITS_PATH" ] && [ -z "$METADATA_DTS_PATH" ]; then
    echo "Error: Provide required input parameters!!"
    exit 1
fi

# Function to create FIT image
function create_fit_image() {
    rm -f "${IMAGES_OUTPUT}/fit_dtb.bin"
    rm -rf "$IMAGES_OUTPUT"/fit_dir
    rm -rf "$IMAGE_OUTPUT_DIR/fit_dtb.bin"
    rm -f "$KERNEL_ARTIFACTS_DIR/fitimage.its"
    rm -f "${KERNEL_ARTIFACTS_DIR}/qcom-metadata.dtb"

    mkdir -p "$IMAGES_OUTPUT"/fit_dir

    cp "$FIT_IMAGE_ITS_PATH" "$KERNEL_ARTIFACTS_DIR/fitimage.its"

    #Compiling metadata DTS to DTB
    dtc -I dts -O dtb -o "${KERNEL_ARTIFACTS_DIR}/qcom-metadata.dtb" "${METADATA_DTS_PATH}"

    #Generating FIT image
    mkimage -f "${KERNEL_ARTIFACTS_DIR}/fitimage.its" "${IMAGES_OUTPUT}/fit_dir/qclinux_fit.img" -E -B 8

    #Packing final image into fit_dtb.bin
    generate_boot_bins.sh bin --input "${IMAGES_OUTPUT}/fit_dir" --output "${IMAGES_OUTPUT}/fit_dtb.bin"
}

echo "Starting FIT image creation..."
create_fit_image
echo "FIT image created at ${IMAGES_OUTPUT}/fit_dtb.bin"
