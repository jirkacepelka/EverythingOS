import QtQuick
import QtQuick.Layouts

// One-line text setting: rounded field that commits on Enter / focus loss.
Rectangle {
    id: tf
    property var sys
    property string text: ""
    property string placeholder: ""
    signal commit(string text)

    Layout.fillWidth: true
    Layout.preferredHeight: 32
    radius: 10
    color: Qt.rgba(tf.sys.colFg.r, tf.sys.colFg.g, tf.sys.colFg.b, 0.07)

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: Text.AlignVCenter
        color: tf.sys.colFg
        clip: true
        selectByMouse: true
        text: tf.text
        font { family: tf.sys.fontBody; pixelSize: tf.sys.fontSize - 3 }
        onEditingFinished: tf.commit(text)

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0
            text: tf.placeholder
            color: tf.sys.colMuted
            elide: Text.ElideRight
            font: input.font
        }
    }
}
