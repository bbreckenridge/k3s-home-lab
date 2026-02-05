#!/bin/bash
echo "=== 1. Host Driver Status ==="
nvidia-smi -L || echo "HOST DRIVER FAILED"

echo -e "\n=== 2. WSL Libraries ==="
ls -l /usr/lib/wsl/lib/libdxcore.so 2>/dev/null || echo "MISSING libdxcore.so"
ls -l /usr/lib/wsl/lib/libd3d12.so 2>/dev/null || echo "MISSING libd3d12.so"

echo -e "\n=== 3. Containerd Config (Runtime) ==="
grep -A 5 'runtimes."nvidia"' /var/lib/rancher/k3s/agent/etc/containerd/config.toml || echo "MISSING RUNTIME IN CONFIG"

echo -e "\n=== 4. Device Plugin Pod Status ==="
# Try Helm label first
POD=$(k3s kubectl get pods -n kube-system -l app.kubernetes.io/name=nvidia-device-plugin -o jsonpath="{.items[0].metadata.name}")
# Fallback to manual label
if [ -z "$POD" ]; then
    POD=$(k3s kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds -o jsonpath="{.items[0].metadata.name}")
fi

if [ -z "$POD" ]; then
    echo "CRITICAL: No Device Plugin Pod Found!"
    k3s kubectl get pods -n kube-system
else 
    echo "Pod Name: $POD"
    echo -e "\n=== 5. Device Plugin Logs ==="
    k3s kubectl logs -n kube-system $POD --tail=50
    
    echo -e "\n=== 6. Device Plugin Pod Description (Events) ==="
    k3s kubectl describe pod -n kube-system $POD | grep -A 20 "Events:"
fi

echo -e "\n=== 7. Node Capacity ==="
k3s kubectl describe node | grep -A 10 "Capacity:"
