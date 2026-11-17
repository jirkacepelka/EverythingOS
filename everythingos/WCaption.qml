import QtQuick

// Small spaced-out capital caption used on desktop widgets.
Text {
    property var sys
    color: sys ? sys.colMuted : "#888888"
    elide: Text.ElideRight
    font {
        family: sys ? sys.fontFam : "sans-serif"
        pixelSize: sys ? sys.fontSize - 3 : 10
        capitalization: Font.AllUppercase
        letterSpacing: 1.1
    }
}
