#!/usr/bin/env python3
"""Print drives, fans and tool availability as JSON for the Quickshell Devices tab."""

import glob
import json
import os
import shutil
import subprocess

SYSTEM_MOUNTS = {"/", "/boot", "/boot/efi", "/efi", "/home", "/var", "/usr", "/nix", "/tmp"}
SKIP_FS = {None, "swap", "crypto_LUKS", "LVM2_member", "linux_raid_member", "squashfs", "BitLocker"}


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def drives():
    try:
        out = subprocess.run(
            ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,FSTYPE,LABEL,MOUNTPOINTS,FSUSED,FSSIZE,RM,HOTPLUG,TYPE,MODEL,PARTLABEL"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        tree = json.loads(out)["blockdevices"]
    except (OSError, subprocess.SubprocessError, ValueError, KeyError):
        return []

    result = []

    def walk(dev, disk):
        if dev.get("type") == "disk":
            disk = dev
        if dev.get("name", "").startswith(("zram", "loop")):
            return
        fs = dev.get("fstype")
        mounts = [m for m in (dev.get("mountpoints") or []) if m and m != "[SWAP]"]
        size = int(dev.get("size") or 0)
        # Skip tiny partitions (EFI helpers, recovery) unless mounted
        if fs not in SKIP_FS and (mounts or size >= 1 << 30):
            removable = bool(disk and (disk.get("rm") or disk.get("hotplug")))
            result.append({
                # Real label, else the main mount point, else the drive model
                "name": dev.get("label") or (min(mounts, key=len) if mounts else "")
                        or ((disk or {}).get("model") or "").strip() or dev["name"],
                "path": dev["path"],
                "disk": disk["path"] if disk else "",
                "model": ((disk or {}).get("model") or "").strip(),
                "fstype": fs,
                "size": size,
                "used": int(dev.get("fsused") or 0),
                "total": int(dev.get("fssize") or 0),
                "mounts": mounts,
                "removable": removable,
                "system": any(m in SYSTEM_MOUNTS for m in mounts),
            })
        for child in dev.get("children") or []:
            walk(child, disk)

    for dev in tree:
        walk(dev, None)
    return result


def fans():
    out = []
    for h in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        chip = read(f"{h}/name")
        for f in sorted(glob.glob(f"{h}/fan*_input")):
            base = f[:-len("_input")]
            rpm = int(read(f, "0") or 0)
            out.append({"source": chip, "label": read(f"{base}_label") or os.path.basename(base).capitalize(), "rpm": rpm})

    # AIOs / fan hubs via liquidctl
    if shutil.which("liquidctl"):
        try:
            data = json.loads(subprocess.run(["liquidctl", "status", "--json"], capture_output=True, text=True, timeout=8).stdout)
            for dev in data:
                for s in dev.get("status", []):
                    if s.get("unit") == "rpm":
                        out.append({"source": dev.get("description", "liquidctl"), "label": s.get("key", ""), "rpm": int(s.get("value") or 0)})
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
    return out


def main():
    print(json.dumps({
        "drives": drives(),
        "fans": fans(),
        "udisks": bool(shutil.which("udisksctl")),
        "liquidctl": bool(shutil.which("liquidctl")),
        "board": read("/sys/class/dmi/id/board_vendor") + " " + read("/sys/class/dmi/id/board_name"),
    }))


if __name__ == "__main__":
    main()
