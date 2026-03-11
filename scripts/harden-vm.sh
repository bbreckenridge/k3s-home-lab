#!/bin/bash
set -e

# Script: scripts/harden-vm.sh
# Purpose: Apply NIST-aligned security hardening (UFW, Fail2Ban, SSH, Auto-Updates)

# Non-interactive mode
export DEBIAN_FRONTEND=noninteractive

echo "[0] Installing Prerequisites..."
apt-get update
# Fail2Ban and Unattended Upgrades
apt-get install -y ufw fail2ban unattended-upgrades

echo "[1] Configuring Application Firewall (UFW)..."
# NIST SC-7: Boundary Protection
# Reset to default
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (Rate Limited)
ufw limit 22/tcp comment 'SSH'

# Allow K3s API (Critical)
ufw allow 6443/tcp comment 'K3s API'

# Allow K3s NodePorts / MetalLB Range (192.168.71.160-180)
# Allowing the whole range for simplicity in a lab
ufw allow from any to any port 30000:32767 proto tcp comment 'NodePorts'
ufw allow from any to any port 80 proto tcp comment 'Ingress HTTP'
ufw allow from any to any port 443 proto tcp comment 'Ingress HTTPS'

# Allow AdGuard Home DNS Resolution
ufw allow 53/tcp comment 'AdGuard DNS TCP'
ufw allow 53/udp comment 'AdGuard DNS UDP'

# Allow Tailscale VPN Tunneling
ufw allow 41641/udp comment 'Tailscale UDP'

# Allow Flannel/VXLAN Overlay (Internal Cluster Traffic)
ufw allow 8472/udp comment 'Flannel VXLAN'
ufw allow 10250/tcp comment 'Kubelet Metrics'

# Enable Firewall
echo "Enabling UFW..."
ufw --force enable
ufw status verbose

echo "[2] Installing & Configuring Fail2Ban..."
# NIST SI-4: Information System Monitoring
# Explicitly set backend to systemd to avoid startup errors on minimal Ubuntus
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
backend = systemd

[sshd]
enabled = true
EOF

systemctl enable fail2ban
systemctl restart fail2ban
systemctl status fail2ban --no-pager

echo "[3] Hardening SSH Config..."
# NIST AC-6: Least Privilege
# Backup
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply Hardening (Disable Root, Disable Password - IF keys are setup!)
# WARNING: We must ensure keys are set up before disabling password auth.
# For this script, we will just disable Root Login and enforce Protocol 2.
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config # Keep yes for now until user confirms keys
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

echo "[4] Unattended Upgrades..."
# NIST SI-2: Flaw Remediation
echo 'Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};' > /etc/apt/apt.conf.d/50unattended-upgrades

echo "✅ Hardening Complete."
