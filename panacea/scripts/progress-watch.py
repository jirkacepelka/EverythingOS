#!/usr/bin/env python3
"""Watches D-Bus for progress that other programs already publish and prints
one line per change:  <id>\t<label>\t<percent 0-100 or -1>\t<1 active|0 finished>

Sources:
  * com.canonical.Unity.LauncherEntry.Update (session bus): the de-facto
    "progress on the dock icon" API - browsers' downloads, file managers,
    Telegram, Steam, many Qt/GTK apps use it.
  * org.freedesktop.PackageKit transactions (system bus): apt/dnf installs
    from software centers (Percentage / Status).
Apps that talk to libflatpak in-process (e.g. Bazaar) publish neither, so they
cannot be followed from outside.
"""
import os, re, select, subprocess, sys, threading

def out(*a):
    print("\t".join(str(x) for x in a), flush=True)

def monitor(bus, rules, handler):
    cmd = ["dbus-monitor", "--" + bus] + rules
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    fd = p.stdout.fileno()
    block, buf = [], b""
    while True:
        # a message has no terminator: flush it once the stream pauses
        ready = select.select([fd], [], [], 0.1)[0]
        if not ready:
            if block: handler(block); block = []
            if p.poll() is not None: return
            continue
        chunk = os.read(fd, 65536)
        if not chunk: break
        buf += chunk
        *lines, buf = buf.split(b"\n")
        for raw in lines:
            line = raw.decode("utf-8", "replace") + "\n"
            if line.startswith("signal "):
                if block: handler(block)
                block = [line]
            elif block:
                block.append(line)
    if block: handler(block)

def launcher(block):
    txt = "".join(block)
    if "member=Update" not in block[0]: return
    m = re.search(r'string "application://([^"]+)"', txt)
    if not m: return
    app = m.group(1).removesuffix(".desktop")
    prog = re.search(r'string "progress"\s+variant\s+double ([0-9.eE+-]+)', txt)
    vis = re.search(r'string "progress-visible"\s+variant\s+boolean (true|false)', txt)
    if not prog and not vis: return
    active = vis.group(1) == "true" if vis else True
    pct = round(float(prog.group(1)) * 100) if prog else -1
    out("launcher:" + app, app, pct, 1 if active else 0)

def packagekit(block):
    txt = "".join(block)
    path = re.search(r"path=([^;]+);", block[0])
    pid = "pk:" + (path.group(1) if path else "?")
    if "member=PropertiesChanged" in block[0]:
        m = re.search(r'string "Percentage"\s+variant\s+uint32 (\d+)', txt)
        if m:
            pct = int(m.group(1))
            out(pid, "Installing packages", pct if pct <= 100 else -1, 1)
    elif "member=Finished" in block[0]:
        out(pid, "Installing packages", 100, 0)

threading.Thread(target=monitor, daemon=True, args=("system",
    ["type='signal',sender='org.freedesktop.PackageKit'"], packagekit)).start()
monitor("session", ["type='signal',interface='com.canonical.Unity.LauncherEntry'"], launcher)
