#!/usr/bin/env python3
"""Print one JSON line of system stats every INTERVAL seconds, for the Quickshell stats tab."""

import glob
import json
import os
import shutil
import subprocess
import sys
import time

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def find_sensors():
    """hwmon numbering changes between boots, so match by driver name."""
    cpu_temp, drives = None, []
    for h in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        name = read(f"{h}/name")
        if name in ("k10temp", "coretemp") and not cpu_temp:
            cpu_temp = f"{h}/temp1_input"
        elif name == "nvme":
            drives.append({"model": read(f"{h}/device/model") or "NVMe", "path": f"{h}/temp1_input"})
    return cpu_temp, drives


def cpu_times():
    """[(busy, total)] for the aggregate line followed by each thread."""
    out = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        vals = list(map(int, line.split()[1:]))
        idle = vals[3] + vals[4]
        total = sum(vals[:8])
        out.append((total - idle, total))
    return out


def pct(prev, cur):
    db, dt = cur[0] - prev[0], cur[1] - prev[1]
    return round(100 * db / dt, 1) if dt > 0 else 0.0


def cpu_freq():
    mhz = [float(l.split(":")[1]) for l in read("/proc/cpuinfo").splitlines() if l.startswith("cpu MHz")]
    return round(sum(mhz) / len(mhz) / 1000, 2) if mhz else 0


def meminfo():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, v = line.split(":")
        m[k] = int(v.split()[0]) * 1024
    return {
        "total": m["MemTotal"],
        "used": m["MemTotal"] - m["MemAvailable"],
        "swapTotal": m["SwapTotal"],
        "swapUsed": m["SwapTotal"] - m["SwapFree"],
    }


def default_iface():
    for line in read("/proc/net/route").splitlines()[1:]:
        f = line.split()
        if f[1] == "00000000":
            return f[0]
    return None


def net_bytes(iface):
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, data = line.split(":", 1)
        if name.strip() == iface:
            f = data.split()
            return int(f[0]), int(f[8])
    return 0, 0


def disks():
    """Real filesystems, one entry per device (btrfs subvolumes share one)."""
    seen, out = set(), []
    for line in read("/proc/mounts").splitlines():
        dev, mount, fstype = line.split()[:3]
        if not dev.startswith("/dev/") or fstype in ("squashfs", "iso9660") or dev in seen:
            continue
        seen.add(dev)
        try:
            st = os.statvfs(mount.replace("\\040", " "))
        except OSError:
            continue
        size = st.f_blocks * st.f_frsize
        if size == 0:
            continue
        out.append({"mount": mount, "size": size, "used": size - st.f_bfree * st.f_frsize})
    return out


def gpu():
    if not shutil.which("nvidia-smi"):
        return None
    fields = "name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,fan.speed,clocks.gr"
    try:
        out = subprocess.run(
            ["nvidia-smi", f"--query-gpu={fields}", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2,
        ).stdout.splitlines()[0]
    except (subprocess.SubprocessError, IndexError):
        return None

    def num(s):
        try:
            return float(s)
        except ValueError:
            return 0

    v = [s.strip() for s in out.split(",")]
    return {
        "name": v[0].replace("NVIDIA GeForce ", ""),
        "usage": num(v[1]), "temp": num(v[2]),
        "memUsed": num(v[3]) * 1024 ** 2, "memTotal": num(v[4]) * 1024 ** 2,
        "power": num(v[5]), "powerLimit": num(v[6]),
        "fan": num(v[7]), "clock": num(v[8]),
    }


def main():
    cpu_temp_path, drives = find_sensors()
    cpu_name = next((l.split(":")[1].strip() for l in read("/proc/cpuinfo").splitlines()
                     if l.startswith("model name")), "CPU")
    cpu_name = cpu_name.replace(" Processor", "").replace("AMD ", "").replace("Intel(R) Core(TM) ", "")
    iface = default_iface()

    prev_cpu = cpu_times()
    prev_net = net_bytes(iface)
    prev_t = time.monotonic()

    while True:
        time.sleep(INTERVAL)
        now = time.monotonic()
        dt = now - prev_t

        cur_cpu = cpu_times()
        usages = [pct(p, c) for p, c in zip(prev_cpu, cur_cpu)]
        cur_net = net_bytes(iface)

        load = read("/proc/loadavg").split()
        stats = {
            "cpu": {
                "name": cpu_name,
                "usage": usages[0],
                "threads": usages[1:],
                "temp": int(read(cpu_temp_path, "0")) / 1000 if cpu_temp_path else None,
                "freq": cpu_freq(),
                "load": [float(x) for x in load[:3]],
            },
            "procs": int(load[3].split("/")[1]),
            "mem": meminfo(),
            "gpu": gpu(),
            "net": {
                "iface": iface or "",
                "rx": max(0, (cur_net[0] - prev_net[0]) / dt),
                "tx": max(0, (cur_net[1] - prev_net[1]) / dt),
            },
            "disks": disks(),
            "drives": [{"model": d["model"], "temp": int(read(d["path"], "0")) / 1000} for d in drives],
        }
        print(json.dumps(stats), flush=True)

        prev_cpu, prev_net, prev_t = cur_cpu, cur_net, now


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
