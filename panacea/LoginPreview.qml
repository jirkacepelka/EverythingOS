import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Miniature of the login / lock screen for Settings > Login: same layout as
// sddm/everythingos/Main.qml and lock.qml, drawn with the shell's own colors.
Rectangle {
    id: pv

    property var sys
    property string mode: "wallpaper"     // wallpaper | custom | black
    property string customPath: ""
    property int blur: 0                  // 0..96
    property int dim: 45                  // 0..100
    property bool showClock: true
    property string hint: ""
    property bool authPill: true
    property string user: "user"

    // wallpaper to show (full file; thumbnail when it is the active one)
    readonly property string source: {
        if (pv.mode === "black") return "";
        var list = pv.sys.wallList || [];
        var want = "";
        if (pv.mode === "custom" && pv.customPath.length) want = pv.customPath;
        for (var i = 0; i < list.length; i++) {
            if (want.length ? list[i].wPath === want : list[i].wActive)
                return list[i].wThumb.length ? list[i].wThumb : list[i].wPath;
        }
        return want;
    }

    Layout.fillWidth: true
    implicitHeight: Math.round(width * 9 / 16)
    radius: 14
    clip: true
    color: pv.sys.colBg
    border.width: 1
    border.color: ShellColors.fgA(0.14)

    Image {
        id: img
        anchors.fill: parent
        source: pv.source.length ? "file://" + pv.source : ""
        sourceSize: Qt.size(640, 360)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        layer.enabled: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        blurEnabled: true
        blurMax: 32
        blur: Math.min(1, pv.blur / 96)
    }
    Rectangle {
        anchors.fill: parent
        color: pv.sys.colBg
        opacity: img.status === Image.Ready ? pv.dim / 100 : 1
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.17
        spacing: parent.height * 0.05
        visible: pv.showClock
        DotText {
            anchors.horizontalCenter: parent.horizontalCenter
            value: "09:41"
            size: pv.height * 0.15
            color: pv.sys.colFg
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Monday, 17 November"
            color: pv.sys.colMuted
            font { family: pv.sys.fontBody; pixelSize: Math.max(7, pv.height * 0.045) }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text.length > 0
            text: pv.hint
            color: pv.sys.colMuted
            font { family: pv.sys.fontBody; pixelSize: Math.max(7, pv.height * 0.04) }
        }
    }

    Rectangle {
        visible: pv.authPill
        width: parent.width * 0.5; height: parent.height * 0.14
        radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.64
        color: ShellColors.fgA(0.08)
        border.width: 1
        border.color: ShellColors.fgA(0.2)
        Rectangle {
            x: parent.height * 0.1; anchors.verticalCenter: parent.verticalCenter
            width: parent.height * 0.8; height: width; radius: width / 2
            color: pv.sys.colFg
            Text {
                anchors.centerIn: parent
                text: pv.user.charAt(0).toUpperCase()
                color: pv.sys.colBg
                font { family: pv.sys.fontBody; pixelSize: parent.height * 0.5; bold: true }
            }
        }
        Row {
            x: parent.height * 1.1; anchors.verticalCenter: parent.verticalCenter
            spacing: parent.height * 0.14
            Repeater {
                model: 6
                Rectangle { width: pv.height * 0.025; height: width; radius: width / 2; color: pv.sys.colFg }
            }
        }
    }
}
