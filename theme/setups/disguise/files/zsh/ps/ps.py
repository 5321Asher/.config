#!/usr/bin/env python3
"""Windows PowerShell's output for the commands Disguise's shell answers (files/zsh/setup.zsh):

  ps.py dir [path] [-Force|-a]     Get-ChildItem's table (Mode, LastWriteTime, Length, Name)
  ps.py ipconfig [/all]            Windows IP Configuration, from `ip -j`

Paths are shown Windows-style: /home/av/x -> C:\\Users\\av\\x, /etc -> C:\\etc.
"""

import datetime
import json
import os
import stat
import subprocess
import sys

HOME = os.path.expanduser("~")
USER = os.environ.get("USER", "user")


def winpath(p):
    p = os.path.abspath(p)
    if p == HOME or p.startswith(HOME + "/"):
        p = f"C:/Users/{USER}" + p[len(HOME):]
    else:
        p = "C:" + p
    return p.replace("/", "\\")


def when(ts):
    d = datetime.datetime.fromtimestamp(ts)
    date = f"{d.month}/{d.day}/{d.year}"
    h = d.hour % 12 or 12
    return f"{date:>18}{f'{h}:{d.minute:02d} {"AM" if d.hour < 12 else "PM"}':>10}"


def mode(path, st, name):
    link = os.path.islink(path)
    is_dir = stat.S_ISDIR(st.st_mode)
    return "".join([
        "d" if is_dir else "-",
        "-" if is_dir else "a",
        "r" if not os.access(path, os.W_OK) else "-",
        "h" if name.startswith(".") else "-",
        "-",
        "l" if link else "-",
    ])


def cmd_dir(args):
    force = any(a.lower() in ("-force", "-a", "-fo", "-hidden") for a in args)
    paths = [a for a in args if not a.startswith("-")] or ["."]
    status = 0
    for target in paths:
        if not os.path.exists(target):
            print(f"\x1b[91mGet-ChildItem : Cannot find path '{winpath(target)}' because it does not exist.\x1b[0m", file=sys.stderr)
            status = 1
            continue
        if os.path.isdir(target):
            names = [n for n in os.listdir(target) if force or not n.startswith(".")]
            entries = [(n, os.path.join(target, n)) for n in names]
            folder = target
        else:
            entries = [(os.path.basename(target), target)]
            folder = os.path.dirname(os.path.abspath(target))
        rows = []
        for name, path in entries:
            try:
                st = os.lstat(path) if os.path.islink(path) and not os.path.exists(path) else os.stat(path)
            except OSError:
                continue
            rows.append((not stat.S_ISDIR(st.st_mode), name.lower(), name, path, st))
        rows.sort()
        print()
        print(f"    Directory: {winpath(folder)}")
        print()
        print()
        print("Mode                 LastWriteTime         Length Name")
        print("----                 -------------         ------ ----")
        for is_file, _, name, path, st in rows:
            length = f"{st.st_size:>15}" if is_file else " " * 15
            print(f"{mode(path, st, name)}{when(st.st_mtime)}{length} {name}")
        print()
        print()
    return status


def cmd_ipconfig(args):
    full = any(a.lower() in ("/all", "-all") for a in args)
    try:
        addrs = json.loads(subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True).stdout)
        routes = json.loads(subprocess.run(["ip", "-j", "route"], capture_output=True, text=True).stdout)
    except (OSError, json.JSONDecodeError):
        addrs, routes = [], []
    gateways = {r.get("dev"): r.get("gateway") for r in routes if r.get("dst") == "default" and r.get("gateway")}
    print()
    print("Windows IP Configuration")
    print()
    if full:
        print(f"   Host Name . . . . . . . . . . . . : {os.uname().nodename.split('.')[0].upper()}")
        print("   Primary Dns Suffix  . . . . . . . : ")
        print("   Node Type . . . . . . . . . . . . : Hybrid")
        print("   IP Routing Enabled. . . . . . . . : No")
        print("   WINS Proxy Enabled. . . . . . . . : No")
        print()
    eth = wifi = 0
    for a in addrs:
        name = a.get("ifname", "")
        if name == "lo" or name.startswith(("docker", "veth", "br-", "virbr")):
            continue
        if name.startswith("wl"):
            wifi += 1
            title = "Wireless LAN adapter Wi-Fi" + (f" {wifi}" if wifi > 1 else "")
        elif name.startswith(("en", "eth")):
            eth += 1
            title = "Ethernet adapter Ethernet" + (f" {eth}" if eth > 1 else "")
        else:
            title = f"Unknown adapter {name.rstrip('0123456789').capitalize() or name}"
        print()
        print(f"{title}:")
        print()
        infos = a.get("addr_info", [])
        up = "UP" in a.get("flags", []) and "LOWER_UP" in a.get("flags", [])
        if not up or not infos:
            print("   Media State . . . . . . . . . . . : Media disconnected")
            print("   Connection-specific DNS Suffix  . : ")
            continue
        print("   Connection-specific DNS Suffix  . : lan" if name in gateways else "   Connection-specific DNS Suffix  . : ")
        if full:
            print(f"   Physical Address. . . . . . . . . : {a.get('address', '').upper().replace(':', '-')}")
            print("   DHCP Enabled. . . . . . . . . . . : Yes")
        for i in infos:
            if i.get("family") == "inet6" and i.get("scope") == "link":
                print(f"   Link-local IPv6 Address . . . . . : {i['local']}%{a.get('ifindex')}")
            elif i.get("family") == "inet6":
                print(f"   IPv6 Address. . . . . . . . . . . : {i['local']}")
        for i in infos:
            if i.get("family") == "inet":
                bits = i.get("prefixlen", 24)
                m = (0xffffffff << (32 - bits)) & 0xffffffff
                mask = ".".join(str((m >> s) & 0xff) for s in (24, 16, 8, 0))
                print(f"   IPv4 Address. . . . . . . . . . . : {i['local']}")
                print(f"   Subnet Mask . . . . . . . . . . . : {mask}")
        print(f"   Default Gateway . . . . . . . . . : {gateways.get(name, '')}")
    print()
    return 0


if __name__ == "__main__":
    cmd, rest = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("dir", [])
    sys.exit({"dir": cmd_dir, "ipconfig": cmd_ipconfig}.get(cmd, cmd_dir)(rest))
