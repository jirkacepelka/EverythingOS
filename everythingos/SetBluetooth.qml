import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bluetooth: adapter switches, scanning, and devices grouped as
// connected / paired / available, each with connect, disconnect, trust and forget.
ColumnLayout {
    id: page

    property var sys
    readonly property var adapter: page.sys.btAdapter

    Layout.fillWidth: true
    spacing: 12

    function isNamed(d) {
        var n = d.name || "";
        // unnamed devices show their MAC address as the name
        return n.length > 0 && !/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(n);
    }
    function groupOf(d) { return d.connected ? 0 : ((d.paired || d.bonded) ? 1 : 2); }
    function iconOf(d) {
        var i = d.icon;
        return (i === "audio-headset" || i === "audio-headphones") ? "󱡏"
             : i === "input-mouse" ? "󰦋" : i === "input-keyboard" ? "󰌌"
             : (i === "audio-speakers" || i === "audio-speaker") ? "󰓃"
             : i === "input-gaming" ? "󰊴" : (i === "phone" || i === "smartphone") ? "󰄞"
             : i === "watch" ? "󰖄" : "󰂯";
    }
    readonly property int hiddenCount: {
        var n = 0, v = page.sys.btDevices ? page.sys.btDevices.values : [];
        for (var i = 0; i < v.length; i++) if (!isNamed(v[i]) && groupOf(v[i]) === 2) n++;
        return n;
    }

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: "Bluetooth"
            sub: !page.adapter ? "No adapter found" : (page.sys.btOn ? (page.sys.btConnectedName.length ? "Connected to " + page.sys.btConnectedName : "On") : "Off")
            on: page.sys.btOn
            onToggled: v => page.sys.toggleBt()
        }
        SetToggle {
            sys: page.sys
            label: "Discoverable"
            sub: "Let nearby devices find this computer."
            on: page.adapter ? page.adapter.discoverable : false
            onToggled: v => { if (page.adapter && page.sys.btOn) page.adapter.discoverable = v; }
        }
        SetToggle {
            sys: page.sys
            label: "Show unnamed devices"
            sub: "Nearby devices that only advertise an address. Usually beacons and noise."
            on: page.sys.cfg.btShowUnnamed
            onToggled: v => { page.sys.cfg.btShowUnnamed = v; page.sys.saveCfg(); }
        }
        SetToggle {
            sys: page.sys
            label: "Bluetooth tile in quick settings"
            sub: "Show the Bluetooth tile and the device list in the island."
            on: page.sys.cfg.featBluetooth
            onToggled: v => { page.sys.cfg.featBluetooth = v; page.sys.saveCfg(); }
        }
        RowLayout {
            Layout.fillWidth: true
            SetButton {
                sys: page.sys
                text: (page.adapter && page.adapter.discovering) ? "Scanning…" : "Scan for devices"
                enabled: page.sys.btOn && !(page.adapter && page.adapter.discovering)
                onClicked: page.sys.scanBt()
            }
            Item { Layout.fillWidth: true }
        }
    }

    component Section: ColumnLayout {
        id: sec
        property int group: 0
        property string title: ""
        readonly property var devs: page.sys.btDevices ? page.sys.btDevices.values : []
        readonly property int shown: {
            var n = 0;
            for (var i = 0; i < sec.devs.length; i++) {
                var d = sec.devs[i];
                if (page.groupOf(d) === sec.group && (sec.group < 2 || page.sys.cfg.btShowUnnamed || page.isNamed(d))) n++;
            }
            return n;
        }
        Layout.fillWidth: true
        spacing: 12
        visible: sec.shown > 0

        SetLabel { sys: page.sys; text: sec.title }
        SetCard {
            sys: page.sys
            spacing: 4
            pad: 10
            Repeater {
                model: page.sys.btDevices
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                    visible: page.groupOf(modelData) === sec.group
                             && (sec.group < 2 || page.sys.cfg.btShowUnnamed || page.isNamed(modelData))
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 52 : 0
                    radius: 12
                    color: modelData.connected ? ShellColors.fgA(0.06) : "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                        spacing: 12
                        Text {
                            text: page.iconOf(modelData)
                            color: modelData.connected ? page.sys.colOn : page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: 17 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || modelData.address
                                elide: Text.ElideRight
                                color: page.sys.colFg
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: modelData.connected }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.pairing ? "Pairing…"
                                    : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                                    : (modelData.connected ? "Connected" : (modelData.paired || modelData.bonded) ? "Paired" : "Available")
                                      + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                                      + (modelData.trusted ? " · trusted" : "")
                                elide: Text.ElideRight
                                color: page.sys.colMuted
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            }
                        }
                        SetButton {
                            sys: page.sys
                            visible: !modelData.connected
                            enabled: !row.busy
                            text: (modelData.paired || modelData.bonded) ? "Connect" : "Pair"
                            onClicked: {
                                modelData.trusted = true;
                                if (modelData.paired || modelData.bonded) modelData.connect(); else modelData.pair();
                            }
                        }
                        SetButton {
                            sys: page.sys
                            visible: modelData.connected
                            text: "Disconnect"
                            onClicked: modelData.disconnect()
                        }
                        SetButton {
                            sys: page.sys
                            visible: modelData.paired || modelData.bonded
                            text: "Forget"
                            onClicked: modelData.forget()
                        }
                    }
                    // finish connecting once pairing completes
                    Connections {
                        target: row.modelData
                        function onPairedChanged() {
                            if (row.modelData.paired && !row.modelData.connected) row.modelData.connect();
                        }
                    }
                }
            }
        }
    }

    Section { group: 0; title: "Connected" }
    Section { group: 1; title: "Paired" }
    Section { group: 2; title: "Available" }

    Text {
        Layout.fillWidth: true
        visible: page.sys.btOn && !page.sys.cfg.btShowUnnamed && page.hiddenCount > 0
        text: page.hiddenCount + " unnamed device" + (page.hiddenCount === 1 ? "" : "s") + " hidden"
        color: page.sys.colMuted
        horizontalAlignment: Text.AlignHCenter
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
    }
    Text {
        Layout.fillWidth: true
        visible: !page.sys.btOn
        text: "Bluetooth is off"
        color: page.sys.colMuted
        horizontalAlignment: Text.AlignHCenter
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
    }
}
