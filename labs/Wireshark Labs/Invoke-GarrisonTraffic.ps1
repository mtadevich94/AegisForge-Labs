<#
.SYNOPSIS
  The Wrkstation Chronicles: Packet Watch -- live traffic generator for WKS01. Lab version 1.0.0

.DESCRIPTION
  Generates *real* network traffic between WKS01 and the Watchtower server so you can capture
  it in Wireshark. Start your capture first, run a module, then stop the capture.

  -Module Warmup    DNS lookups, ping, one plain HTTP request          (Modules 1-3)
  -Module WebLogin  HTTP login to the intranet portal (plaintext POST) (Module 4)
  -Module Ftp       FTP login + directory listing + file download      (Module 5)
  -Module Tls       HTTPS visit to the portal (self-signed cert)       (Module 6)
  -Module Sweep     Quick TCP connect sweep of ports 1-1024            (Module 7 stretch)
  -Module All       Run Warmup, WebLogin, Ftp, Tls in order
  -Noise            Loop forever generating background chatter (Ctrl+C to stop)

  Everything here only talks to the lab server. Lab VM use only.

.EXAMPLE
  .\Invoke-GarrisonTraffic.ps1 -Module WebLogin
  .\Invoke-GarrisonTraffic.ps1 -Module Ftp
  .\Invoke-GarrisonTraffic.ps1 -Noise
#>
[CmdletBinding()]
param(
    [ValidateSet('Warmup','WebLogin','Ftp','Tls','Sweep','All')]
    [string]$Module,
    [switch]$Noise,
    [string]$ServerName = 'watchtower.gielinor.local',
    [string]$ServerIP   = '10.10.10.30',
    [string]$User       = 'Navi',
    [string]$Password   = 'Hey-Listen!2026'
)

$ErrorActionPreference = 'Continue'
function Say($m) { Write-Host "[traffic] $m" -ForegroundColor Yellow }

function Invoke-Warmup {
    Say 'DNS lookups...'
    foreach ($n in $ServerName, 'www.professormesser.com', 'tryhackme.com') {
        try { Resolve-DnsName $n -Type A -DnsOnly -ErrorAction Stop | Out-Null } catch {}
    }
    try { Resolve-DnsName "wizard-tower-backup.gielinor.local" -Type A -DnsOnly -ErrorAction Stop | Out-Null } catch {}   # NXDOMAIN on purpose
    Say 'ping...'
    Test-Connection -ComputerName $ServerName -Count 4 | Out-Null
    Say 'one plain HTTP request...'
    try { Invoke-WebRequest -Uri "http://$ServerName/" -UseBasicParsing | Out-Null } catch {}
}

function Invoke-WebLogin {
    Say "Logging in to http://$ServerName/login as $User (plaintext POST)..."
    $sess = $null
    try {
        Invoke-WebRequest -Uri "http://$ServerName/login" -UseBasicParsing -SessionVariable sess | Out-Null
        Start-Sleep -Seconds 2
        Invoke-WebRequest -Uri "http://$ServerName/login" -Method Post -WebSession $sess -UseBasicParsing `
            -Body @{ username = $User; password = $Password } | Out-Null
        Invoke-WebRequest -Uri "http://$ServerName/dashboard" -WebSession $sess -UseBasicParsing | Out-Null
        Say 'Login traffic sent.'
    } catch { Say "Web request problem: $($_.Exception.Message)" }
}

function Invoke-FtpSession {
    $cred = New-Object Net.NetworkCredential('vaultkeeper', 'Ph0enix-Ash#42')
    Say 'FTP: listing the vaultkeeper home directory...'
    try {
        $req = [Net.FtpWebRequest]::Create("ftp://$ServerName/")
        $req.Method = [Net.WebRequestMethods+Ftp]::ListDirectory
        $req.Credentials = $cred; $req.UsePassive = $true; $req.EnableSsl = $false; $req.KeepAlive = $false
        $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream())
        $sr.ReadToEnd() | Write-Host; $sr.Close(); $resp.Close()
    } catch { Say "FTP list problem: $($_.Exception.Message)" }
    Say 'FTP: downloading vault-notes.txt...'
    try {
        $req = [Net.FtpWebRequest]::Create("ftp://$ServerName/vault-notes.txt")
        $req.Method = [Net.WebRequestMethods+Ftp]::DownloadFile
        $req.Credentials = $cred; $req.UsePassive = $true; $req.EnableSsl = $false; $req.KeepAlive = $false
        $resp = $req.GetResponse(); $sr = New-Object IO.StreamReader($resp.GetResponseStream())
        $text = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
        Say "Downloaded $($text.Length) characters (open your capture to see what was inside!)."
    } catch { Say "FTP download problem: $($_.Exception.Message)" }
}

function Invoke-TlsVisit {
    Say "HTTPS visit to https://$ServerName/ (self-signed cert -- we tell PowerShell to accept it)..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        $sess = $null
        Invoke-WebRequest -Uri "https://$ServerName/login" -UseBasicParsing -SessionVariable sess | Out-Null
        Invoke-WebRequest -Uri "https://$ServerName/login" -Method Post -WebSession $sess -UseBasicParsing `
            -Body @{ username = $User; password = $Password } | Out-Null
        Say 'HTTPS traffic sent.'
    } catch { Say "HTTPS problem: $($_.Exception.Message)" }
    finally { [Net.ServicePointManager]::ServerCertificateValidationCallback = $null }
}

function Invoke-Sweep {
    Say "TCP connect sweep of $ServerIP ports 1-1024 (about 30-60 seconds)..."
    $open = @()
    foreach ($p in 1..1024) {
        $t = New-Object Net.Sockets.TcpClient
        try {
            $iar = $t.BeginConnect($ServerIP, $p, $null, $null)
            if ($iar.AsyncWaitHandle.WaitOne(80) -and $t.Connected) { $open += $p }
        } catch {} finally { $t.Close() }
    }
    Say "Open ports found: $($open -join ', ')"
}

if ($Noise) {
    Say 'Background chatter running. Ctrl+C to stop.'
    while ($true) {
        $pick = Get-Random -InputObject 'dns','http','tls','ping'
        switch ($pick) {
            'dns'  { try { Resolve-DnsName (Get-Random -InputObject $ServerName,'www.professormesser.com','tryhackme.com') -DnsOnly | Out-Null } catch {} }
            'http' { try { Invoke-WebRequest "http://$ServerName/" -UseBasicParsing | Out-Null } catch {} }
            'tls'  { Invoke-TlsVisit }
            'ping' { Test-Connection $ServerName -Count 1 | Out-Null }
        }
        Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 8)
    }
}

switch ($Module) {
    'Warmup'   { Invoke-Warmup }
    'WebLogin' { Invoke-WebLogin }
    'Ftp'      { Invoke-FtpSession }
    'Tls'      { Invoke-TlsVisit }
    'Sweep'    { Invoke-Sweep }
    'All'      { Invoke-Warmup; Invoke-WebLogin; Invoke-FtpSession; Invoke-TlsVisit }
    default    { if (-not $Noise) { Get-Help $MyInvocation.MyCommand.Path -Detailed } }
}
