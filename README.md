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

# TL;DR (Quick Start)

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

Note:
   - The --dtb argument is mandatory. It specifies the Device Tree Blob to be
     packed into the kernel image.
   - Initialize CMDLINE to set your kernel cmdline parameter else a default
     generic is used

### Example
```
kmake-image-run build.sh --dtb qcs6490-rb3gen2.dtb \
        --out kobj \
        --systemd artifacts/systemd/usr/lib/systemd/boot/efi \
        --ramdisk artifacts/ramdisk.gz \
        --images images \
        --cmdline "${CMDLINE}"
```

# TL;DR (Step-by-Step)

The following example captures how to fetch and build efi and dtb bins of the
Qualcomm Linux Kernel for QCS6490 Rb3Gen2.

### 1. Clone kmake-image
```
git clone git@github.com:qualcomm-linux/kmake-image.git
cd kmake-image
```
Build docker
```
docker build -t kmake-image .
```
or
```
docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) --build-arg USER_NAME=$(whoami) -t kmake-image .
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
wget -O artifacts/ramdisk.gz http://storage.kernelci.org/images/rootfs/buildroot/buildroot-baseline/20230703.0/arm64/rootfs.cpio.gz
```

#### Fetch systemd boot binaries
```
wget -O artifacts/systemd-boot-efi.deb http://ports.ubuntu.com/pool/universe/s/systemd/systemd-boot-efi_255.4-1ubuntu8_arm64.deb
dpkg-deb -xv artifacts/systemd-boot-efi.deb artifacts/systemd
```

#### Fetch qcom-dtb-metadata
```
git clone https://github.com/qualcomm-linux/qcom-dtb-metadata.git artifacts/qcom-dtb-metadata
```

### 4. Build Kernel
```
cd kernel
mkdir -p ../kobj
env -u KCONFIG_CONFIG ./scripts/kconfig/merge_config.sh -m -O ../kobj arch/arm64/configs/defconfig arch/arm64/configs/prune.config arch/arm64/configs/qcom.config kernel/configs/debug.config
kmake O=../kobj olddefconfig
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

### 7. Generate dtb.bin for targets supporting device tree partition
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

### 9. Or Generate efi_with_dtb.bin for targets without separate dtb partition
For targets that do not support separate dtb partition, docker can be used to
create efi_with_dtb.bin
The following example demonstrates how to build a boot image of the upstream
Linux kernel for the SM8750 MTP platform.
```
cd ..
kmake-image-run generate_boot_bins.sh efi --ramdisk artifacts/ramdisk.gz \
		--systemd-boot artifacts/systemd/usr/lib/systemd/boot/efi/systemd-bootaa64.efi \
		--stub artifacts/systemd/usr/lib/systemd/boot/efi/linuxaa64.efi.stub \
		--linux kobj/arch/arm64/boot/Image \
		--devicetree kobj/arch/arm64/boot/dts/qcom/sm8750-mtp.dtb \
		--cmdline "${CMDLINE}" \
		--output images
```

The resulting **efi_with_dtb.bin** is ready to be booted on a SM8750 MTP.
```
fastboot flash efi images/efi_with_dtb.bin
fastboot reboot
```

### 10. Or Generate boot.img for targets supporting Android boot partition

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

### 11. Generate FIT image
```
cd ..
kmake-image-run make_fitimage.sh \
        --metadata artifacts/qcom-dtb-metadata/qcom-metadata.dtb \
		--its artifacts/qcom-dtb-metadata/qcom-fitimage.its \
        --kobj kobj \
        --output images
```

### 12. Or Build Ubuntu Kernel deb packages
```
  kmake O=../debian mrproper
  kmake O=../debian defconfig
  kmake O=../debian -j$(nproc) bindeb-pkg
```

### 13. Kernel Configuration Management
Qualcomm's kernel setup builds on top of the standard ***arch/arm64/configs/defconfig*** by introducing three additional configuration fragments:

- **arch/arm64/configs/prune.config** : Disables support for non-Qualcomm architectures to streamline the kernel for Qualcomm platforms

- **arch/arm64/configs/qcom.config** : Enables Qualcomm-specific kernel configurations that are not acceptable within the community's common defconfig

- **kernel/configs/debug.config** : Enables Qualcomm Debug Configs

To modify kernel configuration using menuconfig, follow these steps:
```
kmake O=../kobj menuconfig
kmake O=../kobj savedefconfig
```
This will generate a new defconfig file at ../kobj/defconfig.

#### Applying Changes

- Compare the newly generated **defconfig** with the base **arch/arm64/configs/defconfig**
- Note: The community's common defconfig is not sorted, so you may see many differences
- Identify only the relevant changes you intend to introduce
- Apply those changes to the appropriate fragment:
  - Use prune.config for architecture exclusions
  - Use qcom.config for Qualcomm-specific features
  - Use debug.config for debugging options


## Finer Details

### kmake-image-run

```
alias kmake-image-run='docker run -it --rm --user $(id -u):$(id -g) --workdir="$PWD" -v "$(dirname $PWD)":"$(dirname $PWD)" kmake-image'
```

The **kmake-image-run** alias allow you to run commands within the Docker image
generated above, passing any arguments along. The current directory is mirrored
into the Docker environment, so any paths under the current directory remains
valid in both environments.

### kmake

```
alias kmake='kmake-image-run make'
```

The **kmake** alias runs *make* within the Docker image generated above,
passing any arguments along. This can be used as a drop-in replacement for
**make** in the kernel.

Note that the image defines **CROSS_COMPILE=aarch64-linux-gnu-** and **ARCH=arm64**,
under the assumption that you're cross compiling the Linux kernel for Arm64, using GCC.

#### Examples

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

### ukify

[*ukify*](https://www.man7.org/linux/man-pages//man1/ukify.1.html) is conveniently included in the Docker image. Note that only the
current directory is mirrored into the Docker environment, so relative paths
outside the current one are not accessible.

Run the generate_boot_bins.sh script to create efi.bin and dtb.bin using the ukify tool.

#### Examples
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

### mkbootimg

*mkbootimg* is conveniently included in the Docker image. Note that only the
current directory is mirrored into the Docker environment, so relative paths
outside the current one are not accessible.

#### Examples

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

### mkimage
*mkimage* (part of U-Boot) is used to convert an ITS file into a FIT image.
*Flattened Image Tree (FIT)* image can be used to bundle multiple device tree
blobs (DTBs) into a single image.

Run make_fitimage.sh script to create fit_dtb.bin by utilizing ITS (Image Tree Source)
file and metadata DTS.

#### Examples

The following generates a *fit_dtb.bin* by utilizing a Qualcomm-specific ITS
file and metadata DTS from [qcom-dtb-metadata](https://github.com/qualcomm-linux/qcom-dtb-metadata.git):
```
kmake-image-run make_fitimage.sh \
        --out kobj \
        --images images
```
Or
Generate a *fit_dtb.bin* by utilizing custom ITS file and metadata DTS directory path:
```
kmake-image-run make-fitimage.sh \
        --out kobj \
        --input custom-its-metadata-dir \
        --images images
```


### Install kernel deb packages on Ubuntu
For installing kernel deb packages on Ubuntu, refer [README_ubuntu](./README_ubuntu.md)

### How to update kernel on Yocto
For updating kernel on Yocto, refer [README_yocto](./README_yocto.md)

## License
kmake-image is licensed under the [*BSD-3-clause-clear License*](https://spdx.org/licenses/BSD-3-Clause-Clear.html). See [*LICENSE*](https://github.com/qualcomm-linux/kmake-image/blob/main/LICENSE) for the full license text.
