#!/bin/bash
echo "=== Host: Tailscale ==="
tailscale status

echo -e "\n=== Cluster: Pods ==="
k3s kubectl get pods -n default

echo -e "\n=== Cluster: Services ==="
k3s kubectl get svc -n default

echo -e "\n=== Ingress/Gateway ==="
k3s kubectl get svc -n istio-system
