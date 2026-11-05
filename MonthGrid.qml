import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "gcal.js" as Gcal
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property var now: new Date()
    property var days: ({})
    property string status: "ready"
    property string errorText: ""
    property bool currentMonth: true
    property var viewingDate: Gcal.monthOf(now)
    property var selectedDate: null
    property bool weekMode: false
    readonly property var cells: Gcal.monthCells(viewingDate, now)
    readonly property int selectedRow: Gcal.rowOf(viewingDate, selectedDate)
    readonly property string monthKey: Gcal.toIso(viewingDate)
    property string issue: status
    property real monthFade: 1
    signal daySelected(var date)
    signal headerClicked
    signal stepped(int delta)

    spacing: 0

    onStatusChanged: if (status !== "ready") issue = status
    onMonthKeyChanged: monthFadeIn.restart()

    NumberAnimation {
        id: monthFadeIn
        target: root
        property: "monthFade"
        from: 0.4
        to: 1
        duration: Appearance.animation.elementMoveFast.duration
        easing.type: Appearance.animation.elementMoveFast.type
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 5
        HeaderButton {
            id: monthButton
            clip: true
            buttonText: `${!root.currentMonth && !root.weekMode ? "• " : ""}${root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
            tooltipText: root.weekMode ? Translation.tr("Show month") : root.currentMonth ? "" : Translation.tr("Jump to current month")
            contentItem: RowLayout {
                spacing: 2
                StyledText {
                    Layout.leftMargin: root.weekMode ? 4 : 0
                    text: monthButton.buttonText
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
                MaterialSymbol {
                    visible: root.weekMode
                    text: "expand_more"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
            }
            downAction: () => root.headerClicked()
        }
        Item {
            Layout.fillWidth: true
        }
        HeaderButton {
            forceCircle: true
            opacity: root.status !== "ready" ? 1 : 0
            visible: opacity > 0
            scale: root.status !== "ready" ? 1 : 0.6
            colBackground: root.issue === "loading" ? Appearance.colors.colLayer2 : Appearance.colors.colErrorContainer
            colBackgroundHover: root.issue === "loading" ? Appearance.colors.colLayer2Hover : Appearance.colors.colErrorContainerHover
            colRipple: root.issue === "loading" ? Appearance.colors.colLayer2Active : Appearance.colors.colErrorContainerActive
            tooltipText: root.issue === "loading" ? Translation.tr("Loading events")
                : root.issue === "noauth" ? Translation.tr("Not signed in: run gcalcli init in a terminal")
                : `${root.errorText}. ${Translation.tr("Click to retry")}`
            downAction: () => GcalState.refresh()
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on scale {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            contentItem: MaterialSymbol {
                text: root.issue === "loading" ? "sync" : root.issue === "noauth" ? "no_accounts" : "cloud_off"
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
                color: root.issue === "loading" ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnErrorContainer
                RotationAnimation on rotation {
                    running: root.issue === "loading" && parent.visible
                    loops: Animation.Infinite
                    from: 360
                    to: 0
                    duration: 1200
                    onStopped: parent.rotation = 0
                }
            }
        }
        HeaderButton {
            forceCircle: true
            downAction: () => root.stepped(-1)
            contentItem: MaterialSymbol {
                text: "chevron_left"
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colOnLayer1
            }
        }
        HeaderButton {
            forceCircle: true
            downAction: () => root.stepped(1)
            contentItem: MaterialSymbol {
                text: "chevron_right"
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 5
        spacing: 5
        Repeater {
            model: Gcal.weekDays
            delegate: DayButton {
                required property var modelData
                day: Translation.tr(modelData)
                isToday: 0
                bold: true
                enabled: false
            }
        }
    }

    Repeater {
        model: 6
        delegate: Item {
            id: rowItem
            required property int index
            readonly property bool shown: !root.weekMode || index === root.selectedRow
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: weekRow.implicitWidth
            implicitHeight: shown ? weekRow.implicitHeight + 5 : 0
            opacity: shown ? 1 : 0
            clip: true
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            RowLayout {
                id: weekRow
                anchors.bottom: parent.bottom
                opacity: root.monthFade
                spacing: 5
                Repeater {
                    model: 7
                    delegate: DayButton {
                        required property int index
                        readonly property var cell: root.cells[rowItem.index * 7 + index]
                        readonly property bool active: cell.inMonth || root.weekMode
                        day: cell.day
                        isToday: cell.today && active ? 1 : active ? 0 : -1
                        hasEvents: (root.days[cell.iso]?.length ?? 0) > 0
                        selected: Gcal.sameDay(cell.date, root.selectedDate)
                        onClicked: root.daySelected(cell.date)
                    }
                }
            }
        }
    }
}
