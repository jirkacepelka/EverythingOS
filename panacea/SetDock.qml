import QtQuick
import QtQuick.Layouts
import Quickshell

// Dock: where it shows, auto-hide, and the pinned apps list.
ColumnLayout {
    id: page

    property var sys
    readonly property var pinned: {
        try { var l = JSON.parse(page.sys.cfg.dockPinned); return Array.isArray(l) ? l : []; } catch (e) { return []; }
    }
    readonly property string defaults: "[\"app.zen_browser.zen\",\"org.gnome.Nautilus\",\"foot\",\"com.anthropic.Claude\"]"
    function save(l) { page.sys.cfg.dockPinned = JSON.stringify(l); page.sys.saveCfg(); }
    function nameOf(id) {
        var e = null;
        try { e = DesktopEntries.heuristicLookup(id); } catch (err) {}
        return (e && e.name) ? e.name : id;
    }
    function iconOf(id) {
        var e = null;
        try { e = DesktopEntries.heuristicLookup(id); } catch (err) {}
        var p = Quickshell.iconPath((e && e.icon) ? e.icon : String(id).toLowerCase(), true);
        return p ? String(p) : "";
    }

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: "Dock"
            sub: "Show the app dock at the bottom edge of the screen."
            on: page.sys.cfg.dockEnabled
            onToggled: v => { page.sys.cfg.dockEnabled = v; page.sys.saveCfg(); }
        }
        SetToggle {
            sys: page.sys
            label: "Auto-hide"
            sub: "Slide the dock below the edge. Point at the bottom edge to bring it back. Off: windows keep clear of it."
            on: page.sys.cfg.dockAutoHide
            onToggled: v => { page.sys.cfg.dockAutoHide = v; page.sys.saveCfg(); }
        }
        SetToggle {
            sys: page.sys
            label: "Show in workspaces"
            sub: "Also show the dock in the workspace overview (Super+Tab)."
            on: page.sys.cfg.overviewDock
            onToggled: v => { page.sys.cfg.overviewDock = v; page.sys.saveCfg(); }
        }
    }

    SetLabel { sys: page.sys; text: "Pinned apps" }

    SetCard {
        sys: page.sys
        spacing: 4
        pad: 10

        Text {
            Layout.fillWidth: true
            Layout.margins: 6
            visible: page.pinned.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing pinned. Right-click an app in the dock to pin it."
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        Repeater {
            model: page.pinned
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 12
                color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                    spacing: 12
                    Image {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26
                        sourceSize: Qt.size(52, 52)
                        source: page.iconOf(row.modelData)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: page.nameOf(row.modelData)
                            elide: Text.ElideRight
                            color: page.sys.colFg
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData
                            elide: Text.ElideRight
                            color: page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                        }
                    }
                    SetButton {
                        sys: page.sys; text: "↑"; enabled: row.index > 0
                        Layout.preferredWidth: 40
                        onClicked: { var l = page.pinned.slice(); var t = l[row.index - 1]; l[row.index - 1] = l[row.index]; l[row.index] = t; page.save(l); }
                    }
                    SetButton {
                        sys: page.sys; text: "↓"; enabled: row.index < page.pinned.length - 1
                        Layout.preferredWidth: 40
                        onClicked: { var l = page.pinned.slice(); var t = l[row.index + 1]; l[row.index + 1] = l[row.index]; l[row.index] = t; page.save(l); }
                    }
                    SetButton {
                        sys: page.sys; text: "Remove"
                        onClicked: { var l = page.pinned.slice(); l.splice(row.index, 1); page.save(l); }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            SetButton {
                sys: page.sys; text: "Reset to defaults"
                onClicked: { page.sys.cfg.dockPinned = page.defaults; page.sys.saveCfg(); }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
