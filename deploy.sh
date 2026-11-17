#!/usr/bin/env bash
# Nasadí fork do ~/.config (settings.json a fonts.conf se nepřepisují)
set -e
D=$(cd "$(dirname "$0")" && pwd)
rsync -a --exclude settings.json --exclude fonts.conf --exclude '*.bak*' "$D/panacea/" "$HOME/.config/panacea/"
rsync -a "$D/hypr/custom/" "$HOME/.config/hypr/custom/"
rsync -a "$D/hypr/lua/programs.lua" "$D/hypr/lua/workspaces.lua" "$D/hypr/lua/windowrules.lua" "$D/hypr/lua/keybindings.lua" "$D/hypr/lua/autostart.lua" "$HOME/.config/hypr/lua/"
install -m644 "$D/hypr/theme.lua" "$HOME/.config/hypr/theme.lua"
install -m755 "$D/hypr/scripts/focus_or_workspace.sh" "$HOME/.config/hypr/scripts/"
install -Dm644 "$D/foot/nothing.ini" "$HOME/.config/foot/nothing.ini"
install -Dm644 "$D/fastfetch/nothing.jsonc" "$HOME/.config/fastfetch/nothing.jsonc"
install -Dm644 "$D/fastfetch/nothing-logo.txt" "$HOME/.config/fastfetch/nothing-logo.txt"
install -Dm644 "$D/fish/nothing-init.fish" "$HOME/.config/fish/nothing-init.fish"
# Doto (Google Fonts, SIL OFL): dot-matrix font offered in Settings -> Appearance -> fonts
install -Dm644 "$D/fonts/Doto-Variable.ttf" "$HOME/.local/share/fonts/Doto-Variable.ttf"
install -Dm644 "$D/fonts/Doto-OFL.txt" "$HOME/.local/share/fonts/Doto-OFL.txt"
# Space Mono (Google Fonts, SIL OFL): legible Nothing-like monospace, full Czech coverage
for f in SpaceMono-Regular.ttf SpaceMono-Bold.ttf SpaceMono-OFL.txt; do
    install -Dm644 "$D/fonts/$f" "$HOME/.local/share/fonts/$f"
done
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
echo deployed
