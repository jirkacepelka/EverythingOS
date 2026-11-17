pragma ComponentBehavior: Bound

import QtQuick

// Čísla obyčejným písmem (lišta, panel rychlého nastavení). Widgety používají DotText (tečky).
//
//
// Tady se místo toho vykresluje obyčejné písmo, aby celé rozhraní používalo
// jednu rodinu písma. Rozhraní (value, size, gapRatio, color, charGap) zůstává
// stejné, takže ostatní soubory se nemusí měnit.
Item {
    id: dt

    property string value: ""

    // Výška číslice v pixelech (jako dřív).
    property real size: 14
    // Zachováno kvůli kompatibilitě s původní komponentou; písmo ho nepoužívá.
    property real gapRatio: 0.22
    property color color: "#ffffff"
    property real charGap: 0
    // Rodina písma sjednocená s nastavením EverythingOS (Vzhled → Písmo).
    property string family: "GoogleSansCode Nerd Font Propo"

    // Výška číslice ≈ 0.72 velikosti písma, proto se velikost přepočítává.
    readonly property real fontPx: Math.max(1, Math.round(dt.size / 0.72))

    implicitWidth: txt.implicitWidth
    implicitHeight: dt.size

    Text {
        id: txt
        anchors.verticalCenter: parent.verticalCenter
        text: dt.value
        color: dt.color
        font.family: dt.family
        font.pixelSize: dt.fontPx
        font.weight: Font.Normal
        font.letterSpacing: dt.charGap
        renderType: Text.NativeRendering
    }
}
