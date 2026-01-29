#!/bin/bash
# Script: scripts/configure-static-ip.sh
# Purpose: Configure a static IP (192.168.68.60) via Netplan on Ubuntu 22.04
# Usage: sudo ./scripts/configure-static-ip.sh

set -e

IP_ADDR="192.168.71.150/22"
GATEWAY="192.168.68.1"
DNS_SERVERS="[8.8.8.8, 1.1.1.1]"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

echo "🔧 Configuring Static IP: $IP_ADDR on interface $INTERFACE..."

if [ -z "$INTERFACE" ]; then
    echo "❌ Could not detect network interface. Exiting."
    exit 1
fi

# Backup existing config
echo "📦 Backing up existing Netplan config..."
mkdir -p /etc/netplan/backup
cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true

# Write new config
echo "📝 Writing new Netplan config..."
cat <<EOF > /etc/netplan/99-static-ip.yaml
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: $DNS_SERVERS
EOF

# Remove old configs (standard cloud-init ones) to prevent conflicts, 
# but keep the backup we just made.
# (Optional: cautious users might prefer to just name it 99- so it overrides, 
# but explicit is often better to avoid dual-IPs).
rm -f /etc/netplan/00-installer-config.yaml /etc/netplan/50-cloud-init.yaml

echo "🚀 Applying Netplan config... (Connection Check)"
echo "⚠️  WARNING: You will likely be disconnected if your IP is different!"
netplan apply

echo "✅ Static IP Configured."
