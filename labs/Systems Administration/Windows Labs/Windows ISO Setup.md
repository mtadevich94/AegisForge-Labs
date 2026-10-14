# Windows ISO & VM Foundation Guide
### Getting a Domain Controller and Workstation host machine ready for install

**Goal of this guide:** by the end, you'll have two blank VMs built (one for a domain controller, one for a Windows 11 workstation), and both booted to the Windows Setup screen and installed to a clean, logged-in desktop. Domain promotion and the workstation domain-join happen in the companion **Domain Setup & Workstation Join Guide** — don't configure networking or run `dcpromo`/`Install-ADDSForest` yet.

**Target build:**
| Role | OS | VM name (suggested) |
|---|---|---|
| Domain Controller | Windows Server 2022 (Datacenter, Desktop Experience) | `DC01` |
| Workstation | Windows 11 Enterprise | `WKS01` |

**Host prerequisites:**
- Hardware virtualization (Intel VT-x / AMD-V) enabled in your BIOS/UEFI
- At least ~150 GB free disk (two 60 GB dynamic VDIs plus ISOs, with headroom)
- 16 GB host RAM is comfortable for running both VMs at once (8 GB is workable if you run one at a time)

---

## Step 1 — Download the Windows Server 2022 evaluation ISO

1. Go to **microsoft.com/en-us/evalcenter/evaluate-windows-server-2022**.
2. Click **Get started for free** / **Download the ISO**. You'll be asked to register (name, email, country) — this is Microsoft's standard evaluation gate, not a purchase.
3. Choose:
   - **Edition:** Standard or Datacenter (either works for this lab; Datacenter is a fine default and matches what most write-ups assume)
   - **Language:** English (or your preference)
4. Save the ISO somewhere you'll remember — you'll attach it directly to the DC VM, not burn it to media.

**Know before you install:** the evaluation edition runs for **180 days** and must be activated online within the first 10 days to avoid an automatic shutdown warning banner. For a lab you rebuild from snapshots, this is rarely a practical problem, but it's worth knowing the clock is running.

---

## Step 2 — Download the Windows 11 Enterprise evaluation ISO

1. Go to **microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise**.
2. Click **Download the ISO – Windows 11 Enterprise**. You'll need to sign in with a Microsoft account to reach the download (this is Microsoft's gate for the Enterprise evaluation channel, separate from the Server one).
3. Choose the current version (Windows 11 Enterprise, version 25H2 at the time of writing) and the **x64** architecture — skip Arm64 unless your host is actually ARM.
4. Pick English (United States) or your preferred language.

**Know before you install:** this is a **90-day** evaluation, and Microsoft's own download page notes it can take a while to pull down — the ISO is several GB, so don't be surprised if it takes a good chunk of an hour on a typical connection.

---

## Step 3 — (Optional) Verify your downloads

Both Microsoft ISOs ship with a SHA256 hash on their respective evaluation-center pages. If you want to confirm a clean download before building VMs around it:

```powershell
# On any Windows machine, or in a Linux shell with sha256sum:
Get-FileHash .\SERVER_EVAL_x64FRE_en-us.iso -Algorithm SHA256
```

Compare the result against the hash shown on the download page. This step is optional but worth doing once if your connection is flaky — a corrupt ISO fails partway through setup and wastes more time than the checksum does.

---

## Step 4 — Build the DC01 VM

In VirtualBox, click **New** and configure:

| Setting | Value |
|---|---|
| Name | `DC01` |
| Folder | your VM storage location |
| ISO Image | point directly at the Server 2022 ISO (VirtualBox 7.x lets you pick this during creation and will offer "unattended install" — **decline unattended install** for this lab so you walk through Setup by hand and can create the local admin account yourself) |
| Type / Version | Microsoft Windows / Windows 2022 (64-bit) |
| Base Memory | 4096 MB minimum, 8192 MB if your host can spare it |
| Processors | 2 vCPU minimum |
| Disk | 60 GB, dynamically allocated, VDI format |

Before first boot, open **Settings** on DC01 and check:
- **System → Motherboard:** Enable I/O APIC (should already be on for a 64-bit guest)
- **Storage:** confirm the Server 2022 ISO is mounted in the optical drive
- **Network → Adapter 1:** leave on the default (NAT) for now — you'll change this in the Domain Setup guide once both VMs exist

---

## Step 5 — Build the WKS01 VM

Windows 11 has firm requirements — **TPM 2.0, Secure Boot, and UEFI** — that VirtualBox 7.x can emulate, but only if you turn them on explicitly. Skipping this step is the #1 reason the Windows 11 installer refuses to continue.

Click **New** and configure:

| Setting | Value |
|---|---|
| Name | `WKS01` |
| ISO Image | point at the Windows 11 Enterprise ISO — again, **decline unattended install** |
| Type / Version | Microsoft Windows / Windows 11 (64-bit) |
| Base Memory | 4096 MB minimum, 8192 MB recommended |
| Processors | 2 vCPU minimum |
| Disk | 60 GB, dynamically allocated, VDI format |

VirtualBox 7.x will typically detect the Windows 11 ISO and pop a dialog offering to enable **EFI, Secure Boot, and a virtual TPM 2.0 chip** automatically — accept that. If you don't get the prompt (or built the VM from an older template), set these manually in **Settings** before first boot:

- **System → Motherboard:** check **Enable EFI (special OSes only)**
- **System → Motherboard:** check **Enable I/O APIC**
- **Security tab** (VirtualBox 7.0+): set **TPM** to **2.0**, and check **Enable Secure Boot**

Also confirm:
- **Storage:** the Windows 11 Enterprise ISO is mounted
- **Network → Adapter 1:** leave on NAT for now, same as DC01

---

## Step 6 — Install Windows Server 2022 on DC01

1. Start DC01. Boot from the ISO (press any key if prompted).
2. Language/time/keyboard → **Next** → **Install now**.
3. When asked which image to install, pick **Windows Server 2022 Standard (Desktop Experience)** or **Datacenter (Desktop Experience)** — the Desktop Experience option gives you the full GUI, which is worth having for a first AD build. Avoid the Server Core options unless you specifically want a command-line-only DC.
4. Accept the license terms → **Custom: Install Windows only** → select the 60 GB disk → **Next**. Installation runs and reboots on its own.
5. On first boot, set the local Administrator password when prompted.
6. Log in as `Administrator`. You now have a clean Server 2022 box — **stop here**. Domain promotion is covered in the next guide.

---

## Step 8 — Install Windows 11 Enterprise on WKS01

1. Start WKS01. Boot from the ISO.
2. Language/time/keyboard → **Next** → **Install now**.
3. Accept the license terms → **Custom: Install Windows only** → select the 60 GB disk → **Next**. This installer stage tends to be slower than Server's — let it run.
4. **Out-of-box setup (OOBE):** because this is the Enterprise evaluation SKU, you should see a prompt during account setup offering **"Join a domain instead"** (rather than the consumer flow that forces a Microsoft account). If you see that option, take it and create a **local account** now (e.g., `student` with a password) — you'll join the real domain later once it exists.
   - If you *don't* see that option and get stuck on "Sign in with Microsoft," the standard workaround is: press **Shift+F10** at the sign-in-required screen to open a command prompt, then run:
     ```
     oobe\bypassnro
     ```
     The machine will reboot back into OOBE and offer an "I don't have internet" / local-account path.
5. Finish setup (skip the optional Microsoft Store/privacy prompts as you prefer) and land on the desktop.
6. Log in and confirm you're at a working desktop — **stop here**. Renaming the machine, setting a static IP, and joining it to the domain all happen in the next guide.

---

## Where you should be now

- VirtualBox installed with the current Extension Pack
- `DC01` — Windows Server 2022 (Desktop Experience) installed, logged in as local Administrator, not yet promoted
- `WKS01` — Windows 11 Enterprise installed, logged in with a local account, not yet joined to anything
- Both ISOs kept on disk in case you need to reattach them (e.g., to add server roles later)

**Take a VirtualBox snapshot of both VMs now** (right-click the VM → **Snapshot → Take**), labeled something like `post-install-clean`. That gives you a fast rollback point before you start touching networking and Active Directory in the next guide.

Next: **Domain Setup & Workstation Join Guide**.
