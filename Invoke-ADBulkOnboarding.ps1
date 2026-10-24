<#
.SYNOPSIS
    Automates bulk AD user provisioning for the Hybrid IAM Lab.
.DESCRIPTION
    Reads a CSV dataset from HR, ensures departmental OUs and Security Groups exist,
    and generates AD accounts with standardized UPNs ready for Entra ID sync.
#>

$CSVPath = "C:\Lab\data\new_hires.csv"
$UPNSuffix = "hossainlab.onmicrosoft.com"
$DomainDN = (Get-ADDomain).DistinguishedName
$BaseOU = "OU=Corp_Users,$DomainDN"
$DefaultPassword = ConvertTo-SecureString "Password123!" -AsPlainText -Force

# 1. Ensure the Base OU exists
if (!(Get-ADOrganizationalUnit -Filter "Name -eq 'Corp_Users'")) {
    New-ADOrganizationalUnit -Name "Corp_Users" -Path $DomainDN
    Write-Host "Created Base OU: Corp_Users" -ForegroundColor Green
}

# 2. Import the HR Data
$NewHires = Import-Csv -Path $CSVPath

foreach ($User in $NewHires) {
    $SAM = "$($User.FirstName.Substring(0,1).ToLower())$($User.LastName.ToLower())"
    $UPN = "$($User.FirstName.ToLower()).$($User.LastName.ToLower())@$UPNSuffix"
    $DeptOU = "OU=$($User.Department),$BaseOU"
    $GroupName = "SG_$($User.Department)"

    # 3. Ensure Department OU Exists
    if (!(Get-ADOrganizationalUnit -Filter "Name -eq '$($User.Department)'" -SearchBase $BaseOU)) {
        New-ADOrganizationalUnit -Name $User.Department -Path $BaseOU
        Write-Host "Created OU: $($User.Department)" -ForegroundColor Green
    }

    # 4. Ensure Department Security Group Exists
    if (!(Get-ADGroup -Filter "Name -eq '$GroupName'")) {
        New-ADGroup -Name $GroupName -GroupCategory Security -GroupScope Global -Path $DeptOU
        Write-Host "Created Group: $GroupName" -ForegroundColor Green
    }

    # 5. Create the User Account
    if (!(Get-ADUser -Filter "SamAccountName -eq '$SAM'")) {
        $UserParams = @{
            SamAccountName        = $SAM
            UserPrincipalName     = $UPN
            Name                  = "$($User.FirstName) $($User.LastName)"
            GivenName             = $User.FirstName
            Surname               = $User.LastName
            DisplayName           = "$($User.FirstName) $($User.LastName)"
            Department            = $User.Department
            Title                 = $User.JobTitle
            Path                  = $DeptOU
            AccountPassword       = $DefaultPassword
            Enabled               = $true
            PasswordNeverExpires  = $true
        }
        
        New-ADUser @UserParams
        Add-ADGroupMember -Identity $GroupName -Members $SAM
        
        Write-Host "Successfully onboarded: $UPN" -ForegroundColor Cyan
    } else {
        Write-Host "User $SAM already exists. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Bulk onboarding complete!" -ForegroundColor Green