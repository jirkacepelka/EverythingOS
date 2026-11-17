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

    Component.onCompleted: { page.sys.refreshWalls(); warmDelay.start(); }
    // build missing thumbnails in the background, then reload the list
    Process {
        id: pWarm
        command: ["sh", "-c", page.sys.scriptDir + "/themes.sh warm"]
        onRunningChanged: if (!running) page.sys.refreshWalls()
    }
    Timer { id: warmDelay; interval: 900; onTriggered: pWarm.running = true }

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
        onRunningChanged: if (!running) { page.applying = ""; page.sys.refreshWalls(); }
    }
    Process { id: pDel; onRunningChanged: if (!running) page.sys.refreshWalls() }

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

        Flow {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: page.sys.wallList
                delegate: Item {
                    id: tile
                    required property var modelData
                    readonly property real w: Math.floor((parent.width - 24) / 3)
                    width: w
                    height: w * 9 / 16 + 26

                    Rectangle {
                        id: frame
                        width: parent.width
                        height: tile.w * 9 / 16
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: tile.modelData.wActive ? 2 : 1
                        border.color: tile.modelData.wActive ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.12)
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: tile.modelData.wThumb.length ? "file://" + tile.modelData.wThumb
                                    : (tile.modelData.wPath.length ? "file://" + tile.modelData.wPath : "")
                            sourceSize: Qt.size(400, 225)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
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
                            onClicked: if (!tile.modelData.wActive) page.apply(tile.modelData.wPath)
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.radius
                            color: "white"
                            opacity: ma.containsMouse && !tile.modelData.wActive ? 0.08 : 0
                        }
                        // delete own wallpapers
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
                        anchors { top: frame.bottom; topMargin: 6; left: parent.left; right: parent.right }
                        text: page.pretty(tile.modelData.wName)
                        elide: Text.ElideRight
                        color: tile.modelData.wActive ? page.sys.colFg : page.sys.colMuted
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }
                }
            }
        }
    }
}
