#!/usr/bin/env python3
"""Watches D-Bus for progress that other programs already publish and prints
one line per change:  <id>\t<label>\t<percent 0-100 or -1>\t<1 active|0 finished>

Sources:
  * com.canonical.Unity.LauncherEntry.Update (session bus): the de-facto
    "progress on the dock icon" API - browsers' downloads, file managers,
    Telegram, Steam, many Qt/GTK apps use it.
  * org.freedesktop.PackageKit transactions (system bus): apt/dnf installs
    from software centers (Percentage / Status).
Flatpak jobs (Bazaar, flatpak CLI) publish nothing, so they are detected by activity
in the ostree repo and shown with an unknown total.
"""
import os, re, select, subprocess, sys, threading, time

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

def flatpak_watch():
    """libflatpak (Bazaar, `flatpak install`) publishes no progress, but it writes into the
    ostree repo while it pulls/deploys: recent mtimes there mean "a Flatpak job is running".
    The total is unknown, so the shell shows a slowly filling bar."""
    repos = ["/var/lib/flatpak/repo", os.path.expanduser("~/.local/share/flatpak/repo")]
    active = False
    last_change = 0.0
    while True:
        newest = 0.0
        for r in repos:
            try:
                newest = max(newest, os.stat(r).st_mtime)
                newest = max(newest, os.stat(r + "/tmp").st_mtime)
                with os.scandir(r + "/objects") as it:
                    for e in it:
                        newest = max(newest, e.stat().st_mtime)
                with os.scandir(r + "/tmp") as it:
                    for e in it:
                        if e.name != "cache": newest = max(newest, e.stat().st_mtime)
            except OSError:
                pass
        now = time.time()
        if newest > last_change: last_change = newest
        busy = now - last_change < 6
        if busy and not active: out("flatpak", "Flatpak", -1, 1)
        elif busy: out("flatpak", "Flatpak", -1, 1)
        elif active: out("flatpak", "Flatpak", 100, 0)
        active = busy
        time.sleep(1)

def download_watch():
    """Firefox (and others) expose no progress API, but write the file as name.ext.part /
    .crdownload while downloading. A growing partial file in ~/Downloads = a download."""
    d = os.path.expanduser("~/Downloads")
    exts = (".part", ".crdownload", ".download", ".opdownload")
    active = False
    while True:
        busy = False
        try:
            now = time.time()
            with os.scandir(d) as it:
                for e in it:
                    if e.name.endswith(exts) and now - e.stat().st_mtime < 4:
                        busy = True
                        break
        except OSError:
            pass
        if busy: out("download", "Downloading", -1, 1)
        elif active: out("download", "Downloading", 100, 0)
        active = busy
        time.sleep(1)

threading.Thread(target=flatpak_watch, daemon=True).start()
threading.Thread(target=download_watch, daemon=True).start()
threading.Thread(target=monitor, daemon=True, args=("system",
    ["type='signal',sender='org.freedesktop.PackageKit'"], packagekit)).start()
monitor("session", ["type='signal',interface='com.canonical.Unity.LauncherEntry'"], launcher)
