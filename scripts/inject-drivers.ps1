# Script: scripts/inject-drivers.ps1
# Purpose: Find NVIDIA drivers on Host and copy them to K3s-Node
# Usage: .\scripts\inject-drivers.ps1

$ErrorActionPreference = "Stop"
$VM_IP = "192.168.71.150"
$User = "bbreckenridge"

# 1. Find the Driver Store
Write-Host "[*] Searching for NVIDIA Driver in DriverStore..." -ForegroundColor Cyan
$DriverPath = Get-ChildItem "C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $DriverPath) {
    Write-Error "[!] Could not find NVIDIA driver in DriverStore!"
}

Write-Host "[+] Found Driver: $($DriverPath.FullName)" -ForegroundColor Green

# 2. Prepare Destination
Write-Host "[>] Creating destination on VM..." -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no $User@$VM_IP "mkdir -p ~/host-drivers"

# 3. Copy Files
Write-Host "[>] Copying driver files (approx 1GB). This might take a minute..." -ForegroundColor Yellow
# Using scp -r to copy the folder
scp -r -o StrictHostKeyChecking=no "$($DriverPath.FullName)" "${User}@${VM_IP}:~/host-drivers/"

# 3b. Copy WSL Libraries (dxcore, d3d12)
Write-Host "[>] Copying WSL libraries (libdxcore.so, libd3d12.so)..." -ForegroundColor Yellow
$WslLibPath = "C:\Windows\System32\lxss\lib"
ssh -o StrictHostKeyChecking=no $User@$VM_IP "mkdir -p ~/host-drivers/lib"
scp -o StrictHostKeyChecking=no "$WslLibPath\libdxcore.so" "${User}@${VM_IP}:~/host-drivers/lib/"
scp -o StrictHostKeyChecking=no "$WslLibPath\libd3d12.so" "${User}@${VM_IP}:~/host-drivers/lib/"

# 4. Copy Install Script
Write-Host "[>] Copying install script..." -ForegroundColor Cyan
scp -o StrictHostKeyChecking=no ".\install-host-drivers.sh" "${User}@${VM_IP}:~/host-drivers/"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Driver files copied successfully!" -ForegroundColor Green
    Write-Host "-> Next Step: SSH into the VM and run: sudo ~/host-drivers/install-host-drivers.sh"
} else {
    Write-Error "[!] SCP Failed. Check network connection."
}
