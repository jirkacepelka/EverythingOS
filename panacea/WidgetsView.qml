pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Настольные виджеты темы Nothing — карточки поверх обоев.
//
// Дизайн в стиле Nothing OS:
// - Дата: день недели (красный в выходные), точечное число и месяц
// - Часы Nothing OS: 12-точечный циферблат с двойной точкой на 12, чётко различимые
//   стрелки (короткая часовая капсула 0.38*r и длинная минутная стрелка 0.78*r),
//   фирменная втулка-пончик Nothing, орбитальная красная точка colCrit и цифровая подсказка.
//   Клик переключает между аналоговыми и точечными цифровыми часами.
// - Главная карточка погоды (слева): температура, точечная иконка, город.
//   Клик открывает детальное окно прогноза погоды.
// - Вспомогательная карточка (справа): по клику переключается между подробностями
//   погоды (описание + влажность/ветер) и монитором системы (концентрические дуги RAM и SSD).
// - Шкала прогресса (Life Bar, снизу): 24-сегментный прогресс дня с пульсирующим
//   текущим часом. Клик переключает между прогрессом дня (24H) и года (365D).
// - Nothing Music: стилизованный плеер с крутящимся винилом и управлением треком.
// - ScratchPad: быстрые заметки на рабочем столе с автосохранением в файл.
Item {
    id: view

    property var sys
    property bool scratchpadActive: false
    function dismissScratchpad() {
        scratchEdit.focus = false;
        scratchpadActive = false;
    }

    // Ширина колонки и просвет между карточками
    // two grid cells wide / tall: the desktop grid is stretched to the screen (sys.pitchX / pitchY)
    readonly property real col: view.sys ? 2 * view.sys.pitchX - 12 : 144
    readonly property real row2: view.sys ? 2 * view.sys.pitchY - 12 : 140
    readonly property real gap: 12
    readonly property real fullW: view.col * 2 + view.gap

    // Počátek oblasti widgetů (pod zónou ostrova, na mřížce oken); zadává shell
    // Typografie: jedna rodina (sys.fontFam) + tečkové číslice (DotText); čtyři velikosti
    readonly property int fsCap:     view.sys ? view.sys.fontSize - 5 : 8    // popisky
    readonly property int fsBody:    view.sys ? view.sys.fontSize - 3 : 10   // běžný text
    readonly property int fsLead:    view.sys ? view.sys.fontSize - 1 : 12   // zvýrazněný text
    readonly property int fsDisplay: view.sys ? view.sys.fontSize + 9 : 22   // velká čísla
    readonly property int cardRadius: view.sys ? view.sys.shapeR : 22
    readonly property int cardPad: 14
    property real originX: 11
    property real originY: 59

    // ---- Volné umístění widgetů ------------------------------------------
    // Pozice (relativně k počátku) se ukládají jako JSON v cfg.widgetPosJson.
    function isHidden(id) { return view.sys && view.sys.widgetHidden ? view.sys.widgetHidden.indexOf(id) >= 0 : false; }
    readonly property bool editing: view.sys ? Boolean(view.sys.widgetEdit) : false
    readonly property real snap: view.sys ? view.sys.pitchX : 78   // desktop grid pitch (shared with the tray widgets)
    readonly property var sizes: ({
        date: [view.col, view.row2], clock: [view.col, view.row2], weather: [view.col, view.row2],
        right: [view.col, view.row2], progress: [view.fullW, 72], music: [view.fullW, 180],
        scratch: [view.fullW, view.row2]
    })
    function defaults() {
        var px = view.sys ? view.sys.pitchX : 78, py = view.sys ? view.sys.pitchY : 78;
        return { date: {x: 0, y: 0}, clock: {x: 2 * px, y: 0}, weather: {x: 0, y: 2 * py},
                 right: {x: 2 * px, y: 2 * py}, progress: {x: 0, y: 4 * py}, music: {x: 0, y: 5 * py},
                 scratch: {x: 0, y: 8 * py} };
    }
    function loadPos() {
        var d = view.defaults(), saved = {};
        try { saved = JSON.parse((view.sys && view.sys.cfg && view.sys.cfg.widgetPosJson) || "{}"); } catch (e) {}
        for (var k in saved) if (d[k] && saved[k] && isFinite(saved[k].x) && isFinite(saved[k].y)) d[k] = saved[k];
        return d;
    }
    property var wpos: view.loadPos()
    Connections {
        target: view.sys ? view.sys.cfg : null
        function onWidgetPosJsonChanged() { if (!view.editing) view.wpos = view.loadPos(); }
    }
    function wx(id) { return view.originX + view.wpos[id].x; }
    function wy(id) { return view.originY + view.wpos[id].y; }
    function movePos(id, x, y, commit) {
        var sz = view.sizes[id];
        var nx = Math.max(-view.originX, Math.min(view.width - view.originX - sz[0], x));
        var ny = Math.max(-view.originY, Math.min(view.height - view.originY - sz[1], y));
        if (commit) {
            nx = Math.round(nx / view.snap) * view.snap;
            ny = Math.round(ny / (view.sys ? view.sys.pitchY : view.snap)) * (view.sys ? view.sys.pitchY : view.snap);
        }
        var n = {};
        for (var k in view.wpos) n[k] = view.wpos[k];
        n[id] = { x: nx, y: ny };
        view.wpos = n;
        if (commit && view.sys) { view.sys.cfg.widgetPosJson = JSON.stringify(n); view.sys.saveCfg(); }
    }
    function resetPos() {
        view.wpos = view.defaults();
        if (view.sys) { view.sys.cfg.widgetPosJson = ""; view.sys.saveCfg(); }
    }

    // Prvky pro vstupní masku okna (shell)
    readonly property alias cDate: dateCard
    readonly property alias cClock: clockCard
    readonly property alias cWeather: mainWeatherCard
    readonly property alias cRight: rightToggleCard
    readonly property alias cProgress: progressCard
    readonly property alias cMusic: musicCard
    readonly property alias cScratch: scratchCard
    readonly property alias editBarItem: editBar

    component DragLayer: MouseArea {
        id: dl
        required property string wid
        required property Item card
        property real sx: 0
        property real sy: 0
        property point pp: Qt.point(0, 0)
        x: dl.card.x; y: dl.card.y; width: dl.card.width; height: dl.card.height
        visible: view.editing && dl.card.visible
        enabled: visible
        z: 100
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: m => {
            dl.pp = dl.mapToItem(view, m.x, m.y);
            dl.sx = view.wpos[dl.wid].x; dl.sy = view.wpos[dl.wid].y;
        }
        onPositionChanged: m => {
            if (!pressed) return;
            var p = dl.mapToItem(view, m.x, m.y);
            view.movePos(dl.wid, dl.sx + p.x - dl.pp.x, dl.sy + p.y - dl.pp.y, false);
        }
        onReleased: m => {
            var p = dl.mapToItem(view, m.x, m.y);
            view.movePos(dl.wid, dl.sx + p.x - dl.pp.x, dl.sy + p.y - dl.pp.y, true);
        }
        Rectangle {
            anchors.fill: parent; radius: view.cardRadius; color: Qt.rgba(1, 1, 1, dl.pressed ? 0.10 : 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.55); border.width: 1.5
        }
        Rectangle {   // hide this built-in widget (restore from the tray)
            anchors { top: parent.top; right: parent.right; margins: 6 }
            width: 22; height: 22; radius: 11
            color: view.sys ? view.sys.colCrit : "#D71921"
            Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 15; font.bold: true }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onPressed: m => m.accepted = true
                onClicked: view.sys.hideBuiltin(dl.wid)
            }
        }
    }

    // Режимы карточек
    readonly property string clockMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetClockMode) || "analog"
    readonly property string rightMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetRightMode) || "weather"
    readonly property string progressMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetProgressMode) || "day"

    // Формат часов: 12-часовой или 24-часовой (из системных настроек)
    readonly property bool is12: view.sys && view.sys.cfg ? Boolean(view.sys.cfg.clock12) : false

    // Синхронизация с системным временем через view.sys
    readonly property int curHour: (view.sys && view.sys.timeHour !== undefined) ? view.sys.timeHour : (new Date()).getHours()
    readonly property int curMin: (view.sys && view.sys.timeMinute !== undefined) ? view.sys.timeMinute : (new Date()).getMinutes()
    readonly property int curMonth: { var _ = (view.sys && view.sys.dayNum); return (new Date()).getMonth(); }

    readonly property int curDayOfYear: {
        var _ = (view.sys && view.sys.dayNum);
        var now = new Date();
        var start = new Date(now.getFullYear(), 0, 1);
        return Math.floor((now - start) / (1000 * 60 * 60 * 24));
    }
    readonly property int totalDaysInYear: {
        var _ = (view.sys && view.sys.dayNum);
        var now = new Date();
        var start = new Date(now.getFullYear(), 0, 1);
        var end = new Date(now.getFullYear() + 1, 0, 1);
        return Math.max(1, Math.round((end - start) / (1000 * 60 * 60 * 24)));
    }

    readonly property int dayPct: Math.min(100, Math.max(0, Math.floor((curHour * 60 + curMin) / 1440 * 100)))
    readonly property int yearPct: Math.min(100, Math.max(0, Math.floor(curDayOfYear / totalDaysInYear * 100)))

    readonly property int remainDayMins: Math.max(0, 1440 - (curHour * 60 + curMin))
    readonly property string remainDayText: Math.floor(remainDayMins / 60) + (view.sys && view.sys.isEn ? "h " : "ч ") + (remainDayMins % 60) + (view.sys && view.sys.isEn ? "m" : "м")
    readonly property int remainYearDays: Math.max(0, totalDaysInYear - curDayOfYear)

    // Пульсация текущего сегмента времени в стиле глифов Nothing
    property real pulseOpacity: 1.0
    SequentialAnimation on pulseOpacity {
        loops: Animation.Infinite
        running: view.visible
        NumberAnimation { to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
    }

    // Общий вид карточки: тёмная плашка со скруглением
    // Stejné pozadí a společný okraj jako pilulky ostrova
    // The built-in widgets share their card, dot digits and caption with the tray widgets
    // (WCard / WNum / WCaption).
    component Card: WCard { sys: view.sys }

    component Num: WNum { sys: view.sys }

    // Значок погоды: точечный DotIcon
    component WIcon: Item {
        id: wico
        property real size: 20
        property color color: view.sys ? view.sys.colFg : "#ffffff"

        implicitWidth:  wdots.implicitWidth
        implicitHeight: wdots.implicitHeight

        DotIcon {
            id: wdots
            code: view.sys ? view.sys.weatherIcon : 0
            size: wico.size
            color: wico.color
        }
    }

    component Caption: WCaption { sys: view.sys }

    // Karty jsou volně umístěné (absolutní x/y z view.wpos), ne v layoutu.
    Item {
        id: stack
        anchors.fill: parent

        // ------------------------------------------------------ Ряд 1: Дата и Часы
        Item {

            // Карточка даты (144x140)
            Card {
                id: dateCard
                visible: !view.isHidden("date")
                x: view.wx("date"); y: view.wy("date")
                width: view.col; height: view.row2

                Num {
                    anchors.centerIn: parent
                    value: view.sys ? view.sys.dayNum : ""
                    size: 50
                    gapRatio: 0.14
                    color: view.sys ? view.sys.colFg : "#ffffff"
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 16
                    anchors.topMargin: 13
                    text: view.sys ? view.sys.dayText : ""
                    color: (view.sys && view.sys.weekend) ? view.sys.colCrit : (view.sys ? view.sys.colMuted : "#888888")
                    font {
                        family: view.sys ? view.sys.fontFam : "sans-serif"
                        pixelSize: view.fsBody
                        bold: false
                    }
                }

                Caption {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    anchors.bottomMargin: 13
                    width: parent.width - 32
                    color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.85) : "#dddddd"
                    text: view.sys ? view.sys.monthText : ""
                }

                MouseArea {
                    id: dateMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // Карточка часов Nothing OS (144x140) — переключает аналоговые / цифровые
            Card {
                id: clockCard
                visible: !view.isHidden("clock")
                x: view.wx("clock"); y: view.wy("clock")
                width: view.col; height: view.row2

                // Режим аналоговых часов Nothing
                Item {
                    anchors.fill: parent
                    visible: view.clockMode === "analog"

                    Canvas {
                        id: clockCanvas
                        anchors.fill: parent

                        Connections {
                            target: view.sys
                            function onTimeSecondChanged() { clockCanvas.requestPaint(); }
                            function onTimeTextChanged() { clockCanvas.requestPaint(); }
                            function onTimeHourChanged() { clockCanvas.requestPaint(); }
                        }

                        Connections {
                            target: view
                            function onIs12Changed() { clockCanvas.requestPaint(); }
                        }

                        Timer {
                            interval: 1000
                            running: view.visible && view.clockMode === "analog"
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: clockCanvas.requestPaint()
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = Math.min(cx, cy) - 16;

                            var is12 = view.is12;

                            if (is12) {
                                // 12-часовой циферблат: 12 точечных меток (шаг 30°)
                                for (var i = 0; i < 12; i++) {
                                    var ang = i * (Math.PI / 6) - Math.PI / 2;
                                    var x = cx + Math.cos(ang) * r;
                                    var y = cy + Math.sin(ang) * r;
                                    ctx.beginPath();
                                    if (i % 3 === 0) {
                                        // 12, 3, 6, 9 часов: акцентные белые точки
                                        ctx.arc(x, y, 2.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "#ffffff";
                                    } else {
                                        // Промежуточные часы: полупрозрачные точки
                                        ctx.arc(x, y, 1.3, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
                                    }
                                    ctx.fill();
                                }
                            } else {
                                // 24-часовой циферблат: 24 точечные метки (шаг 15°)
                                for (var j = 0; j < 24; j++) {
                                    var ang24 = j * (Math.PI / 12) - Math.PI / 2;
                                    var x24 = cx + Math.cos(ang24) * r;
                                    var y24 = cy + Math.sin(ang24) * r;
                                    ctx.beginPath();
                                    if (j % 6 === 0) {
                                        // 00 (полночь/верх), 06 (утро/право), 12 (полдень/низ), 18 (вечер/лево)
                                        ctx.arc(x24, y24, 2.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "#ffffff";
                                    } else if (j % 2 === 0) {
                                        // Четные часы: средние белые точки
                                        ctx.arc(x24, y24, 1.4, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.50)";
                                    } else {
                                        // Нечетные часы: тонкие деликатные точки
                                        ctx.arc(x24, y24, 1.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.25)";
                                    }
                                    ctx.fill();
                                }
                            }

                            // Синхронизация с системным временем через view.sys
                            var h = (view.sys && view.sys.timeHour !== undefined) ? view.sys.timeHour : (new Date()).getHours();
                            var m = (view.sys && view.sys.timeMinute !== undefined) ? view.sys.timeMinute : (new Date()).getMinutes();
                            var s = (view.sys && view.sys.timeSecond !== undefined) ? view.sys.timeSecond : (new Date()).getSeconds();

                            // 1. Часовая стрелка: элегантная белая капсула
                            // В 12-часовом формате оборот 12 часов (PI/6), в 24-часовом — 24 часа (PI/12)
                            var hAng = is12
                                ? (((h % 12) + m / 60 + s / 3600) * (Math.PI / 6) - Math.PI / 2)
                                : ((h + m / 60 + s / 3600) * (Math.PI / 12) - Math.PI / 2);

                            ctx.beginPath();
                            ctx.lineWidth = 3.6;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "#ffffff";
                            ctx.moveTo(cx + Math.cos(hAng) * 3, cy + Math.sin(hAng) * 3);
                            ctx.lineTo(cx + Math.cos(hAng) * (r * 0.50), cy + Math.sin(hAng) * (r * 0.50));
                            ctx.stroke();

                            // 2. Минутная стрелка: тонкая изящная белая игла (1 оборот = 60 минут)
                            var mAng = (m + s / 60) * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 2.0;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
                            ctx.moveTo(cx + Math.cos(mAng) * 3, cy + Math.sin(mAng) * 3);
                            ctx.lineTo(cx + Math.cos(mAng) * (r * 0.78), cy + Math.sin(mAng) * (r * 0.78));
                            ctx.stroke();

                            // 3. Секундная стрелка Nothing Red: тонкая стрелка с противовесом (1 оборот = 60 секунд)
                            var sAng = s * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 1.2;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = view.sys ? String(view.sys.colCrit) : "#d71921";
                            ctx.moveTo(cx - Math.cos(sAng) * (r * 0.18), cy - Math.sin(sAng) * (r * 0.18));
                            ctx.lineTo(cx + Math.cos(sAng) * (r * 0.82), cy + Math.sin(sAng) * (r * 0.82));
                            ctx.stroke();

                            // 4. Фирменная центральная втулка Nothing OS
                            ctx.beginPath();
                            ctx.arc(cx, cy, 3.8, 0, Math.PI * 2);
                            ctx.fillStyle = "#141414";
                            ctx.fill();
                            ctx.lineWidth = 1.0;
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
                            ctx.stroke();

                            // Красная точка в самом центре
                            ctx.beginPath();
                            ctx.arc(cx, cy, 1.8, 0, Math.PI * 2);
                            ctx.fillStyle = view.sys ? String(view.sys.colCrit) : "#d71921";
                            ctx.fill();
                        }
                    }
                }

                // Режим цифровых часов
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: view.clockMode !== "analog"
                    spacing: 6

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NOTHING"
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.4) : "#666666"
                    }

                    Num {
                        Layout.alignment: Qt.AlignHCenter
                        value: {
                            if (!view.sys) return "";
                            if (view.is12) {
                                var d12 = new Date();
                                return Qt.formatDateTime(d12, "h:mm");
                            }
                            return view.sys.timeText;
                        }
                        size: 32
                        gapRatio: 0.14
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (view.is12) {
                                var d = new Date();
                                return (d.getHours() >= 12 ? "PM" : "AM") + (view.sys && view.sys.clockSeconds ? " · " + d.getSeconds() : "");
                            }
                            return view.sys && view.sys.clockSeconds ? (new Date()).getSeconds() : "LOCAL";
                        }
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }
                }

                MouseArea {
                    id: clockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.cfg) {
                            view.sys.cfg.widgetClockMode = (view.clockMode === "analog" ? "digital" : "analog");
                            view.sys.saveCfg();
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Ряд 2: Погода / Система
        Item {

            // Главная карточка погоды (144x140) — клик открывает полное окно прогноза
            Card {
                id: mainWeatherCard
                visible: !view.isHidden("weather")
                x: view.wx("weather"); y: view.wy("weather")
                width: view.col; height: view.row2
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (view.sys && view.sys.weatherReady) ? view.sys.weatherTemp + "°" : "--°"
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsDisplay }
                    }

                    WIcon {
                        Layout.alignment: Qt.AlignHCenter
                        size: 28
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: view.col - 20
                        text: (view.sys && view.sys.weatherReady)
                              ? view.sys.weatherPlace : (view.sys ? view.sys.tr("Нет данных") : "--")
                        color: view.sys ? view.sys.colMuted : "#888888"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody }
                    }
                }

                MouseArea {
                    id: wCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (view.sys) view.sys.openWeatherDetails(); }
                }
            }

            // Правая карточка (144x140) — КЛИК ПЕРЕКЛЮЧАЕТ МЕЖДУ ПОГОДОЙ И СИСТЕМОЙ
            Card {
                id: rightToggleCard
                visible: !view.isHidden("right")
                x: view.wx("right"); y: view.wy("right")
                width: view.col; height: view.row2
                Layout.alignment: Qt.AlignTop

                // Режим: ПОДРОБНОСТИ ПОГОДЫ
                Item {
                    anchors.fill: parent
                    visible: view.rightMode === "weather"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Верхняя плашка с описанием погоды
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                WIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    size: 18
                                    color: view.sys ? view.sys.colFg : "#ffffff"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: (view.sys && view.sys.weatherReady) ? view.sys.weatherDesc : "—"
                                    color: view.sys ? view.sys.colFg : "#ffffff"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    lineHeight: 0.95
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody }
                                }

                                // Иконка-подсказка: клик переключит на монитор системы
                                Text {
                                    text: "󰍛"
                                    color: view.sys ? view.sys.colMuted : "#888888"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsLead }
                                }
                            }
                        }

                        // Нижние кружки (Влажность и Ветер)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady) ? (view.sys.weatherHumidity + "%") : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody; bold: false }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: view.sys ? view.sys.tr("Влажность") : "HUMIDITY"
                                        font.pixelSize: view.fsCap
                                        font.letterSpacing: 0.2
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady) ? String(view.sys.weatherWind) : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody; bold: false }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys ? view.sys.tr("Ветер") : "WIND") + " " + (view.sys ? view.sys.weatherWindUnit : "")
                                        font.pixelSize: view.fsCap
                                        font.letterSpacing: 0.2
                                    }
                                }
                            }
                        }
                    }
                }

                // Режим: СИСТЕМНЫЙ МОНИТОР (Концентрические дуги RAM и SSD)
                Item {
                    anchors.fill: parent
                    visible: view.rightMode === "system"

                    // Верхняя строка заголовка
                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        anchors.topMargin: 10

                        Caption {
                            Layout.fillWidth: true
                            text: view.sys ? view.sys.tr("СИСТЕМА") : "SYSTEM"
                            color: view.sys ? view.sys.colMuted : "#888888"
                        }

                        // Иконка-подсказка: клик переключит на погоду
                        Text {
                            text: "󰖐"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsLead }
                            color: view.sys ? view.sys.colMuted : "#888888"
                        }
                    }

                    // Концентрические кольца: внешнее RAM, внутреннее SSD
                    Item {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: 76
                        height: 76

                        Canvas {
                            id: ringsCanvas
                            anchors.fill: parent

                            Connections {
                                target: view.sys
                                function onLoadMemChanged() { ringsCanvas.requestPaint(); }
                                function onLoadDiskChanged() { ringsCanvas.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2;
                                var cy = height / 2;

                                var ram = (view.sys && view.sys.loadMem >= 0) ? view.sys.loadMem : 0;
                                var disk = (view.sys && view.sys.loadDisk >= 0) ? view.sys.loadDisk : 0;

                                // Внешнее кольцо: RAM (radius 31, lineWidth 4)
                                var r1 = 31;
                                ctx.lineWidth = 4;
                                ctx.lineCap = "round";

                                ctx.beginPath();
                                ctx.arc(cx, cy, r1, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                                ctx.stroke();

                                if (ram > 0) {
                                    ctx.beginPath();
                                    var aStart = -Math.PI / 2;
                                    var aEnd = aStart + (Math.min(100, ram) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r1, aStart, aEnd);
                                    ctx.strokeStyle = ram > 85 ? (view.sys ? String(view.sys.colCrit) : "#d71921") : "rgba(255, 255, 255, 0.95)";
                                    ctx.stroke();
                                }

                                // Внутреннее кольцо: SSD (radius 21, lineWidth 4)
                                var r2 = 21;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r2, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
                                ctx.stroke();

                                if (disk > 0) {
                                    ctx.beginPath();
                                    var aStart = -Math.PI / 2;
                                    var aEnd = aStart + (Math.min(100, disk) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r2, aStart, aEnd);
                                    ctx.strokeStyle = view.sys ? String(view.sys.colCrit) : "#d71921";
                                    ctx.stroke();
                                }
                            }
                        }

                        Num {
                            anchors.centerIn: parent
                            value: (view.sys && view.sys.loadMem >= 0) ? String(view.sys.loadMem) : "--"
                            size: 11
                            gapRatio: 0.18
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }
                    }

                    // Нижняя строка: показатели RAM и SSD
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        anchors.bottomMargin: 8

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: (view.sys && view.sys.loadMem >= 0) ? (view.sys.loadMem + "%") : "--%"
                                color: view.sys ? view.sys.colFg : "#ffffff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody; bold: false }
                            }
                            Caption { text: "RAM"; font.pixelSize: view.fsCap }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 1
                            Layout.alignment: Qt.AlignRight
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: (view.sys && view.sys.loadDisk >= 0) ? (view.sys.loadDisk + "%") : "--%"
                                color: view.sys ? view.sys.colCrit : "#d71921"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody; bold: false }
                            }
                            Caption { Layout.alignment: Qt.AlignRight; text: "SSD"; font.pixelSize: view.fsCap }
                        }
                    }
                }

                // ЕДИНЫЙ клик по всей правой карточке: переключает Погода <-> Система
                MouseArea {
                    id: rightCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.cfg) {
                            view.sys.cfg.widgetRightMode = (view.rightMode === "weather" ? "system" : "weather");
                            view.sys.saveCfg();
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Ряд 3: Life Bar / Day & Year Progress (300x72)
        Card {
            id: progressCard
            visible: !view.isHidden("progress")
            x: view.wx("progress"); y: view.wy("progress")
            width: view.fullW; height: 72

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Caption {
                        Layout.fillWidth: true
                        text: view.progressMode === "day"
                              ? (view.sys ? view.sys.tr("ПРОГРЕСС ДНЯ") : "DAY PROGRESS")
                              : (view.sys ? view.sys.tr("ПРОГРЕСС ГОДА") : "YEAR PROGRESS")
                        font.bold: false
                        font.pixelSize: view.fsCap
                        font.letterSpacing: 1.2
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }

                    Num {
                        value: (view.progressMode === "day" ? view.dayPct : view.yearPct) + "%"
                        size: 13
                        gapRatio: 0.15
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }
                }

                // 24 сегмента для 24 часов
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 3
                    visible: view.progressMode === "day"

                    Repeater {
                        model: 24
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curHour
                                   ? Qt.rgba(1, 1, 1, 0.88)
                                   : (index === view.curHour
                                      ? (view.sys ? view.sys.colCrit : "#d71921")
                                      : Qt.rgba(1, 1, 1, 0.12))
                            opacity: index === view.curHour ? view.pulseOpacity : 1.0
                        }
                    }
                }

                // 12 сегментов для 12 месяцев года
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 5
                    visible: view.progressMode === "year"

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curMonth
                                   ? Qt.rgba(1, 1, 1, 0.88)
                                   : (index === view.curMonth
                                      ? (view.sys ? view.sys.colCrit : "#d71921")
                                      : Qt.rgba(1, 1, 1, 0.12))
                            opacity: index === view.curMonth ? view.pulseOpacity : 1.0
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: (view.sys ? view.sys.tr("Осталось ") : "Remaining ") +
                              (view.progressMode === "day"
                               ? view.remainDayText
                               : (view.remainYearDays + " " + (view.sys ? view.sys.tr("дн.") : "days")))
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font {
                            family: view.sys ? view.sys.fontFam : "sans-serif"
                            pixelSize: view.fsBody
                        }
                    }

                    Caption {
                        text: "󰔛 " + (view.progressMode === "day" ? "24H" : "365D")
                        font.pixelSize: view.fsCap
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.4) : "#666666"
                    }
                }
            }

            MouseArea {
                id: progMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.sys && view.sys.cfg) {
                        view.sys.cfg.widgetProgressMode = (view.progressMode === "day" ? "year" : "day");
                        view.sys.saveCfg();
                    }
                }
            }
        }

        MusicWidget {
            id: musicCard
            x: view.wx("music"); y: view.wy("music")
            width: view.fullW; height: implicitHeight
            visible: view.sys && view.sys.cfg && view.sys.cfg.widgetMusic !== false && !view.isHidden("music")
            sys: view.sys
        }

        // ------------------------------------------------------ Ряд 5: ScratchPad Widget (300x140)
        Card {
            id: scratchCard
            visible: (view.sys && view.sys.cfg && view.sys.cfg.widgetScratchpad !== false) && !view.isHidden("scratch")
            x: view.wx("scratch"); y: view.wy("scratch")
            width: view.fullW; height: view.row2

            readonly property string dataDir:
                (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/panacea"
            readonly property string dataPath: dataDir + "/scratchpad.txt"

            Process {
                id: scratchMkdir
                command: ["mkdir", "-p", scratchCard.dataDir]
                onExited: (code, status) => {
                    if (code === 0) scratchFile.setText(scratchEdit.text);
                    else console.warn("ScratchPad: cannot create notes directory")
                }
            }

            FileView {
                id: scratchFile
                path: scratchCard.dataPath
                printErrors: false
                watchChanges: true
                onFileChanged: if (!scratchEdit.activeFocus) reload()
                onLoaded: {
                    var t = text();
                    if (t !== scratchEdit.text && !scratchEdit.activeFocus) {
                        scratchEdit.text = t;
                    }
                }
            }

            Timer {
                id: saveDebounce
                interval: 350
                repeat: false
                onTriggered: {
                    if (!scratchMkdir.running) scratchMkdir.running = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Верхний ряд: заголовок и счетчик символов / кнопки
                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 20
                    Layout.preferredHeight: 20
                    Layout.maximumHeight: 20
                    spacing: 6

                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: view.scratchpadActive ? (view.sys ? view.sys.colCrit : "#d71921")
                                                     : (view.sys ? Qt.rgba(view.sys.colMuted.r, view.sys.colMuted.g, view.sys.colMuted.b, 0.4) : "#555555")
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Caption {
                        text: "SCRATCHPAD"
                        font.bold: false
                        font.pixelSize: view.fsCap
                        font.letterSpacing: 1.1
                    }

                    Item { Layout.fillWidth: true }

                    // Копировать всё
                    Text {
                        visible: scratchEdit.text.length > 0
                        text: "󰆏"
                        color: copyMa.containsMouse ? (view.sys ? view.sys.colFg : "#ffffff") : (view.sys ? view.sys.colMuted : "#888888")
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsLead }
                        MouseArea {
                            id: copyMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.sys) {
                                    view.sys.runDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", scratchEdit.text]);
                                    view.sys.playSound("screenshot");
                                }
                            }
                        }
                    }

                    // Очистить
                    Text {
                        visible: scratchEdit.text.length > 0
                        text: "×"
                        color: clearMa.containsMouse ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colMuted : "#888888")
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody; bold: false }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                scratchEdit.text = "";
                                saveDebounce.restart();
                            }
                        }
                    }

                    Caption {
                        text: scratchEdit.text.length + " " + (view.sys ? view.sys.tr("симв.") : "chars")
                        font.pixelSize: view.fsCap
                    }
                }

                // Область ввода заметок
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onPressedChanged: {
                            if (pressed) {
                                view.scratchpadActive = true;
                                Qt.callLater(function() { scratchEdit.forceActiveFocus(); });
                            }
                        }
                    }

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: scratchEdit.implicitHeight
                        clip: true

                        TextEdit {
                            id: scratchEdit
                            width: flick.width
                            height: Math.max(flick.height, implicitHeight)
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            selectByMouse: true
                            selectionColor: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                            selectedTextColor: "#ffffff"
                            color: view.sys ? view.sys.colFg : "#ffffff"
                            font {
                                family: view.sys ? view.sys.fontFam : "monospace"
                                pixelSize: view.fsLead
                            }

                            onActiveFocusChanged: {
                                view.scratchpadActive = activeFocus;
                            }

                            onTextChanged: {
                                saveDebounce.restart();
                            }

                            Keys.onEscapePressed: {
                                view.dismissScratchpad();
                            }
                        }
                    }

                    // Подсказка (placeholder)
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: view.sys ? view.sys.tr("Нажмите, чтобы записать…") : "Tap to write notes…"
                        color: view.sys ? Qt.rgba(view.sys.colMuted.r, view.sys.colMuted.g, view.sys.colMuted.b, 0.6) : "#666666"
                        visible: scratchEdit.text.length === 0 && !scratchEdit.activeFocus
                        font {
                            family: view.sys ? view.sys.fontFam : "sans-serif"
                            pixelSize: view.fsBody
                        }
                    }

                    MouseArea {
                        id: editClickArea
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            scratchEdit.forceActiveFocus();
                        }
                    }
                }
            }

            MouseArea {
                id: scratchMa
                anchors.fill: parent
                hoverEnabled: true
                z: -2
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    scratchEdit.forceActiveFocus();
                }
            }
        }
    }

    DragLayer { wid: "date";     card: dateCard }
    DragLayer { wid: "clock";    card: clockCard }
    DragLayer { wid: "weather";  card: mainWeatherCard }
    DragLayer { wid: "right";    card: rightToggleCard }
    DragLayer { wid: "progress"; card: progressCard }
    DragLayer { wid: "music";    card: musicCard }
    DragLayer { wid: "scratch";  card: scratchCard }

    // Lišta úprav rozložení
    Rectangle {
        id: editBar
        visible: false   // controls moved to the widget tray
        z: 200
        x: (view.width - width) / 2
        y: view.height - height - 28
        width: barRow.implicitWidth + 28; height: 46; radius: 23
        color: view.sys ? view.sys.colBg : "#000"
        border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: 18
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Drag widgets with the mouse"
                color: view.sys ? view.sys.colMuted : "#888"
                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                color: view.sys ? view.sys.colFg : "#fff"
                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody }
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: view.resetPos() }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 76; height: 30; radius: 15
                color: view.sys ? view.sys.colFg : "#fff"
                Text {
                    anchors.centerIn: parent; text: "Done"
                    color: view.sys ? view.sys.colBg : "#000"
                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: view.fsBody; weight: Font.DemiBold }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.sys.widgetEdit = false }
            }
        }
    }
}
