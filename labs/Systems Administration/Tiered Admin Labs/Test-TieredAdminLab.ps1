<#
.SYNOPSIS
  Self-check for the Tiered Admin Lab -- run on DC01 as a Domain Admin. Lab version 1.0.0

.DESCRIPTION
  Reports PASS / FAIL / SKIP for each control you are asked to build. It only READS -- it never
  changes anything. Use -Module to check just one module's work, or run it with no parameters
  for the whole scorecard.

  Failures tell you WHAT is missing, not how to fix it: that part is the lab.

.PARAMETER Module   1-8. Limits the checks to those relevant after that module (default: all).
.PARAMETER Quiet    Only print FAIL lines and the summary.

.EXAMPLE
  .\Test-TieredAdminLab.ps1
  .\Test-TieredAdminLab.ps1 -Module 3
#>
[CmdletBinding()]
param(
    [ValidateRange(1,8)][int]$Module = 8,
    [switch]$Quiet
)

Import-Module ActiveDirectory -ErrorAction Stop
$dn    = (Get-ADDomain).DistinguishedName
$realm = "OU=Realm,$dn"
$script:pass = 0; $script:fail = 0; $script:skip = 0

function Check {
    param([int]$M, [string]$Name, [scriptblock]$Test, [string]$Hint = '')
    if ($M -gt $Module) { return }
    try {
        $ok = & $Test
        if ($ok) { $script:pass++; if (-not $Quiet) { Write-Host ("  [PASS] M{0} {1}" -f $M,$Name) -ForegroundColor Green } }
        else     { $script:fail++; Write-Host ("  [FAIL] M{0} {1}" -f $M,$Name) -ForegroundColor Red; if ($Hint) { Write-Host "         hint: $Hint" -ForegroundColor DarkGray } }
    } catch {
        $script:skip++; Write-Host ("  [SKIP] M{0} {1}  ({2})" -f $M,$Name,$_.Exception.Message.Split("`n")[0]) -ForegroundColor DarkYellow
    }
}
function MembersOf($group) { @(Get-ADGroupMember -Identity $group -Recursive:$false -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName) }
function OuExists($path)   { [bool](Get-ADObject -SearchBase $path -SearchScope Base -Filter * -ErrorAction SilentlyContinue) }
function GpoReport($name)  { Get-GPOReport -Name $name -ReportType Xml -ErrorAction Stop }
function DenyRight($xml, $right, $who) {
    # Look inside the <UserRightsAssignment> block for this right and see if $who is listed.
    $m = [regex]::Match($xml, "(?s)<(?:\w+:)?Name>$right</(?:\w+:)?Name>(.*?)</(?:\w+:)?UserRightsAssignment>")
    return ($m.Success -and $m.Groups[1].Value -match [regex]::Escape($who))
}

Write-Host "`nTiered Admin Lab scorecard (through Module $Module)" -ForegroundColor Yellow

# ---------------- Module 3: structure ----------------
Check 3 'Tier sub-OUs exist (Admins, Groups under each tier)' {
    $need = 'Tier0','Tier1','Tier2' | ForEach-Object { $t = $_; 'Admins','Groups' | ForEach-Object { "OU=$_,OU=$t,$realm" } }
    -not ($need | Where-Object { -not (OuExists $_) })
} 'Create OU=Admins and OU=Groups under each of Tier0, Tier1, Tier2 in Realm.'
Check 3 'Asset OUs exist (Tier1\Servers, Tier2\Workstations, Tier2\Users)' {
    (OuExists "OU=Servers,OU=Tier1,$realm") -and (OuExists "OU=Workstations,OU=Tier2,$realm") -and (OuExists "OU=Users,OU=Tier2,$realm")
} 'Create the Servers, Workstations and Users OUs.'
Check 3 'Tier groups exist (T0-Admins, T1-Admins, T2-Admins)' {
    -not ('T0-Admins','T1-Admins','T2-Admins' | Where-Object { -not (Get-ADGroup -Filter "SamAccountName -eq '$_'" -ErrorAction SilentlyContinue) })
} 'Create three global security groups.'
Check 3 'Dedicated admin accounts exist (t0-vaultkeeper, t1-zelda, t2-navi)' {
    -not ('t0-vaultkeeper','t1-zelda','t2-navi' | Where-Object { -not (Get-ADUser -Filter "SamAccountName -eq '$_'" -ErrorAction SilentlyContinue) })
} 'One separate admin account per tier for each admin.'
Check 3 'Admin accounts are in their tier group' {
    ((MembersOf 'T0-Admins') -contains 't0-vaultkeeper') -and ((MembersOf 'T1-Admins') -contains 't1-zelda') -and ((MembersOf 'T2-Admins') -contains 't2-navi')
}
Check 3 'T0-Admins is nested in Domain Admins (the only route to Tier 0 rights)' { (MembersOf 'Domain Admins') -contains 'T0-Admins' } 'Add the T0-Admins group (not individual people) to Domain Admins.'
Check 3 'SRV01 is in Tier1\Servers and WKS01 in Tier2\Workstations' {
    $s = Get-ADComputer -Filter "Name -eq 'SRV01'"; $w = Get-ADComputer -Filter "Name -eq 'WKS01'"
    ($s.DistinguishedName -like "*OU=Servers,OU=Tier1,*") -and ($w.DistinguishedName -like "*OU=Workstations,OU=Tier2,*")
} 'Move the computer objects.'
# ---------------- Module 4: delegation ----------------
Check 4 'T2-Admins can reset passwords in Tier2\Users (delegation present)' {
    $acl = Get-Acl "AD:OU=Users,OU=Tier2,$realm"
    [bool]($acl.Access | Where-Object { $_.IdentityReference -match 'T2-Admins' })
} 'Delegate Reset Password on user objects in OU=Users,OU=Tier2.'

# ---------------- Module 5: logon restrictions ----------------
$gpoT2 = 'Tier2-Workstation-Restrictions'; $gpoT1 = 'Tier1-Server-Restrictions'; $gpoT0 = 'Tier0-DC-Logon-Restrictions'
foreach ($g in @(@{N=$gpoT2;P="OU=Workstations,OU=Tier2,$realm"}, @{N=$gpoT1;P="OU=Servers,OU=Tier1,$realm"}, @{N=$gpoT0;P="OU=Domain Controllers,$dn"})) {
    Check 5 "GPO '$($g.N)' exists and is linked to $($g.P.Split(',')[0..1] -join ',')" {
        $null = Get-GPO -Name $g.N -ErrorAction Stop
        (Get-GPInheritance -Target $g.P -ErrorAction Stop).GpoLinks | Where-Object { $_.DisplayName -eq $g.N -and $_.Enabled }
    } 'Create the GPO and link it to the right OU.'
}
$rights = 'SeDenyInteractiveLogonRight','SeDenyRemoteInteractiveLogonRight','SeDenyNetworkLogonRight','SeDenyBatchLogonRight','SeDenyServiceLogonRight'
Check 5 "$gpoT2 denies T0-Admins and T1-Admins all five logon types" {
    $x = GpoReport $gpoT2
    -not ($rights | Where-Object { -not ((DenyRight $x $_ 'T0-Admins') -and (DenyRight $x $_ 'T1-Admins')) })
} 'User Rights Assignment: the five "Deny ..." rights (interactive, RDP, network, batch, service).'
Check 5 "$gpoT1 denies T0-Admins and T2-Admins all five logon types" {
    $x = GpoReport $gpoT1
    -not ($rights | Where-Object { -not ((DenyRight $x $_ 'T0-Admins') -and (DenyRight $x $_ 'T2-Admins')) })
}
Check 5 "$gpoT0 denies T1-Admins and T2-Admins on DCs" {
    $x = GpoReport $gpoT0
    -not ($rights | Where-Object { -not ((DenyRight $x $_ 'T1-Admins') -and (DenyRight $x $_ 'T2-Admins')) })
}
Check 5 'Domain Admins is also denied on Tier 1 and Tier 2 computers' {
    (DenyRight (GpoReport $gpoT2) 'SeDenyInteractiveLogonRight' 'Domain Admins') -and (DenyRight (GpoReport $gpoT1) 'SeDenyInteractiveLogonRight' 'Domain Admins')
} 'The built-in Domain Admins group must be on the deny lists too.'
Check 5 'Local admin is delegated per tier (Local Users and Groups preference in the tier GPOs)' {
    $pat = '(?i)Administrators \(built-in\)|LocalUsersAndGroups|Local Users and Groups'
    $t2 = GpoReport $gpoT2; $t1 = GpoReport $gpoT1
    ($t2 -match $pat) -and ($t2 -match 'T2-Admins') -and ($t1 -match $pat) -and ($t1 -match 'T1-Admins')
} 'Group Policy Preferences > Control Panel Settings > Local Users and Groups: Update "Administrators (built-in)", add the tier group, remove Domain Admins.'

# ---------------- Module 6: credential protections ----------------
Check 6 't0-vaultkeeper is in Protected Users' { (MembersOf 'Protected Users') -contains 't0-vaultkeeper' } 'Add Tier 0 admin accounts to Protected Users.'
Check 6 't0-vaultkeeper is marked "sensitive and cannot be delegated"' {
    (Get-ADUser 't0-vaultkeeper' -Properties AccountNotDelegated).AccountNotDelegated
}
Check 6 'Fine-grained password policy PSO-Tier-Admins exists (min length 16+)' {
    $p = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Tier-Admins'"
    $p -and $p.MinPasswordLength -ge 16
}
Check 6 'PSO applies to all three tier groups' {
    $s = @(Get-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Tier-Admins' | Select-Object -ExpandProperty SamAccountName)
    -not ('T0-Admins','T1-Admins','T2-Admins' | Where-Object { $_ -notin $s })
}
Check 6 'Daily-driver accounts are no longer Domain Admins' {
    $da = MembersOf 'Domain Admins'
    -not ($da | Where-Object { $_ -in 'General_Graardor','Zelda_Warden','Navi','Vaultkeeper' })
} 'Remove the everyday accounts from Domain Admins (the t0- account takes over).'
Check 6 'Schema Admins has no members except the built-in Administrator' { -not ((MembersOf 'Schema Admins') | Where-Object { $_ -ne 'Administrator' }) } 'Schema Admins should be (nearly) empty except during a schema change.'
Check 6 'No leftover adminCount=1 on former admins' {
    -not (Get-ADUser -Filter "SamAccountName -eq 'Navi' -or SamAccountName -eq 'General_Graardor' -or SamAccountName -eq 'Zelda_Warden'" -Properties adminCount |
          Where-Object { $_.adminCount -eq 1 })
} 'Clear adminCount and re-enable ACL inheritance on former admins.'

Check 6 'svc-backup is not in any privileged group' {
    $priv = 'Domain Admins','Enterprise Admins','Schema Admins','Administrators','Account Operators','Backup Operators','Server Operators'
    -not ($priv | Where-Object { (MembersOf $_) -contains 'svc-backup' })
}

# ---------------- Module 7: detection ----------------
Check 7 'Logon + Security Group Management auditing enabled on this DC' {
    $a = (& auditpol.exe /get /subcategory:"Logon","Security Group Management") -join "`n"
    $a -match 'Success and Failure'
}

# ---------------- summary ----------------
Write-Host ''
$col = if ($script:fail -eq 0) { 'Green' } else { 'Yellow' }
Write-Host ("Result: {0} passed, {1} failed, {2} skipped" -f $script:pass,$script:fail,$script:skip) -ForegroundColor $col
if ($script:skip -gt 0) { Write-Host 'Skipped checks usually mean a prerequisite (OU, GPO, group) does not exist yet.' -ForegroundColor DarkGray }
