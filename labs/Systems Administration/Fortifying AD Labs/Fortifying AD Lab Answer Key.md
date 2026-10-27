# Fortifying AD: Answer Key

Expected results for each module, plus a cheat sheet of every policy setting used. **Untested.** Written from Microsoft documentation. If something differs on your build, trust your build and note it in your report.

## Expected results

| Module | What you should see |
|---|---|
| 1 Read the Room | SMB signing not required on members; SMB1 absent on modern builds; LLMNR/NetBIOS/mDNS on (no policy); `LmCompatibilityLevel` missing or low; LDAP signing not enforced; SPN accounts with no AES setting |
| 2 Lanterns | NTLM events 8001/8002/8004 in `Microsoft-Windows-NTLM/Operational`; 4624 entries with package `NTLM` for by-IP and WATCHTOWER traffic; 2889 entries naming WATCHTOWER for unsigned LDAP binds |
| 3 Whispers | After policy: LLMNR disabled (`EnableMulticast`=0), NetBIOS set to disabled on adapters, mDNS off; name resolution of real hosts still works via DNS |
| 4 SMB | `RequireSecuritySignature` true on servers and clients; `Get-SmbConnection` shows `Signed: True`; SMBv1 absent; anonymous restrictions applied |
| 5 LDAP | After enforcing: WATCHTOWER unsigned simple bind fails (strong-auth required); LDAPS on 636 works once the DC has a certificate; 2889 stops for fixed clients |
| 6 NTLM | NTLMv2-only (`LmCompatibilityLevel`=5 on members, DC per lab step); incoming NTLM to SRV01 denied; by-IP connection fails, by-name works; WATCHTOWER either on Kerberos or on the Legacy Register |
| 7 Kerberos | 4769 events: `0x17` before, `0x12` after for `svc-web`; no pre-auth and unconstrained delegation lists empty (except DCs) |
| 8 Quiet Walk | LAPS returns a different password per machine; `keepadmin` refused over the network; WATCHTOWER cannot reach 445/3389 on SRV01; 4104 events present; ASR events 1122 (audit) |
| 9 Inspection | After-column differs from before except documented exceptions; regression list passes |

## Likely wrong turns

- **Policy did not apply.** `gpresult /r` shows whether the GPO is applied and which OU the machine is in. A GPO linked to the wrong OU is the commonest cause.
- **Netsh/registry value correct, behavior unchanged.** Many of these need a reboot or a service restart.
- **NetBIOS still on.** That setting is per adapter. Check each adapter and any DHCP option that overrides it.
- **WATCHTOWER still connects by IP after NTLM restriction.** You may have restricted outgoing instead of incoming, or applied it to the wrong OU.
- **LAPS returns nothing.** Check the update level, that the schema was extended, that the managed account exists, and that the computer has permission to write its password.
- **Firewall scoping blocks everyone.** Check the profile (Domain/Private/Public) and the address list for typos.

## Policy cheat sheet (all names are as they appear in the editor)

| Area | Setting | Value |
|---|---|---|
| LLMNR | Computer Config → Admin Templates → Network → DNS Client → *Turn off multicast name resolution* | Enabled |
| mDNS | DNS Client policy / registry `EnableMDNS` | 0 |
| NetBIOS | Per adapter, or DHCP option | Disabled |
| SMB signing (server) | Security Options → *Microsoft network server: Digitally sign communications (always)* | Enabled |
| SMB signing (client) | Security Options → *Microsoft network client: Digitally sign communications (always)* | Enabled |
| Anonymous | Security Options → *Network access: Do not allow anonymous enumeration of SAM accounts and shares* | Enabled |
| LDAP signing (DC) | Security Options → *Domain controller: LDAP server signing requirements* | Require signing |
| LDAP signing (client) | Security Options → *Network security: LDAP client signing requirements* | Require signing |
| Channel binding | *Domain controller: LDAP server channel binding token requirements* | When supported, then Always after audit |
| LAN Manager level | Security Options → *Network security: LAN Manager authentication level* | Send NTLMv2 response only. Refuse LM & NTLM |
| NTLM audit | Security Options → *Network security: Restrict NTLM: Audit incoming NTLM traffic* | Enable auditing for all accounts |
| NTLM incoming | *Network security: Restrict NTLM: Incoming NTLM traffic* | Deny all accounts (SRV01 only, after audit) |
| Kerberos types | *Network security: Configure encryption types allowed for Kerberos* | AES128, AES256, Future types |
| LAPS | Admin Templates → System → LAPS | AD backup, 20 chars, 30 days, account `keepadmin` |
| Deny network logon | User Rights → *Deny access to this computer from the network* | Local account and member of Administrators group |
| Firewall scope | Admin Templates → Network → Network Connections → Windows Defender Firewall → Domain Profile | File/printer, remote admin, RDP exceptions scoped to admin IPs |
| PowerShell | Admin Templates → Windows Components → Windows PowerShell | Script block + module logging |
| ASR | Defender → Exploit Guard → ASR rules | Audit (2) |
| LSA | `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL` | 1 |
| WDigest | `...\SecurityProviders\WDigest\UseLogonCredential` | 0 or absent |

## Answers to the discussion questions (short form)

**M6-1.** Kerberos needs a service name to look up the right ticket. An IP address has no service name, so Windows falls back to NTLM.
**M6-2.** Because you don't yet know what depends on NTLM. Denying everything first means finding out through outages.
**M7-2.** The account's password is stored wherever the service uses it (service config, scheduled tasks, app files). Resetting it without updating those places breaks them.
**M8-1.** Same password everywhere means one stolen hash or password works on every machine that shares it.
**M8-4.** Logging doesn't stop an attack, but it is how you detect and investigate one.

Your own answers to the legacy questions will depend on what you found in Module 2. There isn't a single correct list.
