pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Přepínač oken (Alt+Tab): řada karet s ikonou a názvem, vybraná je zvýrazněná.
// Potvrzuje se pustěním Alt (viz hypr/custom/keybindings.lua), klik také vybere.
Rectangle {
    id: view

    property var sys
    readonly property var items: view.sys.switcherList
    readonly property int idx: view.sys.switcherIndex

    readonly property int cardW: 132
    readonly property int cardH: 128
    readonly property int perRow: Math.max(1, Math.min(view.items.length, Math.floor((view.sys.width - 160) / (view.cardW + 10))))
    readonly property int rows: Math.ceil(view.items.length / view.perRow)

    implicitWidth: view.perRow * (view.cardW + 10) - 10 + 40
    implicitHeight: view.rows * (view.cardH + 10) - 10 + 40 + 34
    width: implicitWidth
    height: implicitHeight
    radius: 28
    color: view.sys.colBg

    function iconFor(cls) {
        var e = null;
        try { e = DesktopEntries.heuristicLookup(cls); } catch (err) {}
        var name = (e && e.icon) ? e.icon : String(cls).toLowerCase();
        var p = Quickshell.iconPath(name, true);
        return p ? String(p) : "";
    }

    Grid {
        x: 20; y: 20
        columns: view.perRow
        spacing: 10
        Repeater {
            model: view.items
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool sel: card.index === view.idx
                width: view.cardW; height: view.cardH
                radius: 20
                color: card.sel ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                border.width: card.sel ? 2 : 0
                border.color: view.sys.colFg
                Image {
                    anchors { top: parent.top; topMargin: 18; horizontalCenter: parent.horizontalCenter }
                    width: 56; height: 56
                    sourceSize: Qt.size(112, 112)
                    source: view.iconFor(card.modelData.c)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Text {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: 10; rightMargin: 10; bottomMargin: 14 }
                    text: card.modelData.t
                    color: card.sel ? view.sys.colFg : view.sys.colMuted
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { view.sys.switcherIndex = card.index; view.sys.switcherCommit(); }
                }
            }
        }
    }
}
