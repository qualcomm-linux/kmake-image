# kmake-image
Docker image for building the Linux kernel

With engineers using a variety of different versions of Ubuntu, python etc,
issues are often reported related to tasks such as performing DeviceTree
validation with the upstream Linux kernel.

This project contains the recipe for a Docker image containing necessary tools
for building the kernel, packaging boot.img (which contains kernel image along
with dtb packed using mkbootimg tool) or efi.bin (which contains kernel image
packed using ukify tool) and dtb.bin (which contains DeviceTree Blob), checking
DeviceTree bindings and validating DeviceTree source, as well as a few handy
shell aliases for invoking operations within the Docker environment.

## Installing docker

If Docker isn't installed on your system yet, you can follow the instructions
provided at Docker's official documentation.

https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

### Add user to the docker group
```
sudo usermod -aG docker $USER
newgrp docker
```

Restart your terminal, or log out and log in again, to ensure your user is
added to the **docker** group (the output of `id` should contain *docker*).

## Generating kmake Docker image

With docker installed, you can generate the docker image that will be used to
operate on the kernel tree. Do this by running *docker build* in the directory
where you cloned this project:

```
docker build -t kmake-image .
```

## kmake-image-run

```
alias kmake-image-run='docker run -it --rm --user $(id -u):$(id -g) --workdir="$PWD" -v "$(dirname $PWD)":"$(dirname $PWD)" kmake-image'
```

The **kmake-image-run** alias allow you to run commands within the Docker image
generated above, passing any arguments along. The current directory is mirrored
into the Docker environment, so any paths under the current directory remains
valid in both environments.

## kmake

```
alias kmake='kmake-image-run make'
```

The **kmake** alias runs *make* within the Docker image generated above,
passing any arguments along. This can be used as a drop-in replacement for
**make** in the kernel.

Note that the image defines **CROSS_COMPILE=aarch64-linux-gnu-** and **ARCH=arm64**,
under the assumption that you're cross compiling the Linux kernel for Arm64, using GCC.

### Examples

The following examples can be run in the root of a checked out Linux kernel
workspace, where you typically would run *make*. The expected operations will
be performed, using the tools in the Docker environment.

Select arm64 defconfig and build the kernel:
```
kmake defconfig
kmake -j$(nproc)
```

Perform check of all DeviceTree bindings:
```
kmake DT_CHECKER_FLAGS=-m dt_binding_check
```

Perform DeviceTree binding check, of a specific binding:
```
kmake DT_CHECKER_FLAGS=-m DT_SCHEMA_FILES=soc/qcom/qcom,smem.yaml dt_binding_check
```

Build *qcom/qcs6490-rb3gen2.dtb* and validate it against DeviceTree bindings:
```
kmake defconfig
kmake qcom/qcs6490-rb3gen2.dtb CHECK_DTBS=1
```

## ukify

[*ukify*](https://www.man7.org/linux/man-pages//man1/ukify.1.html) is conveniently included in the Docker image. Note that only the
current directory is mirrored into the Docker environment, so relative paths
outside the current one are not accessible.

Run the generate_boot_bins.sh script to create efi.bin and dtb.bin using the ukify tool.

### Examples
The following example generates efi.bin and dtb.bin using ukify for QCS6490 RB3Gen2, as found
in the upstream Linux Kernel:

```
# Generate efi.bin
kmake-image-run generate_boot_bins.sh efi --ramdisk artifacts/ramdisk.gz \
		--systemd-boot artifacts/systemd/usr/lib/systemd/boot/efi/systemd-bootaa64.efi \
		--stub artifacts/systemd/usr/lib/systemd/boot/efi/linuxaa64.efi.stub \
		--linux arch/arm64/boot/Image \
		--cmdline "${CMDLINE}" \
		--output images

# Generate dtb.bin for targets that support device tree
kmake-image-run generate_boot_bins.sh dtb --input kobj/arch/arm64/boot/dts/qcom/qcs6490-rb3gen2.dtb \
		--output images
```
This will generate required binaries in images directory.

## mkbootimg

*mkbootimg* is conveniently included in the Docker image. Note that only the
current directory is mirrored into the Docker environment, so relative paths
outside the current one are not accessible.

### Examples

The following example generates a *boot.img* for the SM8550 MTP using its
device tree, as available in the upstream Linux kernel:
```
kmake-image-run mkbootimg \
        --header_version 2 \
        --kernel kobj/arch/arm64/boot/Image.gz \
        --dtb kobj/arch/arm64/boot/dts/qcom/sm8550-mtp.dtb \
        --cmdline "${CMDLINE}"
        --ramdisk artifacts/ramdisk.gz \
        --base 0x80000000 \
        --pagesize 2048 \
        --output boot.img
```

# TL;DR

The following example captures how to fetch and build efi and dtb bins of the
Qualcomm Linux Kernel for QCS6490 Rb3Gen2.

### 1. Clone kmake-image
```
git clone git@github.com:qualcomm-linux/kmake-image.git
cd kmake-image
docker build -t kmake-image .
```

### 2. Setup the aliases in your .bashrc
```
alias kmake-image-run='docker run -it --rm --user $(id -u):$(id -g) --workdir="$PWD" -v "$(dirname $PWD)":"$(dirname $PWD)" kmake-image'
alias kmake='kmake-image-run make'
```

### 3. Clone Qualcomm Linux Kernel Tree and other dependencies
```
cd ..
git clone git@github.com:qualcomm-linux/kernel.git
```

#### Fetch Ramdisk (For arm64)
```
mkdir artifacts
wget -O artifacts/ramdisk.gz https://snapshots.linaro.org/member-builds/qcomlt/testimages/arm64/1379/initramfs-test-image-qemuarm64-20230321073831-1379.rootfs.cpio.gz
```

#### Fetch systemd boot binaries
```
wget -O artifacts/systemd-boot-efi.deb http://ports.ubuntu.com/pool/universe/s/systemd/systemd-boot-efi_255.4-1ubuntu8_arm64.deb
dpkg-deb -xv artifacts/systemd-boot-efi.deb artifacts/systemd
```

### 4. Build Kernel
```
cd kernel
kmake O=../kobj defconfig prune.config qcom.config debug.config
kmake O=../kobj -j$(nproc)
kmake O=../kobj -j$(nproc) dir-pkg INSTALL_MOD_STRIP=1
```

### 5. Package DLKMs into ramdisk
```
(cd ../kobj/tar-install ; find lib/modules | cpio -o -H newc -R +0:+0 | gzip -9 >> ../../artifacts/ramdisk.gz)
```

### 6. Generate efi.bin
```
cd ..
kmake-image-run generate_boot_bins.sh efi --ramdisk artifacts/ramdisk.gz \
		--systemd-boot artifacts/systemd/usr/lib/systemd/boot/efi/systemd-bootaa64.efi \
		--stub artifacts/systemd/usr/lib/systemd/boot/efi/linuxaa64.efi.stub \
		--linux kobj/arch/arm64/boot/Image \
		--cmdline "${CMDLINE}" \
		--output images
```

### 7. Generate dtb.bin for targets supporting device tree
```
kmake-image-run generate_boot_bins.sh dtb --input kobj/arch/arm64/boot/dts/qcom/qcs6490-rb3gen2.dtb \
		--output images
```

The resulting **efi.bin** and **dtb.bin** are gathered in images directory and is ready to be
booted on a QCS6490 RB3Gen2.

### 8. Flash the binaries
```
fastboot flash efi images/efi.bin
fastboot flash dtb_a images/dtb.bin
fastboot reboot
```

## Generate Boot.img
For targets that support android boot image format, docker can be used to
create a boot image.
The following example demonstrates how to build a boot image of the upstream
Linux kernel for the SM8550 MTP platform.

```
cd ..
kmake-image-run mkbootimg \
        --header_version 2 \
        --kernel kobj/arch/arm64/boot/Image.gz \
        --dtb kobj/arch/arm64/boot/dts/qcom/sm8550-mtp.dtb \
        --cmdline "${CMDLINE}" \
        --ramdisk artifacts/ramdisk.gz \
        --base 0x80000000 \
        --pagesize 2048 \
        --output images/boot.img
```

The resulting **boot.img** is ready to be booted on a SM8550 MTP. But as the
overlay stored on the device is incompatible with the upstream DeviceTree
source, this has to be disabled first.

```
fastboot erase dtbo
fastboot reboot bootloader
fastboot boot images/boot.img
```

## Workspace Setup Script
*setup.sh* script simplify the initial setup for kernel developers:
- Builds the Docker image and fetches Qualcomm Kernel source tree and required
artifacts (ramdisk, systemd-boot).
- Export necessary environment variables for kernel development.
```
./setup.sh
```

## Kernel Image Generation Script
Run *build.sh* script to automate building and packaging a bootable kernel
image into efi.bin, dtb.bin, and boot.img

Note: The --dtb argument is mandatory. It specifies the Device Tree Blob to be
packed into the kernel image.

### Example
```
kmake-image-run build.sh --dtb qcs6490-rb3gen2.dtb \
        --out kobj
        --systemd artifacts/systemd/usr/lib/systemd/boot/efi \
        --ramdisk artifacts/ramdisk.gz \
        --images images \
        --cmdline "${CMDLINE}"
```

## License
kmake-image is licensed under the [*BSD-3-clause-clear License*](https://spdx.org/licenses/BSD-3-Clause-Clear.html). See [*LICENSE*](https://github.com/qualcomm-linux/kmake-image/blob/main/LICENSE) for the full license text.
