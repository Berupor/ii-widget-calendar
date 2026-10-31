import qs.modules.widgets
import qs.services

/** Google Calendar events in the sidebar Calendar tab, through gcalcli. */
WidgetManifest {
    widgetId: "gcal"
    name: Translation.tr("Google Calendar")
    description: Translation.tr("Events in the Calendar tab of the right sidebar, via gcalcli")
    icon: "event"
    version: "1.0"
    author: "Berupor"
    minShellVersion: "1.6"
    dependencies: ["gcalcli"]
    slots: ({
        "calendarView": "GcalView.qml"
    })
    options: [
        {
            "key": "hiddenCalendars",
            "type": "textField",
            "icon": "visibility_off",
            "label": Translation.tr("Hidden calendars, comma-separated"),
            "placeholder": Translation.tr("Holidays, Birthdays"),
            "default": ""
        },
        {
            "key": "refreshMinutes",
            "type": "spinBox",
            "icon": "sync",
            "label": Translation.tr("Refresh every, min"),
            "min": 1,
            "max": 120,
            "step": 1,
            "default": 10
        },
        {
            "key": "addCalendar",
            "type": "textField",
            "icon": "edit_calendar",
            "label": Translation.tr("Calendar for new events"),
            "placeholder": Translation.tr("First one you own"),
            "default": ""
        }
    ]
}
