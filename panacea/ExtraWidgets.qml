pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Desktop widgets that are added from the widget tray (see WidgetTray.qml).
// Each instance is { id, type, x, y } stored in cfg.widgetItemsJson, so the
// same widget type can be placed several times. In edit mode every card can
// be dragged and removed.
Item {
    id: view

    property var sys
    readonly property bool editing: view.sys ? Boolean(view.sys.widgetEdit) : false
    readonly property real snap: 12
    readonly property var items: view.sys ? view.sys.widgetItems : []
    // placement rectangles for the window input mask
    readonly property var rects: {
        var r = [];
        for (var i = 0; i < view.items.length; i++) {
            var t = cat.find(view.items[i].type);
            var m = 0;
            if (t) r.push({ x: view.sys.widgetsOriginX + view.items[i].gx * 78, y: view.sys.widgetsOriginY + view.items[i].gy * 78, w: t.w, h: t.h });
        }
        return r;
    }

    WidgetCatalog { id: cat }

    // ------------------------------------------------------------ instances
    Repeater {
        model: view.items
        delegate: WCard {
            id: card
            sys: view.sys
            required property var modelData
            readonly property var t: cat.find(card.modelData.type)
            property real px: view.sys.widgetsOriginX + card.modelData.gx * 78
            property real py: view.sys.widgetsOriginY + card.modelData.gy * 78
            visible: card.t !== null
            x: card.px; y: card.py
            width: card.t ? card.t.w : 0
            height: card.t ? card.t.h : 0

            WidgetBody {
                anchors.fill: parent
                sys: view.sys
                type: card.modelData.type
                interactive: !view.editing
            }

            // edit mode: drag to move, × to remove
            MouseArea {
                id: drag
                anchors.fill: parent
                visible: view.editing
                enabled: visible
                z: 50
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point pp
                property real sx
                property real sy
                onPressed: m => { pp = drag.mapToItem(view, m.x, m.y); sx = card.px; sy = card.py; }
                onPositionChanged: m => {
                    if (!pressed) return;
                    var p = drag.mapToItem(view, m.x, m.y);
                    card.px = Math.max(0, Math.min(view.width - card.width, sx + p.x - pp.x));
                    card.py = Math.max(0, Math.min(view.height - card.height, sy + p.y - pp.y));
                }
                onReleased: {
                    view.sys.moveWidget(card.modelData.id,
                        Math.max(0, Math.round((card.px - view.sys.widgetsOriginX) / 78)),
                        Math.max(0, Math.round((card.py - view.sys.widgetsOriginY) / 78)));
                }
                Rectangle {
                    anchors.fill: parent; radius: card.radius
                    color: Qt.rgba(1, 1, 1, drag.pressed ? 0.10 : 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.55); border.width: 1.5
                }
            }
            Rectangle {
                visible: view.editing
                z: 60
                anchors { top: parent.top; right: parent.right; margins: 6 }
                width: 22; height: 22; radius: 11
                color: view.sys.colCrit
                Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 15; font.bold: true }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.removeWidget(card.modelData.id)
                }
            }
        }
    }
}
