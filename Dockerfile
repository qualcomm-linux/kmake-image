FROM ubuntu:24.04

ARG USER_ID
ARG GROUP_ID
ARG USER_NAME

RUN if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ] && [ -n "$USER_NAME" ]; then \
        groupadd -g $GROUP_ID $USER_NAME && \
        useradd -m -u $USER_ID -g $GROUP_ID -d / $USER_NAME ; \
    fi

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

COPY generate_boot_bins.sh /usr/bin
COPY build.sh /usr/bin
COPY make_fitimage.sh /usr/bin

RUN printf "Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/\nSuites: noble noble-updates noble-security\nComponents: main restricted universe multiverse\nArchitectures: amd64\n\n" > /etc/apt/sources.list.d/base-amd64.sources && \
    printf "Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports/\nSuites: noble noble-updates noble-security\nComponents: main restricted universe multiverse\nArchitectures: arm64\n\n" > /etc/apt/sources.list.d/ports-arm64.sources && \
    apt-get update && \
    apt-get install -y build-essential git clang-15 lld-15 flex bison bc libssl-dev curl kmod systemd-ukify && \
    apt-get install -y debhelper-compat libdw-dev:amd64 libelf-dev:amd64 && \
    apt-get install -y rsync mtools dosfstools lavacli u-boot-tools cpio && \
    apt-get install -y gcc-aarch64-linux-gnu && \
    apt-get install -y python3-pip swig yamllint && \
    apt install -y python3-setuptools python3-wheel && \
    python3 -m pip install --break-system-packages dtschema==2025.08 jinja2 ply GitPython kas && \
    python3 -m pip install --break-system-packages b4==0.14.3 && \
    apt-get install -y yq && \
    apt-get install -y abigail-tools sparse && \
    apt-get install -y cmake libyaml-dev && \
    curl "https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/android12-release/mkbootimg.py?format=TEXT" | base64 --decode > /usr/bin/mkbootimg && \
    chmod +x /usr/bin/mkbootimg && \
    chmod 755 /usr/bin/generate_boot_bins.sh && \
    chmod 755 /usr/bin/build.sh && \
    chmod 755 /usr/bin/make_fitimage.sh && \
    dpkg --add-architecture arm64 && \
    apt-get install -y libssl-dev:arm64 && \
    rm -rf /var/lib/apt/lists/*
