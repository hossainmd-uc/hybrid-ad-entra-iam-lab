# 1. Disable AD account immediately
Disable-ADAccount -Identity "erostova"

# 2. Strip all non-primary Security Group memberships
$UserGroups = Get-ADPrincipalGroupMembership -Identity "erostova" | Where-Object {$_.Name -ne "Domain Users"}

foreach ($Group in $UserGroups) {
    Remove-ADGroupMember -Identity $Group -Members "erostova" -Confirm:$False
}


# 3. Stamp audit description and move to Quarantine_Disabled OU (outside Entra Connect sync scope!)
$DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Set-ADUser -Identity "erostova" -Description "DISABLED [$DateStamp] - HR Termination Ticket INC004955"
Get-ADUser -Identity "erostova" | Move-ADObject -TargetPath "OU=Quarantine_Disabled,$DomainDN"