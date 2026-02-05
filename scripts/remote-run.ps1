$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'
# We need to run the bootstrap script. It uses sudo.
$RemoteCmd = "echo '$Pass' | sudo -S bash ~/scripts/bootstrap-ansible.sh"

Write-Host "Running Bootstrap on $IP..."
ssh -o StrictHostKeyChecking=no $User@$IP $RemoteCmd
