import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    property string kind: "home"
    property color tint: "white"
    implicitWidth: 19
    implicitHeight: 19
    Shape {
        width: 20; height: 20
        scale: Math.min(icon.width, icon.height) / 20
        transformOrigin: Item.TopLeft
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: icon.tint; strokeWidth: 1.5
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.kind === "home" ? "M 3.5 9 L 10 3.8 L 16.5 9 L 16.5 16.2 Q 16.5 17 15.7 17 L 4.3 17 Q 3.5 17 3.5 16.2 Z M 8 17 L 8 12 L 12 12 L 12 17" : icon.kind === "music" ? "M 7.5 14.5 L 7.5 4.5 L 15 3 L 15 13 M 7.5 14.5 A 2.2 2.2 0 1 1 5.3 12.3 A 2.2 2.2 0 0 1 7.5 14.5 M 15 13 A 2.2 2.2 0 1 1 12.8 10.8 A 2.2 2.2 0 0 1 15 13" : icon.kind === "cal" ? "M 4 5.5 L 16 5.5 L 16 16.5 L 4 16.5 Z M 4 9 L 16 9 M 7.5 3.5 L 7.5 6.5 M 12.5 3.5 L 12.5 6.5" : "M 16.8 9.2 C 16.8 5.5 13.8 2.7 10.1 2.7 C 6.3 2.7 3.3 5.5 3.3 9.2 C 3.3 10.7 3.8 12.1 4.7 13.2 L 3.9 16.7 L 7.3 15.3 C 8.2 15.7 9.1 15.8 10.1 15.8 C 13.8 15.8 16.8 12.9 16.8 9.2 Z" }
        }
    }
}
