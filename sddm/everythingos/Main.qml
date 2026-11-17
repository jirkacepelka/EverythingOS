import QtQuick 2.15

// EverythingOS login screen (Nothing style): dot-matrix clock, round pill with
// the password field, session and power pills. Colors, font, clock format and
// the (pre-blurred) wallpaper come from /var/lib/panacea, written by the shell
// (scripts/login-sync.sh) - the greeter cannot read the user's home.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: root.bg

    // ---- look, loaded as a tiny QML fragment (XHR on file:// is blocked in the greeter)
    Loader { id: look; source: "file:///var/lib/panacea/login.qml"; asynchronous: false }
    function lk(name, fallback) {
        return (look.item && look.item[name] !== undefined) ? look.item[name] : fallback;
    }
    readonly property color bg: lk("bg", "#000000")
    readonly property color fg: lk("fg", "#ffffff")
    readonly property color accent: lk("accent", "#d71921")
    readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
    readonly property color crit: root.accent
    readonly property string fontFam: lk("font", "Space Mono")
    readonly property bool clock12: lk("clock12", false)
    readonly property bool showClock: lk("showClock", true)
    readonly property string hint: lk("hint", "")
    readonly property bool useBg: lk("useBg", true)
    readonly property real dim: lk("dim", 0.45)
    readonly property bool light: (0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b) > 0.5

    readonly property string loginName: userModel.lastUser || ""
    property string errorText: ""
    property bool busy: false
    property bool authMode: false
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessionNames: []

    Repeater {
        model: sessionModel
        Item { Component.onCompleted: { var a = root.sessionNames.slice(); a[index] = name; root.sessionNames = a; } }
    }

    // ---- background
    Image {
        id: wall
        anchors.fill: parent
        source: root.useBg ? "file:///var/lib/panacea/sddm-bg.jpg" : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: wall.visible
        color: root.bg
        opacity: root.dim
    }

    // ---- clock
    property string timeText: ""
    property string dateText: ""
    function tick() {
        var d = new Date();
        var h = d.getHours(), m = ("0" + d.getMinutes()).slice(-2);
        if (root.clock12) { var ap = h >= 12 ? " PM" : " AM"; h = h % 12; if (h === 0) h = 12; timeText = h + ":" + m + ap; }
        else timeText = ("0" + h).slice(-2) + ":" + m;
        dateText = Qt.formatDate(d, "dddd, d MMMM");
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * (root.authMode ? 0.16 : 0.24))
        spacing: 22
        Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
        visible: root.showClock
        DotText {
            anchors.horizontalCenter: parent.horizontalCenter
            value: root.timeText
            size: Math.round(root.height * 0.13)
            color: root.fg
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateText
            color: root.muted
            font { family: root.fontFam; pixelSize: 18; letterSpacing: 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text.length > 0
            text: root.hint
            color: root.muted
            font { family: root.fontFam; pixelSize: 15 }
        }
    }

    // ---- login pill
    Item {
        id: pill
        width: 440; height: 64
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.60)
        transform: Translate { id: shakeT }
        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 55 }
            NumberAnimation { target: shakeT; property: "x"; to: 9; duration: 55 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 55 }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
            border.width: 1
            border.color: root.errorText.length ? root.crit : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, pw.activeFocus ? 0.45 : 0.18)
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        // user initial in a round badge
        Rectangle {
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 48; radius: 24
            color: root.fg
            Text {
                anchors.centerIn: parent
                text: (root.loginName.length ? root.loginName.charAt(0) : "?").toUpperCase()
                color: root.bg
                font { family: root.fontFam; pixelSize: 20; bold: true }
            }
        }

        TextInput {
            id: pw
            anchors { left: parent.left; right: go.left; verticalCenter: parent.verticalCenter; leftMargin: 76; rightMargin: 10 }
            echoMode: TextInput.Password
            passwordCharacter: "●"
            color: root.fg
            clip: true
            focus: true
            enabled: !root.busy
            font { family: root.fontFam; pixelSize: 18 }
            onTextChanged: { if (text.length) { root.errorText = ""; root.authMode = true; } }
            onAccepted: root.submit()
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: pw.text.length === 0
                text: root.errorText.length ? root.errorText : root.loginName
                color: root.errorText.length ? root.crit : root.muted
                font: pw.font
            }
        }

        Rectangle {
            id: go
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: 48; height: 48; radius: 24
            color: pw.text.length ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: root.busy ? "···" : "→"
                color: pw.text.length ? "#ffffff" : root.muted
                font { family: root.fontFam; pixelSize: 22 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
        }
    }

    function submit() {
        if (root.busy || !pw.text.length) return;
        root.busy = true;
        sddm.login(root.loginName, pw.text, root.sessionIndex);
    }
    Connections {
        target: sddm
        onLoginFailed: {
            root.busy = false;
            root.errorText = "Wrong password";
            pw.text = "";
            shake.restart();
            pw.forceActiveFocus();
        }
    }

    // ---- bottom pills: session + power
    // ---- session picker: pill with the current session, click opens a list above it
    property bool sessionOpen: false
    readonly property int sessionCount: root.sessionNames.length

    Rectangle {
        id: sessionList
        visible: root.sessionOpen && root.sessionCount > 0
        width: 280
        height: root.sessionCount * 38 + 12
        radius: 20
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
        anchors { horizontalCenter: parent.horizontalCenter; bottom: bottomRow.top; bottomMargin: 10 }
        Column {
            anchors.fill: parent
            anchors.margins: 6
            Repeater {
                model: root.sessionNames
                Rectangle {
                    width: parent.width; height: 38; radius: 16
                    color: index === root.sessionIndex ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16)
                           : (sma.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08) : "transparent")
                    Text {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        text: modelData
                        color: root.fg
                        font { family: root.fontFam; pixelSize: 15 }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        visible: index === root.sessionIndex
                        text: "\u25CF"
                        color: root.accent
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: sma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.sessionIndex = index; root.sessionOpen = false; pw.forceActiveFocus(); }
                    }
                }
            }
        }
    }

    Row {
        id: bottomRow
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
        spacing: 10
        Pill {
            fg: root.fg; fontFam: root.fontFam
            visible: root.sessionCount > 0
            label: (root.sessionNames[root.sessionIndex] || "Session") + (root.sessionOpen ? "  \u25B4" : "  \u25BE")
            onClicked: root.sessionOpen = !root.sessionOpen
        }
        Pill { fg: root.fg; fontFam: root.fontFam; visible: sddm.canSuspend; label: "Sleep"; onClicked: sddm.suspend() }
        Pill { fg: root.fg; fontFam: root.fontFam; visible: sddm.canReboot; label: "Restart"; onClicked: sddm.reboot() }
        Pill { fg: root.fg; fontFam: root.fontFam; visible: sddm.canPowerOff; label: "Shut down"; onClicked: sddm.powerOff() }
    }

    Component.onCompleted: pw.forceActiveFocus()
}
