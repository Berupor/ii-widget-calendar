import qs.modules.common
import qs.modules.common.widgets
import "calendar.js" as Cal
import QtQuick
import QtQuick.Layouts

/** Calendar tab: month grid with event dots, a picked day folds it to its week. */
Item {
    id: root

    // Writable, so a demo scene draws any state without a provider
    property var days: EventsState.days
    property var now: EventsState.now
    property string status: EventsState.status
    property string errorText: EventsState.errorText
    property bool canAdd: EventsState.canAdd
    property bool surface: false

    property string selected: ""
    property alias addOpen: addLayer.open
    property alias addText: addLayer.text
    // First of the month on screen, null follows today
    property var viewMonth: null
    readonly property var selectedDate: Cal.fromIso(selected)
    readonly property bool weekMode: selectedDate !== null
    readonly property var viewingDate: viewMonth ?? Cal.monthOf(now)
    readonly property bool currentMonth: Cal.sameDay(viewingDate, Cal.monthOf(now))
    onSelectedDateChanged: if (selectedDate) viewMonth = Cal.monthOf(selectedDate)
    onViewingDateChanged: {
        const start = Cal.gridStart(viewingDate);
        EventsState.want(start, Cal.addDays(start, 42));
    }
    Component.onCompleted: {
        EventsState.viewers++;
        viewingDateChanged();
    }
    Component.onDestruction: EventsState.viewers--

    focus: true
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            root.step(event.key === Qt.Key_PageDown ? 1 : -1);
            event.accepted = true;
        }
    }

    function select(date) {
        selected = Cal.toIso(date);
    }

    function step(delta) {
        if (root.weekMode)
            root.select(Cal.addDays(root.selectedDate, 7 * delta));
        else
            root.viewMonth = Cal.addMonths(root.viewingDate, delta);
    }

    Rectangle {
        visible: root.surface
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
    }

    MouseArea {
        property real wheelDelta: 0
        property real lastStep: 0
        anchors.fill: parent
        enabled: !root.weekMode
        onWheel: event => {
            wheelDelta += event.angleDelta.y;
            if (Math.abs(wheelDelta) < 120 || Date.now() - lastStep < 200)
                return;
            root.step(wheelDelta > 0 ? -1 : 1);
            wheelDelta = 0;
            lastStep = Date.now();
        }
    }

    MonthGrid {
        id: grid
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        now: root.now
        days: root.days
        status: root.status
        errorText: root.errorText
        currentMonth: root.currentMonth
        viewingDate: root.viewingDate
        selectedDate: root.selectedDate
        weekMode: root.weekMode
        onDaySelected: date => root.select(date)
        onHeaderClicked: {
            root.selected = "";
            root.viewMonth = null;
        }
        onStepped: delta => root.step(delta)
    }

    EventList {
        anchors.top: grid.bottom
        anchors.topMargin: 10
        anchors.left: grid.left
        anchors.right: grid.right
        anchors.bottom: parent.bottom
        day: root.selectedDate ?? root.now
        now: root.now
        days: root.days
        status: root.status
        errorText: root.errorText
        listBottomPadding: addLayer.fabSize + addLayer.fabMargins * 2
        opacity: root.weekMode ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    AddEventLayer {
        id: addLayer
        anchors.fill: parent
        day: root.selectedDate ?? root.now
        now: root.now
        fabShown: root.weekMode && root.canAdd && root.status !== "setup"
    }
}
