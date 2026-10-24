# 🛡️ Enterprise Hybrid IAM: Active Directory, Microsoft Entra ID & JML Lifecycle Automation

![Windows Server](https://img.shields.io/badge/Windows%20Server%202022-AD%20DS-0078D6?style=for-the-badge&logo=windows)
![Microsoft Entra ID](https://img.shields.io/badge/Microsoft%20Entra%20ID-Hybrid%20Identity-00A4EF?style=for-the-badge&logo=microsoftazure)
![PowerShell](https://img.shields.io/badge/PowerShell-Automation-5391FE?style=for-the-badge&logo=powershell)
![Security](https://img.shields.io/badge/Security-Zero%20Trust%20%26%20GPO-success?style=for-the-badge)

## 📌 Project Overview & Business Problem
Modern enterprises rarely operate in a 100% cloud or 100% on-premises silo. Most organizations rely on a **Hybrid Identity Architecture**, where on-premises **Active Directory Domain Services (AD DS)** acts as the authoritative source of truth and synchronizes identities to **Microsoft Entra ID (formerly Azure AD)** for cloud productivity and Single Sign-On (SSO).

However, poorly configured hybrid environments introduce severe operational and security risks:
* Manual GUI-based account creation leads to naming inconsistencies, typos, and slow onboarding.
* Syncing the entire directory blindly exposes Tier-0 `Domain Admin` accounts to cloud attack surfaces.
* Role transfers ("Movers") result in **privilege creep** when legacy security groups are not revoked.
* Standard 30-minute Entra Connect sync intervals leave a dangerous window where terminated employees ("Leavers") retain active cloud access.

This project implements a hardened, production-grade **Hybrid Identity & Access Management (IAM) Lab** that solves these challenges through **PowerShell bulk provisioning**, **Zero-Trust Organizational Unit (OU) sync scoping**, **Joiner-Mover-Leaver (JML) lifecycle administration**, and **Group Policy (GPO) lockout forensics**.

---

## 🎯 Project Objectives
1. **Architect a Zero-Trust OU Hierarchy:** Deploy an on-premises Windows Server Domain Controller with segregated Organizational Units (`Corp_Users`, `Tier0_Admins`, and `Quarantine_Disabled`) and custom cloud-routable UPN suffixes.
2. **Automate Bulk Identity Provisioning (Joiner):** Engineer an idempotent PowerShell script (`Invoke-ADBulkOnboarding.ps1`) that ingests HR `.csv` feeds to create standardized AD accounts, populate metadata, and assign Role-Based Access Control (RBAC) security groups.
3. **Enforce Scoped Hybrid Synchronization:** Configure **Microsoft Entra Connect** with **Password Hash Synchronization (PHS)**, **Seamless SSO**, and **OU Filtering** to prevent privileged Tier-0 and disabled accounts from replicating to the cloud.
4. **Execute JML Administrative Operations (Mover & Leaver):** Perform lateral department transfers enforcing the **Principle of Least Privilege**, and execute emergency offboarding with forced delta synchronization (`Start-ADSyncSyncCycle -PolicyType Delta`).
5. **Harden Endpoints & Investigate Lockouts:** Enforce domain-wide Account Lockout policies via **GPO** and perform root-cause security forensics using Windows Event Viewer (**Event ID 4740**).

---

## 🛠️ Skills & Competencies Demonstrated

| Competency Area | Specific Technical Implementation |
| :--- | :--- |
| **Hybrid Identity Architecture** | Deploying AD DS (`dcpromo`), configuring alternative UPN suffixes (`Active Directory Domains and Trusts`), and integrating **Microsoft Entra Connect**. |
| **PowerShell IAM Automation** | Writing modular PowerShell scripts using the `ActiveDirectory` and `ADSync` modules (`New-ADUser`, `Add-ADGroupMember`, `Import-Csv`, `Start-ADSyncSyncCycle`). |
| **Lifecycle Governance (JML)** | Executing Joiner, Mover, and Leaver workflows; preventing privilege creep via strict RBAC group hygiene; rapid cloud access revocation. |
| **Cloud Security & Zero-Trust** | Implementing **Entra Connect OU Filtering** to isolate Tier-0 admin accounts from cloud exposure; verifying cloud replication in **Microsoft Entra Admin Center**. |
| **GPO & Incident Forensics** | Authoring **Group Policy Objects (GPO)** for account lockout thresholds (`secpol`) and diagnosing lockouts via Domain Controller Security Logs (**Event ID 4740**). |

---

## 🏗️ Hybrid Directory & Sync Architecture

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ ON-PREMISES: Windows Server 2022 Domain Controller (corp.contoso.local)    │
│                                                                            │
│  [HR CSV Feed: new_hires.csv]                                              │
│        │                                                                   │
│        ▼ (Invoke-ADBulkOnboarding.ps1)                                     │
│  ┌──────────────────────┐   ┌────────────────────┐   ┌──────────────────┐  │
│  │ OU=Corp_Users        │   │ OU=Tier0_Admins    │   │ OU=Quarantine_   │  │
│  │  ├─ OU=Engineering   │   │  └─ Domain Admins  │   │    Disabled      │  │
│  │  ├─ OU=Finance       │   └─────────┬──────────┘   └────────┬─────────┘  │
│  │  └─ OU=HR            │             │                       │            │
│  └──────────┬───────────┘             ▼                       ▼            │
│             │               [BLOCKED BY OU FILTER]  [BLOCKED BY OU FILTER] │
└─────────────┼──────────────────────────────────────────────────────────────┘
              │
              ▼  Microsoft Entra Connect (PHS + Seamless SSO + Delta Sync)
┌────────────────────────────────────────────────────────────────────────────┐
│ CLOUD: Microsoft Entra ID Tenant (<yourtenant>.onmicrosoft.com)            │
│                                                                            │
│  ✓ Synced Corporate Identities (Source: Windows Server AD)                 │
│  ✓ Cloud RBAC & Conditional Access MFA Readiness                           │
│  ✓ Instant Deprovisioning upon On-Prem OU Quarantine Move                  │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 📂 Repository Structure & Deliverables

```text
├── README.md                                 # Executive architecture overview & proof of work
├── SETUP_GUIDE.md                            # Step-by-step implementation runbook & checkpoints
├── scripts/
│   └── Invoke-ADBulkOnboarding.ps1           # Automated CSV-to-AD provisioning & RBAC script
├── data/
│   └── new_hires.csv                         # Sample HR onboarding dataset
└── assets/
    ├── 01_aduc_ou_hierarchy.png              # ADUC showing structured OUs & Security Groups
    ├── 02_powershell_bulk_provisioning.png   # Terminal output of automated user creation
    ├── 03_entra_connect_ou_filtering.png     # Entra Connect wizard showing scoped OU sync
    ├── 04_entra_portal_synced_users.png      # Entra ID Admin Center showing synced identities
    ├── 05_jml_mover_leaver_audit.png         # AD attribute modifications & delta sync revocation
    └── 06_event_4740_lockout_forensics.png   # Event Viewer ID 4740 lockout investigation & unlock
```

---

## 📸 Implementation Walkthrough & Proof of Work

### 1. Zero-Trust OU Structure & PowerShell Bulk Provisioning (`Joiner`)
*(Insert `assets/02_powershell_bulk_provisioning.png` here)*
* **What this shows:** Rather than manually creating users in the GUI, executed `Invoke-ADBulkOnboarding.ps1` against `new_hires.csv`. The script dynamically validated target OUs, constructed routable UPNs, populated job metadata, and bound users to departmental Security Groups (`SG_Engineering`, `SG_Finance`, `SG_HR`).

### 2. Scoped Hybrid Sync via Microsoft Entra Connect
*(Insert `assets/03_entra_connect_ou_filtering.png` and `assets/04_entra_portal_synced_users.png` here)*
* **What this shows:** Configured Custom Installation in Microsoft Entra Connect with Password Hash Synchronization. Restricted synchronization strictly to the `OU=Corp_Users` subtree, ensuring `OU=Tier0_Admins` and `OU=Quarantine_Disabled` remain strictly on-premises.

### 3. Administrative Modifications: Lateral Transfer (`Mover`) & Termination (`Leaver`)
*(Insert `assets/05_jml_mover_leaver_audit.png` here)*
* **Mover Scenario:** Processed a departmental transfer for *Marcus Vance* (Finance -> Engineering). Removed `SG_Finance` membership to prevent privilege creep, assigned `SG_Engineering`, updated `Department`/`Title` attributes, relocated the object to `OU=Engineering`, and pushed a delta sync.
* **Leaver Scenario:** Processed an immediate termination for *Elena Rostova*. Disabled the account, stripped all group memberships, moved the user to `OU=Quarantine_Disabled` (outside the Entra Connect sync scope), and triggered `Start-ADSyncSyncCycle -PolicyType Delta` to immediately purge active cloud access.

### 4. GPO Hardening & Event ID 4740 Lockout Forensics
*(Insert `assets/06_event_4740_lockout_forensics.png` here)*
* **What this shows:** Deployed a Domain Group Policy enforcing a 3-attempt account lockout threshold. Simulated a brute-force/misconfigured credential lockout, traced the originating workstation IP/computer name via **Security Event ID 4740** on the Domain Controller, and remediated the ticket via `Unlock-ADAccount`.

---

## 🚀 How to Reproduce This Lab
1. Clone this repository onto your Windows Server Domain Controller:
   ```powershell
   git clone https://github.com/<your-username>/hybrid-ad-entra-iam-lab.git
   cd hybrid-ad-entra-iam-lab
   ```
2. Follow the complete step-by-step engineering runbook in **[SETUP_GUIDE.md](./SETUP_GUIDE.md)**.
3. Run the provisioning script inside an elevated PowerShell prompt:
   ```powershell
   .\scripts\Invoke-ADBulkOnboarding.ps1 -CsvPath ".\data\new_hires.csv" -UpnSuffix "yourtenant.onmicrosoft.com"
   ```