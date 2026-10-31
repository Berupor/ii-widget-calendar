import qs.modules.common
import qs.modules.common.widgets
import "gcal.js" as Gcal
import QtQuick
import QtQuick.Layouts

/** Calendar tab: month grid with event dots, a picked day folds it to its week. */
Item {
    id: root

    // Writable, so a demo scene draws any state without gcalcli
    property var days: GcalState.days
    property var now: GcalState.now
    property string status: GcalState.status
    property string errorText: GcalState.errorText
    property bool surface: false

    property string selected: ""
    property alias addOpen: addLayer.open
    property int monthShift: 0
    readonly property var selectedDate: Gcal.fromIso(selected)
    readonly property bool weekMode: selectedDate !== null
    readonly property var viewingDate: Gcal.viewDate(monthShift, now)
    onSelectedDateChanged: if (selectedDate) monthShift = Gcal.monthShiftOf(selectedDate, now)
    onViewingDateChanged: {
        const start = Gcal.gridStart(viewingDate);
        GcalState.want(start, Gcal.addDays(start, 42));
    }
    Component.onCompleted: viewingDateChanged()

    function select(date) {
        selected = Gcal.toIso(date);
    }

    Rectangle {
        visible: root.surface
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.weekMode
        onWheel: event => root.monthShift += event.angleDelta.y > 0 ? -1 : 1
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
        monthShift: root.monthShift
        viewingDate: root.viewingDate
        selectedDate: root.selectedDate
        weekMode: root.weekMode
        onDaySelected: date => root.select(date)
        onHeaderClicked: {
            root.selected = "";
            root.monthShift = 0;
        }
        onStepped: delta => {
            if (root.weekMode)
                root.select(Gcal.addDays(root.selectedDate, 7 * delta));
            else
                root.monthShift += delta;
        }
    }

    EventList {
        anchors.top: grid.bottom
        anchors.topMargin: 5
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
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    AddEventLayer {
        id: addLayer
        anchors.fill: parent
        day: root.selectedDate ?? root.now
        fabShown: root.weekMode && root.status !== "noauth"
    }
}
