//@ probe -g 354x350 -H sidebar
import ".."
import "../calendar.js" as Cal
import "../providers/gcalcli.js" as Gcalcli
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
    readonly property var rows: Gcalcli.parseAgenda(tsv)
    readonly property var days: Cal.byDay(rows, "")
    readonly property var today: Cal.dayItems(days, now)

    function row(sd, st, ed, et, title, meet, calendar) {
        const id = `ev${sd.replace(/-/g, "")}${st.replace(":", "")}`;
        return [id, sd, st, ed, et, `https://www.google.com/calendar/event?eid=${id}`, meet ? "https://meet.google.com/abc-defg-hij" : "", "", "", title, calendar ?? "Personal"].join("\t");
    }

    function lines(list) {
        const at = Cal.nowIndex(list, root.now, root.now);
        const titles = list.map(e => e.title);
        if (at >= 0)
            titles.splice(at, 0, "now");
        return titles.join(",");
    }

    CalendarTab {
        id: view
        anchors.fill: parent
        surface: true
        weekStart: 1
        now: root.now
        days: root.days
        status: "ready"
        errorText: status === "setup" ? "Run gcalcli init in a terminal" : ""
        canAdd: true
    }

    // Week mode open on an old day while the clock crosses into the next month
    CalendarTab {
        id: midnight
        visible: false
        width: 354
        height: 350
        weekStart: 1
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
            refetched.days = Cal.byDay(Gcalcli.parseAgenda(root.tsv.replace("\tHalloween\t", "\tHalloween party\t")), "");
        }
    }

    // Answers EventsState from its provider the way a finished fetch does, then puts the state back
    function driveFetches() {
        const s = EventsState;
        const p = s.provider;
        const inside = "2026-09-28 2026-11-09";
        const wide = Cal.fetchWindow(inside, 60);
        const far = "2027-03-01 2027-04-12";
        const failure = { setup: false, text: "Can't reach Google Calendar", exitCode: 1 };
        const wipe = () => {
            s.rows = [];
            s.fetchedWindow = "";
            s.fetchingWindow = "";
            s.pending = false;
            s.needsSetup = false;
            s.failureText = "";
            s.range = "";
        };
        const out = {};
        wipe();
        s.range = inside;
        p.fetched(wide, null, failure);
        out.firstFail = `${s.status} [${s.fetchedWindow}] fetching=${s.fetchingWindow !== ""} fresh=${s.isFresh()}`;
        s.fetchingWindow = wide;
        out.retry = s.status;
        s.fetchingWindow = "";
        p.fetched(wide, Gcalcli.parseAgenda(`${root.head}\n${root.row("2020-01-01", "", "2030-01-01", "", "Decade")}`), null);
        out.ok = `${s.status} ${s.fetchedWindow} days=${Object.keys(s.days).length}`;
        s.range = far;
        out.farUncovered = `${s.status} fresh=${s.isFresh()}`;
        p.fetched(Cal.fetchWindow(far, 60), null, failure);
        out.farFail = `${s.status} ${s.fetchedWindow} fetching=${s.fetchingWindow !== ""} fresh=${s.isFresh()}`;
        s.range = inside;
        p.fetched(wide, null, { setup: true, text: "Run gcalcli init in a terminal", exitCode: 1 });
        out.setup = `${s.status} rows=${s.rows.length}`;
        wipe();
        s.adding = true;
        s.addError = "Google Calendar is down (503), try again";
        s.pending = true;
        s.providerNameChanged();
        out.swap = `${s.adding} [${s.addError}] ${s.pending}`;
        return out;
    }

    function checks() {
        const fetched = root.driveFetches();
        const day = new Date(2026, 10, 3);
        const sundayOct = new Date(2026, 9, 1);
        const decade = Gcalcli.parseAgenda(`${root.head}\n${root.row("2020-01-01", "", "2030-01-01", "", "Decade")}\n${root.row("2026-10-20", "09:00", "2026-10-20", "10:00", "Before")}\n${root.row("2026-10-20", "", "2026-10-28", "", "Straddles start")}\n${root.row("2026-12-05", "", "2026-12-20", "", "Straddles end")}\n${root.row("2026-12-09", "", "2026-12-10", "", "After")}`);
        const windowed = Cal.byDay(decade, "", "2026-10-26 2026-12-07");
        const sameId = Gcalcli.parseAgenda(`${root.head}\n${root.row("2026-10-05", "09:30", "2026-10-05", "10:00", "Car service", false, "Work")}\n${root.row("2026-10-05", "09:30", "2026-10-05", "10:00", "Car service", false, "Family")}`);
        const titled = t => Gcalcli.agendaResult(`${root.head}\n${root.row("2026-10-05", "09:30", "2026-10-05", "10:00", t)}`, "", 0);
        const appended = t => Gcalcli.quickPlan(t, day, root.now).text === `${t} on November 3 2026`;
        const kept = t => {
            const plan = Gcalcli.quickPlan(t, day, root.now);
            return plan.text === t && plan.day === null;
        };
        const tabbed = Gcalcli.parseAgenda(`${root.head}\nev1\t2026-10-31\t08:00\t2026-10-31\t09:00\thttps://www.google.com/calendar/event?eid=ev1\t\t\t\tCoffee\tchat\tHolidays`);
        midnight.now = new Date(2026, 10, 1, 0, 0);
        return [
            {
                "name": "every row of the tsv parses",
                "got": root.rows.length,
                "want": 15
            },
            {
                "name": "a notice before the header is skipped",
                "got": Gcalcli.parseAgenda(`Moving oauth file from legacy path /a to /b...\n${root.tsv}`)?.length,
                "want": 15
            },
            {
                "name": "output without a header is no result, not an empty day",
                "got": Gcalcli.parseAgenda("Moving oauth file from legacy path /a to /b...\n"),
                "want": null
            },
            {
                "name": "a tab in a title stays in the title, the calendar is still read",
                "got": `${tabbed[0].title}|${tabbed[0].calendar}|${tabbed[0].startText}`,
                "want": "Coffee\tchat|Holidays|08:00"
            },
            {
                "name": "agenda asks only for columns after which title is the only free text",
                "got": Gcalcli.agendaDetails.join(","),
                "want": "id,url,conference,calendar"
            },
            {
                "name": "all-day first, now line after the last finished event",
                "got": root.lines(root.today),
                "want": "Halloween,Gym,now,Standup,Dentist,Dinner"
            },
            {
                "name": "no now line on another day",
                "got": Cal.nowIndex(root.days["2026-11-02"], new Date(2026, 10, 2), root.now),
                "want": -1
            },
            {
                "name": "an all-day event is not past until its day ends",
                "got": [Cal.isPast(root.today[0], root.now, root.now), Cal.isPast(root.today[1], root.now, root.now)].join(","),
                "want": "false,true"
            },
            {
                "name": "day items are the grouped events themselves, stable across ticks",
                "got": Cal.dayItems(root.days, root.now) === Cal.dayItems(root.days, new Date(2026, 9, 31, 20, 0)),
                "want": true
            },
            {
                "name": "a hidden calendar drops out",
                "got": (Cal.byDay(root.rows, " holidays ")["2026-10-31"] ?? []).length,
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
                "got": `${Cal.toIso(midnight.viewingDate)} row ${Cal.rowOf(midnight.viewingDate, midnight.selectedDate)}`,
                "want": "2026-10-01 row 1"
            },
            {
                "name": "a refetch keeps the row and shows the new data",
                "got": `${refetched.children[0].itemAtIndex(0) === refetched.firstRow && refetched.firstRow !== null} ${refetched.children[0].itemAtIndex(0)?.modelData?.title}`,
                "want": "true Halloween party"
            },
            {
                "name": "text without a day gets the picked one",
                "got": Gcalcli.quickPlan("Lunch with Anna 1pm", day, root.now).text,
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
                "got": ["Встреча завтра в 15:00", "Ужин в субботу", "Ретро в среду", "Звонок в следующую среду", "Отпуск 3 ноября", "Сессия 5 января", "Отчет через 3 дня", "Сдать 10.11.2026"].map(t => Gcalcli.quickPlan(t, day, root.now).text).join("|"),
                "want": ["Встреча on November 1 2026 at 15:00", "Ужин on October 31 2026", "Ретро on November 4 2026", "Звонок on November 4 2026", "Отпуск on November 3 2026", "Сессия on January 5 2027", "Отчет on November 3 2026", "Сдать on November 10 2026"].join("|")
            },
            {
                "name": "a Russian time keeps the picked day",
                "got": Gcalcli.quickPlan("Обед в 13:00", day, root.now).text,
                "want": "Обед at 13:00 on November 3 2026"
            },
            {
                "name": "quick-add time reads 24h and am/pm, and ignores dates and ratios",
                "got": ["Lunch 13:00", "Call 1:30pm", "Dinner 7 pm", "Noon 12am", "Call May 3pm", "1:1 with lead", "Party 10.11", "Sprint 2026-11-20", "Floor 4", "Late 24:00", "Late 25pm"].map(Cal.quickTime).join("|"),
                "want": "13:00|13:30|19:00|00:00|15:00||||||"
            },
            {
                "name": "a fetch reaches past the view by the margin, and covers the neighbouring months",
                "got": [Cal.fetchWindow("2026-09-28 2026-11-09", 60), Cal.covers("2026-07-30 2027-01-08", "2026-11-02 2026-12-14"), Cal.covers("2026-07-30 2027-01-08", "2026-06-29 2026-08-10")].join("|"),
                "want": "2026-07-30 2027-01-08|true|false"
            },
            {
                "name": "gcalcli asking to sign in, or missing, reads as setup with what to run",
                "got": [Gcalcli.failure("Not yet authenticated.\nStarting auth flow...", 1), Gcalcli.failure("", 127)].map(f => `${f.setup} ${f.text}`).join("|"),
                "want": "true Run gcalcli init in a terminal|true Install gcalcli"
            },
            {
                "name": "a meet link and a conference read as call labels",
                "got": root.rows.filter(ev => ev.call !== "").map(ev => ev.call).join(","),
                "want": "Google Meet,Google Meet,Google Meet"
            },
            {
                "name": "only known providers resolve to a file",
                "got": ["gcalcli", "foo", "toString", ""].map(Cal.providerFile).join("|"),
                "want": "Gcalcli.qml|||"
            },
            {
                "name": "the gcalcli provider loads and can add",
                "got": `${EventsState.providerName} ${EventsState.canAdd}`,
                "want": "gcalcli true"
            },
            {
                "name": "a network failure gets a short message",
                "got": Gcalcli.shortError("Traceback\nhttplib2.error.ServerNotFoundError: Unable to find the server at oauth2.googleapis.com", 1),
                "want": "Can't reach Google Calendar"
            },
            {
                "name": "an http error names its code",
                "got": [503, 400].map(c => Gcalcli.shortError(`googleapiclient.errors.HttpError: <HttpError ${c} when requesting https://www.googleapis.com/calendar/v3/calendars/x/events/quickAdd returned "Backend Error">`, 1)).join("|"),
                "want": "Google Calendar is down (503), try again|Google Calendar refused it (400)"
            },
            {
                "name": "a title naming RefreshError or invalid_grant is an event, not a sign-in failure",
                "got": ["RefreshError postmortem", "invalid_grant outage"].map(t => { const r = titled(t); return `${r.failure} ${r.rows.length} ${r.rows[0].title}`; }).join("|"),
                "want": "null 1 RefreshError postmortem|null 1 invalid_grant outage"
            },
            {
                "name": "a run without a header is unexpected output, a token error still sends to setup",
                "got": [Gcalcli.agendaResult("nothing useful\n", "", 0), Gcalcli.agendaResult("", "google.auth.exceptions.RefreshError: invalid_grant", 1), Gcalcli.agendaResult("", "", 127)].map(r => `${r.rows} ${r.failure.setup} ${r.failure.text} ${r.failure.exitCode}`).join("|"),
                "want": "null false Unexpected gcalcli output 0|null true Run gcalcli init in a terminal 1|null true Install gcalcli 127"
            },
            {
                "name": "a failed fetch does not count as fetched and reads error, not endless loading",
                "got": fetched.firstFail,
                "want": "error [] fetching=false fresh=false"
            },
            {
                "name": "a retry after a failure reads as loading",
                "got": fetched.retry,
                "want": "loading"
            },
            {
                "name": "a successful fetch is ready and keeps only the days of its window",
                "got": fetched.ok,
                "want": "ready 2026-07-30 2027-01-08 days=163"
            },
            {
                "name": "a range nothing was fetched for reads loading until the fetch is started",
                "got": fetched.farUncovered,
                "want": "loading fresh=false"
            },
            {
                "name": "a failure of a new range keeps the old window, reads error and is not fresh, so no refetch loop and navigating refetches",
                "got": fetched.farFail,
                "want": "error 2026-07-30 2027-01-08 fetching=false fresh=false"
            },
            {
                "name": "a sign-in failure marks its window fetched and clears the rows",
                "got": fetched.setup,
                "want": "setup rows=0"
            },
            {
                "name": "a new provider drops the add in flight and the pending refetch",
                "got": fetched.swap,
                "want": "false [] false"
            },
            {
                "name": "the same event id in two calendars gives two keys",
                "got": sameId.map(ev => ev.key).join("|"),
                "want": "Work/ev202610050930|Family/ev202610050930"
            },
            {
                "name": "a row without an id still gets a key from its date and title",
                "got": Gcalcli.parseAgenda("start_date\tstart_time\tend_date\tend_time\ttitle\tcalendar\n2026-10-05\t09:30\t2026-10-05\t10:00\tCar service\tWork")[0].key,
                "want": "2026-10-05 09:30 Car service"
            },
            {
                "name": "a newline in a title reads as a space, a tab stays",
                "got": ["Standup\\nroom 5", "Standup\\n\\nroom 5", "Coffee\\n\tchat"].map(t => titled(t).rows[0].title).join("|"),
                "want": "Standup room 5|Standup room 5|Coffee \tchat"
            },
            {
                "name": "a Russian number of days can be 0 or a word, and lands on a real day",
                "got": ["Отчет через 0 дней", "Отчет через 0 недель", "Отчет через два дня", "Отчет через 2 недели", "Отчет через неделю"].map(t => Gcalcli.quickPlan(t, day, root.now).text).join("|"),
                "want": ["Отчет on October 31 2026", "Отчет on October 31 2026", "Отчет on November 2 2026", "Отчет on November 14 2026", "Отчет on November 7 2026"].join("|")
            },
            {
                "name": "a Russian date that does not exist is no day phrase and does not roll over",
                "got": ["Сдать 31 февраля", "Сдать 31 ноября 2026", "Сдать 31.02.2026", "Сдать 10.13.2026", "Сдать 0 января"].map(t => Gcalcli.quickPlan(t, day, root.now).text).join("|"),
                "want": ["Сдать 31 февраля", "Сдать 31 ноября 2026", "Сдать 31.02.2026", "Сдать 10.13.2026", "Сдать 0 января"].map(t => `${t} on November 3 2026`).join("|")
            },
            {
                "name": "a 29 February is a day in a leap year",
                "got": Gcalcli.quickPlan("Сдать 29 февраля 2028", day, root.now).text,
                "want": "Сдать on February 29 2028"
            },
            {
                "name": "a Sunday week start begins the grid on a Sunday and moves the picked day's row",
                "got": [Cal.toIso(Cal.gridStart(sundayOct)), Cal.toIso(Cal.gridStart(sundayOct, 0)), Cal.toIso(Cal.gridStart(new Date(2026, 10, 1), 0)), Cal.toIso(Cal.gridStart(new Date(2026, 10, 1))), Cal.monthCells(sundayOct, root.now, 0)[0].date.getDay(), Cal.rowOf(sundayOct, new Date(2026, 9, 4)), Cal.rowOf(sundayOct, new Date(2026, 9, 4), 0)].join("|"),
                "want": "2026-09-28|2026-09-27|2026-11-01|2026-10-26|0|0|1"
            },
            {
                "name": "the weekday header starts at the week start",
                "got": [Cal.weekHeader(), Cal.weekHeader(1), Cal.weekHeader(0), Cal.weekHeader(6)].map(h => h.join("")).join("|"),
                "want": "MoTuWeThFrSaSu|MoTuWeThFrSaSu|SuMoTuWeThFrSa|SaSuMoTuWeThFr"
            },
            {
                "name": "a window keeps a multi-year event to the days inside it, and drops what ends before it or starts after",
                "got": `${Object.keys(windowed).length} ${Object.keys(windowed).sort()[0]} ${Object.keys(windowed).sort().pop()} ${windowed["2026-10-26"].map(e => e.title).sort().join("+")} ${windowed["2026-12-07"].map(e => e.title).sort().join("+")} ${windowed["2026-10-20"] ?? "none"} ${windowed["2026-12-09"] ?? "none"}`,
                "want": "43 2026-10-26 2026-12-07 Decade+Straddles start Decade+Straddles end none none"
            }
        ];
    }
}
