# Script: scripts/provision-ubuntu.ps1
# Purpose: Provision the "K3s-Node" Ubuntu VM on Hyper-V
# Usage: .\scripts\provision-ubuntu.ps1 -IsoPath "C:\Path\To\ubuntu-22.04.3-live-server-amd64.iso"

param(
    [string]$IsoPath = "D:\ISOs\ubuntu-24.04.3-live-server-amd64.iso"
)

$VMName = "K3s-Node"
$SwitchName = "PrimarySwitch"
$MemoryStartup = 8GB
$ProcessorCount = 8
$VhdPath = "D:\Hyper-V\$VMName\$VMName.vhdx"
$VhdSize = 60GB

# 1. Check if VM exists
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Warning "VM '$VMName' already exists."
    exit
}

# 2. Create VM directories
$ParentDir = Split-Path $VhdPath -Parent
if (-not (Test-Path $ParentDir)) {
    New-Item -ItemType Directory -Path $ParentDir | Out-Null
}

# 3. Create VM
Write-Host "Creating VM '$VMName'..." -ForegroundColor Cyan
New-VM -Name $VMName -MemoryStartupBytes $MemoryStartup -Generation 2 -NewVHDPath $VhdPath -NewVHDSizeBytes $VhdSize -SwitchName $SwitchName | Out-Null

# 4. Configure CPU
Set-VMProcessor -VMName $VMName -Count $ProcessorCount
Set-VM -VMName $VMName -AutomaticCheckpointsEnabled $false

# 5. Disable Secure Boot (CRITICAL for NVIDIA Drivers on Linux Guest)
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

# 6. Apply GPU Partitioning
Write-Host "Applying GPU Partition..." -ForegroundColor Cyan
$GPU = Get-VMHostPartitionableGpu | Where-Object {$_.Name -match "VEN_10DE"}
if ($GPU) {
    Add-VMGpuPartitionAdapter -VMName $VMName -InstancePath $GPU.Name
    Set-VMGpuPartitionAdapter -VMName $VMName -MinPartitionVRAM 1GB -MaxPartitionVRAM 8GB -OptimalPartitionVRAM 4GB
    Set-VM -VMName $VMName -GuestControlledCacheTypes $true -LowMemoryMappedIoSpace 3000MB -HighMemoryMappedIoSpace 33000MB
    Write-Host "✅ GPU Partition Applied (RTX 5090 Split)" -ForegroundColor Green
} else {
    Write-Warning "No NVIDIA GPU found for partitioning."
}

# 7. Attach ISO and Boot
Add-VMDvdDrive -VMName $VMName -Path $IsoPath
$DVD = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVD

Write-Host "🚀 VM Created! Starting now..."
Start-VM -Name $VMName

Write-Host "Please connect to the VM and install Ubuntu Server."
Write-Host "IMPORTANT: During install, enable 'Install OpenSSH Server'."
