import QtQuick
import QtQuick.Layouts

// Desktop widgets: master switch, layout editor, built-in widget visibility and modes.
ColumnLayout {
    id: page

    property var sys
    readonly property var builtins: [
        { id: "date",     name: "Date" },
        { id: "clock",    name: "Clock" },
        { id: "weather",  name: "Weather" },
        { id: "right",    name: "Info block (weather / system)" },
        { id: "progress", name: "Progress" },
        { id: "music",    name: "Music player", cfg: "widgetMusic" },
        { id: "scratch",  name: "Scratchpad",   cfg: "widgetScratchpad" }
    ]
    function visibleBuiltin(b) {
        if (b.cfg && page.sys.cfg[b.cfg] === false) return false;
        return page.sys.widgetHidden.indexOf(b.id) < 0;
    }
    function setBuiltin(b, on) {
        if (b.cfg) { page.sys.cfg[b.cfg] = on; page.sys.saveCfg(); }
        var h = page.sys.widgetHidden.filter(function (x) { return x !== b.id; });
        if (!on) h.push(b.id);
        page.sys.cfg.widgetHiddenJson = JSON.stringify(h); page.sys.saveCfg();
    }

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: "Desktop widgets"
            sub: "Nothing-style cards on the desktop: date, clocks, weather, system, sound, brightness and more."
            on: page.sys.cfg.featWidgets
            onToggled: v => { page.sys.cfg.featWidgets = v; page.sys.saveCfg(); }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SetButton {
                sys: page.sys; text: "Edit widgets"; primary: true
                enabled: page.sys.cfg.featWidgets
                onClicked: { page.sys.collapse(); page.sys.widgetEdit = true; }
            }
            SetButton { sys: page.sys; text: "Reset layout"; onClicked: page.sys.widgetsResetAll() }
            Item { Layout.fillWidth: true }
        }
        Text {
            Layout.fillWidth: true
            text: "Open the editor to drag widgets onto the grid, add new ones from the tray at the bottom, or remove them. You can also right-click the empty desktop."
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    SetLabel { sys: page.sys; text: "Built-in widgets" }

    SetCard {
        sys: page.sys
        visible: page.sys.cfg.featWidgets
        Repeater {
            model: page.builtins
            delegate: SetToggle {
                required property var modelData
                sys: page.sys
                label: modelData.name
                on: page.visibleBuiltin(modelData)
                onToggled: v => page.setBuiltin(modelData, v)
            }
        }
    }

    SetLabel { sys: page.sys; text: "Modes" }

    SetCard {
        sys: page.sys
        visible: page.sys.cfg.featWidgets

        SetSelect {
            sys: page.sys
            label: "Clock style"
            options: [ { id: "analog", text: "Analog" }, { id: "digital", text: "Dot digits" } ]
            value: page.sys.cfg.widgetClockMode || "analog"
            onPicked: id => { page.sys.cfg.widgetClockMode = id; page.sys.saveCfg(); }
        }
        SetSelect {
            sys: page.sys
            label: "Info block"
            options: [ { id: "weather", text: "Weather" }, { id: "system", text: "System" } ]
            value: page.sys.cfg.widgetRightMode || "weather"
            onPicked: id => { page.sys.cfg.widgetRightMode = id; page.sys.saveCfg(); }
        }
        SetSelect {
            sys: page.sys
            label: "Progress bar"
            options: [ { id: "day", text: "Day" }, { id: "year", text: "Year" } ]
            value: page.sys.cfg.widgetProgressMode || "day"
            onPicked: id => { page.sys.cfg.widgetProgressMode = id; page.sys.saveCfg(); }
        }
    }

    SetLabel { sys: page.sys; text: "Added widgets" }

    SetCard {
        sys: page.sys
        visible: page.sys.cfg.featWidgets
        Text {
            Layout.fillWidth: true
            text: page.sys.widgetItems.length === 0 ? "None yet. Open the editor and pick widgets from the tray."
                                                     : page.sys.widgetItems.length + " widget" + (page.sys.widgetItems.length === 1 ? "" : "s") + " placed on the desktop."
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }
        RowLayout {
            Layout.fillWidth: true
            SetButton { sys: page.sys; text: "Remove all added"; enabled: page.sys.widgetItems.length > 0; onClicked: page.sys.clearWidgets() }
            Item { Layout.fillWidth: true }
        }
    }
}
