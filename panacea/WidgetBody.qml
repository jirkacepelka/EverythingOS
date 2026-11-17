pragma ComponentBehavior: Bound
import QtQuick

// Contents of a tray widget, chosen by type. Built from the same dot-matrix
// digits (WNum), captions (WCaption) and card chrome (WCard) as the built-in
// desktop widgets. Used both on the desktop and for the live previews in the tray.
Item {
    id: root

    property var sys
    property string type: ""
    property bool interactive: true
    readonly property color red: sys ? sys.colCrit : "#D71921"
    readonly property color fg: sys ? sys.colFg : "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.18)

    function two(n) { return ("0" + n).slice(-2); }

    // Bodies with a fixed design are laid out at their design size and scaled uniformly to the card
    // (like Android widgets they stay legible when resized); the rest reflow to the card size.
    readonly property var designs: ({
        battery:   { w: 144, h: 144 },
        date:      { w: 144, h: 144 },
        weather:   { w: 144, h: 144 },
        clockDot:  { w: 300, h: 144 },
        clockFlip: { w: 300, h: 144 },
        calendar:  { w: 300, h: 222 }
    })
    readonly property var design: designs[root.type] || null

    Loader {
        anchors.centerIn: parent
        width: root.design ? root.design.w : root.width
        height: root.design ? root.design.h : root.height
        scale: root.design ? Math.min(root.width / root.design.w, root.height / root.design.h) : 1
        sourceComponent: {
            switch (root.type) {
            case "volume": return volumeBody;
            case "brightness": return brightBody;
            case "clockAnalog": return analogBody;
            case "clockRing": return ringBody;
            case "clockDot": return dotClockBody;
            case "clockFlip": return flipBody;
            case "battery": return batteryBody;
            case "calendar": return calendarBody;
            case "clockHuge": return hugeBody;
            case "clockMinimal": return minimalBody;
            case "date": return dateBody;
            case "weather": return weatherBody;
            case "progress": return progressBody;
            }
            return null;
        }
    }

    // segmented dot bar: white dots up to the level, the last one red, the rest dim
    component DotBar: Item {
        id: bar
        property real value: 0
        property int count: Math.max(8, Math.floor(width / 16))
        property bool locked: false
        signal moved(real v)
        readonly property real d: Math.min(height, (width - (count - 1) * 4) / count)
        readonly property int lit: Math.round(value * count)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: (bar.width - bar.count * bar.d) / Math.max(1, bar.count - 1)
            Repeater {
                model: bar.count
                Rectangle {
                    required property int index
                    width: bar.d; height: bar.d; radius: bar.d / 2
                    color: bar.locked ? root.dim : (index < bar.lit - 1 ? root.fg : (index === bar.lit - 1 ? root.red : root.dim))
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
            function set(m) { bar.moved(Math.max(0, Math.min(1, (m.x + 4) / width))); }
            onPressed: m => set(m)
            onPositionChanged: m => { if (pressed) set(m); }
        }
    }

    Component {
        id: volumeBody
        Item {
            readonly property var a: root.sys ? root.sys.sinkAudio : null
            WCaption { sys: root.sys; x: 16; y: 10; text: (parent.a && parent.a.muted) ? "Sound · muted" : "Sound"
                       color: (parent.a && parent.a.muted) ? root.red : (root.sys ? root.sys.colMuted : "#888") }
            WNum {
                sys: root.sys
                x: 16; y: parent.height - height - 10
                value: parent.a ? String(Math.round(parent.a.volume * 100)) : "0"
                size: 22
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    enabled: root.interactive; cursorShape: Qt.PointingHandCursor
                    onClicked: { var a = parent.parent.a; if (a) a.muted = !a.muted; }
                }
            }
            DotBar {
                anchors { left: parent.left; leftMargin: 100; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                height: 14
                value: parent.a ? parent.a.volume : 0
                locked: parent.a ? parent.a.muted : false
                onMoved: v => { var a = parent.a; if (a) { a.muted = false; a.volume = v; } }
            }
        }
    }

    Component {
        id: brightBody
        Item {
            readonly property var d: (root.sys && root.sys.brightList.length > 0) ? root.sys.brightList[0] : null
            WCaption { sys: root.sys; x: 16; y: 10; text: "Brightness" }
            WNum {
                sys: root.sys
                x: 16; y: parent.height - height - 10
                value: parent.d ? String(parent.d.pct) : "0"
                size: 22
            }
            DotBar {
                anchors { left: parent.left; leftMargin: 100; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                height: 14
                value: parent.d ? parent.d.pct / 100 : 0
                locked: !parent.d
                onMoved: v => { if (parent.d) root.sys.brightSet(parent.d.id, Math.max(1, v * 100)); }
            }
            Component.onCompleted: if (root.sys && root.sys.brightList.length === 0) root.sys.brightRefresh(false)
        }
    }

    Component {
        id: analogBody
        Canvas {
            id: cv
            Connections { target: root.sys; function onTimeSecondChanged() { cv.requestPaint(); } }
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 16;
                var is12 = root.sys ? Boolean(root.sys.cfg.clock12) : false;
                var n = is12 ? 12 : 24;
                for (var i = 0; i < n; i++) {
                    var a = i * (2 * Math.PI / n) - Math.PI / 2;
                    var major = i % (n / 4) === 0, mid = i % 2 === 0;
                    ctx.beginPath();
                    ctx.arc(cx + Math.cos(a) * r, cy + Math.sin(a) * r, major ? 2.0 : (is12 || mid ? 1.3 : 1.0), 0, 2 * Math.PI);
                    ctx.fillStyle = major ? "#ffffff" : "rgba(255,255,255," + (is12 ? 0.35 : (mid ? 0.5 : 0.25)) + ")";
                    ctx.fill();
                }
                var h = root.sys ? root.sys.timeHour : 0, m = root.sys ? root.sys.timeMinute : 0, s = root.sys ? root.sys.timeSecond : 0;
                var hA = is12 ? (((h % 12) + m / 60) * Math.PI / 6 - Math.PI / 2) : ((h + m / 60) * Math.PI / 12 - Math.PI / 2);
                var mA = (m + s / 60) * Math.PI / 30 - Math.PI / 2, sA = s * Math.PI / 30 - Math.PI / 2;
                ctx.lineCap = "round";
                ctx.beginPath(); ctx.lineWidth = 3.6; ctx.strokeStyle = "#ffffff";
                ctx.moveTo(cx + Math.cos(hA) * 3, cy + Math.sin(hA) * 3); ctx.lineTo(cx + Math.cos(hA) * r * 0.5, cy + Math.sin(hA) * r * 0.5); ctx.stroke();
                ctx.beginPath(); ctx.lineWidth = 2; ctx.strokeStyle = "rgba(255,255,255,0.95)";
                ctx.moveTo(cx + Math.cos(mA) * 3, cy + Math.sin(mA) * 3); ctx.lineTo(cx + Math.cos(mA) * r * 0.78, cy + Math.sin(mA) * r * 0.78); ctx.stroke();
                ctx.beginPath(); ctx.lineWidth = 1.2; ctx.strokeStyle = String(root.red);
                ctx.moveTo(cx - Math.cos(sA) * r * 0.18, cy - Math.sin(sA) * r * 0.18); ctx.lineTo(cx + Math.cos(sA) * r * 0.82, cy + Math.sin(sA) * r * 0.82); ctx.stroke();
                ctx.beginPath(); ctx.arc(cx, cy, 3.2, 0, 2 * Math.PI); ctx.fillStyle = String(root.red); ctx.fill();
            }
            Component.onCompleted: requestPaint()
        }
    }

    Component {
        id: ringBody
        Item {
            readonly property real r: Math.min(width, height) / 2 - 12
            readonly property int sec: root.sys ? root.sys.timeSecond : 0
            Repeater {
                model: 60
                Rectangle {
                    required property int index
                    readonly property real s: index % 5 === 0 ? 3.4 : 2.2
                    width: s; height: s; radius: s / 2
                    x: parent.width / 2 - s / 2 + Math.sin(index * Math.PI / 30) * parent.r
                    y: parent.height / 2 - s / 2 - Math.cos(index * Math.PI / 30) * parent.r
                    color: index === parent.sec ? root.red : (index < parent.sec ? root.fg : root.dim)
                }
            }
            WNum {
                sys: root.sys
                anchors.centerIn: parent
                value: root.two(root.sys ? root.sys.timeHour : 0) + ":" + root.two(root.sys ? root.sys.timeMinute : 0)
                size: 20
            }
        }
    }

    Component {
        id: dotClockBody
        Item {
            WNum {
                sys: root.sys
                x: 18; y: 16
                value: root.two(root.sys ? root.sys.timeHour : 0) + ":" + root.two(root.sys ? root.sys.timeMinute : 0)
                size: 52
                gapRatio: 0.14
            }
            Row {
                anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 18; bottom: parent.bottom; bottomMargin: 38 }
                spacing: (width - 30 * 3) / 29
                Repeater {
                    model: 30
                    Rectangle {
                        required property int index
                        readonly property int sec: root.sys ? Math.floor(root.sys.timeSecond / 2) : 0
                        width: 3; height: 3; radius: 1.5
                        color: index === sec ? root.red : (index < sec ? root.fg : root.dim)
                    }
                }
            }
            WCaption {
                sys: root.sys
                anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 18; bottom: parent.bottom; bottomMargin: 13 }
                text: Qt.formatDate(new Date(), "dddd · d MMMM")
            }
        }
    }

    Component {
        id: flipBody
        Item {
            Row {
                anchors.centerIn: parent
                spacing: 12
                Repeater {
                    model: [ root.sys ? root.sys.timeHour : 0, root.sys ? root.sys.timeMinute : 0 ]
                    Rectangle {
                        required property var modelData
                        width: 124; height: 96; radius: 14
                        color: Qt.rgba(1, 1, 1, 0.06)
                        WNum {
                            sys: root.sys
                            anchors.centerIn: parent
                            value: root.two(parent.modelData)
                            size: 56
                            gapRatio: 0.16
                        }
                        Rectangle { // flip seam
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 2; color: root.sys ? root.sys.colBg : "black"
                        }
                    }
                }
            }
        }
    }

    Component {
        id: batteryBody
        Item {
            readonly property int pct: root.sys ? root.sys.batteryPct : 0
            WCaption { sys: root.sys; x: 16; y: 13; text: (root.sys && root.sys.batteryCharging) ? "Charging" : "Battery" }
            WNum {
                sys: root.sys
                anchors.centerIn: parent
                value: parent.pct + "%"
                size: 40
                gapRatio: 0.16
                color: (parent.pct <= 20 && !(root.sys && root.sys.batteryCharging)) ? root.red : root.fg
            }
            Row {
                anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 16 }
                spacing: (width - 10 * 4) / 9
                Repeater {
                    model: 10
                    Rectangle {
                        required property int index
                        width: 4; height: 4; radius: 2
                        color: index < Math.round(parent.parent.pct / 10) ? root.fg : root.dim
                    }
                }
            }
        }
    }

    Component {
        id: calendarBody
        Item {
            readonly property date now: { var _ = root.sys ? root.sys.dayNum : ""; return new Date(); }
            readonly property int first: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() + 6) % 7
            readonly property int days: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
            WCaption { sys: root.sys; x: 16; y: 10; text: Qt.formatDate(parent.now, "MMMM yyyy") }
            Grid {
                x: 16; y: 30
                columns: 7
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    WCaption {
                        required property string modelData
                        required property int index
                        sys: root.sys
                        width: 38; height: 18; horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: index >= 5 ? root.red : (root.sys ? root.sys.colMuted : "#888")
                    }
                }
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int dn: index - parent.parent.first + 1
                        readonly property bool inMonth: dn >= 1 && dn <= parent.parent.days
                        readonly property bool today: inMonth && dn === parent.parent.now.getDate()
                        width: 38; height: 26
                        Rectangle {
                            anchors.centerIn: parent; width: 23; height: 23; radius: 11.5
                            visible: parent.today
                            color: root.red
                        }
                        Text {
                            anchors.centerIn: parent
                            text: parent.inMonth ? parent.dn : ""
                            color: parent.today ? "white" : (index % 7 >= 5 ? root.red : root.fg)
                            opacity: parent.today ? 1 : (index % 7 >= 5 ? 0.8 : 0.9)
                            font { family: root.sys ? root.sys.fontFam : "sans-serif"; pixelSize: root.sys ? root.sys.fontSize - 3 : 10 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: hugeBody
        Item {
            WNum {
                sys: root.sys
                anchors.centerIn: parent
                value: root.two(root.sys ? root.sys.timeHour : 0) + ":" + root.two(root.sys ? root.sys.timeMinute : 0)
                size: Math.min(parent.height * 0.8, parent.width / 4.7)
                gapRatio: 0.16
            }
        }
    }

    Component {
        id: minimalBody
        Item {
            WNum {
                sys: root.sys
                x: 4; anchors.verticalCenter: parent.verticalCenter
                value: root.two(root.sys ? root.sys.timeHour : 0) + ":" + root.two(root.sys ? root.sys.timeMinute : 0)
                size: Math.min(parent.height * 0.62, 40)
            }
            WCaption {
                sys: root.sys
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                text: Qt.formatDate(new Date(), "ddd · d MMM")
                color: root.fg
            }
        }
    }

    Component {
        id: dateBody
        Item {
            WNum {
                sys: root.sys
                anchors.centerIn: parent
                value: root.sys ? root.sys.dayNum : ""
                size: 50; gapRatio: 0.14
            }
            Text {
                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 13 }
                text: root.sys ? root.sys.dayText : ""
                color: (root.sys && root.sys.weekend) ? root.red : (root.sys ? root.sys.colMuted : "#888")
                font { family: root.sys ? root.sys.fontFam : "sans-serif"; pixelSize: root.sys ? root.sys.fontSize - 3 : 10 }
            }
            WCaption {
                sys: root.sys
                anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 13 }
                color: root.fg; opacity: 0.85
                text: root.sys ? root.sys.monthText : ""
            }
        }
    }

    Component {
        id: weatherBody
        Item {
            DotIcon {
                x: 16; y: 14
                code: root.sys ? root.sys.weatherIcon : ""
                size: 22
                color: root.fg
            }
            WNum {
                sys: root.sys
                x: 16; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 12
                value: (root.sys && root.sys.weatherTemp.length) ? root.sys.weatherTemp + "°" : "--°"
                size: 34
            }
            WCaption {
                sys: root.sys
                anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 13 }
                text: (root.sys && root.sys.weatherReady) ? root.sys.weatherDesc : "No data"
            }
        }
    }

    Component {
        id: progressBody
        Item {
            readonly property int hour: root.sys ? root.sys.timeHour : 0
            WCaption { sys: root.sys; x: 16; y: 10; text: "Day progress" }
            WNum {
                sys: root.sys
                anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 9 }
                value: Math.floor((parent.hour * 60 + (root.sys ? root.sys.timeMinute : 0)) / 14.4) + "%"
                size: 13; gapRatio: 0.15
            }
            Row {
                anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 14 }
                spacing: 3
                Repeater {
                    model: 24
                    Rectangle {
                        required property int index
                        width: (parent.width - 23 * 3) / 24; height: 6; radius: 3
                        color: index < parent.parent.hour ? Qt.rgba(1, 1, 1, 0.88) : (index === parent.parent.hour ? root.red : root.dim)
                    }
                }
            }
        }
    }
}
