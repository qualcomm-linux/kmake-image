#!/bin/bash

# Default values
BOOTIMG_VOLUME_ID="BOOT"
BOOTIMG_EXTRA_SPACE="512"
MKFSVFAT_EXTRAOPTS="-S 512"

show_help() {
    echo "Usage: generate_boot_bins.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  efi       Generate EFI image"
    echo "  dtb       Generate DTB image"
    echo "  bin       Generate bin"
    echo "  help      Show this help message"
    echo ""
    echo "efi command options:"
    echo "  --ramdisk PATH         Path to the ramdisk file"
    echo "  --systemd-boot PATH    Path to the systemd boot"
	echo "  --stub                 Path to efi stub"
    echo "  --linux PATH           Path to the Linux Image"
    echo "  --cmdline CMDLINE      Optional Kernel command line parameters"
    echo "  --output DIR           Optional Output directory"
    echo ""
    echo "dtb command options:"
    echo "  --input PATH           Path to the DTB file"
    echo "  --output DIR           Optional Output directory"
    echo "bin command options:"
    echo "  --input DIR            Path to the input directory"
    echo "  --output PATH          Output file path"
}

generate_bin() {
    local FATSOURCEDIR=$1
    local OUT_IMAGE=$2

    # Determine the sector count just for the data
    SECTORS=$(( $(du --apparent-size -ks "${FATSOURCEDIR}" | cut -f 1) * 2 ))

    # 32 bytes per dir entry
    DIR_BYTES=$(( $(find "${FATSOURCEDIR}" | tail -n +2 | wc -l) * 32 ))

    # 32 bytes for every end-of-directory dir entry
    DIR_BYTES=$(( DIR_BYTES + $(( $(find "${FATSOURCEDIR}" -type d | tail -n +2 | wc -l) * 32 )) ))

    # 4 bytes per FAT entry per sector of data
    FAT_BYTES=$(( SECTORS * 4 ))

    # 4 bytes per FAT entry per end-of-cluster list
    FAT_BYTES=$(( FAT_BYTES + $(( $(find "${FATSOURCEDIR}" -type d | tail -n +2 | wc -l) * 4 )) ))

    # Use a ceiling function to determine FS overhead in sectors
    DIR_SECTORS=$(( $(( DIR_BYTES + 511 )) / 512 ))

    # There are two FATs on the image
    FAT_SECTORS=$(( $(( $(( FAT_BYTES + 511 )) / 512 )) * 2 ))
    SECTORS=$(( SECTORS + $(( DIR_SECTORS + FAT_SECTORS )) ))

    # Determine the final size in blocks accounting for some padding
    BLOCKS=$(( $(( SECTORS / 2 )) + BOOTIMG_EXTRA_SPACE ))

    # mkfs.vfat will sometimes use FAT16 when it is not appropriate,
    # resulting in a boot failure. Use FAT32 for images larger
    # than 512MB, otherwise let mkfs.vfat decide.
    if [ "$(( BLOCKS / 1024 ))" -gt 512 ] ; then
        FATSIZE="-F 32"
        mkfs.vfat "${FATSIZE}" -n "${BOOTIMG_VOLUME_ID}" ${MKFSVFAT_EXTRAOPTS} -C "${OUT_IMAGE}" "${BLOCKS}"
    else
        mkfs.vfat -n "${BOOTIMG_VOLUME_ID}" ${MKFSVFAT_EXTRAOPTS} -C "${OUT_IMAGE}" "${BLOCKS}"
    fi

    MTOOLS_SKIP_CHECK=1 mcopy -i "${OUT_IMAGE}" -s "${FATSOURCEDIR}"/* ::/

    echo "${FATSOURCEDIR}.bin image created at ${OUT_IMAGE}"
}

generate_efi_image() {
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --ramdisk) RAMDISK="$2"; shift ;;
            --systemd-boot) SYSTEMD_BOOT="$2"; shift ;;
			--stub) STUB="$2"; shift ;;
            --linux) LINUX_IMAGE="$2"; shift ;;
            --cmdline) KERNEL_VENDOR_CMDLINE="$2"; shift ;;
            --output) OUTPUT_DIR="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; show_help ; exit 1 ;;
        esac
        shift
    done

    # Check if required parameters are provided
    if [ -z "${RAMDISK}" ] || [ -z "${SYSTEMD_BOOT}" ] || [ -z "${STUB}" ] || [ -z "${LINUX_IMAGE}" ]; then
        echo "efi: Missing required parameter"
        echo "Use --help option for usage information."
        exit 1
    fi

    # Prepare output directories
    OUTPUT_DIR="${OUTPUT_DIR:-.}"
    rm -rf "${OUTPUT_DIR}/efi_dir"
    mkdir -p "${OUTPUT_DIR}"/efi_dir/{dtb,EFI/{BOOT,Linux},loader}

    # Copy systemd image
    rsync "${SYSTEMD_BOOT}" "${OUTPUT_DIR}/efi_dir/EFI/BOOT/bootaa64.efi"

    # Create loader.conf
    touch "${OUTPUT_DIR}/efi_dir/loader/loader.conf"

    # Check if ramdisk and Linux Image exist
    if [ ! -e "${RAMDISK}" ]; then
        echo "No ${RAMDISK} found"
        exit 1
    fi

    if [ ! -e "${LINUX_IMAGE}" ]; then
        echo "No Linux Image ${LINUX_IMAGE} found"
        exit 1
    fi

    rm -rf "${OUTPUT_DIR}/uki.efi" "${OUTPUT_DIR}/efi.bin"

    # Build UKI image
    ukify build --initrd="${RAMDISK}" --linux="${LINUX_IMAGE}" \
        --efi-arch=aa64 --cmdline="${KERNEL_VENDOR_CMDLINE}" --stub="${STUB}" --output="${OUTPUT_DIR}/uki.efi"

    echo "UKI image created at ${OUTPUT_DIR}/uki.efi"
    rsync "${OUTPUT_DIR}/uki.efi" "${OUTPUT_DIR}/efi_dir/EFI/Linux/"

    generate_bin "${OUTPUT_DIR}/efi_dir" "${OUTPUT_DIR}/efi.bin"
}

generate_dtb_image() {
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --input) DTB="$2"; shift ;;
            --output) OUTPUT_DIR="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; show_help ; exit 1 ;;
        esac
        shift
    done

    # Check if required parameters are provided
    if [ -z "${DTB}" ]; then
        echo "dtb: Missing required parameter"
        echo "Use --help option for usage information."
        exit 1
    fi

    if [ ! -e "${DTB}" ]; then
        echo "No ${DTB} found"
        exit 1
    fi

    # Prepare output directories
    OUTPUT_DIR="${OUTPUT_DIR:-.}"
    rm -rf "${OUTPUT_DIR}/dtb_dir"
    mkdir -p "${OUTPUT_DIR}/dtb_dir/dtb"

    # Copy DTB file
    cp "${DTB}" "${OUTPUT_DIR}/dtb_dir/dtb/combined-dtb.dtb"

    rm -rf "${OUTPUT_DIR}/dtb.bin"
    generate_bin "${OUTPUT_DIR}/dtb_dir/dtb" "${OUTPUT_DIR}/dtb.bin"
}

generate_bin_image() {
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --input) INPUT_DIR="$2"; shift ;;
            --output) OUTPUT_PATH="$2"; shift ;;
            *) echo "Unknown parameter passed: $1"; show_help ; exit 1 ;;
        esac
        shift
    done

    # Check if required parameters are provided
    if [ -z "${INPUT_DIR}" ] || [ -z "${OUTPUT_PATH}" ]; then
        echo "bin: Missing required parameter"
        echo "Use --help option for usage information."
        exit 1
    fi

    generate_bin "${INPUT_DIR}" "${OUTPUT_PATH}"
}

# Main script logic
if [[ "$1" == "efi" ]]; then
    shift
    generate_efi_image "$@"
elif [[ "$1" == "dtb" ]]; then
    shift
    generate_dtb_image "$@"
elif [[ "$1" == "bin" ]]; then
    shift
    generate_bin_image "$@"
elif [[ "$1" == "--help" ]]; then
    show_help
else
    echo "Unknown command: $1"
    show_help
    exit 1
fi
