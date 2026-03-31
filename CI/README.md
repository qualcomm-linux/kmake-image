# kmake-image-packager

Minimal Docker image for packaging bootable kernel artifacts

**Outputs:** `efi.bin`, `dtb.img`, `boot.img`  

This project focuses on generating bootable images from prebuilt kernel artifacts; if you already have a compiled kernel, a DTB, and an optional ramdisk, this container helps you quickly generate them.
