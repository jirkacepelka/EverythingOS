#!/usr/bin/env bash
# Super+Left/Right: move focus to the neighbouring window; if there is none in that
# direction, switch to the previous/next workspace instead.
#
# Hyprland's focus-direction wraps around (from the right-most window it jumps to the
# left-most one), so "did focus change?" cannot detect the edge. We look at the window
# geometry instead: is there another window on this workspace further in that direction?
dir=$1   # left | right
case "$dir" in
  left)  ws='r-1' ;;
  right) ws='r+1' ;;
  *) exit 1 ;;
esac

act=$(hyprctl activewindow -j 2>/dev/null)
addr=$(jq -r '.address // empty' <<<"$act")
if [ -n "$addr" ]; then
  neighbour=$(hyprctl clients -j 2>/dev/null | jq -r --arg a "$addr" --arg d "$dir" '
    (.[] | select(.address == $a)) as $me
    | ($me.at[0] + $me.size[0] / 2) as $cx
    | [ .[] | select(.mapped and (.hidden | not) and .address != $a
                     and .workspace.id == $me.workspace.id
                     and (if $d == "right" then (.at[0] + .size[0] / 2) > $cx
                                            else (.at[0] + .size[0] / 2) < $cx end)) ]
    | length')
  if [ "${neighbour:-0}" -gt 0 ]; then
    hyprctl dispatch "hl.dsp.focus({direction=\"$dir\"})" >/dev/null 2>&1
    exit 0
  fi
fi
hyprctl dispatch "hl.dsp.focus({workspace=\"$ws\"})" >/dev/null 2>&1
