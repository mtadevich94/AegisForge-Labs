<#
.SYNOPSIS
  The Wrkstation Chronicles: Tiered Admin -- DC01 baseline setup.  Lab version 1.0.0

.DESCRIPTION
  Run as a Domain Admin in an elevated PowerShell on DC01 (the domain controller of gielinor.local).

  This script builds the "flat realm" the lab starts from. It is DELIBERATELY INSECURE:
    * Eight cast-member accounts in the default Users container (no tiering)
    * Several everyday accounts that are Domain Admins (the thing you will fix)
    * A Domain-Admin service account (svc-backup) with an SPN
    * Vaultkeeper in Schema Admins (that group should normally be empty)
    * A DNS record for SRV01 and advanced auditing turned on
    * The tier OU skeleton (Realm\Tier0, Tier1, Tier2, Staging) is created EMPTY for you to fill in

  It does NOT create the tier groups, the admin accounts (t0-/t1-/t2-), the GPOs, or any
  restrictions -- building those is the lab.

  Idempotent: safe to re-run. Use -Reset to put the flat-realm baseline back (it removes
  the lab's tier objects and re-creates the insecure group memberships).

  !! ISOLATED LAB ONLY. Weak-by-design accounts. Never run in a real domain. !!

.PARAMETER LabPassword
  Password given to every lab account. Must be 16+ characters (the lab later enforces that
  for admin accounts). Lab use only.

.PARAMETER Srv01IP
  The address SRV01 will use (the DNS A record is created for this).

.EXAMPLE
  Set-ExecutionPolicy -Scope Process Bypass -Force
  .\Setup-TieredAdminLab-DC01.ps1
#>
[CmdletBinding()]
param(
    [string]$LabPassword = 'Gielinor!Lab#2026',
    [string]$Srv01IP     = '10.10.10.40',
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'
function Say($m)  { Write-Host "[tiered-admin] $m" -ForegroundColor Yellow }
function Good($m) { Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [WARN] $m" -ForegroundColor DarkYellow }
function Bad($m)  { Write-Host "  [FAIL] $m" -ForegroundColor Red }

# --- sanity checks ---------------------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Bad 'Run this from an elevated (Administrator) PowerShell window.'; exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop
try { $domain = Get-ADDomain } catch { Bad 'This does not look like a domain controller (Get-ADDomain failed).'; exit 1 }
if ($domain.DNSRoot -ne 'gielinor.local') {
    Warn "Domain is '$($domain.DNSRoot)', not gielinor.local. Continuing, but the guide uses gielinor.local / GIELINOR\."
}
$dn      = $domain.DistinguishedName          # e.g. DC=gielinor,DC=local
$netbios = $domain.NetBIOSName                # e.g. GIELINOR
$secPw   = ConvertTo-SecureString $LabPassword -AsPlainText -Force
$labDir  = 'C:\GielinorTiered'
New-Item -ItemType Directory -Force -Path $labDir | Out-Null

# --- optional reset -----------------------------------------------------------------------
if ($Reset) {
    Say 'RESET: removing tier objects and restoring the flat-realm baseline...'
    foreach ($gpo in 'Tier0-DC-Logon-Restrictions','Tier1-Server-Restrictions','Tier2-Workstation-Restrictions') {
        if (Get-Command Get-GPO -ErrorAction SilentlyContinue) {
            try { Remove-GPO -Name $gpo -ErrorAction Stop; Good "Removed GPO $gpo" } catch {}
        }
    }
    foreach ($u in 't0-vaultkeeper','t1-zelda','t2-navi') {
        Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue | Remove-ADUser -Confirm:$false
    }
    foreach ($g in 'T0-Admins','T1-Admins','T2-Admins') {
        Get-ADGroup -Filter "SamAccountName -eq '$g'" -ErrorAction SilentlyContinue | Remove-ADGroup -Confirm:$false
    }
    Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Tier-Admins'" -ErrorAction SilentlyContinue | Remove-ADFineGrainedPasswordPolicy -Confirm:$false
    # Put cast users back in the default container
    foreach ($c in 'Vaultkeeper','General_Graardor','Zelda_Warden','Navi','Bandit','Princess_Irulan','Kerbe','DAME','svc-backup','svc-web') {
        $u = Get-ADUser -Filter "SamAccountName -eq '$c'" -ErrorAction SilentlyContinue
        if ($u -and $u.DistinguishedName -notlike "*CN=Users,$dn") { Move-ADObject -Identity $u.DistinguishedName -TargetPath "CN=Users,$dn" }
    }
    foreach ($ou in 'Tier0','Tier1','Tier2') {
        Get-ADOrganizationalUnit -SearchBase "OU=Realm,$dn" -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue |
            ForEach-Object { Set-ADOrganizationalUnit $_ -ProtectedFromAccidentalDeletion $false } 
    }
    # Move computers back to default container so they can be re-sorted
    foreach ($c in 'SRV01','WKS01') {
        $o = Get-ADComputer -Filter "Name -eq '$c'" -ErrorAction SilentlyContinue
        if ($o -and $o.DistinguishedName -notlike "*CN=Computers,$dn") { Move-ADObject $o.DistinguishedName -TargetPath "CN=Computers,$dn" }
    }
    Get-ADOrganizationalUnit -Filter "Name -eq 'Realm'" -SearchBase $dn -SearchScope OneLevel -ErrorAction SilentlyContinue |
        ForEach-Object {
            Set-ADOrganizationalUnit $_ -ProtectedFromAccidentalDeletion $false
            Get-ADObject -SearchBase $_.DistinguishedName -Filter * -SearchScope Subtree |
                Where-Object { $_.ObjectClass -eq 'organizationalUnit' } |
                ForEach-Object { Set-ADObject $_ -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue }
            Remove-ADOrganizationalUnit -Identity $_.DistinguishedName -Recursive -Confirm:$false
        }
    Good 'Reset done. Continuing with a fresh baseline build...'
}

# --- GPMC / RSAT -----------------------------------------------------------------------------
Say 'Step 1/6: management tools'
foreach ($f in 'GPMC','RSAT-AD-PowerShell','RSAT-ADDS-Tools','RSAT-DNS-Server') {
    try { $r = Install-WindowsFeature -Name $f -ErrorAction Stop; if ($r.Success) { Good "$f ready" } } catch { Warn "Could not verify feature ${f}: $($_.Exception.Message)" }
}

# --- DNS record for SRV01 ----------------------------------------------------------------------
Say 'Step 2/6: DNS record for SRV01'
try {
    Import-Module DnsServer -ErrorAction Stop
    $zone = $domain.DNSRoot
    $rec = Get-DnsServerResourceRecord -ZoneName $zone -Name 'srv01' -RRType A -ErrorAction SilentlyContinue
    if (-not $rec) {
        Add-DnsServerResourceRecordA -ZoneName $zone -Name 'srv01' -IPv4Address $Srv01IP
        Good "Created A record srv01.$zone -> $Srv01IP"
    } else { Good "A record for srv01 already exists ($($rec.RecordData.IPv4Address))" }
} catch { Warn "DNS record not created: $($_.Exception.Message)" }

# --- OU skeleton -----------------------------------------------------------------------------------
Say 'Step 3/6: OU skeleton (empty tiers for you to fill)'
function Ensure-OU($name, $path) {
    $existing = Get-ADOrganizationalUnit -SearchBase $path -SearchScope OneLevel -Filter "Name -eq '$name'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false
        Good "Created OU=$name,$path"
    }
}
Ensure-OU 'Realm' $dn
$realm = "OU=Realm,$dn"
foreach ($t in 'Tier0','Tier1','Tier2','Staging') { Ensure-OU $t $realm }
# NOTE: sub-OUs (Admins, Groups, Servers, Workstations, Users...) are built by the learner in Module 3.

# --- cast accounts ----------------------------------------------------------------------------------
Say 'Step 4/6: the flat realm (cast accounts + deliberate mistakes)'
$cast = @(
    @{ Sam='Vaultkeeper';     Name='Vaultkeeper';      Desc='Keeper of the Citadel. Has every key.' }
    @{ Sam='General_Graardor';Name='General Graardor'; Desc='Server warlord. Does everything as Domain Admin.' }
    @{ Sam='Zelda_Warden';    Name='Zelda Warden';     Desc='Server warden for the Keep.' }
    @{ Sam='Navi';            Name='Navi';             Desc='Help desk. Resets passwords and fixes PCs.' }
    @{ Sam='Bandit';          Name='Bandit';           Desc='Ordinary villager.' }
    @{ Sam='Princess_Irulan'; Name='Princess Irulan';  Desc='Executive. Prime phishing target.' }
    @{ Sam='Kerbe';           Name='Kerbe';            Desc='Ordinary villager.' }
    @{ Sam='DAME';            Name='DAME';             Desc='Ordinary villager.' }
)
foreach ($c in $cast) {
    $u = Get-ADUser -Filter "SamAccountName -eq '$($c.Sam)'" -ErrorAction SilentlyContinue
    if (-not $u) {
        New-ADUser -Name $c.Name -SamAccountName $c.Sam -UserPrincipalName "$($c.Sam)@$($domain.DNSRoot)" `
            -DisplayName $c.Name -Description $c.Desc -Path "CN=Users,$dn" `
            -AccountPassword $secPw -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false
        Good "Created user $($c.Sam)"
    } else {
        Set-ADAccountPassword -Identity $u -Reset -NewPassword $secPw
        Enable-ADAccount -Identity $u
    }
}

# service accounts
foreach ($svc in @(
    @{ Sam='svc-backup'; Desc='Nightly backup job on SRV01. (Domain Admin "so the job never fails".)'; Spn='MSSQLSvc/srv01.gielinor.local:1433' },
    @{ Sam='svc-web';    Desc='Intranet web app pool identity on SRV01.';                              Spn='HTTP/srv01.gielinor.local' }
)) {
    $u = Get-ADUser -Filter "SamAccountName -eq '$($svc.Sam)'" -ErrorAction SilentlyContinue
    if (-not $u) {
        New-ADUser -Name $svc.Sam -SamAccountName $svc.Sam -UserPrincipalName "$($svc.Sam)@$($domain.DNSRoot)" `
            -Description $svc.Desc -Path "CN=Users,$dn" -AccountPassword $secPw -Enabled $true `
            -PasswordNeverExpires $true -ChangePasswordAtLogon $false
        Good "Created service account $($svc.Sam)"
    }
    try { Set-ADUser -Identity $svc.Sam -ServicePrincipalNames @{ Add = $svc.Spn } } catch { }
}

# the deliberate mistakes ------------------------------------------------------------------------------
$flaws = @{
    'Domain Admins'     = @('Vaultkeeper','General_Graardor','Zelda_Warden','Navi','svc-backup')
    'Enterprise Admins' = @('Vaultkeeper')
    'Schema Admins'     = @('Vaultkeeper')
}
foreach ($grp in $flaws.Keys) {
    foreach ($m in $flaws[$grp]) {
        try { Add-ADGroupMember -Identity $grp -Members $m -ErrorAction Stop; Good "$m -> $grp  (intentional flaw)" }
        catch { if ($_.Exception.Message -notmatch 'already a member') { Warn "$m / ${grp}: $($_.Exception.Message)" } }
    }
}

# --- auditing -------------------------------------------------------------------------------------------
Say 'Step 5/6: advanced auditing (so the lab has events to read)'
$audit = @('Logon','Logoff','Special Logon','Credential Validation','Kerberos Authentication Service','Kerberos Service Ticket Operations','Security Group Management','User Account Management')
foreach ($sub in $audit) {
    & auditpol.exe /set /subcategory:"$sub" /success:enable /failure:enable | Out-Null
}
Good 'Audit subcategories enabled (Logon, Special Logon, Kerberos, group management, ...)'

# --- lab notes file -------------------------------------------------------------------------------------
Say 'Step 6/6: lab notes'
@"
Tiered Admin Lab -- accounts (all share the lab password you passed to the script)
Domain: $($domain.DNSRoot)   NetBIOS: $netbios

Cast accounts (flat baseline):
  Vaultkeeper        Domain Admins + Enterprise Admins + Schema Admins
  General_Graardor   Domain Admins
  Zelda_Warden       Domain Admins
  Navi               Domain Admins
  svc-backup         Domain Admins (service account, has an SPN)
  svc-web            ordinary service account (SPN)
  Bandit, Princess_Irulan, Kerbe, DAME   ordinary users

OU skeleton:  OU=Realm\{Tier0, Tier1, Tier2, Staging}  (empty -- you fill it in)

Next: join SRV01 (and confirm WKS01) to the domain, run Setup-TieredAdminLab-Member.ps1 on each,
then snapshot all three VMs as 'tiered-baseline'. Start the Lab Guide at Module 1.
"@ | Set-Content -Path "$labDir\README-lab-accounts.txt" -Encoding UTF8
Good "Wrote $labDir\README-lab-accounts.txt"

Write-Host ''
Say 'DC01 baseline ready.'
Say 'Next: build/join SRV01, run Setup-TieredAdminLab-Member.ps1 on SRV01 and WKS01, then snapshot all three VMs.'
