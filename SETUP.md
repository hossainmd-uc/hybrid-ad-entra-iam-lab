# ✏️ Implementation Runbook: Enterprise Hybrid IAM & JML Lifecycle Lab

Welcome to your hands-on implementation guide! Just like your ServiceNow lab, this runbook is structured in the **CodePath Tinker** format. Follow each section sequentially, check off the boxes as you configure your Windows Server Domain Controller and Microsoft Entra ID tenant, and use the **Checkpoints** to prepare for technical IT interviews.

---

## 📋 Lab Prerequisites & Deliverables Checklist

### Environment Requirements
* **Virtualization Host:** Hyper-V (built into Windows 10/11 Pro), VMware Workstation Player, or VirtualBox.
* **Virtual Machine:** 1x **Windows Server 2022 Standard (Desktop Experience)** Evaluation ISO (allocate 4 GB RAM, 2 vCPUs, 50 GB disk, NAT/Bridged internet access).
* **Cloud Tenant:** A free **Microsoft Entra ID** tenant (via a free Azure account or Microsoft 365 Developer/Trial tenant). Note your default verified domain (e.g., `contosolab123.onmicrosoft.com`).

### Portfolio Evidence Checklist (6 Screenshots + 2 Code Files)
* [ ] `assets/01_aduc_ou_hierarchy.png` — Active Directory Users and Computers showing your custom OUs and Security Groups.
* [ ] `assets/02_powershell_bulk_provisioning.png` — PowerShell terminal output showing successful bulk CSV user creation.
* [ ] `assets/03_entra_connect_ou_filtering.png` — Microsoft Entra Connect wizard showing `Tier0_Admins` and `Quarantine_Disabled` unchecked.
* [ ] `assets/04_entra_portal_synced_users.png` — Microsoft Entra Admin Center showing your 5 users with `On-premises sync enabled = Yes`.
* [ ] `assets/05_jml_mover_leaver_audit.png` — PowerShell / Entra proof of your Mover attribute update and Leaver cloud removal.
* [ ] `assets/06_event_4740_lockout_forensics.png` — Event Viewer showing `Event ID 4740` alongside your PowerShell `Unlock-ADAccount` remediation.

---

## ▾ Part 1: Promote Domain Controller & Design Zero-Trust OU Hierarchy

> ⏰ **~20 mins**
> Instead of dumping accounts into the default `Users` container (which cannot have Group Policy Objects linked to it!), you will promote your server to a Domain Controller, register your cloud UPN suffix, and build a clean, tiered Organizational Unit (OU) hierarchy.

* [ ] Boot into your **Windows Server 2022** VM, open **Server Manager**, and set a static internal IP address on your adapter (or keep DHCP if using a single NAT VM with local loopback DNS `127.0.0.1`).
* [ ] Open an **Administrator PowerShell** window and install the Active Directory Domain Services role and management tools:
  ```powershell
  Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
  ```
* [ ] Promote the server to a new forest root Domain Controller (`corp.contoso.local`). You will be prompted to enter a SafeMode Administrator Password:
  ```powershell
  Install-ADDSForest -DomainName "corp.contoso.local" -DomainNetbiosName "CORP" -InstallDns:$true -Force:$true
  ```
  *(The server will automatically reboot after ~3 minutes. Log back in as `CORP\Administrator`).*
* [ ] **Register your Entra ID UPN Suffix:** By default, local users get `@corp.contoso.local`, which Microsoft Entra ID cannot route on the public internet. Let's add your free `.onmicrosoft.com` domain suffix:
  * Open **Server Manager > Tools > Active Directory Domains and Trusts** (or run `domain.msc`).
  * Right-click the root node **Active Directory Domains and Trusts** (top left) and select **Properties**.
  * In the **Alternative UPN suffixes** box, type your exact Entra ID default domain (e.g., `yourtenant.onmicrosoft.com`), click **Add**, and click **OK**.
* [ ] **Build the Zero-Trust OU Structure & RBAC Security Groups via PowerShell:**
  * Run the following PowerShell block to build your enterprise OUs and Security Groups automatically:
    ```powershell
    Import-Module ActiveDirectory
    $DomainDN = (Get-ADDomain).DistinguishedName

    # 1. Create Top-Level OUs
    New-ADOrganizationalUnit -Name "Corp_Users" -Path $DomainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Tier0_Admins" -Path $DomainDN -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Quarantine_Disabled" -Path $DomainDN -ProtectedFromAccidentalDeletion $true

    # 2. Create Departmental Child OUs inside Corp_Users
    $Departments = @("Engineering", "Finance", "HR")
    foreach ($Dept in $Departments) {
        New-ADOrganizationalUnit -Name $Dept -Path "OU=Corp_Users,$DomainDN"
        New-ADGroup -Name "SG_$Dept" -GroupScope Global -GroupCategory Security -Path "OU=$Dept,OU=Corp_Users,$DomainDN" -Description "RBAC Security Group for $Dept Department"
    }
    ```
* [ ] Open **Active Directory Users and Computers** (`dsa.msc`), expand `corp.contoso.local`, and expand `Corp_Users`.
* [ ] Take a screenshot showing your OUs (`Corp_Users`, `Engineering`, `Finance`, `HR`, `Tier0_Admins`, `Quarantine_Disabled`) and save it as `01_aduc_ou_hierarchy.png`.

> 📍 **Checkpoint:** `Get-ADOrganizationalUnit -Filter * | Select-Object Name` returns your 6 custom OUs, and your `.onmicrosoft.com` suffix is registered in `domain.msc`.
>
> **Interview Prep Question:** *Why do enterprise administrators create custom Organizational Units (OUs) like `Corp_Users` instead of leaving employee accounts in the built-in default `Users` folder in Active Directory?*
> *(Hint: Can you link a Group Policy Object (GPO) to the default `Users` container? Notice its icon in ADUC doesn't have the small book/GPO symbol on it!).*

---

## ▾ Part 2: Automate Bulk Onboarding with PowerShell ("Joiner" Workflow)

> ⏰ **~15 mins**
> Imagine HR sends you a spreadsheet of 5 new hires starting Monday morning. Clicking through the "New User" wizard 5 times is error-prone. You will now run your `Invoke-ADBulkOnboarding.ps1` script to provision all 5 employees, assign their cloud UPNs, and bind them to their departmental RBAC security groups in under 2 seconds.

* [ ] On your Domain Controller, create a folder at `C:\IAMLab` and save `new_hires.csv` and `Invoke-ADBulkOnboarding.ps1` (from the generated files in this workspace) into `C:\IAMLab`.
* [ ] Open `C:\IAMLab\new_hires.csv` in Notepad and inspect the 5 employees across `Engineering`, `Finance`, and `HR`.
* [ ] In your elevated PowerShell window, navigate to `C:\IAMLab` and run the bulk provisioning script (replace `yourtenant.onmicrosoft.com` with your actual Entra ID domain):
  ```powershell
  cd C:\IAMLab
  .\Invoke-ADBulkOnboarding.ps1 -CsvPath ".\new_hires.csv" -UpnSuffix "yourtenant.onmicrosoft.com"
  ```
* [ ] Verify the color-coded terminal output showing each user created, placed in their respective `OU=<Department>,OU=Corp_Users`, and added to `SG_<Department>`.
* [ ] Take a screenshot of the PowerShell terminal output alongside ADUC showing the newly created accounts, and save it as `02_powershell_bulk_provisioning.png`.

> 📍 **Checkpoint:** Run `Get-ADUser -Filter * -SearchBase "OU=Corp_Users,$((Get-ADDomain).DistinguishedName)" | Select Name, UserPrincipalName, Enabled` and confirm all 5 users exist with `@yourtenant.onmicrosoft.com` UPNs.
>
> **Interview Prep Question:** *Why do we assign file share and application permissions to a Security Group (like `SG_Finance`) and put users inside the group, rather than assigning permissions directly to individual user accounts?*
> *(Think about what happens when 20 people join or leave the Finance team).*

---

## ▾ Part 3: Configure Scoped Hybrid Sync with Microsoft Entra Connect

> ⏰ **~20 mins**
> Now bridge your on-premises Domain Controller to Microsoft Entra ID. Crucially, you will use **Custom Installation** to filter out `Tier0_Admins` and `Quarantine_Disabled` so privileged local admins and terminated accounts never replicate to the cloud.

* [ ] **Prepare Cloud Hybrid Admin Account:**
  * Log into the **Microsoft Entra Admin Center** (`https://entra.microsoft.com`).
  * Go to **Identity > Users > All users > New user > Create new user**.
  * Create a user named `syncadmin@yourtenant.onmicrosoft.com` and assign the role **Hybrid Identity Administrator**.
  * Open an Incognito browser window and log into `https://entra.microsoft.com` once as `syncadmin` to complete the initial password change and MFA prompt.
* [ ] **Enable TLS 1.2 & Download Microsoft Entra Connect on the Domain Controller:**
  * Run this snippet in PowerShell on your DC to ensure TLS 1.2 is enabled (required by Entra Connect):
    ```powershell
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    ```
  * Download the **Microsoft Entra Connect** installer (`AzureADConnect.msi`) from the Microsoft Download Center (`https://www.microsoft.com/en-us/download/details.aspx?id=47594`) and launch it.
* [ ] **Configure Custom Sync with OU Filtering:**
  * On the Welcome screen, agree to terms and click **Continue**.
  * **CRITICAL:** Do *not* click Express Settings. Click **Customize**.
  * Leave custom components unchecked and click **Install**.
  * **User Sign-In:** Check **Password Hash Synchronization** and check **Enable single sign-on** (Seamless SSO). Click **Next**.
  * **Connect to Microsoft Entra ID:** Enter your `syncadmin@yourtenant.onmicrosoft.com` credentials and click **Next**.
  * **Connect Your Directories:** Select `Active Directory` -> Click **Add Directory** -> Select **Create new AD account** -> Enter your local `CORP\Administrator` credentials -> Click **OK**, then **Next**.
  * **Microsoft Entra sign-in configuration:** Check **Continue without matching all UPN suffixes to verified domains** (if prompted) and click **Next**.
  * **Domain and OU Filtering (The Security Flex!):**
    * Select **Sync selected domains and OUs**.
    * Expand `corp.contoso.local`.
    * **Uncheck** everything *except* `Corp_Users` (and its child OUs `Engineering`, `Finance`, `HR`). Ensure `Tier0_Admins` and `Quarantine_Disabled` are **UNCHECKED**.
    * Take a screenshot of this exact wizard screen and save it as `03_entra_connect_ou_filtering.png`.
  * Click **Next** through Optional Features, enter your `CORP\Administrator` password for **Seamless SSO**, check **Start the synchronization process when configuration completes**, and click **Install**.
* [ ] Wait ~2 minutes, then refresh **Microsoft Entra Admin Center > Identity > Users > All users**.
* [ ] Verify that your 5 new hires appear in Entra ID with **On-premises sync enabled = Yes**!
* [ ] Take a screenshot of the Entra ID Users list and save it as `04_entra_portal_synced_users.png`.

> 📍 **Checkpoint:** All 5 corporate users appear in Entra ID, while your local `Administrator` account is excluded.
>
> **Interview Prep Question:** *What is the difference between **Password Hash Synchronization (PHS)** and **Pass-through Authentication (PTA)** in Microsoft Entra Connect?*
> *(Hint: With PHS, Entra ID validates a hash of the hash in the cloud—meaning users can still log into cloud apps even if your on-prem Domain Controller goes offline during a power outage!).*

---

## ▾ Part 4: Execute "Mover" and "Leaver" Admin Modifications

> ⏰ **~15 mins**
> Now prove to employers that you can handle day-to-day identity modification tickets securely: promoting/transferring an employee without causing privilege creep (**Mover**), and executing an emergency employee termination with instant cloud sync (**Leaver**).

### Ticket A: The "Mover" (Department Transfer & Least Privilege)
> **Scenario:** Ticket `INC004921` — *Marcus Vance (`marcus.vance`) has transferred from the Finance department to Engineering as a Cloud Systems Engineer. Update his directory profile, revoke Finance access, and grant Engineering access.*

* [ ] Run the following PowerShell commands on your Domain Controller to modify Marcus's attributes, swap his RBAC security groups, and move his AD object to the Engineering OU:
  ```powershell
  Import-Module ActiveDirectory
  $DomainDN = (Get-ADDomain).DistinguishedName

  # 1. Update Job Title & Department metadata
  Set-ADUser -Identity "marcus.vance" -Title "Cloud Systems Engineer" -Department "Engineering" -Description "Transferred from Finance to Engineering (Ticket INC004921)"

  # 2. Enforce Principle of Least Privilege: Remove old Finance group, add Engineering group
  Remove-ADGroupMember -Identity "SG_Finance" -Members "marcus.vance" -Confirm:$false
  Add-ADGroupMember -Identity "SG_Engineering" -Members "marcus.vance"

  # 3. Move AD Object to the Engineering OU
  Get-ADUser -Identity "marcus.vance" | Move-ADObject -TargetPath "OU=Engineering,OU=Corp_Users,$DomainDN"
  ```

### Ticket B: The "Leaver" (Emergency Offboarding & Quarantine)
> **Scenario:** Ticket `INC004955` — *URGENT HR Termination: Elena Rostova (`elena.rostova`) in HR is leaving the organization effective immediately. Disable her account, strip all group memberships, move to Quarantine, and immediately cut off Microsoft Entra ID cloud access.*

* [ ] Run the following PowerShell offboarding routine:
  ```powershell
  # 1. Disable the AD account immediately
  Disable-ADAccount -Identity "elena.rostova"

  # 2. Strip all non-primary Security Group memberships
  $UserGroups = Get-ADPrincipalGroupMembership -Identity "elena.rostova" | Where-Object { $_.Name -ne "Domain Users" }
  foreach ($Group in $UserGroups) {
      Remove-ADGroupMember -Identity $Group -Members "elena.rostova" -Confirm:$false
  }

  # 3. Stamp audit description and move to Quarantine_Disabled OU (outside Entra Connect sync scope!)
  $DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
  Set-ADUser -Identity "elena.rostova" -Description "DISABLED [$DateStamp] - HR Termination Ticket INC004955"
  Get-ADUser -Identity "elena.rostova" | Move-ADObject -TargetPath "OU=Quarantine_Disabled,$DomainDN"
  ```
* [ ] **Force an Immediate Cloud Delta Sync:** Instead of waiting 30 minutes for Entra Connect's scheduled timer, force an immediate synchronization cycle:
  ```powershell
  Import-Module ADSync
  Start-ADSyncSyncCycle -PolicyType Delta
  ```
* [ ] Wait 60 seconds, then check **Microsoft Entra Admin Center > Users > All users**:
  * Verify `Marcus Vance` now shows **Job title = Cloud Systems Engineer** and **Department = Engineering**.
  * Verify `Elena Rostova` has been **automatically removed** from active users (moved to **Deleted users**) because she was moved into the unsynced `Quarantine_Disabled` OU!
* [ ] Take a screenshot showing your PowerShell commands and the updated Entra ID user view, and save it as `05_jml_mover_leaver_audit.png`.

> 📍 **Checkpoint:** `Marcus Vance` only belongs to `SG_Engineering` (not `SG_Finance`), and `Elena Rostova` is disabled in `OU=Quarantine_Disabled` and deleted from active Entra ID users.
>
> **Interview Prep Question:** *Why did moving Elena Rostova into `OU=Quarantine_Disabled` automatically soft-delete her cloud account in Microsoft Entra ID?*
> *(Hint: Connect this back to the OU Filtering you configured in Part 3!).*

---

## ▾ Part 5: GPO Hardening & Event ID 4740 Lockout Forensics

> ⏰ **~15 mins**
> Account lockouts are one of the highest-volume tickets in IT Operations. You will now configure a Group Policy Object (GPO) to lock accounts after 3 bad passwords, trigger a real lockout, hunt down **Event ID 4740** in the Domain Controller Security Logs, and unlock the user.

* [ ] **Configure Account Lockout Policy via Group Policy Management:**
  * Open **Server Manager > Tools > Group Policy Management** (`gpmc.msc`).
  * Expand `Forest: corp.contoso.local > Domains > corp.contoso.local`.
  * Right-click **Default Domain Policy** and select **Edit**.
  * Navigate to **Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Account Lockout Policy**.
  * Configure the three settings:
    * **Account lockout duration:** `15 minutes`
    * **Account lockout threshold:** `3 invalid logon attempts`
    * **Reset account lockout counter after:** `15 minutes`
  * Close the GPO Editor and run `gpupdate /force` in PowerShell so the policy takes effect immediately.
* [ ] **Simulate a User Account Lockout (`david.chen`):**
  * In PowerShell, intentionally attempt to authenticate as `david.chen` three times with a bad password using `net use` against the local loopback share:
    ```powershell
    net use \\localhost\IPC$ /user:CORP\david.chen WrongPass1!
    net use \\localhost\IPC$ /user:CORP\david.chen WrongPass2!
    net use \\localhost\IPC$ /user:CORP\david.chen WrongPass3!
    ```
  * Verify the account is locked:
    ```powershell
    Get-ADUser -Identity "david.chen" -Properties LockedOut | Select-Object Name, LockedOut
    ```
    *(Confirm `LockedOut` is `True`!).*
* [ ] **Perform Event ID 4740 Security Log Forensics & Remediate:**
  * Query the Domain Controller Security Event Log for **Event ID 4740** (or open `eventvwr.msc` > **Windows Logs > Security** > **Filter Current Log** > Event ID `4740`):
    ```powershell
    Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4740} -MaxEvents 1 | Format-List TimeCreated, Id, Message
    ```
  * Notice the log message explicitly reveals the **Account Name (`david.chen`)** and the **Caller Computer Name** that caused the lockout!
  * Now unlock `david.chen`'s account via PowerShell and verify:
    ```powershell
    Unlock-ADAccount -Identity "david.chen"
    Get-ADUser -Identity "david.chen" -Properties LockedOut | Select-Object Name, LockedOut
    ```
* [ ] Take a screenshot showing the `Event ID 4740` output and your `Unlock-ADAccount` verification (`LockedOut = False`), and save it as `06_event_4740_lockout_forensics.png`.

> 📍 **Final Checkpoint:** You have completed the entire 4-Pillar Hybrid IAM lab! Commit your `README.md`, `SETUP_GUIDE.md`, `scripts/Invoke-ADBulkOnboarding.ps1`, `data/new_hires.csv`, and your 6 screenshots in `assets/` to your new GitHub repository (`hybrid-ad-entra-iam-lab`).