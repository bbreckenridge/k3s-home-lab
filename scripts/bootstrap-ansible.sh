#!/bin/bash
# Script: scripts/bootstrap-ansible.sh
# Purpose: Boostrap Ansible on Proxmox and auto-deploy K3s
# export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
export SOPS_AGE_KEY_FILE=/home/username/.config/sops/age/keys.txt
set -e

echo "ðŸš€ Bootstrapping Ansible..."

# 1. Install Ansible (if missing)
if ! command -v ansible &> /dev/null; then
    echo "ðŸ“¦ Installing Ansible..."
    apt update
    apt install -y ansible git python3-kubernetes
    apt install -y ansible git python3-kubernetes
fi

# Ensure kubernetes.core collection is installed (Idempotent-ish)
ansible-galaxy collection install kubernetes.core

# Install Age and SOPS for Secret Decryption
if ! command -v age &> /dev/null; then
    echo "Installing Age..."
    apt install -y age || echo "Age package not found in default repos, skipping..."
fi

if ! command -v sops &> /dev/null; then
    echo "Installing SOPS..."
    # Download latest SOPS deb
    SOPS_VERSION="v3.8.1"
    wget -q https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops_${SOPS_VERSION#v}_amd64.deb
    dpkg -i sops_${SOPS_VERSION#v}_amd64.deb
    rm sops_${SOPS_VERSION#v}_amd64.deb
fi

# Install Community General (specifically for sops)
ansible-galaxy collection install community.sops

# Symlink SOPS so root can find it (secure_path often excludes /usr/local/bin)
if [ -f /usr/local/bin/sops ]; then
    ln -sf /usr/local/bin/sops /usr/bin/sops
fi

# 2. Clone/Update Repo (Optional: Assumes we are running from mapped folder or simple copy)
# For now, we assume the user copied the 'ansible' directory to /root/ansible
# or we are running inside the repo structure.

REPO_ROOT=$(dirname "$(readlink -f "$0")")/..
ANSIBLE_DIR="$REPO_ROOT/ansible"

if [ ! -d "$ANSIBLE_DIR" ]; then
    echo "âŒ Ansible directory not found at $ANSIBLE_DIR"
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

# SECRETS HANDLING: Copy pre-encrypted secrets from user home if present
REAL_USER_HOME="/home/username"
if [ -f "$REAL_USER_HOME/secrets.enc.yaml" ]; then
    echo "ðŸ” Found pre-encrypted secrets. Copying to inventory..."
    cp "$REAL_USER_HOME/secrets.enc.yaml" "$ANSIBLE_DIR/inventory/group_vars/all/secrets.enc.yaml"
fi

# 5. Run Platform Services Playbook
# FIX: Inject known-good playbook content to avoid corruption
echo "ðŸ”§ Injecting Platform Services Playbook..."
cat <<'EOF' > playbooks/platform-services.yml
---
- name: bootstrap_platform_services
  hosts: k3s_cluster
  become: true
  vars:
    tailscale_auth_key: "" # User to provide or manual login

  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml

  tasks:
    # --- TAILSCALE (Host Level) ---
    - name: Install Tailscale Dependencies
      apt:
        name: [curl, apt-transport-https]
        state: present
        update_cache: yes

    - name: Add Tailscale Repo Key
      get_url:
        url: https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg
        dest: /usr/share/keyrings/tailscale-archive-keyring.gpg
        mode: '0644'

    - name: Add Tailscale Repository
      get_url:
        url: https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list
        dest: /etc/apt/sources.list.d/tailscale.list

    - name: Install Tailscale
      apt:
        name: tailscale
        state: latest
        update_cache: yes

    - name: Check Tailscale Status
      command: tailscale status
      register: tailscale_status
      failed_when: false
      changed_when: false

    - name: Enable Tailscale (Manual Auth Required if no key)
      command: "tailscale up --authkey={{ tailscale_auth_key }}"
      when: tailscale_status.rc != 0 and tailscale_auth_key != ""
      ignore_errors: true
      register: tailscale_up

    - name: Tailscale Auth Instructions
      debug:
        msg: "Tailscale installed. If no auth key provided, run 'sudo tailscale up' manually on the host to authenticate."
      when: tailscale_status.rc != 0 and tailscale_auth_key == ""

    # --- HELM CONFIG ---
    - name: Check for Helm
      command: which helm
      register: helm_check
      failed_when: false
      changed_when: false

    - name: Install Helm (Script)
      shell: |
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 get_helm.sh
        ./get_helm.sh
        rm get_helm.sh
      when: helm_check.rc != 0

    - name: Add Bitnami Helm Repo
      kubernetes.core.helm_repository:
        name: bitnami
        repo_url: "https://charts.bitnami.com/bitnami"
    
    - name: Add Grafana Helm Repo
      kubernetes.core.helm_repository:
        name: grafana
        repo_url: "https://grafana.github.io/helm-charts"

    - name: Add OpenTelemetry Helm Repo
      kubernetes.core.helm_repository:
        name: open-telemetry
        repo_url: "https://open-telemetry.github.io/opentelemetry-helm-charts"



    # --- GRAFANA (Cluster Level) ---
    - name: Install Grafana
      kubernetes.core.helm:
        name: grafana
        chart_ref: grafana/grafana
        release_namespace: platform-services
        create_namespace: true
        wait: no # Debugging: Don't wait, so we can see why it fails
        values:
          adminPassword: "<INSERT_SECURE_PASSWORD_HERE>" # Change in production!
          service:
            type: LoadBalancer

    # --- OBSERVABILITY STACK (LGTM + OTel) ---
    
    # Mimir (Metrics) - Monolithic Mode for Single Node
    - name: Install Mimir
      kubernetes.core.helm:
        name: mimir
        chart_ref: grafana/mimir-distributed
        release_namespace: observability
        create_namespace: true
        wait: no # Heavy install, don't block
        values:
          mimir:
            structuredConfig:
              common:
                storage:
                  backend: filesystem
                  filesystem:
                    dir: /data/mimir
          # Resources Tuning for Single Node
          ingester:
            resources:
              requests: {cpu: 10m, memory: 128Mi}
          distributor:
            resources:
              requests: {cpu: 10m, memory: 64Mi}
          querier:
            resources:
              requests: {cpu: 10m, memory: 128Mi}
          query_frontend:
            resources:
              requests: {cpu: 10m, memory: 64Mi}
          store_gateway:
            resources:
              requests: {cpu: 10m, memory: 64Mi}
          compactor:
            resources:
              requests: {cpu: 10m, memory: 64Mi}
          ruler:
            resources:
              requests: {cpu: 10m, memory: 64Mi}
          minio:
            enabled: true
          alertmanager:
            enabled: false # Use Grafana Alerting

    # Loki (Logs) - Scalable Mode
    - name: Install Loki
      kubernetes.core.helm:
        name: loki
        chart_ref: grafana/loki
        release_namespace: observability
        create_namespace: true
        wait: no
        values:
          loki:
            useTestSchema: true
            auth_enabled: false
            commonConfig:
              replication_factor: 1
            storage:
              type: 'filesystem'
          deploymentMode: SingleBinary
          singleBinary:
            replicas: 1
            resources:
              requests: {cpu: 10m, memory: 128Mi}
          # Disable scalable components to avoid conflict
          read:
            replicas: 0
          write:
            replicas: 0
          backend:
            replicas: 0
          # Tune Cache (Memcached) Resources
          chunksCache:
            enabled: true
            resources:
              requests: {cpu: 10m, memory: 64Mi} 
          resultsCache:
            enabled: true
            resources:
              requests: {cpu: 10m, memory: 64Mi}
          gateway:
            resources:
              requests: {cpu: 10m, memory: 32Mi}

    # Tempo (Traces)
    - name: Install Tempo
      kubernetes.core.helm:
        name: tempo
        chart_ref: grafana/tempo
        release_namespace: observability
        create_namespace: true
        wait: no
        values:
          tempo:
            storage:
              trace:
                backend: local
                local:
                  path: /var/tempo/traces
                wal:
                  path: /var/tempo/wal
          # The following `values` block was a duplicate and has been merged or removed if redundant.
          # If specific `repository` or `tag` values are needed, they should be placed under the `tempo:` key.
          # For example:
          #   tempo:
          #     repository: "grafana/tempo"
          #     tag: "latest"
          #     storage:
          #       trace:
          #         backend: local
          #         local:
          #           path: /var/tempo/traces
          #         wal:
          #           path: /var/tempo/wal
          repository: "grafana/tempo"
          tag: "latest"

    # OpenTelemetry Collector
    - name: Install OpenTelemetry Collector
      kubernetes.core.helm:
        name: otel-collector
        chart_ref: open-telemetry/opentelemetry-collector
        release_namespace: observability
        create_namespace: true
        wait: no
        values:
          mode: daemonset
EOF

echo "Running Platform Services (Tailscale, Keycloak, Grafana)..."
ansible-playbook -v -i inventory/hosts.ini playbooks/platform-services.yml

# 6. Apply NVIDIA Device Plugin
echo "Applying NVIDIA Device Plugin..."
k3s kubectl apply -f "$REPO_ROOT/kubernetes/nvidia-device-plugin.yml"

echo "âœ… Deployment Complete!"
