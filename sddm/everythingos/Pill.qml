import QtQuick 2.15

Rectangle {
    id: p
    property string label: ""
    property color fg: "#ffffff"
    property string fontFam: "Space Mono"
    signal clicked()
    height: 36
    width: t.implicitWidth + 30
    radius: height / 2
    color: ma.containsMouse ? Qt.rgba(fg.r, fg.g, fg.b, 0.16) : Qt.rgba(fg.r, fg.g, fg.b, 0.07)
    border.width: 1
    border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.14)
    Text { id: t; anchors.centerIn: parent; text: p.label; color: p.fg; font { family: p.fontFam; pixelSize: 14 } }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.clicked() }
}
