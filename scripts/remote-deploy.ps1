$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'

$RemoteScript = @"
echo '$Pass' | sudo -S apt update && echo '$Pass' | sudo -S apt install -y unzip
cd ~
unzip -o ansible.zip
unzip -o scripts.zip
chmod +x scripts/bootstrap-ansible.sh
echo '$Pass' | sudo -S bash ~/scripts/bootstrap-ansible.sh
"@

Write-Host "Deploying to $IP..."
# Use base64 encoding to avoid quoting hell
$Encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($RemoteScript))
ssh -o StrictHostKeyChecking=no $User@$IP "echo $Encoded | base64 -d | bash"
