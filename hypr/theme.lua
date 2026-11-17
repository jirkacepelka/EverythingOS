local okGap, gd = pcall(require, "lua.gaps_data")
local GAP = (okGap and type(gd) == "table" and gd.gap) or 16
local BW = (okGap and type(gd) == "table" and gd.bw) or 1
local RD = (okGap and type(gd) == "table" and gd.rd) or 12
local BA = (okGap and type(gd) == "table" and gd.ba) or 55
local BAH = string.format("%02x", math.floor(BA * 255 / 100))
local BIH = string.format("%02x", math.floor(BA * 255 / 200))
local BC = (okGap and type(gd) == "table" and gd.bc) or "9a9aa2"
return {
    gaps_in = GAP,
    gaps_out = GAP,
    border_size = BW,
    -- Рамка активного окна. Красный конец прежнего градиента лез в кадр
    -- полосой под островом и спорил с чёрно-белой оболочкой; здесь он ничего
    -- не обозначал — просто цвет.
    active_border = "rgba(" .. BC .. BAH .. ")",
    inactive_border = "rgba(" .. BC .. BIH .. ")",
    rounding = RD,
    rounding_power = 4.0,
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    shadow_enabled = false,
    shadow_range = 4,
    shadow_render_power = 3,
    shadow_color = "rgba(1a1a1aee)",
    blur_enabled = false,
    blur_size = 3,
    blur_passes = 1,
    blur_vibrancy = 0.1696,
}
