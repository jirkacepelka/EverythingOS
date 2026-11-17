import QtQuick

// Dot-matrix number (Nothing digits), shared by every desktop widget.
Item {
    id: num
    property var sys
    property string value: ""
    property real size: 14
    property real gapRatio: 0.22
    property color color: sys ? sys.colFg : "#ffffff"

    implicitWidth: dots.implicitWidth
    implicitHeight: dots.implicitHeight

    DotText {
        id: dots
        value: num.value
        size: num.size
        gapRatio: num.gapRatio
        color: num.color
    }
}
