# VM Setup Guide: AlmaLinux 8 on VirtualBox (Windows Host)
### For students who have never built a VM before

This guide gets you from "empty Windows PC" to "AlmaLinux 8 VM ready for the lab" in one sitting. Follow it top to bottom — don't skip steps, even ones that seem obvious. Once you're done, come back to **Lab_Guide.md** and run **setup_lab_environment.sh**.

We're using **AlmaLinux 8.10** ("Cerulean Leopard") — the final release in the 8.x line, matching the RHEL 8 command set the lab was built for, supported with security updates into 2029 — and the current **VirtualBox 7.2.x** release for Windows.

---

## Part 1 — Check Your PC Can Actually Run a VM

1. **Confirm virtualization is turned on in your BIOS/UEFI.**
   - Open Task Manager (`Ctrl+Shift+Esc`) → **Performance** tab → **CPU**.
   - Look at the bottom right. If it says **Virtualization: Enabled**, skip to Part 2.
   - If it says **Disabled**: restart your PC, press the BIOS key during boot (commonly `F2`, `F10`, `F12`, `Del`, or `Esc` — check your PC's brand), and find a setting called **Intel VT-x**, **Intel Virtualization Technology**, **AMD-V**, or **SVM Mode**. Enable it, save, and reboot into Windows.
2. **Turn off Windows features that conflict with VirtualBox** (only needed if you hit errors in Part 4 — most people can skip this and come back to it):
   - Search Windows for "Turn Windows features on or off."
   - Make sure **Hyper-V**, **Windows Hypervisor Platform**, **Virtual Machine Platform**, and **Windows Sandbox** are all **unchecked**, unless you specifically need them for something else. These can conflict with VirtualBox's own virtualization engine.
3. **Free disk space:** you'll want at least **30 GB free** on your `C:` drive (VirtualBox itself is small, but the virtual hard disk for AlmaLinux needs room to grow).

---

## Part 2 — Download VirtualBox

1. Go to **https://www.virtualbox.org/wiki/Downloads**
2. Under "VirtualBox 7.2.x platform packages," click **Windows hosts**. This downloads a file like `VirtualBox-7.2.x-xxxxx-Win.exe`.
3. On the same page, also download the **Oracle VM VirtualBox Extension Pack** (the single `.vbox-extpack` file lower on the page) — you don't need it for this lab, but it's good to have for USB passthrough later.

---

## Part 3 — Download the AlmaLinux 8 ISO

1. Go to **https://almalinux.org/get-almalinux/** (or directly to `https://repo.almalinux.org/almalinux/8/isos/x86_64/`).
2. Download the file named **`AlmaLinux-8-latest-x86_64-minimal.iso`** (roughly 2 GB).
   - **Minimal** is what you want — it's a full installable OS with no wasted space on a graphical desktop we won't use. Skip "boot" (needs constant internet during install) and "dvd" (includes extra packages you don't need).
3. Save both this ISO and the VirtualBox installer to somewhere easy to find, like `C:\VMLab\`.

---

## Part 4 — Install VirtualBox

1. Double-click the VirtualBox installer you downloaded.
2. Click through the setup wizard, accepting the defaults (**Next → Next → Next → Install**).
3. Windows will warn you that installing VirtualBox will temporarily disconnect your network — this is normal, click **Yes**.
4. You may see a driver installation prompt from "Oracle Corporation" — click **Install**.
5. When it finishes, check **Start Oracle VM VirtualBox after installation** and click **Finish**. VirtualBox Manager should open — an empty window with a left-hand sidebar.