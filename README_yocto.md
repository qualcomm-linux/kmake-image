# How to update kernel on Yocto

This workflow provides a guide for Yocto developers who
already have a working build and need to update to a newer kernel
version. It outlines the steps to rebuild the kernel and modules,
and deploy them to the target device for validation.

## Prerequisites
 1. [Make sure your Docker environment is setup](./README.md)
 2. For getting qcom-next kernel, refer to [Clone Qualcomm Linux Kernel Tree](./README.md#3-clone-qualcomm-linux-kernel-tree-and-other-dependencies)


## Download the ramdisk (debian)

```
wget -O ./artifacts/ramdisk_deb.cpio.gz https://storage.kernelci.org/images/rootfs/debian/bookworm-kselftest/20250724.0/arm64/initrd.cpio.gz
```

## Build the kernel to generate efi and dtb
Build the kernel with additional command line parameters
- "copy-modules root=PARTLABEL=rootfs rw rootwait" and pack the
ramdisk downloaded above. The kmake build.sh script can be used for
same as show in example. This will generate efi.bin and dtb.bin that
can be flashed on the device.

Example: Build command with sa8775p-ride.dtb
```
# run from kernel dir

kmake-image-run build.sh --dtb sa8775p-ride.dtb \
        --out kobj \
        --systemd ../artifacts/systemd/usr/lib/systemd/boot/efi \
        --ramdisk ../artifacts/ramdisk_deb.cpio.gz \
        --images images \
        --cmdline "copy-modules root=PARTLABEL=rootfs rw rootwait qcom_geni_serial.con_enabled=1 earlycon"
```

## Flash efi and dtb
```
 fastboot flash efi efi.bin
 fastboot flash dtb_a dtb.bin
 fastboot reboot
```
