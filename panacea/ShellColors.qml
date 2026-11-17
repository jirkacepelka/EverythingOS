pragma Singleton
import QtQuick
import Quickshell

// Current foreground/background of the shell theme, shared by every QML file.
// shell.qml binds fg and bg to the active theme (dark or light); everything that used to be a
// hard-coded white overlay or text goes through here so it flips with the system mode.
Singleton {
    property color fg: "#ffffff"
    property color bg: "#000000"
    property bool light: false
    // UI font chosen in Settings (fallback for components without a reference to the shell)
    property string family: "GoogleSansCode Nerd Font Propo"

    // foreground at a given opacity (replaces Qt.rgba(1, 1, 1, a))
    function fgA(a) { return Qt.rgba(fg.r, fg.g, fg.b, a); }
    function bgA(a) { return Qt.rgba(bg.r, bg.g, bg.b, a); }
    // CSS strings for Canvas contexts
    function fgCss(a) { return "rgba(" + Math.round(fg.r * 255) + "," + Math.round(fg.g * 255) + "," + Math.round(fg.b * 255) + "," + a + ")"; }
}
