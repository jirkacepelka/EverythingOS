pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

// App dock: pinned apps plus running ones. Left click focuses (or launches),
// right click pins / unpins. Shape follows the shared window/pill style.
Rectangle {
    id: dock

    property var sys
    signal launched()

    readonly property var pinned: {
        try { var l = JSON.parse(dock.sys.cfg.dockPinned); return Array.isArray(l) ? l : []; } catch (e) { return []; }
    }
    function key(s) { var p = String(s || "").toLowerCase().split("."); return p[p.length - 1]; }
    readonly property var items: {
        var run = [];
        var tl = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < tl.length; i++) {
            var o = tl[i].lastIpcObject;
            if (o && o["class"] && run.indexOf(o["class"]) < 0) run.push(o["class"]);
        }
        var out = [], used = {};
        for (var p = 0; p < dock.pinned.length; p++) {
            var id = dock.pinned[p], isRun = false;
            for (var r = 0; r < run.length; r++)
                if (dock.key(run[r]) === dock.key(id)) { isRun = true; used[r] = true; }
            out.push({ id: id, running: isRun, pinned: true });
        }
        for (var q = 0; q < run.length; q++)
            if (!used[q]) out.push({ id: run[q], running: true, pinned: false });
        return out;
    }
    function togglePin(id) {
        var l = dock.pinned.slice(), k = -1;
        for (var i = 0; i < l.length; i++) if (dock.key(l[i]) === dock.key(id)) k = i;
        if (k >= 0) l.splice(k, 1); else l.push(id);
        dock.sys.cfg.dockPinned = JSON.stringify(l);
        dock.sys.saveCfg();
    }
    function iconFor(id) {
        var e = null;
        try { e = DesktopEntries.heuristicLookup(id); } catch (err) {}
        var n = (e && e.icon) ? e.icon : String(id).toLowerCase();
        var p = Quickshell.iconPath(n, true);
        return p ? String(p) : "";
    }

    width: row.implicitWidth + 28
    height: 64
    radius: dock.sys.winR
    color: dock.sys.colBg
    border.width: dock.sys.edgeW
    border.color: dock.sys.edgeColor
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Repeater {
            model: dock.items
            delegate: Item {
                id: di
                required property var modelData
                width: 46; height: 46
                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(8, dock.radius - 10)
                    color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                }
                Image {
                    anchors.centerIn: parent
                    width: 32; height: 32
                    sourceSize: Qt.size(64, 64)
                    source: dock.iconFor(di.modelData.id)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    scale: ma.containsMouse ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                }
                Rectangle {
                    visible: di.modelData.running
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                    width: 4; height: 4; radius: 2
                    color: dock.sys.colFg
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) { dock.togglePin(di.modelData.id); return; }
                        dock.launched();
                        dock.sys.focusApp(di.modelData.id);
                    }
                }
            }
        }
    }
}
