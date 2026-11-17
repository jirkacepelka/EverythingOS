import QtQuick
import QtQuick.Layouts

// Wi-Fi: adapter switch, current connection, saved/nearby networks with
// connect / disconnect / forget, and an inline password prompt.
ColumnLayout {
    id: page

    property var sys
    property string passwordFor: ""
    property string passwordSecurity: "psk"

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { page.sys.refreshWifiList(); page.sys.scanWifi(); }

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: "Wi-Fi"
            sub: !page.sys.wifiOn ? "Off"
               : page.sys.wifiSsid.length ? "Connected to " + page.sys.wifiSsid + " · " + page.sys.wifiQuality + "%"
               : (page.sys.wifiConnectingSsid.length ? "Connecting to " + page.sys.wifiConnectingSsid + "…" : "Not connected")
            on: page.sys.wifiOn
            onToggled: v => page.sys.toggleWifi()
        }

        SetToggle {
            sys: page.sys
            label: "Wi-Fi tile in quick settings"
            sub: "Show the Wi-Fi tile and the network list in the island."
            on: page.sys.cfg.featWifi
            onToggled: v => { page.sys.cfg.featWifi = v; page.sys.saveCfg(); }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SetButton {
                sys: page.sys; text: page.sys.wifiBusy ? "Scanning…" : "Scan"
                enabled: page.sys.wifiOn && !page.sys.wifiBusy
                onClicked: page.sys.scanWifi()
            }
            SetButton {
                sys: page.sys; text: "Disconnect"
                enabled: page.sys.wifiOn && page.sys.wifiSsid.length > 0
                onClicked: page.sys.disconnectWifi()
            }
            Item { Layout.fillWidth: true }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: page.sys.wifiError.length > 0
        text: page.sys.wifiError
        color: page.sys.colCrit
        wrapMode: Text.WordWrap
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
    }

    // password prompt for a new secured network
    SetCard {
        sys: page.sys
        visible: page.passwordFor.length > 0

        SetLabel { sys: page.sys; text: "Join " + page.passwordFor }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)
            visible: page.passwordSecurity === "eap"
            TextInput {
                id: userField
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                Text { visible: !parent.text.length; text: "Username"; color: page.sys.colMuted; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)
            TextInput {
                id: pwField
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: page.sys.colFg
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onAccepted: page.join()
                Text { visible: !parent.text.length; text: "Password"; color: page.sys.colMuted; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SetButton {
                sys: page.sys; text: "Connect"; primary: true
                enabled: pwField.text.length > 0 && (page.passwordSecurity !== "eap" || userField.text.length > 0)
                onClicked: page.join()
            }
            SetButton { sys: page.sys; text: "Cancel"; onClicked: page.closePrompt() }
            Item { Layout.fillWidth: true }
        }
    }

    function join() {
        if (!pwField.text.length) return;
        page.sys.connectWifi(page.passwordFor, pwField.text, userField.text, page.passwordSecurity);
        page.closePrompt();
    }
    function closePrompt() {
        page.passwordFor = ""; pwField.text = ""; userField.text = "";
        page.sys.holdOpen = false;
    }

    SetLabel { sys: page.sys; text: "Networks" }

    SetCard {
        sys: page.sys
        spacing: 4
        pad: 10

        Text {
            Layout.fillWidth: true
            Layout.margins: 6
            visible: page.sys.wifiNetworks.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: !page.sys.wifiOn ? "Wi-Fi is off" : (page.sys.wifiBusy ? "Looking for networks…" : "No networks found")
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
        }

        Repeater {
            model: page.sys.wifiNetworks
            delegate: Rectangle {
                id: row
                required property var model
                readonly property bool connecting: page.sys.wifiConnectingSsid.length > 0 && model.ssid === page.sys.wifiConnectingSsid
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 12
                color: model.connected ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                    spacing: 12
                    Text {
                        text: row.connecting ? "󰤩" : (model.quality > 66 ? "󰤨" : model.quality > 33 ? "󰤥" : "󰤟")
                        color: model.connected ? page.sys.colOn : page.sys.colFg
                        font { family: page.sys.fontFam; pixelSize: 17 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: model.ssid
                            elide: Text.ElideRight
                            color: page.sys.colFg
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2; bold: model.connected }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.connecting ? "Connecting…"
                                : (model.connected ? "Connected · " : "")
                                  + (model.security === "open" ? "Open" : model.security === "eap" ? "Enterprise" : "Secured")
                                  + " · " + model.quality + "%" + (model.known ? " · saved" : "")
                            elide: Text.ElideRight
                            color: page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                        }
                    }
                    SetButton {
                        sys: page.sys
                        visible: !model.connected && !row.connecting
                        text: "Connect"
                        onClicked: {
                            if (model.security === "open" || model.known) page.sys.connectWifi(model.ssid, "");
                            else {
                                page.passwordFor = model.ssid;
                                page.passwordSecurity = model.security;
                                page.sys.holdOpen = true;
                                pwField.forceActiveFocus();
                            }
                        }
                    }
                    SetButton {
                        sys: page.sys
                        visible: model.connected
                        text: "Disconnect"
                        onClicked: page.sys.disconnectWifi()
                    }
                    SetButton {
                        sys: page.sys
                        visible: model.known
                        text: "Forget"
                        onClicked: page.sys.forgetWifi(model.ssid)
                    }
                }
            }
        }
    }
}
