#!/bin/bash
echo "=== HOST LEVEL ==="
echo "[1] Kernel Module (dxgkrnl):"
lsmod | grep dxgkrnl || echo "CRITICAL: dxgkrnl not loaded"

echo "[2] Device Node (/dev/dxg):"
ls -l /dev/dxg || echo "CRITICAL: /dev/dxg missing"

echo "[3] Host NVIDIA-SMI:"
nvidia-smi -L || echo "CRITICAL: Host nvidia-smi failed"

echo "=== RUNTIME LEVEL ==="
echo "[4] Containerd Config (Runtime):"
grep -A 5 "runtimes.nvidia" /var/lib/rancher/k3s/agent/etc/containerd/config.toml || echo "WARNING: No nvidia runtime config"

echo "=== PLUGIN LEVEL ==="
echo "[5] Plugin Logs (Startup):"
k3s kubectl logs -n kube-system -l name=nvidia-device-plugin-ds --tail=100 | grep -i "error\|starting\|device"

echo "[6] Plugin Mounts:"
k3s kubectl get ds -n kube-system nvidia-device-plugin-daemonset -o yaml | grep -A 2 volumeMounts
