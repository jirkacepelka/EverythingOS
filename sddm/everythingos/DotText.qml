import QtQuick 2.15

// Dot-matrix digits (5x7 grid of round dots), self-contained copy of the shell's DotText.
Item {
    id: dt
    property string value: ""
    property real size: 14
    property real gapRatio: 0.22
    property color color: "#ffffff"
    readonly property real dotSize: dt.size / (7 + 6 * dt.gapRatio)
    readonly property real gap: dt.dotSize * dt.gapRatio
    readonly property real pitch: dt.dotSize + dt.gap
    property real charGap: dt.dotSize + dt.gap

    readonly property var glyphs: ({
        "0": ["01110","10001","10001","10001","10001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["0","0","1","0","0","1","0"],
        " ": ["00","00","00","00","00","00","00"],
        "A": ["01110","10001","10001","11111","10001","10001","10001"],
        "P": ["11110","10001","10001","11110","10000","10000","10000"],
        "M": ["10001","11011","10101","10001","10001","10001","10001"]
    })

    readonly property var cells: {
        var out = [];
        var s = String(dt.value);
        var cx = 0;
        for (var i = 0; i < s.length; i++) {
            var g = dt.glyphs[s[i]];
            var w = g ? g[0].length : 3;
            if (g) {
                for (var r = 0; r < g.length; r++)
                    for (var c = 0; c < w; c++)
                        if (g[r][c] === "1")
                            out.push({ x: cx + c * dt.pitch, y: r * dt.pitch });
            }
            cx += w * dt.pitch;
            if (i < s.length - 1) cx += dt.charGap;
        }
        return out;
    }
    implicitWidth: {
        var s = String(dt.value);
        if (!s.length) return 0;
        var w = 0;
        for (var i = 0; i < s.length; i++) {
            var g = dt.glyphs[s[i]];
            w += (g ? g[0].length : 3) * dt.pitch;
        }
        return w + (s.length - 1) * dt.charGap - dt.gap;
    }
    implicitHeight: 7 * dt.pitch - dt.gap
    width: implicitWidth
    height: implicitHeight

    Repeater {
        model: dt.cells
        Rectangle {
            x: modelData.x; y: modelData.y
            width: dt.dotSize; height: dt.dotSize
            radius: dt.dotSize / 2
            color: dt.color
        }
    }
}
