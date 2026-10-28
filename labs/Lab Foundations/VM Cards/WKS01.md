# WKS01 — Windows Workstation

The most-shared VM in the fleet. It has two states so that no lab forces you to build more than it needs.

| | |
|---|---|
| **OS** | Windows 11 Enterprise (evaluation ISO) |
| **Resources** | 4 GB RAM, 2 vCPU, 60 GB disk |
| **Network** | `GielinorNAT` (flat realm) or `realm-garrison` (Gatehouse) |
| **Address** | `10.10.10.20/24` static, gateway `10.10.10.1`, DNS `10.10.10.10` (flat realm); DHCP from FW01 in the Gatehouse |
| **Built by** | Windows Lab series; the Gatehouse and Packet Watch reuse it |
| **Accounts** | `labadmin` is the local administrator (create it at install; it is also the break-glass account). `GIELINOR\student` is a standard user, only in the domain-joined state. See [Lab Account Standard](../Lab%20Account%20Standard.md). |

## The two states

| State | What it is | Needed by |
|---|---|---|
| **Minimal** | Windows installed, static `10.10.10.20`, local administrator `labadmin`, not domain-joined | Packet Watch, the Gatehouse |
| **Domain-joined** | Minimal + joined to `gielinor.local`, DNS `10.10.10.10` | Windows Administration, Tiered Admin |

If you only need the Gatehouse or Packet Watch, build **minimal** and stop. DC01 isn't required.

## Build (minimal)

1. Create the VM, attach the Windows 11 ISO, install. If setup demands a Microsoft account, use the Windows Labs guide's bypass steps.
2. Set the static address above (Settings → Network → Ethernet → IP assignment → Manual), or in PowerShell with the commands in the restore block below.
3. Snapshot as `post-install-clean`.

## Ready when

- `ipconfig` shows `10.10.10.20`
- `ping 10.10.10.1` succeeds

## Verify

```powershell
Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4; Test-Connection 10.10.10.1 -Count 1
```

## Using WKS01 in the Gatehouse (recommended: linked clone)

The Gatehouse moves WKS01 onto `realm-garrison`, where FW01 hands out addresses by DHCP. **Make a linked clone** named `WKS01-gatehouse` from your `post-install-clean` snapshot so your flat-realm WKS01 stays untouched. Then, in the clone, switch to DHCP.

**Switch to DHCP** (adapter alias `Ethernet`; check with `Get-NetAdapter`):

```powershell
$if="Ethernet"
Remove-NetRoute -InterfaceAlias $if -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetIPAddress -InterfaceAlias $if -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
Set-NetIPInterface -InterfaceAlias $if -Dhcp Enabled
Set-DnsClientServerAddress -InterfaceAlias $if -ResetServerAddresses
ipconfig /renew
```

**Restore the flat-realm address** (if you did this to the original instead of a clone):

```powershell
$if="Ethernet"
Set-NetIPInterface -InterfaceAlias $if -Dhcp Disabled
New-NetIPAddress -InterfaceAlias $if -IPAddress 10.10.10.20 -PrefixLength 24 -DefaultGateway 10.10.10.1
Set-DnsClientServerAddress -InterfaceAlias $if -ServerAddresses 10.10.10.10
```

Then change the VM's adapter back to `GielinorNAT`.

> **Domain-joined WKS01 in the Gatehouse?** Don't. A domain-joined machine with no route to DC01 behaves badly (slow logons, trust warnings). Use the minimal state or a clone of it.

## Snapshots

`post-install-clean`, `domain-joined-clean`, `gatehouse-start` (on the clone).

## Expiry

Windows 11 evaluation lasts 90 days.
