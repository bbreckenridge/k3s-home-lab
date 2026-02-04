#!/bin/bash
set -e
echo "Symlinking NVIDIA libraries to standard paths..."

LIBS_DIR="/usr/lib/wsl/lib"
TARGET_DIR="/usr/lib/x86_64-linux-gnu"

# List of critical libs
LIBS=(
    "libnvidia-ml.so.1"
    "libcuda.so.1"
    "libdxcore.so"
    "libd3d12.so"
)

for lib in "${LIBS[@]}"; do
    if [ -f "$LIBS_DIR/$lib" ]; then
        echo "Linking $lib..."
        ln -sf "$LIBS_DIR/$lib" "$TARGET_DIR/$lib"
    else
        echo "Warning: $lib not found in $LIBS_DIR"
    fi
done

# Reload linker
ldconfig

echo "Restarting K3s..."
systemctl restart k3s
echo "Waiting for node check..."
sleep 15
k3s kubectl describe node | grep nvidia.com/gpu
