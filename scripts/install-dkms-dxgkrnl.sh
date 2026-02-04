#!/bin/bash
set -e

echo "[1] Installing dependencies..."
sudo apt-get update
sudo apt-get install -y dkms git linux-headers-$(uname -r)

echo "[2] Cloning DKMS repository..."
cd ~
rm -rf dxgkrnl-dkms # Clean up previous runs
git clone https://github.com/staralt/dxgkrnl-dkms.git
cd dxgkrnl-dkms

echo "[3] Building and Installing module..."
# The makefile in this repo handles the dkms install
sudo make install

echo "[4] Loading module..."
# The module name is typically 'dxgkrnl'
sudo modprobe dxgkrnl

echo "[5] Verifying..."
ls -l /dev/dxg
dmesg | grep -i dxg
