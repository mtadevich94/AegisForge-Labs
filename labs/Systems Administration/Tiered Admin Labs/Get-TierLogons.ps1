<#
.SYNOPSIS
  Pull logon-related Security events from a machine and show them as tidy objects. Lab version 1.0.0

.DESCRIPTION
  Wraps Get-WinEvent so you can answer "WHO logged on to WHERE, HOW, and what happened?"
  Run it from DC01 against SRV01 / WKS01, or run it locally with -ComputerName localhost.

  Common event IDs:
    4624  successful logon          (LogonType: 2 console, 3 network, 4 batch, 5 service, 10 RDP, ...)
    4625  failed logon              (SubStatus 0xC000015B = "not granted the requested logon type" -> a Deny right worked)
    4672  special privileges assigned to a new logon (an admin-level logon)
    4768/4769  Kerberos TGT / service ticket requests (run against a DC)
    4728/4732/4756  member added to a security-enabled group (global / local / universal)

.PARAMETER ComputerName   Target machine (FQDN recommended -> Kerberos).
.PARAMETER Credential     Credential with rights to read that machine's Security log (e.g. a Tier-appropriate admin).
.PARAMETER Id             Event ID(s). Default 4624.
.PARAMETER Max            Maximum events per ID. Default 100.
.PARAMETER User           Only show events whose account name matches this wildcard (e.g. 'Navi', 't0-*').
.PARAMETER HideMachineAccounts  Hides noisy computer ($) and SYSTEM-type accounts.

.EXAMPLE
  .\Get-TierLogons.ps1 -ComputerName wks01.gielinor.local -Id 4624 -Max 200 -HideMachineAccounts |
      Where-Object LogonType -in 2,4,10 | Format-Table -Auto
#>
[CmdletBinding()]
param(
    [string]$ComputerName = 'localhost',
    [System.Management.Automation.PSCredential]$Credential,
    [int[]]$Id = 4624,
    [int]$Max = 100,
    [string]$User = '*',
    [switch]$HideMachineAccounts
)

$logonTypeNames = @{ '2'='2 Interactive'; '3'='3 Network'; '4'='4 Batch'; '5'='5 Service'; '7'='7 Unlock'; '8'='8 NetworkCleartext'; '9'='9 NewCredentials'; '10'='10 RemoteInteractive'; '11'='11 CachedInteractive' }

$block = {
    param($ids, $max)
    foreach ($eid in $ids) {
        try {
            Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = $eid } -MaxEvents $max -ErrorAction Stop |
                ForEach-Object {
                    $d = @{}
                    ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }
                    [pscustomobject]@{
                        Time      = $_.TimeCreated
                        EventId   = $_.Id
                        Account   = if ($d.TargetUserName) { $d.TargetUserName } else { $d.SubjectUserName }
                        Domain    = if ($d.TargetDomainName) { $d.TargetDomainName } else { $d.SubjectDomainName }
                        LogonType = $d.LogonType
                        Status    = $d.Status
                        SubStatus = $d.SubStatus
                        SourceIP  = $d.IpAddress
                        SourceWS  = $d.WorkstationName
                        Process   = $d.ProcessName
                    }
                }
        } catch {
            if ($_.Exception.Message -notmatch 'No events were found') { Write-Warning "ID ${eid}: $($_.Exception.Message)" }
        }
    }
}

$results = if ($ComputerName -in 'localhost','.',$env:COMPUTERNAME) {
    & $block $Id $Max
} else {
    $icm = @{ ComputerName = $ComputerName; ScriptBlock = $block; ArgumentList = @($Id, $Max) }
    if ($Credential) { $icm.Credential = $Credential }
    Invoke-Command @icm
}

$results |
    Where-Object { $_.Account -like $User } |
    Where-Object { -not $HideMachineAccounts -or ($_.Account -notmatch '\$$' -and $_.Account -notin 'SYSTEM','LOCAL SERVICE','NETWORK SERVICE','ANONYMOUS LOGON' -and $_.Account -notmatch '^(DWM|UMFD)-') } |
    Select-Object Time, EventId, Account, Domain,
        @{ n='LogonType'; e={ if ($_.LogonType -and $logonTypeNames[$_.LogonType]) { $logonTypeNames[$_.LogonType] } else { $_.LogonType } } },
        Status, SubStatus, SourceIP, SourceWS |
    Sort-Object Time -Descending
