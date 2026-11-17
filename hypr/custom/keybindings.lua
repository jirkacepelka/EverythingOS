-- Custom Keybindings & Shortcuts (Lua)
--
-- API: hl.bind(combo, dispatcher [, options])
-- Dispatchers live in hl.dsp — hl.dsp.exec_cmd, hl.dsp.killactive, ...
--
-- Examples:
-- hl.bind("SUPER + C", hl.dsp.exec_cmd("code"))
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("brave"))
-- hl.bind("SUPER + SHIFT + Q", hl.dsp.killactive())

-- Super+Left/Right: focus the neighbouring window; at the edge switch workspace
local HOME = os.getenv("HOME")
local fow = HOME .. "/.config/hypr/scripts/focus_or_workspace.sh"
hl.bind("SUPER + left",  hl.dsp.exec_cmd(fow .. " left"))
hl.bind("SUPER + right", hl.dsp.exec_cmd(fow .. " right"))

-- Samotný Super (stisk a pustit) otevře přehled ploch; psaní tam spustí hledání aplikací
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("qs -c " .. HOME .. "/.config/panacea ipc call pill overview"), { release = true })

-- Alt+Tab / Alt+Shift+Tab: přepínání oken (cyklus + zvednutí nad ostatní)
hl.bind("ALT + Tab",         hl.dsp.window.cycle_next({}))
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
