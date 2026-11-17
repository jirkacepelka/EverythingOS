import QtQuick

// Shared desktop-widget card chrome: same radius, background and edge as the island.
Rectangle {
    property var sys
    radius: sys ? sys.shapeR : 22
    color: sys ? sys.colBg : "#000000"
    border.width: sys ? sys.edgeW : 0
    border.color: sys ? sys.edgeColor : "transparent"
}
