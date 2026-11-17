import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Wallpapers: thumbnail grid of installed wallpapers. Click applies one,
// "Remove" deletes the ones you added yourself.
ColumnLayout {
    id: page

    property var sys
    property string applying: ""

    Layout.fillWidth: true
    spacing: 12

    // the list is read once when the page opens (329 wallpapers: nothing here may touch every item at once)
    Component.onCompleted: page.sys.refreshWalls()

    function pretty(n) {
        var s = String(n).replace(/_/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function apply(path) {
        page.applying = path;
        page.sys.startThemeFade();
        pSet.command = ["sh", "-c", page.sys.scriptDir + "/themes.sh set \"$1\"", "_", path];
        pSet.running = true;
    }
    Process {
        id: pSet
        onRunningChanged: if (!running) { page.applying = ""; refreshLater.restart(); }
    }
    Process { id: pDel; onRunningChanged: if (!running) refreshLater.restart() }
    // one refresh, a moment after the change, instead of one per event
    Timer { id: refreshLater; interval: 1200; onTriggered: page.sys.refreshWalls() }

    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SetButton { sys: page.sys; text: "Add wallpaper…"; onClicked: page.sys.startWallpaperPick() }
            SetButton { sys: page.sys; text: "Open carousel"; onClicked: page.sys.openWalls() }
            Item { Layout.fillWidth: true }
        }
    }

    SetLabel { sys: page.sys; text: "Installed" }

    SetCard {
        sys: page.sys
        pad: 12

        Text {
            Layout.fillWidth: true
            visible: page.sys.wallList.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: page.sys.wallListReady ? "No wallpapers found" : "Loading…"
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        // virtualised: only the tiles on screen exist, however many wallpapers there are
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: 440
            clip: true
            cellWidth: Math.floor(width / 3)
            cellHeight: Math.floor(cellWidth * 9 / 16) + 44
            cacheBuffer: 0
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: page.sys.wallList
            delegate: Item {
                id: tile
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight

                Rectangle {
                    id: frame
                    x: 6; y: 6
                    width: parent.width - 12
                    height: Math.floor((parent.width - 12) * 9 / 16)
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: tile.modelData.wActive ? 2 : 1
                    border.color: tile.modelData.wActive ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.12)
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        // thumbnails only: never decode a full-size wallpaper for a preview
                        source: tile.modelData.wThumb.length ? "file://" + tile.modelData.wThumb : ""
                        sourceSize: Qt.size(320, 180)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: page.applying === tile.modelData.wPath ? 0.5 : 1
                    }
                    Rectangle {
                        visible: tile.modelData.wActive
                        anchors { right: parent.right; top: parent.top; margins: 8 }
                        width: 22; height: 22; radius: 11
                        color: page.sys.colOn
                        Text { anchors.centerIn: parent; text: "✓"; color: page.sys.colBg; font.pixelSize: 13; font.bold: true }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!tile.modelData.wActive && page.applying === "") page.apply(tile.modelData.wPath)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: frame.radius
                        color: "white"
                        opacity: ma.containsMouse && !tile.modelData.wActive ? 0.08 : 0
                    }
                    Rectangle {
                        visible: tile.modelData.wOwn && ma.containsMouse
                        anchors { left: parent.left; top: parent.top; margins: 8 }
                        height: 22; width: rmTxt.implicitWidth + 16; radius: 11
                        color: Qt.rgba(0, 0, 0, 0.7)
                        Text { id: rmTxt; anchors.centerIn: parent; text: "Remove"; color: page.sys.colFg
                               font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 5 } }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pDel.command = ["sh", "-c", page.sys.scriptDir + "/themes.sh del \"$1\"", "_", tile.modelData.wName];
                                pDel.running = true;
                            }
                        }
                    }
                }
                Text {
                    anchors { top: frame.bottom; topMargin: 6; left: frame.left; right: frame.right }
                    text: page.pretty(tile.modelData.wName)
                    elide: Text.ElideRight
                    color: tile.modelData.wActive ? page.sys.colFg : page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }
        }
    }
}
