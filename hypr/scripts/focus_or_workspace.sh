#!/usr/bin/env bash
# Super+Left/Right: move focus to the neighbouring window; if there is none in that
# direction, switch to the previous/next workspace instead.
dir=$1   # left | right
case "$dir" in
  left)  ws='r-1' ;;
  right) ws='r+1' ;;
  *) exit 1 ;;
esac
before=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
hyprctl dispatch "hl.dsp.focus({direction=\"$dir\"})" >/dev/null 2>&1
after=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
if [ "$before" = "$after" ]; then
  hyprctl dispatch "hl.dsp.focus({workspace=\"$ws\"})" >/dev/null 2>&1
fi
