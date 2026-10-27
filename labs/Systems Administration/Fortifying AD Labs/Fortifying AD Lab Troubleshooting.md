# Fortifying AD: Troubleshooting and Recovery

This lab deliberately breaks things. Here is how to get back.

## The universal fix: snapshots

Every module starts and ends with a snapshot (`fN-...`). Revert **all four VMs** to the last good one. Reverting only one VM can leave the domain inconsistent (machine passwords and replication state differ). If in doubt, go back to `fortify-start`.

## Symptoms

| Symptom | Likely cause | Fix |
|---|---|---|
| Can't open `\\srv01\Keep` from WKS01 | SMB signing mismatch, NTLM restriction, or firewall scoping | Use the **name**, not the IP. Check `Get-SmbConnection`, the NTLM operational log, and the firewall address list |
| WKS01 won't sign in with a domain account | DC unreachable, Kerberos types, or clock skew | Check `ping dc01`, time sync, `nltest /dsgetdc:gielinor.local`. Revert if needed |
| `gpupdate` errors | DNS or SYSVOL problem, not usually the policy | `dcdiag /q`, `nslookup gielinor.local` |
| WATCHTOWER can't query LDAP | You enforced signing (that's the lesson) | Use LDAPS (Module 5C), or temporarily set the DC setting back to *None* in `GPO-Fortify-DC` |
| `kinit` fails from WATCHTOWER | Realm not uppercase, clock skew, wrong KDC | Fix `/etc/krb5.conf`, sync time |
| LAPS returns nothing | Update level, schema, permission, account name | See the Answer Key |
| Locked out after "deny network logon" | A needed account was local | Sign in at the **console** with a domain admin, or revert the GPO setting |
| Everything slow after enabling logging | Log size | Increase log size, or turn module logging down to specific modules |

## Undoing individual settings

Prefer undoing in the **GPO** (set the policy back to *Not configured*), then `gpupdate /force` on the affected machines, because a registry change made by hand will be overwritten.

If you can't reach Group Policy, these values can be reverted locally as an administrator:

| Control | Local revert |
|---|---|
| NTLM level | `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LmCompatibilityLevel` |
| SMB signing (server) | `Set-SmbServerConfiguration -RequireSecuritySignature $false -Force` |
| SMB signing (client) | `Set-SmbClientConfiguration -RequireSecuritySignature $false -Force` |
| LSA protection | Set `RunAsPPL` to 0 and reboot (if Secure Boot UEFI locked it, you may need a snapshot instead) |
| LDAP signing (DC) | `HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters\LDAPServerIntegrity` back to 1 |

## When you're locked out of the domain controller

1. Revert DC01 **and** the other VMs to the last good snapshot.
2. If no snapshot is good, boot DC01 into **Directory Services Restore Mode** (F8 or Advanced boot options) to fix the local policy. This is slow. Snapshots are easier, which is the whole reason the lab asks for them.

## The lesson inside the troubleshooting

Notice how you diagnosed each break: from **logs and a known last-good state**, not by guessing. That is the same discipline a real change needs. Write any new failure you find into your Legacy Register.
