import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

/** Grid day: today filled, picked tonal, a dot when it has events. */
RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property bool hasEvents: false
    property bool selected: false
    readonly property bool tonal: selected && isToday !== 1

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38
    implicitHeight: 38

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small
    colBackground: tonal ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colBackgroundHover: tonal ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: tonal ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer1Active

    readonly property color contentColor: (isToday == 1) ? Appearance.m3colors.m3onPrimary
        : tonal ? Appearance.colors.colOnSecondaryContainer
        : (isToday == 0) ? Appearance.colors.colOnLayer1
        : Appearance.colors.colOutlineVariant

    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: button.contentColor

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    Rectangle {
        visible: opacity > 0
        opacity: button.hasEvents ? 1 : 0
        scale: button.hasEvents ? 1 : 0.4
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: 4
        height: 4
        radius: Appearance.rounding.full
        color: (button.isToday == 1 || button.tonal) ? button.contentColor
            : (button.isToday == 0) ? Appearance.colors.colPrimary
            : Appearance.colors.colOutlineVariant

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on scale {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
