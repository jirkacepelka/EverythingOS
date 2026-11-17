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

-- Alt+Tab / Alt+Shift+Tab: vizuální přepínač oken; potvrzuje se pustěním Alt
local PILL = "qs -c " .. HOME .. "/.config/panacea ipc call pill "
hl.bind("ALT + Tab",         hl.dsp.exec_cmd(PILL .. "switcherNext"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(PILL .. "switcherPrev"))
for _, c in ipairs({ "ALT + Alt_L", "ALT + SHIFT + Alt_L", "SHIFT + Alt_L", "ALT + Alt_R", "ALT + SHIFT + Alt_R" }) do
    hl.bind(c, hl.dsp.exec_cmd(PILL .. "switcherDone"), { release = true })
end

-- Super+Shift+D: režim úprav rozložení widgetů (přetahování myší)
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("qs -c " .. HOME .. "/.config/panacea ipc call pill widgetsEdit"))
