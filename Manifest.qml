import qs.modules.widgets
import qs.services

/** Calendar events in the sidebar Calendar tab, from the provider picked in options. */
WidgetManifest {
    widgetId: "calendar"
    name: Translation.tr("Calendar")
    description: Translation.tr("Events in the Calendar tab of the right sidebar, from gcalcli (Google Calendar)")
    icon: "event"
    version: "2.0"
    author: "Berupor"
    minShellVersion: "1.6"
    slots: ({
        "calendarView": "CalendarTab.qml"
    })
    options: [
        {
            "key": "provider",
            "type": "textField",
            "icon": "cloud_sync",
            "label": Translation.tr("Provider"),
            "placeholder": "gcalcli",
            "default": "gcalcli"
        },
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
