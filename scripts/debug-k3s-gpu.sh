#!/bin/bash
echo "--- 1. NVIDIA-SMI Check ---"
nvidia-smi -L || echo "nvidia-smi failed"

echo "--- 2. Device Plugin Pod Status ---"
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds

echo "--- 3. Device Plugin Logs ---"
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds --tail=20

echo "--- 4. Containerd Config Check ---"
cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep -i nvidia || echo "No nvidia config found in toml"

echo "--- 5. Runtime Class ---"
kubectl get runtimeclass
