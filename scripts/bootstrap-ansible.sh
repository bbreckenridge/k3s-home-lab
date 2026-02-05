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
if systemctl is-active --quiet k3s; then
    systemctl restart k3s
fi
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

# 5. Run Platform Services Playbook
echo "Running Platform Services (Tailscale, Keycloak, Grafana)..."
ansible-playbook -i inventory/hosts.ini playbooks/platform-services.yml

# 6. Apply NVIDIA Device Plugin
echo "Applying NVIDIA Device Plugin..."
k3s kubectl apply -f "$REPO_ROOT/kubernetes/nvidia-device-plugin.yml"

echo "✅ Deployment Complete!"
