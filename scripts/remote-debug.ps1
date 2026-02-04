$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'
$RemoteCmd = "echo '$Pass' | sudo -S nvidia-smi -L; echo '---'; echo '$Pass' | sudo -S cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep -A 5 'runtimes.nvidia'; echo '---'; echo '$Pass' | sudo -S k3s kubectl get pods -A"

Write-Host "Debugging on $IP..."
ssh -o StrictHostKeyChecking=no $User@$IP $RemoteCmd
