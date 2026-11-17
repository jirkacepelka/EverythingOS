pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Обзор рабочих столов (Super+Tab).
//
// Превью не рисованные: каждое окно показывается живым кадром через
// ScreencopyView, поэтому в карточках продолжают идти видео и анимации.
// Геометрию окон берём из lastIpcObject — того же JSON, что отдаёт
// hyprctl clients, — и просто ужимаем её до размера карточки.
FocusScope {
    id: view
    property var sys

    // Opening: the content fades in once everything has been created, instead of
    // popping in piece by piece; the heavy parts (widget snapshots) stop updating after a moment.
    property bool opened: false
    property bool settling: true
    Timer { interval: 30; running: true; onTriggered: view.opened = true }
    Timer { interval: 900; running: true; onTriggered: view.settling = false }
    opacity: view.opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Без focus: true клавиатура остаётся у корня окна, и Enter в оверлее
    // просто никуда не приходил — стол не переключался.
    focus: true

    // Blurred copy of the desktop behind the workspace cards (Settings → Appearance)
    ScreencopyView {
        id: bgShot
        anchors.fill: parent
        captureSource: view.sys.screen
        live: false
        paintCursor: false
        visible: false
        layer.enabled: view.sys.cfg.overviewBlur
        layer.smooth: true
        // blurred anyway: a quarter-resolution texture makes the blur several times cheaper
        layer.textureSize: Qt.size(Math.max(1, width / 4), Math.max(1, height / 4))
    }
    MultiEffect {
        anchors.fill: parent
        source: bgShot
        opacity: view.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        visible: view.sys.cfg.overviewBlur && bgShot.hasContent
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 32
        blur: 1.0
        blurMultiplier: 1.0
        saturation: 0.15
    }

    // Выбор храним по номеру стола, а не по индексу в списке: список
    // приходит асинхронно и на первом кадре ещё пустой, поэтому индекс,
    // посчитанный в onCompleted, указывал не туда — оверлей открывался
    // с выделенным вторым столом вместо текущего.
    property int currentWs: 0

    readonly property string wallPath: view.sys.currentWallPath()

    // One live copy of the desktop widgets, drawn into every workspace card
    WidgetsView {
        id: deskWidgets
        sys: view.sys
        width: view.monW
        height: view.monH
        originX: view.sys.widgetsOriginX
        originY: view.sys.widgetsOriginY
        enabled: false
    }

    // Hledání aplikací uvnitř přehledu
    // Psaní otevře launcher v notchi (stejný jako Super+A); přehled jen ztmavne
    readonly property bool searching: view.sys.launcherOpen
    Connections {
        target: view.sys
        function onLauncherOpenChanged() { if (!view.sys.launcherOpen) view.forceActiveFocus(); }
    }
    readonly property int current: {
        for (var i = 0; i < wsList.length; i++)
            if (wsList[i].id === view.currentWs) return i;
        return 0;
    }

    readonly property var mon: Compositor.isNiri ? Compositor.focusedMonitor : Hyprland.focusedMonitor
    readonly property real monW: mon ? mon.width : 1920
    readonly property real monH: mon ? mon.height : 1080

    // Столы по порядку номеров. Пустые тоже показываем: на них переходят
    // не реже, чем на занятые.
    readonly property var wsList: {
        var out = [];
        if (Compositor.isNiri) return Compositor.workspaces;
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (!w || w.id < 0) continue;      // спецстолы не показываем
            out.push(w);
        }
        out.sort(function (a, b) { return a.id - b.id; });
        return out;
    }

    Component.onCompleted: {
        if (Compositor.isNiri) {
            Compositor.refresh();
        } else {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
        // Стол, с которого открыли: пилюля знает его точно и без опроса —
        // она слушает события Hyprland постоянно.
        view.currentWs = view.sys.wsId;
        view.forceActiveFocus();
    }
    FocusGrabber { target: view }

    // ------------------------------------------------------------ клавиши
    function move(d) {
        if (wsList.length === 0) return;
        var i = Math.max(0, Math.min(wsList.length - 1, view.current + d));
        view.currentWs = wsList[i].id;
    }
    Keys.onLeftPressed:  view.move(-1)
    Keys.onRightPressed: view.move(1)
    Keys.onUpPressed:    view.move(-view.columns)
    Keys.onDownPressed:  view.move(view.columns)
    Keys.onEscapePressed: view.sys.closeOverview()
    Keys.onReturnPressed: view.pick(view.current)
    Keys.onEnterPressed:  view.pick(view.current)
    Keys.onSpacePressed:  view.pick(view.current)
    Keys.onTabPressed:    view.move(1)
    Keys.onBacktabPressed: view.move(-1)
    Keys.onPressed: event => {
        // цифрой — сразу на нужный стол
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var n = event.key - Qt.Key_0;
            for (var i = 0; i < view.wsList.length; i++) {
                if (view.wsList[i].id !== n) continue;
                view.pick(i);
                event.accepted = true;
                return;
            }
        }
        // psaní písmen = hledání aplikací přímo v přehledu (jako v GNOME)
        var mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (!mods && event.text.length === 1 && event.text.charCodeAt(0) > 32) {
            view.sys.launcherPrefill = event.text;
            view.sys.openLauncher();
            event.accepted = true;
        }
    }

    // ------------------------------------------------------------- выбор
    // Своей анимации перехода тут нет: оверлей просто уходит, а стол
    // сменяется штатной прокруткой Hyprland — той же, что по Super+1 и жестам.
    function pick(i) {
        if (i < 0 || i >= wsList.length) return;
        view.currentWs = wsList[i].id;
        view.sys.gotoWorkspace(wsList[i].id);
        view.sys.closeOverview();
    }

    // ------------------------------------------------ drag a window to another workspace
    // Drag a window preview onto another workspace card (or the "new workspace" zone at
    // the bottom) to move the window there.
    property var dragWin: null            // { addr, cls }
    property real dragX: 0                // pointer in overview coordinates
    property real dragY: 0
    readonly property bool dragging: view.dragWin !== null
    property int dropWs: 0                // workspace id under the pointer (0 = none)
    readonly property int newWsId: {
        var m = 0;
        for (var i = 0; i < wsList.length; i++) m = Math.max(m, wsList[i].id);
        return m + 1;
    }
    function moveWindow(addr, ws) {
        moveProc.command = ["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = " + ws
                            + ", follow = false, window = 'address:" + addr + "' })"];
        moveProc.running = true;
    }
    Process {
        id: moveProc
        onRunningChanged: if (!running) refreshTimer.restart()
    }
    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); }
    }
    function endDrag() {
        if (view.dragWin && view.dropWs > 0) view.moveWindow(view.dragWin.addr, view.dropWs);
        view.dragWin = null;
        view.dropWs = 0;
    }

    // ------------------------------------------------------------ раскладка
    readonly property int columns: Math.min(3, Math.max(1, wsList.length))
    // Карточка занимает столько, сколько влезает: и по ширине, и по высоте —
    // иначе на трёх столбцах нижний ряд уезжал за экран.
    readonly property real cardW: Math.min(
        (view.width - 140) / columns - 20,
        ((view.height - 210) / Math.max(1, Math.ceil(wsList.length / columns)) - 20)
            * (monW / monH))
    readonly property real cardH: cardW * (monH / monW)

    MouseArea {
        anchors.fill: parent
        onClicked: view.sys.closeOverview()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.sys.tr("Рабочие столы")
            color: ShellColors.fgA(0.55)
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3
                bold: false; capitalization: Font.AllUppercase; letterSpacing: 2
            }
        }

        GridLayout {
            id: grid
            Layout.alignment: Qt.AlignHCenter
            columns: view.columns
            rowSpacing: 20
            columnSpacing: 20

            Repeater {
                model: view.wsList

                Rectangle {
                    id: card
                    required property int index
                    required property var modelData

                    readonly property bool picked: view.current === card.index
                    readonly property bool live: view.sys.wsId === card.modelData.id
                    readonly property bool dropHover: {
                        if (!view.dragging) return false;
                        var p = card.mapFromItem(view, view.dragX, view.dragY);
                        return p.x >= 0 && p.y >= 0 && p.x <= card.width && p.y <= card.height
                               && !(view.dragWin && winOwner(view.dragWin.addr) === card.modelData.id);
                    }
                    function winOwner(addr) {
                        var l = view.sys.overviewToplevels || [];
                        for (var i = 0; i < l.length; i++) if (String(l[i].geo.addr || "") === addr) return l[i].geo.ws;
                        return -1;
                    }
                    onDropHoverChanged: if (dropHover) view.dropWs = card.modelData.id; else if (view.dropWs === card.modelData.id) view.dropWs = 0

                    Layout.preferredWidth: view.cardW
                    Layout.preferredHeight: view.cardH
                    radius: 16
                    color: Qt.rgba(0.06, 0.06, 0.07, 0.92)
                    border.color: card.dropHover ? view.sys.colFg
                                : card.picked ? view.sys.colOn
                                : card.live ? ShellColors.fgA(0.35)
                                            : ShellColors.fgA(0.12)
                    border.width: (card.picked || card.dropHover) ? 2 : 1
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    scale: card.picked ? 1.04 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                    }

                    // ------------------------ wallpaper + widgets behind the windows
                    // Every card shows the desktop (wallpaper and widgets), so an
                    // empty workspace is not just a black rectangle.
                    Item {
                        id: deskLayer
                        anchors.fill: parent
                        z: 0
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: deskMask
                        }
                        Image {
                            anchors.fill: parent
                            source: view.wallPath.length ? "file://" + view.wallPath : ""
                            sourceSize: Qt.size(640, 360)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                        Rectangle { anchors.fill: parent; color: "black"; opacity: 0.18 }
                        ShaderEffectSource {
                            anchors.fill: parent
                            visible: view.sys.cfg.featWidgets
                            sourceItem: view.sys.cfg.featWidgets ? deskWidgets : null
                            live: view.settling
                            hideSource: true
                        }
                    }
                    Rectangle {
                        id: deskMask
                        anchors.fill: parent
                        radius: card.radius
                        visible: false
                        layer.enabled: true
                    }

                    // ---------------------------------------- окна стола
                    // Отдельный слой с отступом: у карточки скруглённые углы,
                    // и окно, лежащее вплотную к краю, срезалось ими.
                    Item {
                        id: winLayer
                        anchors.fill: parent
                        anchors.margins: 7
                        z: 2   // above the card click area so window previews can be dragged

                    Repeater {
                        model: view.sys.overviewToplevels

                        Item {
                            id: win
                            required property var modelData
                            readonly property var geo: modelData.geo

                            visible: win.geo.ws === card.modelData.id
                            // Координаты окна в системе монитора ужимаем до
                            // карточки. Заголовок и рамки Hyprland сюда не
                            // входят — берём чистую геометрию клиента.
                            x: (win.geo.x - (view.mon ? view.mon.x : 0)) * winLayer.width / view.monW
                            y: (win.geo.y - (view.mon ? view.mon.y : 0)) * winLayer.height / view.monH
                            width:  win.geo.w * winLayer.width / view.monW
                            height: win.geo.h * winLayer.height / view.monH

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: ShellColors.fgA(0.05)
                                border.color: ShellColors.fgA(0.10)
                                border.width: 1
                                clip: true

                                // Живой кадр окна: видео и анимации в превью
                                // продолжают идти, потому что это тот же
                                // буфер, а не снимок.
                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.modelData.wayland
                                    live: true
                                    paintCursor: false
                                    visible: hasContent
                                    // Кадр окна ужимается в разы, и без
                                    // сглаживания края текста рассыпались
                                    // в пиксельную кашу.
                                    smooth: true
                                    antialiasing: true
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.mipmap: true
                                }

                                // drag to move the window to another workspace
                                MouseArea {
                                    id: dragMa
                                    anchors.fill: parent
                                    z: 5
                                    hoverEnabled: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property point pressPos
                                    property bool moved: false
                                    onEntered: view.currentWs = card.modelData.id
                                    onPressed: mouse => {
                                        var p = dragMa.mapToItem(view, mouse.x, mouse.y);
                                        dragMa.pressPos = Qt.point(p.x, p.y);
                                        dragMa.moved = false;
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressed) return;
                                        var p = dragMa.mapToItem(view, mouse.x, mouse.y);
                                        if (!dragMa.moved && Math.abs(p.x - dragMa.pressPos.x) + Math.abs(p.y - dragMa.pressPos.y) > 10) {
                                            dragMa.moved = true;
                                            view.dragWin = { addr: String(win.geo.addr || ""), cls: String(win.geo.cls || "") };
                                        }
                                        if (dragMa.moved) { view.dragX = p.x; view.dragY = p.y; }
                                    }
                                    onReleased: {
                                        if (dragMa.moved) view.endDrag();
                                        else view.pick(card.index);
                                    }
                                    onCanceled: { view.dragWin = null; view.dropWs = 0; }
                                }

                                // пока кадра нет — класс приложения текстом
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.children.length > 0
                                             && !parent.children[0].hasContent
                                    text: String(win.geo.cls || "")
                                    color: ShellColors.fgA(0.45)
                                    elide: Text.ElideRight
                                    width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                                }
                            }
                        }
                    }

                    }

                    // ------------------------------------------ подпись
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: wsNum.implicitWidth + 18
                        height: 24
                        radius: 12
                        color: card.picked
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.85)
                               : Qt.rgba(0, 0, 0, 0.6)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: wsNum
                            anchors.centerIn: parent
                            text: card.modelData.name
                            color: "#ffffff"
                            font {
                                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3
                                bold: card.picked || card.live
                            }
                        }
                    }

                    // точка «здесь вы сейчас»
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        width: 8; height: 8; radius: 4
                        visible: card.live
                        color: view.sys.colOk
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: view.currentWs = card.modelData.id
                        onClicked: view.pick(card.index)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.sys.tr("Стрелки — выбрать · Enter — перейти · Esc — закрыть")
            color: ShellColors.fgA(0.30)
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }
    }


    // Ztmavení ploch při hledání: černá vrstva přes ně, plochy zůstávají plně
    // neprůhledné (jen tmavší), nic se přes ně nepropíjí.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: view.searching ? 0.6 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }


    // App dock inside the overview (Settings → Controls → Dock)
    DockBar {
        sys: view.sys
        visible: view.sys.cfg.overviewDock && !view.sys.cfg.dockEnabled && items.length > 0
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: view.sys.cfg.islandGap + 1 }
        onLaunched: view.sys.closeOverview()
    }

    // drop zone: move the dragged window to a brand new workspace
    Rectangle {
        id: newZone
        visible: view.dragging
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: 260; height: 46; radius: 23
        readonly property bool hot: view.dragging && view.dragY > newZone.y - 10 && view.dragY < newZone.y + newZone.height + 10
                                    && view.dragX > newZone.x && view.dragX < newZone.x + newZone.width
        color: newZone.hot ? view.sys.colFg : Qt.rgba(0, 0, 0, 0.7)
        border.width: 1
        border.color: ShellColors.fgA(0.3)
        onHotChanged: if (hot) view.dropWs = view.newWsId; else if (view.dropWs === view.newWsId) view.dropWs = 0
        Text {
            anchors.centerIn: parent
            text: "+ New workspace"
            color: newZone.hot ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }

    // ghost following the pointer while dragging
    Rectangle {
        visible: view.dragging
        z: 100
        x: view.dragX - width / 2
        y: view.dragY - height / 2
        width: 150; height: 90; radius: 10
        color: Qt.rgba(0.1, 0.1, 0.12, 0.92)
        border.width: 2
        border.color: view.sys.colFg
        opacity: 0.9
        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: view.dragWin ? view.dragWin.cls : ""
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
