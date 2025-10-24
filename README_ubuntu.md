# How to install kernel deb packages on Ubuntu

For building kernel deb packages, refer to [Build Kernel deb packages](./README.md#10-or-build-ubuntu-kernel-deb-packages)

The **linux-image-<kernel_ver>_arm64.deb** contains kernel image and modules.
Copy the deb package to the device and install the deb package on device
using "dpkg -i" and reboot the device.

Example:
```
dpkg -i /linux-image-6.17.0-rc7-dbg_6.17.0~rc7-7_arm64.deb
reboot
```
After reboot, your kernel will be booted on device.

## License
kmake-image is licensed under the [*BSD-3-clause-clear License*](https://spdx.org/licenses/BSD-3-Clause-Clear.html). See [*LICENSE*](https://github.com/qualcomm-linux/kmake-image/blob/main/LICENSE) for the full license text.
