import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "calendar.js" as Cal
import QtQuick
import QtQuick.Layouts
import Quickshell

/** A day's events, all-day first, a now line today; else what is missing. */
Item {
    id: root
    property var day: new Date()
    property var now: new Date()
    property var days: ({})
    property string status: "ready"
    property string errorText: ""
    property real listBottomPadding: 0
    readonly property var items: Cal.dayItems(days, day)
    readonly property int nowIndex: Cal.nowIndex(items, day, now)
    readonly property var placeholder: root.status === "setup" ? {
            "icon": "no_accounts",
            "title": Translation.tr("Not connected"),
            "hint": root.errorText
        } : root.status === "error" ? {
            "icon": "cloud_off",
            "title": Translation.tr("Couldn't load events"),
            "hint": root.errorText
        } : root.status === "loading" ? {
            "icon": "",
            "title": Translation.tr("Loading events"),
            "hint": ""
        } : {
            "icon": "event_available",
            "title": Translation.tr("Nothing planned"),
            "hint": Translation.tr("Press + to add an event")
        }

    StyledListView {
        id: listView
        anchors.fill: parent
        bottomMargin: root.listBottomPadding
        spacing: 5
        clip: true
        animateAppearance: false
        model: ScriptModel {
            objectProp: "key"
            values: root.items
        }
        delegate: Column {
            id: entry
            required property var modelData
            required property int index
            width: ListView.view.width
            spacing: 5
            NowLine {
                visible: entry.index === root.nowIndex
                width: parent.width
            }
            EventRow {
                modelData: entry.modelData
                past: Cal.isPast(entry.modelData, root.day, root.now)
                width: parent.width
            }
        }
        footer: Item {
            width: ListView.view.width
            height: root.nowIndex === root.items.length ? 13 : 0
            NowLine {
                visible: parent.height > 0
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }
    }

    component NowLine: Item {
        implicitHeight: 8
        Rectangle {
            id: nowDot
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: nowDot.right
            anchors.right: parent.right
            height: 2
            radius: 1
            color: Appearance.colors.colPrimary
        }
    }

    component EventRow: RippleButton {
        id: row
        property var modelData
        property bool past: false
        readonly property string timeText: modelData?.allDay ? Translation.tr("All day") : `${modelData?.startText ?? ""} - ${modelData?.endText ?? ""}`
        readonly property string callText: modelData?.call ? Translation.tr(modelData.call) : ""
        implicitHeight: rowLayout.implicitHeight + 6 * 2
        padding: 0
        buttonRadius: Appearance.rounding.small
        colBackground: past ? ColorUtils.transparentize(Appearance.colors.colLayer2, 1) : Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        enabled: (modelData?.link ?? "") !== ""
        onClicked: Qt.openUrlExternally(modelData.link)

        contentItem: Item {
            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: 6
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 10

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 4
                    radius: Appearance.rounding.full
                    color: row.past ? Appearance.colors.colOutlineVariant : Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData?.title || Translation.tr("(No title)")
                        elide: Text.ElideRight
                        color: row.past ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        StyledText {
                            text: row.timeText
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            visible: row.callText !== ""
                            Layout.leftMargin: 4
                            text: "videocam"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            visible: row.callText !== ""
                            Layout.fillWidth: true
                            text: row.callText
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    Item {
        visible: opacity > 0
        opacity: root.items.length === 0 ? 1 : 0
        anchors.fill: parent
        anchors.bottomMargin: root.listBottomPadding / 2

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width
            spacing: 5

            MaterialSymbol {
                visible: root.placeholder.icon !== ""
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: root.placeholder.icon
            }
            MaterialLoadingIndicator {
                visible: root.status === "loading"
                loading: visible
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.placeholder.title
            }
            StyledText {
                visible: text !== ""
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.placeholder.hint
            }
        }
    }
}
