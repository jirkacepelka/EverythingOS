import QtQuick
import QtQuick.Layouts

// Bar & Island. Главный переключатель здесь — режим выреза: от него зависит,
// примыкает остров к кромке или висит отдельной капсулой, и часть ползунков
// имеет смысл только в одном из двух состояний.
ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false
    readonly property bool notch: page.sys.cfg.notchMode

    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- форма
    SetCard {
        sys: page.sys

        IslandStylePicker { sys: page.sys }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Автоскрытие")
            sub: page.sys.tr("Остров уезжает за кромку и не занимает место под себя: окна получают весь экран. Возвращается наведением на край.")
            on: page.sys.cfg.pillAutoHide
            onToggled: value => { page.sys.cfg.pillAutoHide = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Режим оверлея (Floating)")
            sub: page.sys.tr("Остров парит поверх окон без резервирования верхней строки: окна приложений не сжимаются и не прыгают при открытии или скрытии.")
            on: page.sys.cfg.pillOverlay
            onToggled: value => { page.sys.cfg.pillOverlay = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Остров виден при раскрытии")
            sub: page.sys.tr("Остров остаётся на своём месте в свёрнутом виде, а панель быстрых настроек и страницы открываются отдельной плавающей карточкой под ним.")
            on: page.sys.cfg.pillKeepVisible
            onToggled: value => { page.sys.cfg.pillKeepVisible = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Нагрузка системы на острове")
            sub: page.sys.tr("Показывать загрузку и температуру CPU и GPU на свёрнутом острове.")
            on: page.sys.cfg.systemLoadOnIsland
            onToggled: value => { page.sys.cfg.systemLoadOnIsland = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Закрывать окна EverythingOS по Super+Q")
            visible: page.detailsOpen
            sub: page.sys.tr("При открытых панелях или настройках EverythingOS нажатие Super+Q закрывает оверлей. Выключить — Super+Q всегда закрывает активное приложение на фоне.")
            on: page.sys.cfg.closePanaceaFirst
            onToggled: value => { page.sys.cfg.closePanaceaFirst = value; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Выступ выреза")
            from: 0; to: 32; step: 1
            value: page.sys.cfg.notchFlare
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchFlare = v; page.sys.saveCfg(); }
        }
    }

    SetButton {
        sys: page.sys
        text: page.detailsOpen ? page.sys.tr("Скрыть подробности") : page.sys.tr("Подробные настройки")
        onClicked: page.detailsOpen = !page.detailsOpen
    }

    // ------------------------------------------------------------- размеры
    SetCard {
        sys: page.sys
        visible: page.detailsOpen

        SetLabel { sys: page.sys; text: page.sys.tr("Размеры") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Высота панели")
            from: 24; to: 72; step: 1
            value: page.sys.cfg.pillH
            suffix: "px"
            onMoved: v => { page.sys.cfg.pillH = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Ширина свёрнутого острова")
            from: 120; to: 640; step: 4
            value: page.sys.cfg.collapsedW
            suffix: "px"
            onMoved: v => { page.sys.cfg.collapsedW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Ширина раскрытого острова")
            from: 380; to: 900; step: 10
            value: page.sys.cfg.panelW
            suffix: "px"
            onMoved: v => { page.sys.cfg.panelW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Высота раскрытого острова")
            from: 260; to: 1000; step: 10
            value: page.sys.cfg.expandedH
            suffix: "px"
            onMoved: v => { page.sys.cfg.expandedH = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- поведение
    SetCard {
        sys: page.sys
        visible: page.detailsOpen

        SetLabel { sys: page.sys; text: page.sys.tr("Поведение") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Переносить остров мышью")
            sub: page.sys.tr("Остров можно взять прямо на экране и перетащить к другой кромке.")
            on: page.sys.cfg.pillDrag
            onToggled: value => { page.sys.cfg.pillDrag = value; page.sys.saveCfg(); }
        }
    }
}
