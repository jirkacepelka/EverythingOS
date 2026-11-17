#!/usr/bin/env bash
# Nasadí fork do ~/.config (settings.json a fonts.conf se nepřepisují)
set -e
D=$(cd "$(dirname "$0")" && pwd)
rsync -a --exclude settings.json --exclude fonts.conf --exclude '*.bak*' "$D/panacea/" "$HOME/.config/panacea/"
rsync -a "$D/hypr/custom/" "$HOME/.config/hypr/custom/"
install -m755 "$D/hypr/scripts/focus_or_workspace.sh" "$HOME/.config/hypr/scripts/"
echo deployed
