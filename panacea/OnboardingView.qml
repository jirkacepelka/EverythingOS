pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Uvítací okno: ukazuje se při každém spuštění Panacea (jde vypnout dole)
// a dává základní nastavení vizuálně, s náhledy místo seznamu přepínačů.
FocusScope {
    id: view

    property var sys
    readonly property var cfg: view.sys.cfg

    // 0 výřez · 1 plovoucí · 2 tři pilulky
    readonly property int islandMode: view.cfg.notchMode ? 0 : (view.cfg.splitIsland ? 2 : 1)
    function setIslandMode(m) {
        view.cfg.notchMode = (m === 0);
        view.cfg.splitIsland = (m === 2);
        view.sys.saveCfg();
    }
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
                    text: "Vítej v Panacea"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.fs + 12; weight: Font.Normal }
                }
                Text {
                    text: "Pár věcí si můžeš nastavit hned. Všechno jde později změnit v Nastavení (Super+I)."
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.fs - 1 }
                }
            }

            // ------------------------------------------------ styl ostrova
            Text {
                text: "STYL OSTROVA"
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.fs - 4; letterSpacing: 1.5 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Repeater {
                    model: [
                        { m: 0, title: "Výřez",     sub: "Přisazený k hraně obrazovky" },
                        { m: 1, title: "Plovoucí",  sub: "Samostatná kapsle s odstupem" },
                        { m: 2, title: "3 pilulky", sub: "Stoly, hodiny a systém zvlášť" }
                    ]
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool sel: view.islandMode === card.modelData.m
                        Layout.fillWidth: true
                        Layout.preferredHeight: 190
                        radius: 18
                        color: view.cardBg
                        border.width: card.sel ? 2 : 1
                        border.color: card.sel ? view.accent : view.cardLine

                        // náhled obrazovky
                        Rectangle {
                            id: scr
                            anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
                            width: parent.width - 32
                            height: 104
                            radius: 10
                            color: "#141416"
                            clip: true

                            // okno aplikace s mezerami (stejná mřížka jako ve skutečnosti)
                            Rectangle {
                                x: 8; y: card.modelData.m === 0 ? 20 : 30
                                width: parent.width - 16
                                height: parent.height - y - 8
                                radius: 6
                                color: "#2b2b2f"
                            }
                            // ostrov
                            Rectangle {
                                visible: card.modelData.m === 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 0; width: 110; height: 14
                                bottomLeftRadius: 8; bottomRightRadius: 8
                                color: "#000000"
                            }
                            Rectangle {
                                visible: card.modelData.m === 1
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 8; width: 110; height: 14; radius: 7
                                color: "#000000"
                            }
                            Repeater {
                                model: card.modelData.m === 2 ? 3 : 0
                                delegate: Rectangle {
                                    required property int index
                                    y: 8; height: 14; radius: 7; color: "#000000"
                                    width: index === 1 ? 34 : 50
                                    x: index === 0 ? 8
                                     : index === 1 ? (scr.width - width) / 2
                                     : scr.width - width - 8
                                }
                            }
                        }

                        Text {
                            anchors { left: parent.left; leftMargin: 18; top: scr.bottom; topMargin: 12 }
                            text: card.modelData.title
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.fs }
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 18
                                      bottom: parent.bottom; bottomMargin: 12 }
                            text: card.modelData.sub
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: view.fs - 3 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.setIslandMode(card.modelData.m)
                        }
                    }
                }
            }

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
                        Text { text: "Oči v ostrově"; color: view.sys.colFg
                               font { family: view.sys.fontFam; pixelSize: view.fs } }
                        Text { text: parent.parent.on ? "Zapnuto" : "Vypnuto"; color: view.sys.colMuted
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
                        Text { text: "Widgety na ploše"; color: view.sys.colFg
                               font { family: view.sys.fontFam; pixelSize: view.fs } }
                        Text { text: parent.parent.on ? "Zapnuto" : "Vypnuto"; color: view.sys.colMuted
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
                        Text { id: editTxt; anchors.centerIn: parent; text: "Upravit rozložení"; color: view.sys.colFg
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
                text: "ZKRATKY"
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.fs - 4; letterSpacing: 1.5 }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [
                        { k: "Super",      d: "Plochy, pak psaním hledání" },
                        { k: "Super+A",    d: "Spouštěč aplikací" },
                        { k: "Super+F",    d: "Soubory" },
                        { k: "Super+B",    d: "Prohlížeč" },
                        { k: "Alt+Tab",    d: "Přepínání oken" },
                        { k: "Super+I",    d: "Nastavení" },
                        { k: "Super+/",    d: "Všechny zkratky" }
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
                        text: "Zobrazovat při každém spuštění"
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
                        text: "Hotovo"
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
