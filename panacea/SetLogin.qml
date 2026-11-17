pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Login: the SDDM login screen (EverythingOS theme) and the lock screen.
// Nothing here writes to the system by itself: installing the theme and
// writing /etc/sddm.conf.d go through pkexec (sddm/install.sh), which asks
// for the user's password in the polkit dialog.
ColumnLayout {
    id: page

    property var sys

    // snapshot of the SDDM setup (scripts/login-info.sh)
    property var info: ({ themes: [], sessions: [], users: [], current: "", autologinUser: "",
                          autologinSession: "", installed: false, confExists: false, stateWritable: false, me: "" })
    property bool busy: false
    property string status: ""
    // pending (not yet applied) choices
    property string themePick: ""
    property bool autoOn: false
    property string autoUser: ""
    property string autoSession: ""

    readonly property string helper: Quickshell.env("HOME") + "/.config/panacea/sddm/install.sh"
    readonly property string syncCmd: page.sys.scriptDir + "/login-sync.sh"

    Layout.fillWidth: true
    spacing: 12

    function sessionsUnique() {
        var seen = {}, out = [];
        for (var i = 0; i < page.info.sessions.length; i++) {
            var s = page.info.sessions[i];
            if (!seen[s.id]) { seen[s.id] = 1; out.push(s); }
        }
        return out;
    }
    function themeOptions() {
        var o = page.info.themes.slice();
        var has = o.some(t => t.id === "everythingos");
        if (!has) o.unshift({ id: "everythingos", text: "EverythingOS (not installed yet)" });
        return o;
    }
    function refresh() { infoProc.running = false; infoProc.running = true; }
    function save() { page.sys.saveCfg(); syncTimer.restart(); }

    Component.onCompleted: { page.sys.refreshWalls(); page.refresh(); }

    Process {
        id: infoProc
        command: [page.sys.scriptDir + "/login-info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.info = JSON.parse(text);
                    page.themePick = page.themePick || page.info.current || "everythingos";
                    page.autoOn = page.info.autologinUser.length > 0;
                    page.autoUser = page.info.autologinUser || page.info.me;
                    page.autoSession = page.info.autologinSession
                        || (page.sessionsUnique().some(s => s.id === "hyprland.desktop") ? "hyprland.desktop" : "");
                } catch (e) { page.status = "Could not read the SDDM setup"; }
            }
        }
    }
    // publish colors / font / wallpaper to the greeter (debounced)
    Timer { id: syncTimer; interval: 500; onTriggered: { syncProc.running = false; syncProc.running = true; } }
    Process { id: syncProc; command: [page.syncCmd] }

    // privileged helper through polkit: the user confirms in the system dialog
    Process {
        id: rootProc
        stdout: StdioCollector { id: rootOut }
        stderr: StdioCollector { id: rootErr }
        onExited: code => {
            page.busy = false;
            if (code === 0) { page.status = "Applied. Takes effect at the next login screen."; syncProc.running = true; }
            else if (code === 126 || code === 127) page.status = "Cancelled (no permission was given).";
            else page.status = "Failed: " + (rootErr.text.trim() || ("exit " + code));
            page.refresh();
        }
    }
    function runRoot(args) {
        page.busy = true;
        page.status = "Waiting for confirmation…";
        rootProc.command = ["pkexec", page.helper].concat(args);
        rootProc.running = false;
        rootProc.running = true;
    }
    function applySddm() {
        var theme = page.themePick || "everythingos";
        runRoot(["apply", theme, page.autoOn ? page.autoUser : "-", page.autoOn && page.autoSession ? page.autoSession : "-"]);
    }

    // ============================================================ SDDM theme
    SetLabel { sys: page.sys; text: "SDDM login screen" }

    SetCard {
        sys: page.sys

        LoginPreview {
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignHCenter
            sys: page.sys
            mode: page.sys.cfg.loginBgMode
            customPath: page.sys.cfg.loginBgPath
            blur: page.sys.cfg.loginBlur
            dim: page.sys.cfg.loginDim
            showClock: page.sys.cfg.loginShowClock
            hint: page.sys.cfg.loginHint
            user: page.info.me
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            text: page.info.current === "everythingos"
                  ? "EverythingOS is the active login theme."
                  : (page.info.installed
                     ? "Active theme: " + (page.info.current || "default") + ". EverythingOS is installed but not selected."
                     : "EverythingOS is not installed yet. Install it to use it at login.")
        }

        SetPick {
            sys: page.sys
            label: "Theme"
            options: page.themeOptions()
            value: page.themePick
            onPicked: id => page.themePick = id
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SetButton {
                sys: page.sys
                primary: true
                enabled: !page.busy
                text: (page.info.installed && page.info.current === page.themePick) ? "Apply" : (page.themePick === "everythingos" ? "Install & apply" : "Apply")
                onClicked: page.applySddm()
            }
            SetButton {
                sys: page.sys
                enabled: !page.busy && page.info.installed
                text: "Remove EverythingOS"
                onClicked: page.runRoot(["uninstall"])
            }
            Item { Layout.fillWidth: true }
        }
        Text {
            Layout.fillWidth: true
            visible: page.status.length > 0
            wrapMode: Text.WordWrap
            text: page.status
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    SetLabel { sys: page.sys; text: "Login background" }

    SetCard {
        sys: page.sys

        SetSelect {
            sys: page.sys
            label: "Background"
            options: [{ id: "wallpaper", text: "Wallpaper" }, { id: "custom", text: "Image" }, { id: "black", text: "Plain" }]
            value: page.sys.cfg.loginBgMode
            onPicked: id => { page.sys.cfg.loginBgMode = id; page.save(); }
        }
        SetPick {
            sys: page.sys
            visible: page.sys.cfg.loginBgMode === "custom"
            label: "Image"
            searchable: true
            options: page.sys.wallList.map(w => ({ id: w.wPath, text: w.wName }))
            value: page.sys.cfg.loginBgPath
            onPicked: id => { page.sys.cfg.loginBgPath = id; page.save(); }
        }
        SetSlider {
            sys: page.sys
            label: "Blur"
            from: 0; to: 96; step: 4
            value: page.sys.cfg.loginBlur
            suffix: "px"
            onMoved: v => { page.sys.cfg.loginBlur = v; page.save(); }
        }
        SetSlider {
            sys: page.sys
            label: "Dim"
            from: 0; to: 100; step: 5
            value: page.sys.cfg.loginDim
            suffix: "%"
            onMoved: v => { page.sys.cfg.loginDim = v; page.save(); }
        }
        SetToggle {
            sys: page.sys
            label: "Show clock"
            on: page.sys.cfg.loginShowClock
            onToggled: v => { page.sys.cfg.loginShowClock = v; page.save(); }
        }
        TextField2 { sys: page.sys; placeholder: "Line under the clock (e.g. whose computer this is)"
            text: page.sys.cfg.loginHint
            onCommit: t => { page.sys.cfg.loginHint = t; page.save(); } }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: !page.info.stateWritable
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            text: "These options reach the login screen after EverythingOS is installed (it creates the shared folder the greeter reads)."
        }
    }

    // =========================================================== autologin
    SetLabel { sys: page.sys; text: "Autologin" }

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: "Log in automatically"
            sub: "Skips the password at boot. Anyone with the machine gets into this account."
            on: page.autoOn
            onToggled: v => page.autoOn = v
        }
        SetPick {
            sys: page.sys
            visible: page.autoOn
            label: "User"
            options: page.info.users
            value: page.autoUser
            onPicked: id => page.autoUser = id
        }
        SetPick {
            sys: page.sys
            visible: page.autoOn
            label: "Session"
            options: page.sessionsUnique()
            value: page.autoSession
            onPicked: id => page.autoSession = id
        }
        RowLayout {
            Layout.fillWidth: true
            SetButton { sys: page.sys; enabled: !page.busy; text: "Apply autologin"; onClicked: page.applySddm() }
            Item { Layout.fillWidth: true }
        }
    }

    // ============================================================ lockscreen
    SetLabel { sys: page.sys; text: "Lock screen" }

    SetCard {
        sys: page.sys

        LoginPreview {
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignHCenter
            sys: page.sys
            mode: page.sys.cfg.lockBgMode
            customPath: page.sys.cfg.lockBgPath
            blur: 0
            dim: page.sys.cfg.lockDim
            showClock: page.sys.cfg.lockShowClock
            hint: page.sys.cfg.lockHint
            user: page.info.me
            authPill: false
        }
        SetSelect {
            sys: page.sys
            label: "Background"
            options: [{ id: "wallpaper", text: "Wallpaper" }, { id: "custom", text: "Image" }, { id: "black", text: "Plain" }]
            value: page.sys.cfg.lockBgMode
            onPicked: id => { page.sys.cfg.lockBgMode = id; page.sys.saveCfg(); }
        }
        SetPick {
            sys: page.sys
            visible: page.sys.cfg.lockBgMode === "custom"
            label: "Image"
            searchable: true
            options: page.sys.wallList.map(w => ({ id: w.wPath, text: w.wName }))
            value: page.sys.cfg.lockBgPath
            onPicked: id => { page.sys.cfg.lockBgPath = id; page.sys.saveCfg(); }
        }
        SetSlider {
            sys: page.sys
            label: "Blur when typing"
            from: 0; to: 96; step: 2
            value: page.sys.cfg.lockBlur
            suffix: "px"
            onMoved: v => { page.sys.cfg.lockBlur = v; page.sys.saveCfg(); }
        }
        SetSlider {
            sys: page.sys
            label: "Dim"
            from: 0; to: 100; step: 5
            value: page.sys.cfg.lockDim
            suffix: "%"
            onMoved: v => { page.sys.cfg.lockDim = v; page.sys.saveCfg(); }
        }
        SetToggle {
            sys: page.sys
            label: "Show clock"
            on: page.sys.cfg.lockShowClock
            onToggled: v => { page.sys.cfg.lockShowClock = v; page.sys.saveCfg(); }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            text: "The lock text and enabling the lock screen are on the Lock Screen page. Lock with Super+L."
        }
    }
}
