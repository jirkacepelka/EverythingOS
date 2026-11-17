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
            var t = cat.find(view.items[i].type); var sp = view.sys.widgetSpan(view.items[i]);
            var m = 0;
            var m = view.editing ? 10 : 0;   // room for the resize handles that straddle the card edge
            if (t) r.push({ x: view.sys.widgetsOriginX + view.items[i].gx * view.sys.pitchX - m, y: view.sys.widgetsOriginY + view.items[i].gy * view.sys.pitchY - m, w: sp.cw * view.sys.pitchX - 12 + 2 * m, h: sp.ch * view.sys.pitchY - 12 + 2 * m });
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
            property real px: view.sys.widgetsOriginX + card.gx * view.sys.pitchX
            property real py: view.sys.widgetsOriginY + card.gy * view.sys.pitchY
            visible: card.t !== null
            x: card.px; y: card.py
            // span in cells: the widget's own size (resized) or the default of its type
            property int gx: card.modelData.gx
            property int gy: card.modelData.gy
            property int cw: card.modelData.cw || (card.t ? card.t.cw : 1)
            property int ch: card.modelData.ch || (card.t ? card.t.ch : 1)
            width: card.cw * view.sys.pitchX - 12
            height: card.ch * view.sys.pitchY - 12
            color: (card.t && card.t.bare) ? "transparent" : view.sys.colBg
            border.width: (card.t && card.t.bare) ? 0 : view.sys.edgeW

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
                        Math.max(0, Math.round((card.px - view.sys.widgetsOriginX) / view.sys.pitchX)),
                        Math.max(0, Math.round((card.py - view.sys.widgetsOriginY) / view.sys.pitchY)));
                }
                Rectangle {
                    anchors.fill: parent; radius: card.radius
                    color: Qt.rgba(1, 1, 1, drag.pressed ? 0.10 : 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.55); border.width: 1.5
                }
            }

            // Android-style resize handles (edit mode): drag an edge, the size snaps to grid cells
            // and is limited by what the widget type supports and by the free space around it
            Repeater {
                model: view.editing && card.t ? ["l", "r", "t", "b"] : []
                delegate: Rectangle {
                    id: hnd
                    required property string modelData
                    readonly property bool horiz: modelData === "l" || modelData === "r"
                    readonly property bool canResize: card.t && (horiz ? card.t.minW !== card.t.maxW : card.t.minH !== card.t.maxH)
                    visible: canResize
                    z: 70
                    width: horiz ? 8 : 34; height: horiz ? 34 : 8; radius: 4
                    color: view.sys.colFg
                    x: modelData === "l" ? -4 : modelData === "r" ? card.width - 4 : (card.width - width) / 2
                    y: modelData === "t" ? -4 : modelData === "b" ? card.height - 4 : (card.height - height) / 2
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -8
                        cursorShape: hnd.horiz ? Qt.SizeHorCursor : Qt.SizeVerCursor
                        property point pp
                        property int sgx; property int sgy; property int scw; property int sch
                        property int ngx; property int ngy; property int ncw; property int nch
                        onPressed: m => {
                            pp = mapToItem(view, m.x, m.y);
                            sgx = card.gx; sgy = card.gy; scw = card.cw; sch = card.ch;
                            ngx = sgx; ngy = sgy; ncw = scw; nch = sch;
                        }
                        onPositionChanged: m => {
                            if (!pressed) return;
                            var p = mapToItem(view, m.x, m.y);
                            var dx = Math.round((p.x - pp.x) / view.sys.pitchX), dy = Math.round((p.y - pp.y) / view.sys.pitchY);
                            var t = card.t;
                            var gx = sgx, gy = sgy, cw = scw, ch = sch;
                            if (hnd.modelData === "r") cw = scw + dx;
                            if (hnd.modelData === "l") { cw = scw - dx; gx = sgx + dx; }
                            if (hnd.modelData === "b") ch = sch + dy;
                            if (hnd.modelData === "t") { ch = sch - dy; gy = sgy + dy; }
                            // clamp to the type's limits, keeping the opposite edge fixed
                            var ccw = Math.max(t.minW, Math.min(t.maxW, cw)), cch = Math.max(t.minH, Math.min(t.maxH, ch));
                            if (hnd.modelData === "l") gx = sgx + (scw - ccw);
                            if (hnd.modelData === "t") gy = sgy + (sch - cch);
                            if (view.sys.widgetFits(gx, gy, ccw, cch, card.modelData.id)) { ngx = gx; ngy = gy; ncw = ccw; nch = cch; }
                            card.gx = ngx; card.gy = ngy; card.cw = ncw; card.ch = nch;
                        }
                        onReleased: view.sys.resizeWidget(card.modelData.id, ngx, ngy, ncw, nch)
                    }
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
