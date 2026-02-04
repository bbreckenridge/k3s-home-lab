# 🚀 Homelab & AI Orchestration: Master Engineering Specification

## Executive Summary
This project implements a **High-Assurance Hybrid Cloud** environment on local hardware. The mission is to provide a production-grade playground for **AI Agent Orchestration** and **Media Automation** while maintaining strict **NIST 800-53 Rev 5** security controls.

### Hardware Core
* **CPU:** AMD Ryzen 9 9950X3D (16C/32T) — *AMD-V & SVM Enabled*
* **GPU:** NVIDIA RTX 5090 (32GB VRAM) — *GPU-P Enabled*
* **Memory:** 64GB DDR5 (ECC Preferred)
* **Storage:** NVMe Gen5 RAID (Data Integrity Layer)

---

## 1. System Architecture & Virtualization Topology 🏗️

The environment utilizes **Type 1 Hypervisor (Hyper-V)** to host the AI workload directly. This eliminates nested virtualization overhead and solves kernel compatibility issues for GPU partitioning.

### 1.1 Virtualization & Network Topology (L1)

```mermaid
graph TD
    subgraph Host [L0: Physical Host Windows 11]
        NIC[Physical 10GbE NIC]
        Switch[Hyper-V Switch PrimarySwitch]
        GPU[RTX 5090]
    end

    subgraph VM [L1: K3s Node Ubuntu 22.04 VM]
        UseSpace[User Space]
        Kernel[Linux Kernel Azure 6.8+]
        Module[dxgkrnl DKMS]
        vGPU[Partitioned vGPU 16GB]
        K3s[K3s Single Node]
    end

    subgraph ServiceMesh [L2: Service Mesh]
        Ingress[Istio Ingress Gateway]
        Auth[Keycloak Sidecar]
        App[Workload AI Agent]
    end

    NIC --> Switch
    Switch --> K3s
    GPU -.-> vGPU
    vGPU -.-> Module
    Module --> Kernel
    Kernel --> K3s
    K3s --> Ingress
    Ingress --> Auth
    Auth --> App
```

### 1.2 Resource Allocation

| Hardware Component | Allocation Strategy | Host (Win 11) | Guest (Ubuntu VM) |
| :--- | :--- | :--- | :--- |
| **CPU (9950X3D)** | Game Mode Scheduling | 8 Cores (Gaming) | 8 Cores (Lab Services) |
| **GPU (RTX 5090)** | GPU-P (Partitioning) | 100% 3D / Video Enc | ~25-50% CUDA Compute |
| **RAM (64GB)** | Static Allocation | 32GB Reserved | 32GB Static |
| **Network** | Virtual Switch | 10GbE Native | Virtualized Bridge |

---

## 2. NIST 800-53 Rev 5 Compliance Mapping 🛡️

All technical decisions are mapped to federal security standards to ensure a "production-grade" posture.

| NIST ID | Control Family | Technical Implementation | Logic Detail |
| :--- | :--- | :--- | :--- |
| **AC-2** | Account Mgmt | **Keycloak OIDC** | Disables local `/etc/shadow` passwords; forces OIDC login. |
| **AC-3** | Access Enforcement | **Istio AuthPolicy** | Default "Deny-All" ingress; requires valid JWT for all routes. |
| **AC-6** | Least Privilege | **K8s RBAC** | ClusterRoles mapped to Keycloak groups (`admins`, `devs`). |
| **IA-2** | Identification/Auth | **MFA (TOTP)** | Mandatory 2FA at Istio Gateway; seeds encrypted in Keycloak DB. |
| **IA-8** | Non-Org Users | **Tailscale ACLs** | Mesh-only access for remote management. |
| **AU-2** | Event Logging | **Grafana Loki** | Log levels: `info` for applications, `audit` for API server. |
| **SC-8** | Transmission | **Istio mTLS** | X.509 certs rotated via Citadel; mTLS mode: `STRICT`. |
| **SC-7** | Boundary Protection | **UFW Firewall** | Deny-All incoming; explicit allow for K3s/SSH only. |
| **SI-4** | System Monitoring | **Fail2Ban** | Monitors `sshd` logs; bans IPs after 5 failed attempts. |
| **SI-2** | Flaw Remediation | **Unattended Upgrades** | Automatic installation of critical security patches. |

---

## 3. Secret Management Specification (SOPS + age) 🔑

All sensitive data in this repository is encrypted using **SOPS** with the **age** backend to ensure no plaintext secrets are committed to GitHub.

### 3.1 Encryption Policy (`.sops.yaml`)

```yaml
creation_rules:
  - path_regex: .*\.enc\.yaml$
    key_groups:
      - age:
          - age1your_public_key_here # Replace with your public key
```

### 3.2 Secret Injection Workflow

1.  **Generate Master Key**:
    ```powershell
    age-keygen -o "$env:AppData\sops\age\keys.txt"
    ```
2.  **Set Environment Variable**:
    ```powershell
    $env:SOPS_AGE_KEY_FILE="$env:AppData\sops\age\keys.txt"
    ```
3.  **Encrypt a Secret**:
    ```bash
    sops -e -i kubernetes/apps/media/secrets.enc.yaml
    ```
4.  **Decrypt (Verify)**:
    ```bash
    sops -d kubernetes/apps/media/secrets.enc.yaml
    ```

---

## 4. Service Mesh & Zero-Trust Networking (Istio + Keycloak) 🌐

### 4.1 Authentication Request Flow (NIST IA-2)

```mermaid
sequenceDiagram
    participant User
    participant Ingress as Istio Gateway
    participant Keycloak
    participant App as Workload

    User->>Ingress: HTTPS Request (No Token)
    Ingress-->>User: 302 Redirect to Keycloak
    User->>Keycloak: Login (User/Pass + TOTP)
    Keycloak-->>User: Return JWT (Access Token)
    User->>Ingress: HTTPS Request (Header: Authorization Bearer JWT)
    Ingress->>Ingress: Validate JWT Signature (JWKS)
    alt Valid Token
        Ingress->>App: Proxy Request
        App-->>User: 200 OK
    else Invalid Token
        Ingress-->>User: 401 Unauthorized
    end
```

### 4.2 Peer Authentication (mTLS Strict)

Enforces end-to-end encryption for all inter-pod traffic.

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT # Rejects all non-encrypted or non-mTLS traffic
```

---

## 5. The GPU Pipeline: Gaming & AI Coexistence 🏎️

To utilize the RTX 5090 for both 4K gaming and AI workloads, we implement **GPU Partitioning (GPU-P)** directly on Hyper-V.

### 5.1 Host-Level Partitioning Logic (PowerShell)
Handled automatically by `scripts/provision-ubuntu.ps1`.

### 5.2 Guest Configuration
*   **OS**: Ubuntu 22.04 LTS (Kernel 6.x+ `linux-image-azure`)
*   **Driver**: NVIDIA Server Driver 535+
*   **Runtime**: Nvidia Container Toolkit

---

## 6. Implementation Flight Manual ⚓

### Step 1: BIOS & Hardware Prep
Enable SVM, IOMMU, SR-IOV in BIOS.

### Step 2: Host Tooling (PowerShell Admin)
```powershell
choco install -y git ansible sops age.portable kubernetes-cli kubernetes-helm
```

### Step 3: Provision Infrastructure
Run the PowerShell script to create the VM and apply GPU partitioning:
> **Note:** Requires `Administrator` privileges.

```powershell
.\scripts\provision-ubuntu.ps1
```

> [!IMPORTANT]
> **RTX 5090 / Consumer GPU "Insufficient Resources" Error:**
> If the VM fails to start with `0x800705AA`, the Host is likely reporting a capped "Partitionable Limit".
> **Fix:** The script intentionally sets the partition VRAM to 512MB to bypass the launch check. The Guest will still access the full VRAM.

### Step 4: Inject Drivers (The critical "Consumer GPU" fix) 🌶️
Because we are using a Consumer GPU (GeForce) in a VM, we must manually inject both the Driver Store files AND the WSL compatibility libraries (`libdxcore.so`).

**A. On Windows (Admin PowerShell):**
This script parses your System32, finds the driver and the missing libs, and copies them to the VM (`~/host-drivers`).
```powershell
.\scripts\inject-drivers.ps1
```

**B. On Ubuntu (SSH):**

1.  **Install the User-Space Drivers**:
    ```bash
    sudo bash ~/host-drivers/install-host-drivers.sh
    ```
    *Verifies `libdxcore.so` and `libd3d12.so` are linked in `/usr/lib/wsl/lib`.*

2.  **Install the Kernel (Official Azure + DKMS)**:
    We use the official Azure kernel (for Hyper-V support) and build the `dxgkrnl` module manually via DKMS.

    ```bash
    # 1. Install Azure Kernel (6.8+)
    sudo bash ~/install-azure-kernel.sh
    # (VM will reboot automatically)

    # 2. Select "Ubuntu with Linux ... azure" in GRUB if prompted.

    # 3. Install dxgkrnl via DKMS
    sudo bash ~/install-dkms-dxgkrnl.sh
    ```

### Step 5: Security Hardening (NIST Baseline) 🛡️

Before exposing services, apply the security baseline:

```bash
# On the Ubuntu VM
sudo bash ~/harden-vm.sh
```
*   Configures UFW (Firewall)
*   Installs/Configures Fail2Ban (SSH Protection)
*   Enables Automatic Security Updates
*   Hardens SSH Configuration

### Step 6: K3s & AI Bootstrap (Ansible)

```bash
# On the Ubuntu VM
chmod +x scripts/bootstrap-ansible.sh
./scripts/bootstrap-ansible.sh
```

### Step 7: Verification

**Check GPU:**
```bash
nvidia-smi
# Should list the RTX 5090 (partitioned)
```

**Check Kubernetes:**
```bash
kubectl describe node | grep nvidia.com/gpu
# Should show capacity: 1
```

---

## 7. Repository Directory Structure 📂

Cleaned up to show only verified production scripts.

```text
k3slab/
├── .sops.yaml                # Secret encryption policy
├── .gitignore                # Git exclusion rules
├── ansible/                  # Configuration Management
│   ├── playbooks/            # K3s install, GPU setup
│   └── inventory/            # Dynamic host mapping
├── kubernetes/               # GitOps Manifests (ArgoCD)
└── scripts/                  # Provisioning & Bootstrap
    ├── provision-ubuntu.ps1    # Hyper-V VM Creator & GPU-P Config
    ├── inject-drivers.ps1      # Host Driver & WSL Lib Extractor (Windows)
    ├── install-host-drivers.sh # Guest Driver Installer (Ubuntu)
    ├── install-azure-kernel.sh # Installs official linux-image-azure
    ├── install-dkms-dxgkrnl.sh # Compiles dxgkrnl module via DKMS
    ├── bootstrap-ansible.sh    # Ansible Wrapper
    ├── harden-vm.sh            # Security Hardening (UFW/Fail2Ban/SSH)
    └── configure-static-ip.sh  # IP Configuration
```

---

## 8. Storage & Backup Strategy 💾

### 8.1 Storage Architecture (Hyper-V + Ubuntu)
We utilize a mix of virtualized disks and passed-through NVMe storage for performance and data integrity.

| Dataset | Mount Point | Source | Strategy |
| :--- | :--- | :--- | :--- |
| **OS / Etcd** | `/var/lib/rancher` | VHDX (OS Drive) | Standard ext4 |
| **Media Library** | `/mnt/media` | SMB Mount / VHDX | Data Drive (Separate VHDX) |
| **AI Models** | `/mnt/models` | Local NVMe | High-perf scratch space |

### 8.2 Backup Policy (3-2-1 Rule)

| Type | Source | Destination | Frequency | Tool |
| :--- | :--- | :--- | :--- | :--- |
| **Cluster State** | K3s Etcd | TrueNAS / S3 | Hourly | `velero` |
| **Config** | GitHub Repo | Local + GitHub | Push-Trigger | `git` |
| **VM Snapshots** | Hyper-V | NAS / External HDD | Weekly | `Checkpoints` |

---

## 9. Day 1 Checklist ✅

- [ ] **BIOS**: Enable SVM, IOMMU, SR-IOV.
- [ ] **Hyper-V**: Feature enabled in Windows.
- [ ] **Network**: Create External V-Switch "PrimarySwitch".
- [ ] **Tools**: Install Choco, Git, Ansible, SOPS.
- [ ] **Keys**: Generate `age` key for SOPS.
- [ ] **Provision**: Run `scripts/provision-ubuntu.ps1`.
- [ ] **Install**: Install Ubuntu Server 22.04 LTS on the VM.
- [ ] **Inject**: Run `scripts/inject-drivers.ps1` (Copies Drivers + WSL Libs).
- [ ] **Kernel**: Run `install-azure-kernel.sh` (Official Azure Kernel).
- [ ] **Module**: Run `install-dkms-dxgkrnl.sh` (DKMS Build).
- [ ] **Harden**: Run `harden-vm.sh` (Firewall & Security).
- [ ] **Verify**: Check `nvidia-smi` and `kubectl get nodes`.