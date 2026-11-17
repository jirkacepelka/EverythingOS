pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Appearance. Оформление в стиле Nothing OS: минималистичная монохромная
// палитра, фирменные точечные шрифты, виджеты рабочего стола и системные звуки.
ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false
    readonly property color cur: Qt.color(page.sys.cfg.borderColor)
    property var localeOptions: [{ id: "en", text: "English" }, { id: "ru", text: "Русский" }, { id: "tr", text: "Türkçe" }]

    Process {
        command: [page.sys.scriptDir + "/locale.sh", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var options = [];
                var lines = String(text).trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|");
                    if (parts.length !== 2 || !parts[0].length) continue;
                    var locale = Qt.locale(parts[0]);
                    var nativeName = locale && locale.name !== "C" ? locale.nativeLanguageName : "";
                    options.push({ id: parts[0], text: nativeName ? nativeName + " · " + parts[0] : parts[1] });
                }
                if (options.length) page.localeOptions = options;
            }
        }
    }
    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- язык
    // Стоит первым: с языка начинают, а не заканчивают им.
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: "Workspaces" }

        SetToggle {
            sys: page.sys
            label: "Blurred background"
            sub: "Blur the desktop behind the workspace overview."
            on: page.sys.cfg.overviewBlur
            onToggled: v => { page.sys.cfg.overviewBlur = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Язык") }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Язык системы")
            options: page.localeOptions
            searchable: true
            value: page.sys.cfg.lang
            onPicked: id => page.sys.setLang(id)
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.sysLangPending
                  ? page.sys.tr("Меняем язык системы…")
                  : (!page.sys.systemLocaleMatches
                     ? page.sys.tr("Оболочка уже на новом языке. Приложения и меню читают язык при входе — они переключатся после перезахода.")
                     : page.sys.tr("Оболочка переключается сразу. Приложения и меню — после перезахода: язык они читают при входе."))
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }
        Text {
            Layout.fillWidth: true
            visible: ["en", "ru", "tr"].indexOf(page.sys.languageCode) < 0
            text: page.sys.tr("Для этого языка нет перевода интерфейса EverythingOS. Пока используется английский; запросите перевод через issue на GitHub.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }
    }

    // ------------------------------------------------------------- виджеты
    // --------------------------------------------- společný tvar a okraje
    // Jedna sada hodnot pro okna, ostrov, popupy i widgety.
    SetCard {
        sys: page.sys

        SetSlider {
            sys: page.sys
            label: "Gap / edge spacing (windows, island, widgets)"
            from: 0; to: 48; step: 1
            value: page.sys.cfg.islandGap
            suffix: "px"
            onMoved: v => { page.sys.cfg.islandGap = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: "Corner radius (windows, island, popups, widgets)"
            from: 0; to: 40; step: 1
            value: page.sys.cfg.islandRadius
            valueText: page.sys.cfg.islandRadius === 0 ? "default" : page.sys.cfg.islandRadius + " px"
            onMoved: v => { page.sys.cfg.islandRadius = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: "Colored border – width"
            from: 0; to: 6; step: 1
            value: page.sys.cfg.borderWidth
            suffix: "px"
            onMoved: v => { page.sys.cfg.borderWidth = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: "Colored border – opacity"
            from: 0; to: 100; step: 5
            value: page.sys.cfg.borderAlpha
            suffix: "%"
            onMoved: v => { page.sys.cfg.borderAlpha = v; page.sys.saveCfg(); }
        }

        // Jemná paleta (tlumené tóny) – klik nastaví barvu okraje
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: ["#9a9aa2", "#d8d8dc", "#b9a7a0", "#c9a48a", "#c8bd8a", "#8fb59a", "#8aa9c4", "#a49bc4", "#c49bb4"]
                delegate: Rectangle {
                    required property string modelData
                    width: 30; height: 30; radius: 15
                    color: modelData
                    border.width: page.sys.cfg.borderColor === modelData ? 3 : 1
                    border.color: page.sys.cfg.borderColor === modelData ? page.sys.colFg : Qt.rgba(1, 1, 1, 0.25)
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { page.sys.cfg.borderColor = parent.modelData; page.sys.saveCfg(); }
                    }
                }
            }
        }

        // Vlastní barva: odstín / sytost / jas
        Text {
            text: "Custom color (hue · saturation · lightness)"
            color: page.sys.colMuted
            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 3 }
        }
        SetSlider {
            sys: page.sys
            label: "Hue"
            from: 0; to: 360; step: 1
            value: Math.max(0, page.cur.hslHue) * 360
            onMoved: v => { page.sys.cfg.borderColor = String(Qt.hsla(v / 360, Math.max(0.05, page.cur.hslSaturation), page.cur.hslLightness, 1)); page.sys.saveCfg(); }
        }
        SetSlider {
            sys: page.sys
            label: "Saturation"
            from: 0; to: 100; step: 1
            value: page.cur.hslSaturation * 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.borderColor = String(Qt.hsla(Math.max(0, page.cur.hslHue), v / 100, page.cur.hslLightness, 1)); page.sys.saveCfg(); }
        }
        SetSlider {
            sys: page.sys
            label: "Lightness"
            from: 10; to: 95; step: 1
            value: page.cur.hslLightness * 100
            suffix: "%"
            onMoved: v => { page.sys.cfg.borderColor = String(Qt.hsla(Math.max(0, page.cur.hslHue), page.cur.hslSaturation, v / 100, 1)); page.sys.saveCfg(); }
        }
    }

    SetButton {
        sys: page.sys
        text: page.detailsOpen ? page.sys.tr("Скрыть подробности") : page.sys.tr("Подробные настройки")
        onClicked: page.detailsOpen = !page.detailsOpen
    }

    // ------------------------------------------------------------- оформление
    SetCard {
        sys: page.sys
        visible: page.detailsOpen

        SetLabel { sys: page.sys; text: page.sys.tr("Оформление") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Приглушённый текст")
            from: 0.2; to: 1.0; step: 0.05
            decimals: 2
            value: page.sys.cfg.mutedAlpha
            onMoved: v => { page.sys.cfg.mutedAlpha = v; page.sys.saveCfg(); }
        }

        // Прозрачность терминала
        SetSlider {
            sys: page.sys
            label: page.sys.tr("Прозрачность терминала")
            from: 0.5; to: 1.0; step: 0.01
            decimals: 2
            value: page.sys.cfg.termAlpha
            onMoved: v => {
                page.sys.cfg.termAlpha = v;
                page.sys.saveCfg();
                page.sys.applyTermAlpha();
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("1.00 — сплошной фон. Действует сразу; если нет — терминал держит свои настройки с прошлого входа, и его серверу нужен перезапуск.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Перезапустить терминал")
                onClicked: page.sys.restartTerminalServer()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Открытые окна терминала при этом закроются: они работают от того же сервера.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }
    }

    // ------------------------------------------------------------- шрифты
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Шрифты") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Размер текста")
            from: 10; to: 24; step: 1
            value: page.sys.cfg.fontSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.fontSize = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Размер иконок")
            visible: page.detailsOpen
            from: 12; to: 28; step: 1
            value: page.sys.cfg.iconSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.iconSize = v; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Шрифт текста")
            visible: page.detailsOpen
            options: page.sys.fontList
            value: page.sys.cfg.fontBody || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontBody = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Шрифт заголовков")
            visible: page.detailsOpen
            options: page.sys.fontList
            value: page.sys.cfg.fontDisplay || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontDisplay = id; page.sys.saveCfg(); }
        }

        // Значковый шрифт отдельно: подписи можно поставить любые, но иконки
        // рисует только Nerd Font, и менять его вместе с текстовым нельзя.
        SetPick {
            sys: page.sys
            label: page.sys.tr("Шрифт значков")
            visible: page.detailsOpen
            options: page.sys.fontList
            value: page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontFam = id; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- звуки
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Звуки") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Звуковые эффекты системы")
            sub: page.sys.tr("Зарядка, подключение Bluetooth, скриншоты, голосовой ввод")
            on: page.sys.cfg.uiSounds !== false
            onToggled: value => {
                page.sys.cfg.uiSounds = value;
                page.sys.saveCfg();
                if (value) page.sys.playSound("connect");
            }
        }

        // Кнопки предпрослушивания звуков
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            visible: page.sys.cfg.uiSounds !== false && page.detailsOpen

            Repeater {
                model: [
                    { id: "charge",      label: page.sys.tr("Зарядка"),     icon: "󰂄" },
                    { id: "connect",     label: "Bluetooth",               icon: "󰂯" },
                    { id: "disconnect",  label: page.sys.tr("Отключение"),  icon: "󰂲" },
                    { id: "screenshot",  label: page.sys.tr("Скриншот"),    icon: "󰄀" },
                    { id: "voice_start", label: page.sys.tr("Голос"),       icon: "󰍬" }
                ]

                Rectangle {
                    id: sndBtn

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: sndMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: sndMa.containsMouse ? page.sys.colOn : page.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: sndBtn.modelData.icon
                            color: sndMa.containsMouse ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: sndBtn.modelData.label
                            color: sndMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.sys.playSound(sndBtn.modelData.id)
                    }
                }
            }
        }
    }
}
