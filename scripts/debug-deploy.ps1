$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'

$RemoteScript = @"
echo '=== Checking bootstrap-ansible.sh ==='
grep 'platform-services' ~/scripts/bootstrap-ansible.sh || echo 'MISSING: platform-services call'

echo -e '\n=== Checking platform-services.yml ==='
ls -l ~/ansible/playbooks/platform-services.yml || echo 'MISSING: playbook file'

echo -e '\n=== Checking Ansible Playbooks Dir ==='
ls -l ~/ansible/playbooks/
"@

Write-Host "Checking remote state on $IP..."
# 1. Normalize line endings (CRLF -> LF)
$RemoteScript = $RemoteScript -replace "`r`n", "`n"
# 2. Upload script to temp file
$Encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($RemoteScript))
ssh -o StrictHostKeyChecking=no $User@$IP "echo $Encoded | base64 -d > /tmp/debug-deploy.sh"

# 3. Exec
ssh -o StrictHostKeyChecking=no $User@$IP "bash /tmp/debug-deploy.sh"
