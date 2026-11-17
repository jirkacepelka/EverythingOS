pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Full-screen widget editor layer: a tray at the bottom with every widget type.
// Drag a tile onto the desktop to place it (or click it to add it near the top
// left), then drag placed widgets to move them or use × to remove them.
Item {
    id: view

    property var sys
    readonly property alias bar: bar

    WidgetCatalog { id: cat }

    // dim the desktop a little so the editor reads as a mode
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }

    // the desktop grid: square cells that widgets snap to (and, later, app icons)
    readonly property real ox: view.sys.widgetsOriginX
    readonly property real oy: view.sys.widgetsOriginY
    readonly property int gcols: view.sys.widgetCols
    readonly property int grows: view.sys.widgetRows
    readonly property real px: view.sys.pitchX
    readonly property real py: view.sys.pitchY
    Repeater {
        model: view.gcols * view.grows
        Rectangle {
            required property int index
            x: view.ox + (index % view.gcols) * view.px
            y: view.oy + Math.floor(index / view.gcols) * view.py
            width: view.px - 12; height: view.py - 12; radius: 10
            color: "transparent"
            border.width: 1; border.color: ShellColors.fgA(0.07)
        }
    }

    // ghost that follows the pointer while dragging a tile
    Rectangle {
        id: ghost
        visible: false
        property var type: null
        z: 100
        width: type ? type.cw * view.px - 12 : 0
        height: type ? type.ch * view.py - 12 : 0
        radius: view.sys.shapeR
        color: view.sys.colBg
        opacity: 0.92
        border.color: ShellColors.fgA(0.7); border.width: 1.5
        WidgetBody {
            anchors.fill: parent
            sys: view.sys
            type: ghost.type ? ghost.type.id : ""
            interactive: false
        }
    }


    Rectangle {
        id: bar
        z: 50
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: view.sys.cfg.islandGap + 1 }
        // the buttons on the right always keep their place; only the tile list scrolls
        width: Math.min(view.width - 40, tilesRow.implicitWidth + 150)
        height: 140
        radius: view.sys.winR
        color: view.sys.colBg
        border.width: view.sys.edgeW
        border.color: view.sys.edgeColor

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10

            // the widget picker scrolls sideways when there are more tiles than fit
            Item {
                id: scroller
                width: bar.width - 150
                height: 118
                readonly property bool overflow: tilesRow.implicitWidth > width

                Flickable {
                    id: fl
                    anchors.fill: parent
                    contentWidth: tilesRow.implicitWidth
                    contentHeight: height
                    interactive: false              // dragging a tile must not pan the list
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Behavior on contentX { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Row {
                        id: tilesRow
                        spacing: 10
                    Repeater {
                        model: cat.types
                        delegate: Item {
                            id: tile
                            required property var modelData
                            // live miniature of the widget, scaled to fit the tile
                            readonly property real sc: Math.min(120 / modelData.w, 78 / modelData.h)
                            width: Math.max(96, modelData.w * sc + 16)
                            height: 118
                            Rectangle {
                                anchors.fill: parent; radius: Math.max(10, view.sys.winR - 6)
                                color: tma.containsMouse || tma.pressed ? ShellColors.fgA(0.10) : "transparent"
                            }
                            WCard {
                                sys: view.sys
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                                width: tile.modelData.w * tile.sc; height: tile.modelData.h * tile.sc
                                radius: Math.max(5, view.sys.shapeR * tile.sc)
                                color: tile.modelData.bare ? ShellColors.fgA(0.05) : view.sys.colBg
                                border.width: tile.modelData.bare ? 0 : view.sys.edgeW
                                clip: true
                                WidgetBody {
                                    width: tile.modelData.w; height: tile.modelData.h
                                    scale: tile.sc; transformOrigin: Item.TopLeft
                                    sys: view.sys
                                    type: tile.modelData.id
                                    interactive: false
                                }
                            }
                            WCaption {
                                sys: view.sys
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                                text: tile.modelData.name
                                font.pixelSize: view.sys.fontSize - 5
                            }
                            MouseArea {
                                id: tma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                property bool moved: false
                                onPressed: m => { moved = false; }
                                onPositionChanged: m => {
                                    if (!pressed) return;
                                    var p = tma.mapToItem(view, m.x, m.y);
                                    if (!moved && Math.abs(m.x - width / 2) + Math.abs(m.y - height / 2) < 24) return;
                                    if (!moved) { moved = true; ghost.type = tile.modelData; ghost.visible = true; }
                                    // the ghost snaps to the cell the widget would land on
                                    var gx = Math.max(0, Math.min(view.gcols - tile.modelData.cw, Math.round((p.x - ghost.width / 2 - view.ox) / view.px)));
                                    var gy = Math.max(0, Math.min(view.grows - tile.modelData.ch, Math.round((p.y - ghost.height / 2 - view.oy) / view.py)));
                                    ghost.x = view.ox + gx * view.px;
                                    ghost.y = view.oy + gy * view.py;
                                }
                                onReleased: m => {
                                    var p = tma.mapToItem(view, m.x, m.y);
                                    if (moved) {
                                        ghost.visible = false;
                                        if (p.y < bar.y - 10) {
                                            view.sys.addWidget(tile.modelData.id,
                                                Math.round((ghost.x - view.ox) / view.px), Math.round((ghost.y - view.oy) / view.py));
                                        }
                                    }
                                }
                                onClicked: if (!moved) view.sys.addWidget(tile.modelData.id, -1, -1)
                            }
                        }
                    }

                    // built-in widgets that were removed from the desktop: click to put them back
                    Repeater {
                        model: view.sys.removedBuiltins
                        delegate: Item {
                            id: bt
                            required property string modelData
                            readonly property var info: ({
                                date: "Date", clock: "Clock", weather: "Weather", right: "Info",
                                progress: "Progress", music: "Music", scratch: "Notes"
                            })
                            width: 96; height: 118
                            Rectangle {
                                anchors.fill: parent; radius: Math.max(10, view.sys.winR - 6)
                                color: bma.containsMouse ? ShellColors.fgA(0.10) : "transparent"
                            }
                            WCard {
                                sys: view.sys
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                                width: 78; height: 78
                                radius: 10
                                WCaption {
                                    sys: view.sys
                                    anchors.centerIn: parent
                                    text: bt.info[bt.modelData] || bt.modelData
                                    color: view.sys.colFg
                                }
                            }
                            WCaption {
                                sys: view.sys
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                                text: "Add"
                                font.pixelSize: view.sys.fontSize - 5
                            }
                            MouseArea {
                                id: bma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.showBuiltin(bt.modelData)
                            }
                        }
                    }


                    }
                }

                WheelHandler {
                    onWheel: ev => {
                        var d = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x;
                        fl.contentX = Math.max(0, Math.min(fl.contentWidth - fl.width, fl.contentX - d));
                    }
                }

                // arrows appear only when the list overflows
                Repeater {
                    model: scroller.overflow ? [ -1, 1 ] : []
                    delegate: Rectangle {
                        required property int modelData
                        visible: modelData < 0 ? fl.contentX > 2 : fl.contentX < fl.contentWidth - fl.width - 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: modelData < 0 ? 0 : parent.width - width
                        width: 30; height: 30; radius: 15
                        color: view.sys.colBg
                        border.width: 1; border.color: ShellColors.fgA(0.3)
                        z: 5
                        Text { anchors.centerIn: parent; text: modelData < 0 ? "‹" : "›"; color: view.sys.colFg; font.pixelSize: 20 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: fl.contentX = Math.max(0, Math.min(fl.contentWidth - fl.width, fl.contentX + modelData * (fl.width * 0.7)))
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 60; anchors.verticalCenter: parent.verticalCenter; color: ShellColors.fgA(0.12) }

            Column {
                id: rightCol
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Rectangle {
                    width: 84; height: 32; radius: 16
                    color: view.sys.colFg
                    Text { anchors.centerIn: parent; text: "Done"; color: view.sys.colBg
                           font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; weight: Font.DemiBold } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.sys.widgetEdit = false }
                }
                Rectangle {
                    width: 84; height: 32; radius: 16
                    color: "transparent"; border.width: 1; border.color: view.sys.colLine
                    Text { anchors.centerIn: parent; text: "Clear added"; color: view.sys.colMuted
                           font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.sys.clearWidgets() }
                }
            }
        }
    }
}
