<#
.SYNOPSIS
  Simulates a "lazy admin day" so Module 1 has real events to investigate.  Lab version 1.0.0

.DESCRIPTION
  Run on DC01 as a Domain Admin AFTER SRV01 and WKS01 are domain-joined and prepped.
  Each privileged account connects to SRV01 and WKS01 over PowerShell remoting. That
  produces Event 4624 (network logon) and Event 4672 (special privileges) on those machines --
  showing Domain Admin accounts touching Tier 1 and Tier 2 computers.

  (Interactive / RDP logons -- the kind that leave reusable credentials behind -- you will
  create yourself in Module 1, because they need a human at a keyboard.)

  Safe to re-run; it only runs `hostname` remotely.
#>
[CmdletBinding()]
param(
    [string]$LabPassword = 'Gielinor!Lab#2026',
    [string]$NetBios     = 'GIELINOR',
    [string[]]$Accounts  = @('General_Graardor','Zelda_Warden','Navi','Vaultkeeper'),
    [string[]]$Targets   = @('wks01.gielinor.local','srv01.gielinor.local')
)
$pw = ConvertTo-SecureString $LabPassword -AsPlainText -Force
foreach ($acct in $Accounts) {
    $cred = New-Object System.Management.Automation.PSCredential("$NetBios\$acct", $pw)
    foreach ($t in $Targets) {
        try {
            $h = Invoke-Command -ComputerName $t -Credential $cred -ScriptBlock { hostname } -ErrorAction Stop
            Write-Host ("[ OK ] {0,-18} -> {1,-24} ({2})" -f $acct, $t, $h) -ForegroundColor Green
        } catch {
            Write-Host ("[FAIL] {0,-18} -> {1,-24} {2}" -f $acct, $t, $_.Exception.Message.Split("`n")[0]) -ForegroundColor DarkYellow
        }
    }
}
Write-Host "`nDone. Now go and look at what those machines recorded (Module 1)." -ForegroundColor Yellow
