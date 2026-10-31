import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/** + FAB and the quick-add dialog, To Do tab style. */
Item {
    id: root
    property var day: new Date()
    readonly property bool adding: GcalState.adding
    readonly property string addError: GcalState.addError

    Connections {
        target: GcalState
        function onAdded() {
            root.open = false;
        }
    }
    property bool open: false
    property bool fabShown: true
    property int dialogMargins: 20
    property int fabMargins: 14
    readonly property real fabSize: fabButton.implicitHeight

    StyledRectangularShadow {
        target: fabButton
        radius: fabButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
        opacity: fabButton.opacity
    }
    FloatingActionButton {
        id: fabButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins
        opacity: root.fabShown ? 1 : 0
        visible: opacity > 0
        scale: root.fabShown ? 1 : 0.6
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on scale {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        onClicked: root.open = true
        iconText: "add"
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (visible)
                GcalState.addError = "";
            else
                eventInput.text = "";
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle {
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumnLayout.implicitHeight

            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            function addEvent() {
                if (eventInput.text.trim().length > 0 && !root.adding)
                    GcalState.add(eventInput.text, root.day);
            }

            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: Translation.tr("Add event")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 6

                    TextField {
                        id: eventInput
                        Layout.fillWidth: true
                        padding: 10
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        renderType: Text.NativeRendering
                        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                        selectionColor: Appearance.colors.colSecondaryContainer
                        placeholderText: Translation.tr("Lunch with Anna 1pm")
                        placeholderTextColor: Appearance.m3colors.m3outline
                        focus: root.open
                        onAccepted: dialog.addEvent()

                        background: Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.verysmall
                            border.width: 2
                            border.color: eventInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                            color: "transparent"
                        }

                        cursorDelegate: Rectangle {
                            width: 1
                            color: eventInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                            radius: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        spacing: 6
                        MaterialSymbol {
                            text: root.addError !== "" ? "error" : "event"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.addError !== "" ? Appearance.colors.colError : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.addError !== "" ? root.addError
                                : root.adding ? Translation.tr("Adding...")
                                : Translation.tr("%1, or name a day in the text").arg(root.day.toLocaleDateString(Qt.locale(), "ddd, d MMM"))
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.addError !== "" ? Appearance.colors.colError : Appearance.colors.colSubtext
                        }
                    }
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignRight
                    spacing: 5

                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        onClicked: root.open = false
                    }
                    DialogButton {
                        buttonText: Translation.tr("Add")
                        enabled: eventInput.text.trim().length > 0 && !root.adding
                        onClicked: dialog.addEvent()
                    }
                }
            }
        }
    }
}
