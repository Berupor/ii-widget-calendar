//@ probe -g 354x350 -H sidebar
import ".."
import "../gcal.js" as Gcal
import QtQuick

/** The view on stub events at a fixed time, and the date logic behind adding. */
Item {
    id: root
    property alias selected: view.selected
    property alias addOpen: view.addOpen
    property alias status: view.status
    readonly property var now: new Date(2026, 9, 31, 14, 48)
    readonly property string tsv: [
        "id\tstart_date\tstart_time\tend_date\tend_time\thtml_link\thangout_link\tconference_entry_point_type\tconference_uri\ttitle\tlocation\tdescription\tcalendar\temail\taction",
        row("2026-10-05", "09:30", "2026-10-05", "10:00", "Car service"),
        row("2026-10-12", "18:00", "2026-10-12", "19:00", "Parents evening at school"),
        row("2026-10-15", "12:30", "2026-10-15", "13:30", "Lunch with Anna"),
        row("2026-10-20", "11:00", "2026-10-20", "11:30", "Sprint planning", true),
        row("2026-10-26", "20:00", "2026-10-26", "22:00", "Concert"),
        row("2026-10-31", "", "2026-11-01", "", "Halloween", false, "Holidays"),
        row("2026-10-31", "08:00", "2026-10-31", "09:00", "Gym"),
        row("2026-10-31", "15:00", "2026-10-31", "15:15", "Standup", true),
        row("2026-10-31", "17:30", "2026-10-31", "18:00", "Dentist"),
        row("2026-10-31", "19:00", "2026-10-31", "21:00", "Dinner"),
        row("2026-11-02", "10:00", "2026-11-02", "10:30", "1:1 with lead", true),
        row("2026-11-03", "", "2026-11-03", "", "Trip", false, "Holidays"),
        row("2026-11-05", "23:30", "2026-11-06", "00:30", "Night call")
    ].join("\n")
    readonly property var rows: Gcal.parseAgenda(tsv)
    readonly property var today: Gcal.dayItems(Gcal.byDay(rows, ""), now, now)

    function row(sd, st, ed, et, title, meet, calendar) {
        return ["x", sd, st, ed, et, "https://calendar.google.com", meet ? "https://meet.google.com/x" : "", "", "", title, "", "", calendar ?? "Personal", "", ""].join("\t");
    }

    GcalView {
        id: view
        anchors.fill: parent
        surface: true
        now: root.now
        days: Gcal.byDay(root.rows, "")
        status: "ready"
        errorText: ""
    }

    function checks() {
        const day = new Date(2026, 10, 3);
        return [
            {
                "name": "every row of the tsv parses",
                "got": root.rows.length,
                "want": 13
            },
            {
                "name": "all-day first, now line after the last finished event",
                "got": root.today.map(e => e.nowLine ? "now" : e.title).join(","),
                "want": "Halloween,Gym,now,Standup,Dentist,Dinner"
            },
            {
                "name": "an all-day event is not past until its day ends",
                "got": root.today[0].past,
                "want": false
            },
            {
                "name": "a hidden calendar drops out",
                "got": (Gcal.byDay(root.rows, " holidays ")["2026-10-31"] ?? []).length,
                "want": 4
            },
            {
                "name": "an event past midnight is on both days",
                "got": [Gcal.byDay(root.rows, "")["2026-11-05"]?.length, Gcal.byDay(root.rows, "")["2026-11-06"]?.length].join(","),
                "want": "1,1"
            },
            {
                "name": "text without a day gets the picked one",
                "got": Gcal.quickText("Lunch with Anna 1pm", day),
                "want": "Lunch with Anna 1pm November 3 2026"
            },
            {
                "name": "a time with a dot is not a date",
                "got": Gcal.quickText("Call 12.30", day),
                "want": "Call 12.30 November 3 2026"
            },
            {
                "name": "day words keep the text as is",
                "got": ["Dentist friday 5pm", "Sync on the 5th", "Party 10.11", "Sprint 2026-11-20", "Встреча завтра в 15:00", "Ужин в субботу", "Отпуск 3 ноября"].every(t => Gcal.quickText(t, day) === t),
                "want": true
            },
            {
                "name": "words that only look like days append the date",
                "got": ["Mark the market", "1:1 with lead", "Обед 13.00", "Среднее"].every(t => Gcal.quickText(t, day) !== t),
                "want": true
            },
            {
                "name": "gcalcli asking to sign in reads as noauth",
                "got": Gcal.needsAuth("Not yet authenticated.\nStarting auth flow..."),
                "want": true
            },
            {
                "name": "a network failure gets a short message",
                "got": Gcal.shortError("Traceback\nhttplib2.error.ServerNotFoundError: Unable to find the server at oauth2.googleapis.com", 1),
                "want": "Can't reach Google Calendar"
            }
        ];
    }
}
