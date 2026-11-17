#!/usr/bin/env bash
# Read-only snapshot of the SDDM setup for Settings > Login (no root needed).
# One JSON object on stdout.
python3 - <<'PY'
import glob, json, os, re, pwd, configparser
def read_conf():
    files = ["/usr/lib/sddm/sddm.conf.d/*.conf"] + ["/etc/sddm.conf.d/*.conf"]
    paths = sorted(sum((glob.glob(f) for f in files), []), key=os.path.basename)
    if os.path.isfile("/etc/sddm.conf"): paths.append("/etc/sddm.conf")
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    for p in paths:
        try: cp.read(p)
        except Exception: pass
    return cp
cp = read_conf()
g = lambda s, k: cp.get(s, k, fallback="")
themes = []
for d in sorted(glob.glob("/usr/share/sddm/themes/*/")):
    n = os.path.basename(d.rstrip("/"))
    name = n
    try:
        m = re.search(r"^Name=(.+)$", open(d + "metadata.desktop").read(), re.M)
        if m: name = m.group(1).strip()
    except Exception: pass
    themes.append({"id": n, "text": name})
sessions = []
for d in ("/usr/share/wayland-sessions", "/usr/share/xsessions"):
    for f in sorted(glob.glob(d + "/*.desktop")):
        m = re.search(r"^Name=(.+)$", open(f).read(), re.M)
        sessions.append({"id": os.path.basename(f), "text": (m.group(1).strip() if m else os.path.basename(f)) + (" (X11)" if "xsessions" in d else "")})
users = [u.pw_name for u in pwd.getpwall() if 1000 <= u.pw_uid < 60000 and u.pw_shell not in ("/usr/sbin/nologin", "/bin/false")]
print(json.dumps({
    "themes": themes, "sessions": sessions, "users": users,
    "current": g("Theme", "Current"),
    "autologinUser": g("Autologin", "User"), "autologinSession": g("Autologin", "Session"),
    "installed": os.path.isfile("/usr/share/sddm/themes/everythingos/metadata.desktop"),
    "confExists": os.path.isfile("/etc/sddm.conf.d/20-everythingos.conf"),
    "stateWritable": os.access("/var/lib/panacea", os.W_OK),
    "me": os.environ.get("USER", ""),
}))
PY
