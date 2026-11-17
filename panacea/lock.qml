pragma ComponentBehavior: Bound
//@ pragma UseQApplication
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "Themes.js" as Themes

// EverythingOS lock screen (Nothing style).
//
// Two states:
//   idle  - wallpaper, dot-matrix clock, date, "Press Enter"
//   auth  - wallpaper blurs, a round pill with the password dots slides in
//
// Runs as its own process:  quickshell --path ~/.config/panacea/lock.qml
// (scripts/lock.sh does that and exports PANACEA_LOCK_BG). While the process
// lives, ext-session-lock keeps the session closed.
ShellRoot {
    id: root

    property string password: ""
    property bool authMode: false
    property bool checking: false
    property string errorText: ""
    property int attempts: 0

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string nick: user.charAt(0).toUpperCase() + user.slice(1)

    // Settings are read from the shell's settings.json (separate process).
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/panacea/settings.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var cfg: {
        try { return JSON.parse(cfgFile.text() || "{}") || {}; } catch (e) { return {}; }
    }
    readonly property int blurAmount: cfg.lockBlur !== undefined ? cfg.lockBlur : 32
    readonly property int dimPct: cfg.lockDim !== undefined ? cfg.lockDim : 40
    readonly property string hint: cfg.lockHint || ""
    readonly property bool clock12: !!cfg.clock12
    readonly property bool showClock: cfg.lockShowClock !== false
    // the font chosen in Settings; no hard-coded family
    readonly property string fontFam: cfg.fontBody || cfg.fontFam || "Space Mono"

    // palette: same table as the shell (Themes.js), so dark/white mode match
    readonly property var theme: Themes.of(cfg.themeId || "nothing")
    readonly property color colFg: theme.fg
    readonly property color colBg: theme.bg
    readonly property color colCrit: theme.crit
    function fgA(a) { return Qt.rgba(colFg.r, colFg.g, colFg.b, a); }

    // Debug-only unlock/auth via IPC, enabled only for PANACEA_LOCK_TEST=1
    readonly property bool testMode: Quickshell.env("PANACEA_LOCK_TEST") === "1"

    // wallpaper: lock.sh resolves it (honours the Login settings) and exports it
    readonly property string wallpaper: Quickshell.env("PANACEA_LOCK_BG") || ""

    // ----------------------------------------------------------------- clock
    property string timeText: "--:--"
    property string dateText: ""
    function tick() {
        var d = new Date();
        root.timeText = root.clock12 ? Qt.formatDateTime(d, "h:mm AP") : Qt.formatDateTime(d, "HH:mm");
        root.dateText = Qt.formatDateTime(d, "dddd, d MMMM");
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }

    // ------------------------------------------------------------------- PAM
    PamContext {
        id: pam
        config: "swaylock"
        user: root.user
        onPamMessage: { if (responseRequired) respond(root.password); }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.password = "";
                lock.locked = false;
                quitTimer.start();
            } else {
                root.attempts++;
                root.errorText = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
                root.password = "";
            }
        }
        onError: {
            root.checking = false;
            root.errorText = "Verification error";
            root.password = "";
        }
    }
    Timer { id: quitTimer; interval: 220; onTriggered: Qt.quit() }

    function submit() {
        if (root.checking || !root.password.length) return;
        root.errorText = "";
        root.checking = true;
        if (!pam.start()) { root.checking = false; root.errorText = "PAM unavailable"; }
    }

    IpcHandler {
        target: "lock"
        function unlock(): void { if (!root.testMode) return; lock.locked = false; quitTimer.start(); }
        function auth(): void { if (!root.testMode) return; root.authMode = true; }
    }

    // --------------------------------------------------------------- surface
    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: root.colBg

            Item {
                anchors.fill: parent

                Image {
                    id: bg
                    anchors.fill: parent
                    source: root.wallpaper.length ? "file://" + root.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    asynchronous: false
                    // huge wallpapers: decode already scaled down
                    sourceSize: Qt.size(surface.width * 2, surface.height * 2)
                    layer.enabled: true
                    layer.smooth: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: bg
                    visible: bg.status === Image.Ready
                    blurEnabled: true
                    blurMax: root.blurAmount
                    blurMultiplier: 0.85
                    blur: root.authMode ? 1.0 : 0.0
                    Behavior on blur { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                }
                // tint in the theme's background colour (black or off-white)
                Rectangle {
                    anchors.fill: parent
                    color: root.colBg
                    opacity: bg.status === Image.Ready
                             ? Math.min(1, root.dimPct / 100 + (root.authMode ? 0.15 : 0)) : 1
                    Behavior on opacity { NumberAnimation { duration: 420 } }
                }

                // ----------------------------------------------- clock block
                Column {
                    id: idleBlock
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 22
                    y: Math.round(parent.height * (root.authMode ? 0.17 : 0.30))
                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.showClock
                        value: root.timeText
                        size: Math.round(surface.height * 0.14)
                        color: root.colFg
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dateText
                        color: root.fgA(0.6)
                        font { family: root.fontFam; pixelSize: 18; letterSpacing: 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text.length > 0
                        text: root.hint
                        color: root.fgA(0.5)
                        font { family: root.fontFam; pixelSize: 15 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Press Enter"
                        color: root.fgA(0.4)
                        opacity: root.authMode ? 0 : 1
                        visible: opacity > 0.01
                        font { family: root.fontFam; pixelSize: 14; letterSpacing: 1 }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }

                // ----------------------------------------------- password pill
                Item {
                    id: island
                    width: root.authMode ? 440 : 160
                    height: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.62)
                    opacity: root.authMode ? 1 : 0
                    visible: opacity > 0.01
                    scale: root.authMode ? 1 : 0.92
                    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

                    transform: Translate { id: shakeT }
                    SequentialAnimation {
                        id: shake
                        loops: 2
                        NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 55 }
                        NumberAnimation { target: shakeT; property: "x"; to: 9; duration: 55 }
                        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 55 }
                    }
                    Connections {
                        target: root
                        function onErrorTextChanged() { if (root.errorText.length) shake.restart(); }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.78)
                        border.width: 1
                        border.color: root.errorText.length ? root.colCrit : root.fgA(0.22)
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    // user initial badge
                    Rectangle {
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        width: 48; height: 48; radius: 24
                        color: root.errorText.length ? root.colCrit : root.colFg
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.checking
                            text: root.nick.charAt(0)
                            color: root.colBg
                            font { family: root.fontFam; pixelSize: 20; bold: true }
                        }
                        // three dots while PAM checks
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: root.checking
                            Repeater {
                                model: 3
                                Rectangle {
                                    id: bd
                                    required property int index
                                    width: 6; height: 6; radius: 3
                                    color: root.colBg
                                    SequentialAnimation on opacity {
                                        running: root.checking
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: bd.index * 130 }
                                        NumberAnimation { to: 0.2; duration: 260 }
                                        NumberAnimation { to: 1.0; duration: 260 }
                                        PauseAnimation { duration: (2 - bd.index) * 130 }
                                    }
                                }
                            }
                        }
                    }

                    // typed characters as round dots
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 76
                        spacing: 8
                        Repeater {
                            model: Math.min(root.password.length, 18)
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: root.colFg
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                            }
                        }
                        Text {
                            visible: root.password.length === 0
                            text: root.errorText.length ? root.errorText : root.nick
                            color: root.errorText.length ? root.colCrit : root.fgA(0.45)
                            font { family: root.fontFam; pixelSize: 17 }
                        }
                    }
                }

                // hidden real input: layouts, Backspace and paste come for free
                TextInput {
                    id: pwInput
                    focus: true
                    width: 1; height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    activeFocusOnPress: false
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: { root.password = text; if (text.length) root.errorText = ""; }
                    onAccepted: root.submit()

                    Connections {
                        target: root
                        function onPasswordChanged() {
                            if (root.password === "" && pwInput.text !== "") pwInput.text = "";
                        }
                    }
                    Keys.onEscapePressed: {
                        if (root.authMode && !root.checking) {
                            pwInput.text = "";
                            root.errorText = "";
                            root.authMode = false;
                        }
                    }
                    Keys.onPressed: event => {
                        if (root.checking) { event.accepted = true; return; }
                        if (!root.authMode) {
                            root.authMode = true;
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                                event.accepted = true;
                        }
                    }
                }
                Timer {
                    interval: 400; running: true; repeat: true
                    onTriggered: if (!pwInput.activeFocus) pwInput.forceActiveFocus()
                }
            }
        }
    }
}
