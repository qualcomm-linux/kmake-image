#!/bin/bash

###############################################################################
# setup.sh - Environment setup script for Qualcomm Linux kernel development
#
# Usage:
#   ./setup.sh [--kernel <kernel_repo_url>] [--branch <branch_name>] [--ramdisk]
#
# Options:
#   --kernel   URL of the kernel repository to clone (default: https://github.com/qualcomm-linux/kernel.git)
#   --branch   Branch name to checkout from the kernel repository (default: qcom-next)
#   --ramdisk  If specified, downloads a default ramdisk image
#
# Description:
#   This script sets up a development environment for building the Qualcomm
#   Linux kernel using Docker. It installs Docker if not present, builds a
#   Docker image, sets up useful aliases for kernel compilation, clones the
#   kernel repository, and downloads systemd boot binaries and optionally a
#   ramdisk image.
#
# Notes:
#   - Run this script from your workspace directory.
#   - After running, restart your terminal or run `source ~/.bashrc` to activate aliases.
###############################################################################

set -e

# Default values
KERNEL_REPO=https://github.com/qualcomm-linux/kernel.git
KERNEL_BRANCH=qcom-next
KERNEL_PATH="../kernel"
RAMDISK_PATH="http://storage.kernelci.org/images/rootfs/buildroot/buildroot-baseline/20230703.0/arm64/rootfs.cpio.gz"

# Parse long options
eval set -- "$(getopt -n "$0" -o "" \
    --long kernel:,branch:,artifacts: -- "$@")"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel) KERNEL_REPO="$2"; shift 2 ;;
        --branch) KERNEL_BRANCH="$2"; shift 2 ;;
        --ramdisk) RAMDISK_PATH="$2"; shift 2 ;;
        --) shift; break ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -n "$KERNEL_REPO" ] && [ -z "$KERNEL_BRANCH" ]; then
    echo "Error: Provide branch name"
    exit 1
fi

echo "Installing Docker (if not already installed)..."
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y docker.io
fi

echo "Adding current user to docker group..."
sudo groupadd docker || true
sudo usermod -aG docker $USER

echo "Building Docker image..."
docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) --build-arg USER_NAME=$(whoami) -t kmake-image .

echo "Setting up Docker aliases..."
{
    echo ""
    echo "# kmake-image Docker aliases"
    echo "alias kmake-image-run='docker run -it --rm --user \$(id -u):\$(id -g) --workdir=\"\$PWD\" -v \"\$(dirname \$PWD)\":\"\$(dirname \$PWD)\" kmake-image'"
    echo "alias kmake='kmake-image-run make'"
} >> ~/.bashrc

export PATH=$PWD:$PATH


if [ -d "$KERNEL_PATH" ]; then
    if [ "$(ls -A "$KERNEL_PATH")" ]; then
        echo "Directory '$DIR' exists but is not-empty. Skip cloning kernel."
	skip_kernel=true
    fi
fi

if [[ $skip_kernel != true ]]; then
    echo "Cloning Qualcomm Linux kernel tree..."
    git clone --branch "$KERNEL_BRANCH" "$KERNEL_REPO" ../kernel
fi

echo "Downloading systemd boot binaries..."
mkdir -p ../artifacts
cd ../artifacts
wget -O ../artifacts/systemd-boot-efi.deb http://ports.ubuntu.com/pool/universe/s/systemd/systemd-boot-efi_255.4-1ubuntu8_arm64.deb
dpkg-deb -xv ../artifacts/systemd-boot-efi.deb ../artifacts/systemd

if [ -n "$RAMDISK_PATH" ]; then
    echo "Downloading ramdisk..."
    wget -O ../artifacts/ramdisk.gz "$RAMDISK_PATH"
fi

echo "Environment setup complete. Please restart your terminal or run 'source ~/.bashrc' to activate aliases."
