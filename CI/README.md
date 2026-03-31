# CI Docker Image

This directory contains a Dockerfile used to build a reproducible CI image for generating ARM64 boot images.

## Base Image
- Ubuntu 24.04

## Features
- ARM64 cross-compilation support
- Systemd ukify tooling
- mkbootimg utility
- FAT filesystem utilities
- Required scripts pre-installed:
  - generate_boot_bins.sh
  - build.sh
  - make_fitimage.sh

## Build the Docker Image

```bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  --build-arg USER_NAME=$(whoami) \
  -t make-image-ci \
  .
