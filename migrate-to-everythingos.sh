#!/usr/bin/env bash
# One-time migration of an installed Panacea/EverythingOS from ~/.config/panacea
# to ~/.config/everythingos (config dir, cache, data, systemd unit, compositor
# configs). Restarts the shell once. Safe to re-run. The old config dir is kept
# as ~/.config/panacea.pre-everythingos (rollback: see the end of the output).
#
#   ./migrate-to-everythingos.sh            # do it
#   ./migrate-to-everythingos.sh --dry-run  # only print what would happen
set -eu
D=$(cd "$(dirname "$0")" && pwd)
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
UNITS="$CFG/systemd/user"

run() { echo "+ $*"; [ "$DRY" = 1 ] || "$@"; }

[ -d "$CFG/panacea" ] || [ -d "$CFG/everythingos" ] || { echo "nothing to migrate"; exit 0; }

# 1. stop the old shell first, so its in-memory settings are flushed to disk
run systemctl --user stop panacea-shell.service 2>/dev/null || true

# 2. move user state (config copy keeps settings.json, fonts.conf, .version, ...)
if [ -d "$CFG/panacea" ] && [ ! -L "$CFG/panacea" ]; then
    [ -d "$CFG/everythingos" ] || run cp -a "$CFG/panacea" "$CFG/everythingos"
fi
for p in "$CACHE" "$DATA"; do
    if [ -d "$p/panacea" ] && [ ! -L "$p/panacea" ] && [ ! -e "$p/everythingos" ]; then
        run mv "$p/panacea" "$p/everythingos"
    fi
done

# 3. install the new tree over the copy (settings.json / fonts.conf are kept)
run "$D/deploy.sh"

# 4. systemd unit + drop-ins
run mkdir -p "$UNITS/everythingos-shell.service.d"
run install -m644 "$D/everythingos/everythingos-shell.service" "$UNITS/everythingos-shell.service"
if [ "$DRY" = 0 ]; then
    cat > "$UNITS/everythingos-shell.service.d/path.conf" <<EOF
[Service]
Environment=PATH=%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=FONTCONFIG_FILE=%h/.config/everythingos/fonts.conf
EOF
fi
run systemctl --user disable panacea-shell.service 2>/dev/null || true
run rm -rf "$UNITS/panacea-shell.service" "$UNITS/panacea-shell.service.d"
run systemctl --user daemon-reload

# 5. compositor configs: point every binding at the new path
for f in "$CFG"/hypr/hyprland.conf "$CFG"/hypr/lua/*.lua "$CFG"/hypr/custom/*.lua \
         "$CFG"/hypr/scripts/*.sh "$CFG"/niri/config.kdl; do
    [ -f "$f" ] && grep -q '\.config/panacea\|\.cache/panacea' "$f" || continue
    run sed -i 's#\.config/panacea#.config/everythingos#g; s#\.cache/panacea#.cache/everythingos#g' "$f"
done

# 6. keep old paths working (external scripts, `qs -c panacea`), old dir kept as backup
if [ -d "$CFG/panacea" ] && [ ! -L "$CFG/panacea" ]; then
    run mv "$CFG/panacea" "$CFG/panacea.pre-everythingos"
fi
[ -e "$CFG/panacea" ] || run ln -s "$CFG/everythingos" "$CFG/panacea"
if [ -d "$CFG/quickshell" ]; then
    run ln -sfn "$CFG/everythingos" "$CFG/quickshell/everythingos"
fi

# 7. start the new shell and reload the compositor config
run systemctl --user enable everythingos-shell.service
run systemctl --user restart everythingos-shell.service
command -v hyprctl >/dev/null && run hyprctl reload || true

cat <<'EOF'

Done. EverythingOS now lives in ~/.config/everythingos (service everythingos-shell).
Rollback: systemctl --user stop everythingos-shell; rm ~/.config/panacea;
          mv ~/.config/panacea.pre-everythingos ~/.config/panacea
          (and restore the old unit from the repo history), then relogin.
EOF
