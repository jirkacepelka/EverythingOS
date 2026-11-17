import QtQuick

// Catalogue of the widgets that can be placed on the desktop from the tray.
// bare: true means no card background or border (the widget sits straight on the wallpaper).
// minW/maxW/minH/maxH are the resize limits in cells (like Android widgets, each type has its own).
// The desktop is a grid of square cells (pitch 78 px, cell 66 px, gap 12 px):
// cw x ch is the span in cells, w / h the resulting card size in pixels.
QtObject {
    readonly property int pitch: 78
    readonly property int gap: 12
    function px(cells) { return cells * pitch - gap; }

    readonly property var types: [
        { id: "volume",       name: "Sound",      cw: 4, ch: 1, minW: 3, maxW: 8, minH: 1, maxH: 1 },
        { id: "brightness",   name: "Brightness", cw: 4, ch: 1, minW: 3, maxW: 8, minH: 1, maxH: 1 },
        { id: "clockAnalog",  name: "Analog",     cw: 2, ch: 2, minW: 2, maxW: 4, minH: 2, maxH: 4 },
        { id: "clockRing",    name: "Ring clock", cw: 2, ch: 2, minW: 2, maxW: 4, minH: 2, maxH: 4 },
        { id: "clockDot",     name: "Dot clock",  cw: 4, ch: 2, minW: 3, maxW: 8, minH: 1, maxH: 3 },
        { id: "clockFlip",    name: "Flip clock", cw: 4, ch: 2, minW: 3, maxW: 8, minH: 2, maxH: 4 },
        { id: "battery",      name: "Battery",    cw: 2, ch: 2, minW: 2, maxW: 4, minH: 1, maxH: 3 },
        { id: "calendar",     name: "Calendar",   cw: 4, ch: 3, minW: 4, maxW: 8, minH: 3, maxH: 5 },
        { id: "clockHuge",    name: "Huge clock", cw: 8, ch: 3, bare: true, minW: 4, maxW: 12, minH: 2, maxH: 4 },
        { id: "clockMinimal", name: "Minimal",    cw: 4, ch: 1, bare: true, minW: 3, maxW: 8, minH: 1, maxH: 2 },
        { id: "date",         name: "Date",       cw: 2, ch: 2, minW: 2, maxW: 3, minH: 2, maxH: 3 },
        { id: "weather",      name: "Weather",    cw: 2, ch: 2, minW: 2, maxW: 4, minH: 2, maxH: 4 },
        { id: "progress",     name: "Day",        cw: 4, ch: 1, minW: 3, maxW: 8, minH: 1, maxH: 1 }
    ].map(function (t) { t.w = t.cw * 78 - 12; t.h = t.ch * 78 - 12; return t; })

    function find(id) {
        if (id === "clockDigital") id = "clockDot";   // renamed
        for (var i = 0; i < types.length; i++) if (types[i].id === id) return types[i];
        return null;
    }
}
