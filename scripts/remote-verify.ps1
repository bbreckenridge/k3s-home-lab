$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'

$RemoteScript = @"
echo '=== Tailscale Status ==='
tailscale status
tailscale ip -4

echo -e '\n=== Cluster Pods (Default) ==='
/usr/local/bin/k3s kubectl get pods -n default -o wide

echo -e '\n=== Cluster Services (Default) ==='
/usr/local/bin/k3s kubectl get svc -n default

echo -e '\n=== Gateway IP ==='
/usr/local/bin/k3s kubectl get svc -n istio-system -l app=istio-ingressgateway
"@

Write-Host "Verifying on $IP..."
# 1. Normalize line endings (CRLF -> LF)
$RemoteScript = $RemoteScript -replace "`r`n", "`n"
# 2. Upload script to temp file
$Encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($RemoteScript))
ssh -o StrictHostKeyChecking=no $User@$IP "echo $Encoded | base64 -d > /tmp/verify.sh"

# 2. Exec with sudo
$RunCmd = "echo '$Pass' | sudo -S bash /tmp/verify.sh"
ssh -o StrictHostKeyChecking=no $User@$IP $RunCmd
