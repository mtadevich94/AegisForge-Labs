# VM Setup Guide: AlmaLinux 10 on VirtualBox (Windows Host)
### For students who have never built a VM before

This guide gets you from "empty Windows PC" to "AlmaLinux 10 VM ready for the lab" in one sitting. Follow it top to bottom — don't skip steps, even ones that seem obvious. Once you're done, continue with the **Linux Administration Lab Guide**. Its Access section covers the first login and the setup script.

We're using **AlmaLinux 10** (10.2 at the time of writing), the current major release, and the current **VirtualBox 7.2.x** release for Windows.

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

## Part 3 — Download the AlmaLinux 10 ISO

1. Go to **https://almalinux.org/get-almalinux/** (or directly to `https://repo.almalinux.org/almalinux/10/isos/x86_64/`).
2. Download the file named **`AlmaLinux-10-latest-x86_64-minimal.iso`** (roughly 1.5 GB).
   - **Minimal** is what you want — it's a full installable OS with no wasted space on a graphical desktop we won't use. Skip "boot" (needs constant internet during install) and "dvd" (includes extra packages you don't need).
   - **Older PC?** AlmaLinux 10's standard ISO needs a CPU with the *x86-64-v3* feature level (most PCs from the last decade). If your PC is older, or the VM won't start in Part 7, download the **x86-64-v2** variant from the same page instead (its file name contains `v2`) and use that ISO.
3. Save both this ISO and the VirtualBox installer to somewhere easy to find, like `C:\VMLab\`.

---

## Part 4 — Install VirtualBox

1. Double-click the VirtualBox installer you downloaded.
2. Click through the setup wizard, accepting the defaults (**Next → Next → Next → Install**).
3. Windows will warn you that installing VirtualBox will temporarily disconnect your network — this is normal, click **Yes**.
4. You may see a driver installation prompt from "Oracle Corporation" — click **Install**.
5. When it finishes, check **Start Oracle VM VirtualBox after installation** and click **Finish**. VirtualBox Manager should open — an empty window with a left-hand sidebar.

---

## Part 5 — Create the VM

1. In VirtualBox Manager click **New**.
2. **Name:** `AlmaLinux-Lab`. **ISO Image:** pick the AlmaLinux ISO you downloaded. Tick **Skip Unattended Installation**. Type **Linux**, Version **Red Hat (64-bit)**.
3. **Hardware:** Base Memory **2048 MB**, Processors **1 or 2**.
4. **Hard Disk:** create a new virtual hard disk, **20 GB**, dynamically allocated.
5. Finish. Leave the network on the default **NAT** (Settings → Network → Adapter 1).

## Part 6 — Add the SSH port-forward

This lets your PC reach the VM's SSH port as `127.0.0.1:2222`.

1. Select the VM → **Settings → Network → Adapter 1 → Advanced → Port Forwarding**.
2. Click the **+** and fill in one rule: **Name** `SSH`, **Protocol** `TCP`, **Host IP** `127.0.0.1`, **Host Port** `2222`, **Guest IP** blank, **Guest Port** `22`.
3. **OK**, **OK**.

## Part 7 — Install AlmaLinux

1. Start the VM. At the boot menu choose **Install AlmaLinux 10**. Click inside the VM window to use the mouse and press **Right Ctrl** to give it back.
   - **Kernel panic, or an instant reboot, right after this menu?** There are two usual causes. First, your CPU may be v2-only: use the **x86-64-v2** ISO from Part 3. Second, Windows' own virtualization (Hyper-V, Memory Integrity) may be active, so VirtualBox runs in a slow fallback mode and the VM can't see your CPU's v3 features: turn off the Windows features listed in Part 1, step 2, restart your PC, and try again. Updating VirtualBox to the latest 7.2.x release has also fixed this for some people.
2. Pick your language and continue to the **Installation Summary** screen.
3. **Installation Destination:** click it, make sure the 20 GB disk is selected, click **Done**.
4. **Network & Host Name:** switch the Ethernet adapter **On**, click **Done**.
5. **Root Password:** set one and **write it down**. This is the `root` password the lab guide asks for on first login. It is a throwaway lab password: do not reuse a real one. Tick **Allow root SSH login with password** if you see it. AlmaLinux 10 normally blocks password logins for `root` over SSH unless you allow them. (If you don't see the option, Part 8 shows how to switch it on afterwards.)
6. **User Creation:** skip it. The lab's setup script creates the `student` account.
7. **Software Selection** stays on **Minimal Install**. Click **Begin Installation** and wait about ten minutes.
8. Click **Reboot System**. If you land back in the installer, power the VM off, remove the ISO (**Settings → Storage**, or **Devices → Optical Drives → Remove disk from virtual drive**), and start it again.

## Part 8 — Check you can log in

1. At the VM console, log in as `root` with the password from Part 7.
2. Confirm SSH is running: `systemctl is-active sshd` should print `active`. If not, run `systemctl enable --now sshd`.
3. On your PC open **Command Prompt** or **PowerShell** and run `ssh -p 2222 root@127.0.0.1`. Type `yes` to accept the host key and enter the root password. You should get a `root` prompt.
   If you get `Permission denied`, root password logins over SSH are off. At the VM console (logged in as `root`) run:
   ```
   echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/99-first-login.conf
   systemctl restart sshd
   ```
   then try the `ssh` command again. The lab's setup script removes this file and turns root SSH off for good.
4. If you rebuild the VM later and SSH warns that the host key changed, clear the old one with `ssh-keygen -R "[127.0.0.1]:2222"`.

## Part 9 — Snapshot, then start the lab

Shut the VM down and take a snapshot named `post-install-clean`. Then open the **Linux Administration Lab Guide**. Its **Access** section covers the first login, the setup script, and the `student` account you work as from then on.
