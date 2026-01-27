# Script: scripts/gpu-partition.ps1
# Use: Project physical GPU into the Proxmox "Seed" VM

$GPU = Get-VMHostPartitionableGpu | Where-Object {$_.Name -match "VEN_10DE"}
if (-not $GPU) {
    Write-Warning "RTX 5090 not found. Listing available GPUs:"
    Get-VMHostPartitionableGpu | Select-Object Name
    return
}

Add-VMGpuPartitionAdapter -VMName "PVE-Seed" -InstancePath $GPU.Name
Set-VMGpuPartitionAdapter -VMName "PVE-Seed" `
    -MinPartitionVRAM 1GB `
    -MaxPartitionVRAM 8GB `
    -OptimalPartitionVRAM 4GB
