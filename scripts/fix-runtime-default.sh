#!/bin/bash
set -e
echo "Setting NVIDIA Runtime as Default..."

# Configure containerd to use nvidia as default runtime
nvidia-ctk runtime configure --runtime=containerd --set-as-default --config=/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl

# K3s uses the template to generate the config on restart
# We need to make sure the template is correct

echo "Applied to template. Restarting K3s..."
systemctl restart k3s

echo "Waiting for K3s..."
sleep 20

echo "Restarting Device Plugin..."
k3s kubectl delete daemonset -n kube-system nvidia-device-plugin-daemonset
k3s kubectl apply -f /home/bbreckenridge/kubernetes/nvidia-device-plugin.yml

echo "Waiting for pods..."
sleep 15
k3s kubectl describe node | grep nvidia.com/gpu
