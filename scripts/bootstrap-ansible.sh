#!/bin/bash
# Script: scripts/bootstrap-ansible.sh
# Purpose: Boostrap Ansible on Proxmox and auto-deploy K3s
set -e

echo "🚀 Bootstrapping Ansible..."

# 1. Install Ansible (if missing)
if ! command -v ansible &> /dev/null; then
    echo "📦 Installing Ansible..."
    apt update
    apt install -y ansible git
fi

# 2. Clone/Update Repo (Optional: Assumes we are running from mapped folder or simple copy)
# For now, we assume the user copied the 'ansible' directory to /root/ansible
# or we are running inside the repo structure.

REPO_ROOT=$(dirname "$(readlink -f "$0")")/..
ANSIBLE_DIR="$REPO_ROOT/ansible"

if [ ! -d "$ANSIBLE_DIR" ]; then
    echo "❌ Ansible directory not found at $ANSIBLE_DIR"
    echo "   Please upload the entire 'ansible' folder to the server."
    exit 1
fi

# Change to Ansible directory for playbook execution
cd "$ANSIBLE_DIR"

# 1. Pre-flight Cleanup (Fix bad GPU config state)
echo "Cleaning up potential bad K3s config..."
rm -f /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
systemctl restart k3s
echo "Waiting for K3s to recover..."
sleep 15

# 2. Run K3s Deployment Playbook
echo "Running K3s Deployment Playbook..."
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 3. Run Networking Playbook
echo "Running Networking & Service Mesh Playbook..."
ansible-playbook -i inventory/hosts.ini playbooks/networking.yml

# 4. Run GPU Setup Playbook
echo "Running GPU Setup Playbook..."
ansible-playbook -i inventory/hosts.ini playbooks/gpu-setup.yml

# 5. Apply NVIDIA Device Plugin
echo "Applying NVIDIA Device Plugin..."
k3s kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      priorityClassName: "system-node-critical"
      containers:
      - image: nvcr.io/nvidia/k8s-device-plugin:v0.14.1
        name: nvidia-device-plugin-ctr
        env:
          - name: FAIL_ON_INIT_ERROR
            value: "false"
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
EOF

echo "✅ Deployment Complete!"
