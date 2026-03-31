FROM ubuntu:24.04

ARG USER_ID
ARG GROUP_ID
ARG USER_NAME

RUN if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ] && [ -n "$USER_NAME" ]; then \
        groupadd -g "$GROUP_ID" "$USER_NAME" && \
        useradd -m -u "$USER_ID" -g "$GROUP_ID" -d / "$USER_NAME" ; \
    fi

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

COPY generate_boot_bins.sh /usr/bin/
COPY build.sh /usr/bin/
COPY make_fitimage.sh /usr/bin/

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        binutils \
        python3 \
        locales \
        kmod \
        rsync \
        systemd-ukify \
        dosfstools \
        mtools \
        cpio \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8; \
    \
    curl "https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/android12-release/mkbootimg.py?format=TEXT" \
      | base64 --decode > /usr/bin/mkbootimg; \
    chmod +x /usr/bin/mkbootimg; \
    chmod 755 /usr/bin/generate_boot_bins.sh /usr/bin/build.sh /usr/bin/make_fitimage.sh; \
    \
    command -v ukify; \
    command -v mkfs.vfat; \
    command -v mcopy; \
    command -v rsync

# Fetch & unpack systemd-boot .deb
ARG SYSTEMD_BOOT_DEB_URL="http://ports.ubuntu.com/pool/universe/s/systemd/systemd-boot-efi_255.4-1ubuntu8_arm64.deb"
RUN set -eux; \
    mkdir -p /artifacts/systemd; \
    echo "Downloading systemd-boot from: ${SYSTEMD_BOOT_DEB_URL}"; \
    curl -fsSL "${SYSTEMD_BOOT_DEB_URL}" -o /artifacts/systemd-boot-efi.deb; \
    dpkg-deb -xv /artifacts/systemd-boot-efi.deb /artifacts/systemd; \
    test -d /artifacts/systemd/usr/lib/systemd/boot/efi

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
