$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'

$RemoteScript = @"
echo '=== Listing Home Dir ==='
ls -la ~

echo -e '\n=== Finding bootstrap-ansible.sh ==='
find ~ -name "bootstrap-ansible.sh"

echo -e '\n=== Checking zip files ==='
ls -l ~/ansible.zip ~/scripts.zip
"@

Write-Host "Finding files on $IP..."
$RemoteScript = $RemoteScript -replace "`r`n", "`n"
$Encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($RemoteScript))
ssh -o StrictHostKeyChecking=no $User@$IP "echo $Encoded | base64 -d | bash"
