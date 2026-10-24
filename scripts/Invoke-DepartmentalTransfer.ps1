Import-Module ActiveDirectory

$DomainDN = (Get-ADDomain).DistinguishedName

# 1. Update Job Title & Departmental metadata
Set-ADUser -Identity "mvance" -Title "Cloud Systems Engineer" -Department "Engineering" -Description "Transferred from Finance to Engineering (Ticket INC004921)"

# 2. Enforce Principle of Least Privilege: Removing old Finance SG, replacing with Engineering
Remove-ADGroupMember -Identity "SG_Finance" -Members "mvance" -Confirm:$False
Add-ADGroupMember -Identity "SG_Engineering" -Members "mvance"

Get-ADUser -Identity "mvance" | Move-ADObject -TargetPath "OU=Engineering, OU=Corp_Users, $DomainDN"
