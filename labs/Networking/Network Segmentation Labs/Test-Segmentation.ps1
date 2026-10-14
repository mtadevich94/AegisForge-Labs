<#
.SYNOPSIS
  The Wrkstation Chronicles: The Gatehouse -- segmentation test matrix (Windows / Garrison).

.DESCRIPTION
  Tries a list of TCP connections from WKS01 and compares what happened with what your
  firewall policy is SUPPOSED to allow. Plain connection attempts only.

  Results:
    OPEN     the connection completed          -> the firewall let it through
    DROPPED  silence until the timeout         -> silently discarded (rule action: Block)
    REFUSED  an instant "connection refused"   -> answered with a reset (rule action: Reject)
    NODNS    the name could not be resolved
  "Denied" in the expectation means DROPPED or REFUSED.

.PARAMETER Profile
  flat      Module 1 - the open field (everything OPEN)
  policy    Modules 3-5 - the zone policy in force   (default)
  mgmt      after Module 6 - management plane locked down
  hardened  after Module 7 - egress and DNS control too

.PARAMETER OutIp
  The "outside" host, WATCHTOWER. Default 10.10.10.30.

.PARAMETER TimeoutMs
  How long to wait before calling a connection DROPPED. Default 3000.

.EXAMPLE
  .\Test-Segmentation.ps1 -Profile flat
  .\Test-Segmentation.ps1 -Profile policy

.NOTES
  Lab version 1.0.0. Read-only: it makes connection attempts and prints a table.
#>
[CmdletBinding()]
param(
  [ValidateSet('flat','policy','mgmt','hardened')]
  [string]$Profile = 'policy',
  [string]$OutIp = '10.10.10.30',
  [int]$TimeoutMs = 3000
)

$ErrorActionPreference = 'Stop'

# test label, host, port, expectations for flat/policy/mgmt/hardened  (O = open, D = denied)
$matrix = @(
  @('Firewall DNS (Garrison address)',                '10.20.10.1',         53,  'O','O','O','O'),
  @('Firewall web GUI from the Garrison',             '10.20.10.1',         443, 'O','O','D','D'),
  @('WEB01 public site :80',                          '10.20.20.10',        80,  'O','O','O','O'),
  @('WEB01 public site :443',                         '10.20.20.10',        443, 'O','O','O','O'),
  @('WEB01 SSH',                                      '10.20.20.10',        22,  'O','D','D','D'),
  @('WEB01 admin panel :8080',                        '10.20.20.10',        8080,'O','D','D','D'),
  @('ADM01 SSH (Citadel) - admin jump host',          '10.20.30.10',        22,  'O','D','O','O'),
  @('ADM01 ledger :80 (Citadel)',                     '10.20.30.10',        80,  'O','D','D','D'),
  @('ADM01 ops dashboard :8080 (Citadel)',            '10.20.30.10',        8080,'O','D','D','D'),
  @('WATCHTOWER web (outside host)',                  $OutIp,               80,  'O','O','O','O'),
  @('WATCHTOWER FTP (outside host)',                  $OutIp,               21,  'O','D','D','D'),
  @('WATCHTOWER SSH (outside host)',                  $OutIp,               22,  'O','D','D','D'),
  @('Public internet HTTPS (1.1.1.1)',                '1.1.1.1',            443, 'O','O','O','O'),
  @('Public DNS-over-TLS (1.1.1.1)',                  '1.1.1.1',            853, 'O','D','D','D')
)

$col = switch ($Profile) { 'flat' { 3 } 'policy' { 4 } 'mgmt' { 5 } 'hardened' { 6 } }
$ipPattern = '^\d{1,3}(\.\d{1,3}){3}$'

function Test-TcpPort {
  param([string]$Target, [int]$Port, [int]$Ms)
  if ($Target -notmatch $ipPattern) {
    try { [void][System.Net.Dns]::GetHostAddresses($Target) } catch { return 'NODNS' }
  }
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $task = $client.ConnectAsync($Target, $Port)
    if ($task.Wait($Ms)) {
      if ($client.Connected) { return 'OPEN' } else { return 'REFUSED' }
    }
    return 'DROPPED'
  }
  catch { return 'REFUSED' }     # an instant error (connection refused / unreachable)
  finally { $client.Close() }
}

Write-Host ("Segmentation test  role=lan(WKS01)  profile={0}  timeout={1} ms  ({2})" -f $Profile, $TimeoutMs, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor White
$ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '10.20.10.*' }).IPAddress
if (-not $ips) {
  Write-Host 'WARNING: this machine has no 10.20.10.x address. Is WKS01 on the Garrison network and did DHCP work?' -ForegroundColor Yellow
}
'{0,-42} {1,-16} {2,-6} {3,-9} {4,-9} {5}' -f 'TEST','TARGET','PORT','EXPECT','RESULT','VERDICT'
('-' * 100)

$pass = 0; $fail = 0
foreach ($row in $matrix) {
  $label = $row[0]; $target = $row[1]; $port = [int]$row[2]; $exp = $row[$col]
  $res = Test-TcpPort -Target $target -Port $port -Ms $TimeoutMs
  $want = if ($exp -eq 'O') { 'OPEN' } else { 'Denied' }
  $good = ($exp -eq 'O' -and $res -eq 'OPEN') -or ($exp -eq 'D' -and ($res -eq 'DROPPED' -or $res -eq 'REFUSED'))
  if ($good) { $pass++; $v = 'PASS'; $c = 'Green' } else { $fail++; $v = 'FAIL'; $c = 'Red' }
  Write-Host ('{0,-42} {1,-16} {2,-6} {3,-9} {4,-9} ' -f $label, $target, $port, $want, $res) -NoNewline
  Write-Host $v -ForegroundColor $c
}

Write-Host ''
Write-Host ("Result: {0} passed, {1} failed." -f $pass, $fail) -ForegroundColor White
if ($fail -gt 0) {
  Write-Host "Read the FAIL rows: 'expected Denied but OPEN' means a rule is too loose;" -ForegroundColor Yellow
  Write-Host "'expected OPEN but DROPPED/REFUSED' means a rule is missing or in the wrong order." -ForegroundColor Yellow
  exit 1
}
exit 0
