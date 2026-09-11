# Super Xiao AI / Xiao AI (PC) — Device Check Bypass

**English** | [中文](README.md)

Run Xiaomi's **Super Xiao AI (超级小爱) / Xiao AI (小爱同学)** PC client on **any brand** of computer — Lenovo, ASUS, Dell, HP, Apple, custom builds, etc.

> Xiaomi's PC client refuses to install and run on non-Xiaomi laptops by checking the machine model. This project removes that restriction so you can use it with your Xiaomi account and ecosystem.

---

## 1. Who is this for

The core problem: **your account and ecosystem are Xiaomi's, but your computer isn't a Xiaomi laptop — so the official client refuses to install.**

- **Scenario 1 — Xiaomi phone + non-Xiaomi laptop.** You want file transfer, clipboard sync and cross-device features between your Xiaomi phone and your Lenovo/ASUS/Dell/HP/Mac. Official client won't install, so none of it works.
- **Scenario 2 — Xiaomi ecosystem at home, only the PC is "foreign".** Mi Home devices, Xiaomi earbuds, Xiao AI speakers — everything except the computer. After patching, everything can live under one Xiaomi account.
- **Scenario 3 — You want the AI features without buying a new laptop.** File search, app control, Q&A, voice wake-up, screenshot Q&A. These are **software capabilities** — they have nothing to do with your laptop's brand, it's just a vendor whitelist.
- **Scenario 4 — Hackintosh / custom builds / older laptops.** Their motherboard models will never appear on an official whitelist. This tool is **generic**: it reads your real model and injects it.

**Requirements:** a Xiaomi account, Windows 10 1803+ (64-bit), and 2–3 GB free on the C: drive.

---

## 2. How the device check works

Xiaomi checks the machine model in **two independent places**. Both are entirely **local — no server-side verification**.

**a) The installer** (`vJ_O_XiaoaiAgent_*.exe`)
The whitelist lives in a plaintext JSON config embedded in the installer:

```json
"support_tm_list": [ "TM2424", "TM2425", "TM2426", "TM2427", "TM2428" ]
```

**b) The installed app** (`XiaoaiAgent.dll`)
On startup, `App.CheckSignatureAndPCType()` verifies both the digital signature of the install directory and the machine model. On failure it:

- calls `Application.Current.Shutdown()` → exits immediately (log: `exit on unsupport device.`)
- fires `InfoCheckerService.OnFail()` → sets `IsLegal = false`, hiding the main window

The model is read from WMI (`Win32_BaseBoard` Product, e.g. Lenovo `LNVNB161216`) and cached in `HKCU\Software\MI\XiaoaiAgent\Cache\PCModel`.

> Editing that registry cache **does not work** — the client re-queries WMI on startup and overwrites it.

---

## 3. Files

| File | Purpose |
|---|---|
| `install_any_pc.bat` | **Install on any brand**: reads your local model → patches the installer whitelist → installs with elevation |
| `patch_installer.ps1` | The implementation behind the above (equal-length replacement, so JSON stays valid and container offsets don't shift) |
| `install.bat` | **Menu-driven app patcher**: lists patch versions, one-key apply / restore |
| `patch_installer.py`, `patch_installer2.py` | Python version (patch whitelist / change install drive) |
| `patches/<version>/` | App patches + original backups (2.0.0.231, 3.0.4.289) |
| `tools/Patcher/` | Patch generator (Mono.Cecil) — regenerate patches after an app update |
| `说明-详细分析.md` | Full reverse-engineering write-up (Chinese) |

The app patch rewrites the IL of three methods in `XiaoaiAgent.dll`:

| Method | Change |
|---|---|
| `App::CheckSignatureAndPCType()` | Empty body — no more shutdown |
| `InfoCheckerService::OnFail()` | Empty body — no more hidden window |
| `LocalSettingsHelper::get_IsInSupportWhiteList()` | Always returns `true` (2.0.0.231 only) |

---

## 4. Usage

### Step 1 — Download the official installer

From Xiaomi's driver page for your model:

https://www.mi.com/service/notebook/drivers/TM2424

### Step 2 — Install with the check bypassed

Double-click **`install_any_pc.bat`**, paste (or drag in) the installer path, press Enter.
The script reads your local model, writes it into the installer's whitelist, then launches the installer with a UAC prompt.

> To install to a different drive (recommended when C: is low on space):
> `python patch_installer2.py "installer.exe" "output.exe" E your-model`

### Step 3 — Patch the app

After installation, double-click **`install.bat`**:

```
choose version  →  [1] apply patch
```

It auto-detects the install directory (searches C/D/E/F/G), backs up the original, then replaces it.

### Step 4 — Launch

Run `XiaoaiAgent.exe` from the install directory and sign in with your Xiaomi account.

**Restore original:** `install.bat` → choose version → `[2]`.

---

## 5. Troubleshooting (real-world issues — read this first)

### 5.1 "MiService 服务未启动，请修复后重试"

If the C: drive was low on space during install, `MiService2_Setup.exe` **fails silently** and the service is never registered. Check:

```powershell
Get-Service MiService*
```

Nothing found = not installed. Fix: run `MiService2_Setup.exe` from the install directory as administrator. It should end up `Running` / `Automatic`.

### 5.2 Patch stops working after a reboot

Two causes — check both:

**Cause A: the patch never reached the real install directory** (most common). People patch a copy and then launch the original. Verify the MD5 of `XiaoaiAgent.dll` in the install directory matches `patches/<version>/XiaoaiAgent.dll`.

**Cause B: auto-update overwrote the patch.** Disable it:

```powershell
Set-ItemProperty -Path 'HKCU:\Software\MI\XiaoaiAgent' -Name 'AutoUpdateAppWifiFlag' -Value 0 -Type DWord
```

> Side effect: the client stops auto-updating. Future updates require installing the new version and re-patching.

### 5.3 Install fails with exit code -3

Check `C:\ProgramData\MI\XiaoaiAgent\Log\Installer.log.txt` for:

```
ExtractArchive: [...\packages\*.7z] failed
Install failed: -3
```

**This is a disk-space problem, not a device-check problem** (the check has already passed by then). Keep at least 2–3 GB free on C:. To install elsewhere:

```bash
python patch_installer2.py "installer.exe" "output.exe" E your-model
```

> Even with a different install drive, extraction still needs ~500 MB of temp space on C:.

---

## 6. Regenerating patches for a new version

```bash
# 1. Obtain XiaoaiAgent.dll from the install directory
# 2. Generate the patch
cd tools/Patcher
dotnet build -c Release
dotnet bin/Release/net8.0/Patcher.dll <original.dll> <output.dll> --wakeup
# 3. Drop it into patches/<version>/XiaoaiAgent.dll
```

---

## 7. Notes & disclaimer

- After an app update, `XiaoaiAgent.dll` is replaced by the official file and the patch is lost — just re-apply step 3. If the version number changed, regenerate the patch with `tools/Patcher`.
- A patched installer loses its digital signature; Windows may warn about an "unknown publisher" — choose "Run anyway".
- The voice wake-up toggle becomes visible, but that feature depends on model-specific audio hardware and will likely not work on non-Xiaomi machines.
- **This tool bypasses a vendor's model restriction. It is an unofficial modification and may violate the software license agreement. For personal, local research and study only. Use at your own risk.**
- This repository includes prebuilt patched DLLs and their original backups, which are derived from Xiaomi's proprietary binaries. Redistributing them may constitute copyright infringement and could result in a DMCA takedown. If you prefer a version with no vendor binaries, delete `patches/*/XiaoaiAgent.dll*` and generate patches locally with `tools/Patcher` against your own installation.
- The official installer is **not** included — download it from Xiaomi yourself.
