$User = "bbreckenridge"
$IP = "192.168.71.150"
$Pass = 'USarmy12$$'
$RemoteCmd = "echo '$Pass' | sudo -S bash ~/post-reboot-check.sh > ~/debug-output.txt"

Write-Host "Debugging on $IP..."
ssh -o StrictHostKeyChecking=no $User@$IP $RemoteCmd
