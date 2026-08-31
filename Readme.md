# scripts

A personal grab-bag of sysadmin, forensics, and media-processing scripts.

## Contents

### Linux system administration & hardening
| File | What it does |
|---|---|
| [`disk_clean.sh`](./disk_clean.sh) | Cleans up a Pop!_OS/Debian-based system: APT cache, logs, Snap cache, Python caches, Trash, and interactively deletes files >500MB in `/home`. |
| [`stig_harden_ubuntu.sh`](./stig_harden_ubuntu.sh) | Applies DISA-STIG-style hardening to Ubuntu 22.04 (UFW, auditd, fail2ban, libpam-pwquality, and related lockdown steps). Must be run as root. |
| [`openvpn-install.sh`](./openvpn-install.sh) | Third-party ([angristan/openvpn-install](https://github.com/angristan/openvpn-install)) secure OpenVPN server installer for Debian, Ubuntu, CentOS, Amazon Linux 2, Fedora, Oracle Linux, Arch, Rocky, and AlmaLinux. |
| [`wireguard-install.sh`](./wireguard-install.sh) | Interactive WireGuard server installer and client manager (add/revoke clients, QR code for mobile) for Debian, Ubuntu, Fedora, CentOS/Rocky/AlmaLinux, and Arch. Companion to `openvpn-install.sh` for the WireGuard case. |
| [`maintenance-debian.md`](./maintenance-debian.md) | `auto-maintenance.sh` — a scheduled Debian + WordPress maintenance script (unattended-upgrades setup, update/cleanup routine) with logging. |
| [`Upgrade_Debian.md`](./Upgrade_Debian.md) | Step-by-step guide for upgrading a vanilla Debian 12 "bookworm" install to Debian 13 "trixie," including handling third-party repos. |

### Windows
| File | What it does |
|---|---|
| [`Reset_Reregister_Windows_Update_Components.bat`](./Reset_Reregister_Windows_Update_Components.bat) | Resets and re-registers Windows Update components (services, SoftwareDistribution/catroot2, DLL re-registration) to fix a broken Windows Update. Self-elevates to admin. |
| [`Certutil-Encode_decode Base64`](./Certutil-Encode_decode%20Base64) | Notes on using the built-in `certutil` tool to Base64-encode/decode files on Windows without any third-party utility. |

### Digital forensics
| File | What it does |
|---|---|
| [`Mount shadow volumes on disk images`](./Mount%20shadow%20volumes%20on%20disk%20images) | Notes on using `vssadmin` + `mklink` to enumerate and mount Volume Shadow Copies found on a mounted disk image. |

### Video processing (FFmpeg scene splitting)
| File | What it does |
|---|---|
| [`FFmpeg_split_scenes_CPU.sh`](./FFmpeg_split_scenes_CPU.sh) | Detects scene changes with FFmpeg's `select` filter and splits a video into per-scene clips, CPU-only. |
| [`FFmpeg_split_scenes_NVIDIA.sh`](./FFmpeg_split_scenes_NVIDIA.sh) | Same scene-splitting approach, using NVIDIA NVENC/CUDA for accelerated decoding/encoding. |
| [`FFmpeg_split_scenes_Python.py`](./FFmpeg_split_scenes_Python.py) | Same task using PySceneDetect for scene detection instead of FFmpeg's built-in filter, then cuts with FFmpeg NVENC. |
| [`FFmpeg_split_scenes_AI.py`](./FFmpeg_split_scenes_AI.py) | Same task using the TransNetV2 model for scene detection, then cuts with FFmpeg NVENC. Auto-installs missing Python deps. |

### Misc
| File | What it does |
|---|---|
| [`Chia_ubuntu_ploting`](./Chia_ubuntu_ploting) | Quick-reference commands for installing the Chia blockchain client and creating plots on Ubuntu. |

## Usage notes

- **Read before running.** Several scripts (`stig_harden_ubuntu.sh`, `openvpn-install.sh`, `Reset_Reregister_Windows_Update_Components.bat`) make system-level changes (firewall rules, services, the registry-equivalent Windows Update state) and should be reviewed and tested in a non-production environment first.
- **Root/admin required:** `stig_harden_ubuntu.sh` and `openvpn-install.sh` must be run as root; `Reset_Reregister_Windows_Update_Components.bat` self-elevates via UAC.
- The four `FFmpeg_split_scenes_*` scripts all solve the same problem (split a video on scene changes) with different tradeoffs — pick CPU, NVIDIA-accelerated, PySceneDetect, or TransNetV2-based detection depending on what's installed and available.

## License

No license file is currently included. Treat these as personal reference scripts unless/until one is added.