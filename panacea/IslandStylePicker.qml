pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Visual island style picker, shared by Settings and Onboarding.
// Two independent choices: Position (attached to top / floating) and
// Layout (together / 3 pills). 3 pills implies a floating island.
ColumnLayout {
    id: pk

    property var sys
    readonly property var cfg: pk.sys.cfg
    readonly property bool attached: pk.cfg.notchMode
    readonly property bool split: pk.cfg.splitIsland
    property int cardHeight: 150

    Layout.fillWidth: true
    spacing: 10

    function pickPosition(att) {
        pk.cfg.notchMode = att;
        pk.sys.saveCfg();
    }
    function pickLayout(split) {
        pk.cfg.splitIsland = split;
        pk.sys.saveCfg();
    }

    // one small preview card: kind = attached | floating | together | pills
    component Card: Rectangle {
        id: card
        property string kind: "attached"
        property string title: ""
        property string sub: ""
        property bool sel: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: pk.cardHeight
        radius: 18
        color: ShellColors.fgA(0.05)
        border.width: card.sel ? 2 : 1
        border.color: card.sel ? pk.sys.colFg : ShellColors.fgA(0.10)

        Rectangle {
            id: scr
            anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 28
            height: pk.cardHeight - 78
            radius: 10
            color: "#141416"
            clip: true

            Rectangle {   // app window
                x: 8; y: card.kind === "attached" ? 20 : 30
                width: parent.width - 16
                height: parent.height - y - 8
                radius: 6
                color: "#2b2b2f"
            }
            Rectangle {   // attached notch
                visible: card.kind === "attached"
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0; width: 110; height: 14
                bottomLeftRadius: 8; bottomRightRadius: 8
                color: "#000000"
            }
            Rectangle {   // floating single capsule
                visible: card.kind === "floating" || card.kind === "together"
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8; width: 110; height: 14; radius: 7
                color: "#000000"
            }
            Repeater {    // three pills (flush with the top edge when Attached is selected)
                model: card.kind === "pills" ? 3 : 0
                delegate: Rectangle {
                    required property int index
                    y: pk.attached ? 0 : 8; height: 14; radius: 7; color: "#000000"
                    topLeftRadius: pk.attached ? 0 : radius; topRightRadius: pk.attached ? 0 : radius
                    width: index === 1 ? 34 : 50
                    x: index === 0 ? 8 : index === 1 ? (scr.width - width) / 2 : scr.width - width - 8
                }
            }
        }
        Text {
            anchors { left: parent.left; leftMargin: 16; top: scr.bottom; topMargin: 10 }
            text: card.title
            color: pk.sys.colFg
            font { family: pk.sys.fontFam; pixelSize: pk.sys.fontSize - 1 }
        }
        Text {
            anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 12
                      bottom: parent.bottom; bottomMargin: 10 }
            text: card.sub
            color: pk.sys.colMuted
            elide: Text.ElideRight
            font { family: pk.sys.fontFam; pixelSize: pk.sys.fontSize - 4 }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }
    }

    Text {
        text: "POSITION"
        color: pk.sys.colMuted
        font { family: pk.sys.fontFam; pixelSize: pk.sys.fontSize - 4; letterSpacing: 1.5 }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Card { kind: "attached"; title: "Attached"; sub: "Fixed to the top edge"
               sel: pk.attached; onClicked: pk.pickPosition(true) }
        Card { kind: "floating"; title: "Floating"; sub: "Detached, with a gap"
               sel: !pk.attached; onClicked: pk.pickPosition(false) }
    }

    Text {
        text: "LAYOUT"
        color: pk.sys.colMuted
        font { family: pk.sys.fontFam; pixelSize: pk.sys.fontSize - 4; letterSpacing: 1.5 }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Card { kind: "together"; title: "Together"; sub: "One capsule"
               sel: !pk.split; onClicked: pk.pickLayout(false) }
        Card { kind: "pills"; title: "3 pills"; sub: "Workspaces · clock · system"
               sel: pk.split; onClicked: pk.pickLayout(true) }
    }
}
