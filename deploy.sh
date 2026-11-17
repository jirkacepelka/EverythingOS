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
echo deployed
