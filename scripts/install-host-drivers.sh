#!/bin/bash
set -e

# Get real user's home directory even when running with sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SOURCE_DIR="$REAL_HOME/host-drivers"
DEST_DIR="/usr/lib/wsl/drivers"

echo "🔧 Installing Host Drivers..."

# Validate Source
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Error: $SOURCE_DIR not found. Did you run inject-drivers.ps1?"
    exit 1
fi

DRIVER_FOLDER=$(ls -d $SOURCE_DIR/nv_dispi.inf_amd64_*)
DRIVER_NAME=$(basename "$DRIVER_FOLDER")

echo "Found Driver: $DRIVER_NAME"

# Create Destination
echo "📂 Moving files to $DEST_DIR..."
sudo mkdir -p "$DEST_DIR"
sudo cp -r "$DRIVER_FOLDER" "$DEST_DIR/"

# Configure ld.so
echo "🔗 Configuring Library Path..."
echo "$DEST_DIR/$DRIVER_NAME" | sudo tee /etc/ld.so.conf.d/nvidia-wsl.conf

# Fix permissions
sudo chmod 755 -R "$DEST_DIR"

# Refresh Libraries
echo "♻️ Refreshing ldconfig..."
sudo ldconfig

echo "✅ Drivers Installed!"
echo "👉 Please REBOOT using 'sudo reboot' for changes to take effect."
