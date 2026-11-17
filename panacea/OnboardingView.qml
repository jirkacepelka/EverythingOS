pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Uvítací okno: ukazuje se při každém spuštění Panacea (jde vypnout dole)
// a dává základní nastavení vizuálně, s náhledy místo seznamu přepínačů.
FocusScope {
    id: view

    property var sys
    readonly property var cfg: view.sys.cfg

    function close() { view.sys.onboardingOpen = false; }

    Component.onCompleted: view.forceActiveFocus()
    Keys.onEscapePressed: view.close()
    Keys.onReturnPressed: view.close()

    readonly property color cardBg:   Qt.rgba(1, 1, 1, 0.05)
    readonly property color cardLine: Qt.rgba(1, 1, 1, 0.10)
    readonly property color accent:   view.sys.colFg
    readonly property int fs: view.sys.fontSize

    // ztmavení pozadí, klik mimo okno zavře
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.62)
        MouseArea { anchors.fill: parent; onClicked: view.close() }
    }

    Rectangle {
        id: win
        anchors.centerIn: parent
        width: Math.min(960, parent.width - 80)
        height: Math.min(content.implicitHeight + 64, parent.height - 80)
        radius: 28
        color: view.sys.colBg
        border.color: view.cardLine
        border.width: 1
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors { fill: parent; margins: 32 }
            spacing: 22

            // ------------------------------------------------ hlavička
            ColumnLayout {
                spacing: 4
                Text {
                    text: "Welcome to Panacea"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.fs + 12; weight: Font.Normal }
                }
                Text {
                    text: "A few things you can set up right away. Everything can be changed later in Settings (Super+I)."
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.fs - 1 }
                }
            }

            // ------------------------------------------------ island style
            IslandStylePicker { sys: view.sys; cardHeight: 118 }

            // ------------------------------------------------ přepínače
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // oči
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    radius: 18
                    color: view.cardBg
                    border.color: view.cardLine; border.width: 1
                    readonly property bool on: view.cfg.mascotEnabled
                    Row {
                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                        spacing: 7
                        opacity: parent.on ? 1 : 0.25
                        Repeater { model: 2; Rectangle { width: 9; height: 24; radius: 5; color: view.sys.colFg } }
                    }
                    Column {
                        anchors { left: parent.left; leftMargin: 70; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text { text: "Eyes in the island"; color: view.sys.colFg
                               font { family: view.sys.fontFam; pixelSize: view.fs } }
                        Text { text: parent.parent.on ? "On" : "Off"; color: view.sys.colMuted
                               font { family: view.sys.fontFam; pixelSize: view.fs - 3 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { view.cfg.mascotEnabled = !view.cfg.mascotEnabled; view.sys.saveCfg(); }
                    }
                }

                // widgety na ploše
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    radius: 18
                    color: view.cardBg
                    border.color: view.cardLine; border.width: 1
                    readonly property bool on: view.cfg.featWidgets
                    Grid {
                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                        columns: 2; spacing: 4
                        opacity: parent.on ? 1 : 0.25
                        Repeater { model: 4; Rectangle { width: 16; height: 16; radius: 5; color: view.sys.colFg } }
                    }
                    Column {
                        anchors { left: parent.left; leftMargin: 70; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text { text: "Desktop widgets"; color: view.sys.colFg
                               font { family: view.sys.fontFam; pixelSize: view.fs } }
                        Text { text: parent.parent.on ? "On" : "Off"; color: view.sys.colMuted
                               font { family: view.sys.fontFam; pixelSize: view.fs - 3 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { view.cfg.featWidgets = !view.cfg.featWidgets; view.sys.saveCfg(); }
                    }
                    // úprava rozložení: zavře okno a zapne přetahování (Super+Shift+D)
                    Rectangle {
                        visible: parent.on
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        width: editTxt.implicitWidth + 24; height: 32; radius: 16
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Text { id: editTxt; anchors.centerIn: parent; text: "Edit layout"; color: view.sys.colFg
                               font { family: view.sys.fontFam; pixelSize: view.fs - 3 } }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { view.sys.onboardingOpen = false; view.sys.widgetEdit = true; }
                        }
                    }
                }
            }

            // ------------------------------------------------ zkratky
            Text {
                text: "SHORTCUTS"
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.fs - 4; letterSpacing: 1.5 }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [
                        { k: "Super",      d: "Workspaces, then type to search" },
                        { k: "Super+A",    d: "App launcher" },
                        { k: "Super+F",    d: "Files" },
                        { k: "Super+B",    d: "Browser" },
                        { k: "Alt+Tab",    d: "Switch windows" },
                        { k: "Super+Ctrl+←/→", d: "Move window to workspace" },
                        { k: "Super+I",    d: "Settings" },
                        { k: "Super+/",    d: "All shortcuts" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: row.implicitWidth + 24; height: 34; radius: 17
                        color: view.cardBg
                        border.color: view.cardLine; border.width: 1
                        Row {
                            id: row
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: modelData.k; color: view.sys.colFg
                                   font { family: view.sys.fontFam; pixelSize: view.fs - 3; weight: Font.DemiBold } }
                            Text { text: modelData.d; color: view.sys.colMuted
                                   font { family: view.sys.fontFam; pixelSize: view.fs - 3 } }
                        }
                    }
                }
            }

            // ------------------------------------------------ patička
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                MouseArea {
                    Layout.preferredWidth: chk.implicitWidth + 34
                    Layout.preferredHeight: 34
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { view.cfg.showOnboarding = !view.cfg.showOnboarding; view.sys.saveCfg(); }
                    Rectangle {
                        id: box
                        width: 20; height: 20; radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.cfg.showOnboarding ? view.sys.colFg : "transparent"
                        border.color: view.cfg.showOnboarding ? view.sys.colFg : view.sys.colMuted
                        border.width: 1.5
                        Text {
                            anchors.centerIn: parent; visible: view.cfg.showOnboarding
                            text: "✓"; color: view.sys.colBg
                            font { pixelSize: 13; bold: true }
                        }
                    }
                    Text {
                        id: chk
                        anchors { left: box.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "Show on every start"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.fs - 2 }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 130; Layout.preferredHeight: 42
                    radius: 21
                    color: view.sys.colFg
                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: view.sys.colBg
                        font { family: view.sys.fontFam; pixelSize: view.fs - 1; weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: view.close()
                    }
                }
            }
        }
    }
}
