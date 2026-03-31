# kmake-image-packager

Docker image for packaging bootable Linux kernel artifacts.

This project focuse on generating bootable images (`efi.bin`, `dtb.bin`) from prebuilt kernel artifacts (kernel image and DTB).


# TL;DR (Step-by-Step)


### 1. Clone kmake-image

```bash
git clone git@github.com:qualcomm-linux/kmake-image.git
cd kmake-image
```

### 2. Build the Docker Image

You can build the Docker image in one of the following ways.

#### Option A: Simple build

```bash
docker build -f CI/Dockerfile.ci -t kmake-image-ci .
```

#### Option B: Build with user mapping (recommended)

This avoids file permission issues on generated artifacts.

```bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  --build-arg USER_NAME=$(whoami) \
  -f CI/Dockerfile.ci \
  -t kmake-image-ci .
```

### 3. Set up the alias in your `.bashrc`

Add the following alias:

```bash
alias kmake-image-ci='docker run -it --rm \
  --user $(id -u):$(id -g) \
  --workdir="$PWD" \
  -v "$(dirname "$PWD")":"$(dirname "$PWD")" \
  kmake-image-ci'
```

Apply the change:

```bash
source ~/.bashrc
```

### Prerequisites (Required Artifacts)

Before generating `efi.bin`, ensure the following artifacts are available locally:

- **Kernel Image**: `Image` (uncompressed)
- **Ramdisk**: `initrd.cpio.gz`
- **Target DTB**: example `qcs6490-rb3gen2.dtb`

### 4. Generate `efi.bin`

Run the EFI image generation command:

```bash
kmake-image-ci generate_boot_bins.sh efi \
  --ramdisk artifacts/initrd.cpio.gz \
  --systemd-boot /artifacts/systemd/usr/lib/systemd/boot/efi/systemd-bootaa64.efi \
  --stub /artifacts/systemd/usr/lib/systemd/boot/efi/linuxaa64.efi.stub \
  --linux artifacts/Image \
  --cmdline "console=ttyMSM0,115200n8 copy-modules rootdelay=10 root=PARTLABEL=rootfs rw rootwait qcom_geni_serial.con_enabled=1" \
  --output images
```

### 5. Generate `dtb.bin`
*(For targets supporting a DTB partition)*

```bash
kmake-image-ci generate_boot_bins.sh dtb \
  --input artifacts/qcs6490-rb3gen2.dtb \
  --output images
```

### 6. Output

The generated files:

- `efi.bin`
- `dtb.bin`

are available in the `images/` directory and are ready to be booted on
**QCS6490 RB3Gen2**.

