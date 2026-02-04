#!/bin/bash
set -e

echo "[1] Updating package lists..."
sudo apt-get update

echo "[2] Installing Azure Kernel and Extra Modules..."
# "linux-azure" is a meta-package that points to the latest kernel
# "linux-modules-extra-azure" contains the drivers we need (hyperv-drm, dxgkrnl, etc.)
sudo apt-get install -y linux-image-azure linux-modules-extra-azure

echo "[3] Verifying installation..."
dpkg -l | grep linux-image-azure
dpkg -l | grep linux-modules-extra

echo "Success! Rebooting to load the new kernel..."
sudo reboot
