//@ probe -g 354x350 -H sidebar
import ".."
import "../gcal.js" as Gcal
import QtQuick

/** The view on stub events at a fixed time, and the date logic behind adding. */
Item {
    id: root
    property alias selected: view.selected
    property alias addOpen: view.addOpen
    property alias addText: view.addText
    property alias status: view.status
    readonly property var now: new Date(2026, 9, 31, 14, 48)
    // Shape of `gcalcli agenda --tsv --details id --details url --details conference --details calendar`
    readonly property string head: "id\tstart_date\tstart_time\tend_date\tend_time\thtml_link\thangout_link\tconference_entry_point_type\tconference_uri\ttitle\tcalendar"
    readonly property string tsv: [
        root.head,
        row("2026-10-05", "09:30", "2026-10-05", "10:00", "Car service"),
        row("2026-10-12", "18:00", "2026-10-12", "19:00", "Parents evening at school"),
        row("2026-10-15", "12:30", "2026-10-15", "13:30", "Lunch with Anna"),
        row("2026-10-20", "11:00", "2026-10-20", "11:30", "Sprint planning", true),
        row("2026-10-26", "20:00", "2026-10-26", "22:00", "Concert"),
        row("2026-10-28", "23:00", "2026-10-29", "00:00", "Late call"),
        row("2026-10-31", "", "2026-11-01", "", "Halloween", false, "Holidays"),
        row("2026-10-31", "08:00", "2026-10-31", "09:00", "Gym"),
        row("2026-10-31", "15:00", "2026-10-31", "15:15", "Standup", true),
        row("2026-10-31", "17:30", "2026-10-31", "18:00", "Dentist"),
        row("2026-10-31", "19:00", "2026-10-31", "21:00", "Dinner"),
        row("2026-11-02", "10:00", "2026-11-02", "10:30", "1:1 with lead", true),
        row("2026-11-03", "", "2026-11-04", "", "Trip", false, "Holidays"),
        row("2026-11-05", "23:30", "2026-11-06", "00:30", "Night call"),
        row("2026-11-09", "", "2026-11-12", "", "Conference")
    ].join("\n")
    readonly property var rows: Gcal.parseAgenda(tsv)
    readonly property var days: Gcal.byDay(rows, "")
    readonly property var today: Gcal.dayItems(days, now)

    function row(sd, st, ed, et, title, meet, calendar) {
        const id = `ev${sd.replace(/-/g, "")}${st.replace(":", "")}`;
        return [id, sd, st, ed, et, `https://www.google.com/calendar/event?eid=${id}`, meet ? "https://meet.google.com/abc-defg-hij" : "", "", "", title, calendar ?? "Personal"].join("\t");
    }

    function lines(list) {
        const at = Gcal.nowIndex(list, root.now, root.now);
        const titles = list.map(e => e.title);
        if (at >= 0)
            titles.splice(at, 0, "now");
        return titles.join(",");
    }

    GcalView {
        id: view
        anchors.fill: parent
        surface: true
        now: root.now
        days: root.days
        status: "ready"
        errorText: ""
    }

    // Week mode open on an old day while the clock crosses into the next month
    GcalView {
        id: midnight
        visible: false
        width: 354
        height: 350
        now: new Date(2026, 9, 31, 23, 59)
        days: root.days
        status: "ready"
        selected: "2026-10-05"
    }

    // A refetch brings new objects for the same events
    EventList {
        id: refetched
        visible: false
        width: 300
        height: 300
        day: root.now
        now: root.now
        days: root.days
        property var firstRow: null
    }
    Timer {
        running: true
        interval: 300
        onTriggered: {
            refetched.firstRow = refetched.children[0].itemAtIndex(0);
            refetched.days = Gcal.byDay(Gcal.parseAgenda(root.tsv.replace("\tHalloween\t", "\tHalloween party\t")), "");
        }
    }

    function checks() {
        const day = new Date(2026, 10, 3);
        const appended = t => Gcal.quickPlan(t, day, root.now).text === `${t} on November 3 2026`;
        const kept = t => {
            const plan = Gcal.quickPlan(t, day, root.now);
            return plan.text === t && plan.day === null;
        };
        const tabbed = Gcal.parseAgenda(`${root.head}\nev1\t2026-10-31\t08:00\t2026-10-31\t09:00\thttps://www.google.com/calendar/event?eid=ev1\t\t\t\tCoffee\tchat\tHolidays`);
        midnight.now = new Date(2026, 10, 1, 0, 0);
        return [
            {
                "name": "every row of the tsv parses",
                "got": root.rows.length,
                "want": 15
            },
            {
                "name": "a notice before the header is skipped",
                "got": Gcal.parseAgenda(`Moving oauth file from legacy path /a to /b...\n${root.tsv}`)?.length,
                "want": 15
            },
            {
                "name": "output without a header is no result, not an empty day",
                "got": Gcal.parseAgenda("Moving oauth file from legacy path /a to /b...\n"),
                "want": null
            },
            {
                "name": "a tab in a title stays in the title, the calendar is still read",
                "got": `${tabbed[0].title}|${tabbed[0].calendar}|${tabbed[0].startText}`,
                "want": "Coffee\tchat|Holidays|08:00"
            },
            {
                "name": "agenda asks only for columns after which title is the only free text",
                "got": Gcal.agendaDetails.join(","),
                "want": "id,url,conference,calendar"
            },
            {
                "name": "all-day first, now line after the last finished event",
                "got": root.lines(root.today),
                "want": "Halloween,Gym,now,Standup,Dentist,Dinner"
            },
            {
                "name": "no now line on another day",
                "got": Gcal.nowIndex(root.days["2026-11-02"], new Date(2026, 10, 2), root.now),
                "want": -1
            },
            {
                "name": "an all-day event is not past until its day ends",
                "got": [Gcal.isPast(root.today[0], root.now, root.now), Gcal.isPast(root.today[1], root.now, root.now)].join(","),
                "want": "false,true"
            },
            {
                "name": "day items are the grouped events themselves, stable across ticks",
                "got": Gcal.dayItems(root.days, root.now) === Gcal.dayItems(root.days, new Date(2026, 9, 31, 20, 0)),
                "want": true
            },
            {
                "name": "a hidden calendar drops out",
                "got": (Gcal.byDay(root.rows, " holidays ")["2026-10-31"] ?? []).length,
                "want": 4
            },
            {
                "name": "an event past midnight is on both days, one ending at midnight only on its own",
                "got": ["2026-11-05", "2026-11-06", "2026-10-28", "2026-10-29"].map(d => root.days[d]?.length ?? 0).join(","),
                "want": "1,1,1,0"
            },
            {
                "name": "a multi-day all-day event is on each of its days, end date exclusive",
                "got": ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-03", "2026-11-04"].map(d => root.days[d]?.length ?? 0).join(","),
                "want": "1,1,1,0,1,0"
            },
            {
                "name": "midnight keeps the viewed month and the picked week",
                "got": `${Gcal.toIso(midnight.viewingDate)} row ${Gcal.rowOf(midnight.viewingDate, midnight.selectedDate)}`,
                "want": "2026-10-01 row 1"
            },
            {
                "name": "a refetch keeps the row and shows the new data",
                "got": `${refetched.children[0].itemAtIndex(0) === refetched.firstRow && refetched.firstRow !== null} ${refetched.children[0].itemAtIndex(0)?.modelData?.title}`,
                "want": "true Halloween party"
            },
            {
                "name": "text without a day gets the picked one",
                "got": Gcal.quickPlan("Lunch with Anna 1pm", day, root.now).text,
                "want": "Lunch with Anna 1pm on November 3 2026"
            },
            {
                "name": "words that only look like days append the date",
                "got": ["Lunch with Jan", "Call May 3pm", "Maybe 3 people", "Sun salutation yoga", "4th floor sync", "Mark the market", "1:1 with lead", "Call 12.30", "Party 10.11", "Встреча 10.05", "Обед 13.00", "Обсуждение среды", "Среднее"].filter(t => !appended(t)).join("|"),
                "want": ""
            },
            {
                "name": "English day phrases are left for Google",
                "got": ["Dentist friday 5pm", "Review on wed", "next week standup", "in 3 days review", "Dinner tomorrow 7pm", "Trip May 3", "Call 3 May", "Sync on the 5th", "Sprint 2026-11-20", "Retro 11/20"].filter(t => !kept(t)).join("|"),
                "want": ""
            },
            {
                "name": "Russian day phrases become an English date, Google quick-add reads only English",
                "got": ["Встреча завтра в 15:00", "Ужин в субботу", "Ретро в среду", "Звонок в следующую среду", "Отпуск 3 ноября", "Сессия 5 января", "Отчет через 3 дня", "Сдать 10.11.2026"].map(t => Gcal.quickPlan(t, day, root.now).text).join("|"),
                "want": ["Встреча on November 1 2026 at 15:00", "Ужин on October 31 2026", "Ретро on November 4 2026", "Звонок on November 4 2026", "Отпуск on November 3 2026", "Сессия on January 5 2027", "Отчет on November 3 2026", "Сдать on November 10 2026"].join("|")
            },
            {
                "name": "a Russian time keeps the picked day",
                "got": Gcal.quickPlan("Обед в 13:00", day, root.now).text,
                "want": "Обед at 13:00 on November 3 2026"
            },
            {
                "name": "quick-add time reads 24h and am/pm, and ignores dates and ratios",
                "got": ["Lunch 13:00", "Call 1:30pm", "Dinner 7 pm", "Noon 12am", "Call May 3pm", "1:1 with lead", "Party 10.11", "Sprint 2026-11-20", "Floor 4", "Late 24:00", "Late 25pm"].map(Gcal.quickTime).join("|"),
                "want": "13:00|13:30|19:00|00:00|15:00||||||"
            },
            {
                "name": "a fetch reaches past the view by the margin, and covers the neighbouring months",
                "got": [Gcal.fetchWindow("2026-09-28 2026-11-09", 60), Gcal.covers("2026-07-30 2027-01-08", "2026-11-02 2026-12-14"), Gcal.covers("2026-07-30 2027-01-08", "2026-06-29 2026-08-10")].join("|"),
                "want": "2026-07-30 2027-01-08|true|false"
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
            },
            {
                "name": "an http error names its code",
                "got": [503, 400].map(c => Gcal.shortError(`googleapiclient.errors.HttpError: <HttpError ${c} when requesting https://www.googleapis.com/calendar/v3/calendars/x/events/quickAdd returned "Backend Error">`, 1)).join("|"),
                "want": "Google Calendar is down (503), try again|Google Calendar refused it (400)"
            }
        ];
    }
}
