#!/usr/bin/env bash
# Publishes the current look to the SDDM greeter (which cannot read ~):
#   /var/lib/panacea/login.qml    colors, font, clock format, hint (QML fragment)
#   /var/lib/panacea/sddm-bg.jpg  wallpaper, scaled and blurred
# The directory is created by sddm/install.sh and owned by the user, so no root
# is needed here. Silently does nothing if the theme is not installed.
# Also prints the file paths the lock screen / preview use:  login-sync.sh bg lock|login
set -u
STATE=/var/lib/panacea
CFG="$HOME/.config/everythingos/settings.json"
WALLCONF="$HOME/.config/hypr/wallpaper.conf"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/everythingos"

cur_wall() {
    local w
    w=$(grep -m1 '^\$wallpaper' "$WALLCONF" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//')
    printf '%s' "${w/#\~/$HOME}"
}

# resolve the background source for "lock" or "login": prints a path or nothing (black)
bg_source() {
    python3 - "$1" "$CFG" "$(cur_wall)" <<'PY'
import json, os, sys
which, cfgp, wall = sys.argv[1:4]
try: c = json.load(open(cfgp))
except Exception: c = {}
mode = c.get(which + "BgMode", "wallpaper")
if mode == "black": sys.exit(0)
if mode == "custom":
    p = os.path.expanduser(c.get(which + "BgPath", ""))
    if os.path.isfile(p): print(p); sys.exit(0)
if wall and wall != "black" and os.path.isfile(wall): print(wall)
PY
}

if [ "${1:-}" = bg ]; then bg_source "${2:-lock}"; exit 0; fi

[ -w "$STATE" ] || exit 0

python3 - "$CFG" "$STATE" <<'PY'
import json, os, sys
cfgp, state = sys.argv[1:3]
try: c = json.load(open(cfgp))
except Exception: c = {}
import re
# palette comes from the shell's own table (Themes.js), not a copy
themes = {}
try:
    js = open(os.path.expanduser("~/.config/everythingos/Themes.js")).read()
    for m in re.finditer(r'id: "(\w+)".*?bg: "(#\w+)", fg: "(#\w+)".*?crit: "(#\w+)"', js):
        themes[m.group(1)] = (m.group(2), m.group(3), m.group(4))
except Exception: pass
themes.setdefault("nothing", ("#000000", "#ffffff", "#d71921"))
bg, fg, crit = themes.get(c.get("themeId", "nothing"), themes["nothing"])
font = c.get("fontBody") or c.get("fontFam") or "Space Mono"
def q(s): return str(s).replace("\\", "\\\\").replace('"', '\\"')
out = ('import QtQuick 2.15\nQtObject {\n'
  f'  property color bg: "{bg}"\n  property color fg: "{fg}"\n  property color accent: "{crit}"\n'
  f'  property string font: "{q(font)}"\n'
  f'  property bool clock12: {"true" if c.get("clock12") else "false"}\n'
  f'  property bool showClock: {"true" if c.get("loginShowClock", True) else "false"}\n'
  f'  property string hint: "{q(c.get("loginHint", ""))}"\n'
  f'  property real dim: {max(0, min(100, int(c.get("loginDim", 45)))) / 100}\n'
  f'  property bool useBg: {"false" if c.get("loginBgMode") == "black" else "true"}\n'
  '}\n')
tmp = os.path.join(state, "login.qml.tmp")
open(tmp, "w").write(out); os.chmod(tmp, 0o644); os.replace(tmp, os.path.join(state, "login.qml"))
PY

src=$(bg_source login)
if [ -n "$src" ]; then
    blur=$(python3 -c "import json;print(int(json.load(open('$CFG')).get('loginBlur',0)))" 2>/dev/null || echo 0)
    vf="scale='min(1920,iw)':-2"
    # cheap blur: shrink, box-blur, the greeter scales it back up
    [ "$blur" -gt 0 ] && vf="scale='min(960,iw)':-2,boxblur=$(( blur / 8 + 1 )):2"
    ffmpeg -loglevel error -y -i "$src" -vf "$vf" -q:v 3 "$STATE/sddm-bg.tmp.jpg" </dev/null \
        && chmod 644 "$STATE/sddm-bg.tmp.jpg" && mv -f "$STATE/sddm-bg.tmp.jpg" "$STATE/sddm-bg.jpg"
else
    rm -f "$STATE/sddm-bg.jpg"
fi
