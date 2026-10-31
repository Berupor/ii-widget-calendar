pragma Singleton

import qs.modules.widgets
import Quickshell
import Quickshell.Io
import QtQuick
import "gcal.js" as Gcal

/** gcalcli behind the view: one fetch in flight, polling only while enabled. */
Singleton {
    id: root

    readonly property bool enabled: WidgetCatalog.isEnabled("gcal")
    readonly property int refreshMinutes: Math.max(1, WidgetCatalog.option("gcal", "refreshMinutes") || 1)
    readonly property string hiddenCalendars: WidgetCatalog.option("gcal", "hiddenCalendars") ?? ""
    readonly property string addCalendar: (WidgetCatalog.option("gcal", "addCalendar") ?? "").trim()

    property var now: new Date()
    property var rows: []
    readonly property var days: Gcal.byDay(root.rows, root.hiddenCalendars)

    /// "start end" of the window the view shows, iso days
    property string range: ""
    property string fetchedRange: ""
    property bool pending: false
    property bool needsAuth: false
    property string errorText: ""
    readonly property bool fetching: fetchProc.running
    readonly property string status: root.needsAuth ? "noauth" : root.errorText !== "" ? "error"
        : (root.fetchedRange !== root.range) ? "loading" : "ready"

    property bool adding: false
    property string addError: ""
    property string ownCalendar: ""
    property var queued: null
    signal added

    function want(start, end) {
        const next = `${Gcal.toIso(start)} ${Gcal.toIso(end)}`;
        if (next === root.range)
            return;
        root.range = next;
        root.refresh();
    }

    function refresh() {
        if (!root.enabled || root.range === "")
            return;
        if (fetchProc.running) {
            root.pending = true;
            return;
        }
        fetchProc.window = root.range;
        fetchProc.command = ["timeout", "60", "gcalcli", "--nocolor", "agenda", "--tsv", "--details=all", ...root.range.split(" ")];
        fetchProc.running = true;
    }

    function add(text, day) {
        if (root.adding || text.trim() === "")
            return;
        root.addError = "";
        root.adding = true;
        root.queued = Gcal.quickText(text, day);
        const calendar = root.addCalendar || root.ownCalendar;
        if (calendar)
            root.runAdd(calendar);
        else
            listProc.running = true;
    }

    function runAdd(calendar) {
        addProc.command = ["timeout", "60", "gcalcli", "--nocolor", "--calendar", calendar, "quick", root.queued];
        addProc.running = true;
    }

    function failAdd(output, exitCode) {
        root.adding = false;
        root.needsAuth = Gcal.needsAuth(output);
        root.addError = Gcal.shortError(output, exitCode);
        console.warn(`gcal_add_failed exit=${exitCode} message="${root.addError}"`);
    }

    onEnabledChanged: root.refresh()

    Timer {
        interval: root.refreshMinutes * 60000
        repeat: true
        running: root.enabled
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Process {
        id: fetchProc
        property string window
        stdout: StdioCollector {
            id: fetchOut
        }
        stderr: StdioCollector {
            id: fetchErr
        }
        onExited: exitCode => {
            const output = `${fetchOut.text}\n${fetchErr.text}`;
            root.needsAuth = Gcal.needsAuth(output);
            if (exitCode === 0 && !root.needsAuth) {
                root.rows = Gcal.parseAgenda(fetchOut.text);
                root.errorText = "";
                root.fetchedRange = fetchProc.window;
            } else {
                root.errorText = Gcal.shortError(output, exitCode);
                root.fetchedRange = fetchProc.window;
                console.warn(`gcal_fetch_failed exit=${exitCode} message="${root.errorText}"`);
            }
            if (root.pending || fetchProc.window !== root.range) {
                root.pending = false;
                root.refresh();
            }
        }
    }

    // First calendar the account owns, for adding when the option is empty
    Process {
        id: listProc
        command: ["timeout", "60", "gcalcli", "--nocolor", "list"]
        stdout: StdioCollector {
            id: listOut
        }
        stderr: StdioCollector {
            id: listErr
        }
        onExited: exitCode => {
            const own = listOut.text.split("\n").map(l => /^\s*owner\s+(.+?)\s*$/.exec(l)).find(m => m);
            if (own) {
                root.ownCalendar = own[1];
                root.runAdd(root.ownCalendar);
            } else if (exitCode === 0) {
                root.failAdd("Specify calendar", 1);
            } else {
                root.failAdd(`${listOut.text}\n${listErr.text}`, exitCode);
            }
        }
    }

    Process {
        id: addProc
        stdout: StdioCollector {
            id: addOut
        }
        stderr: StdioCollector {
            id: addErr
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.failAdd(`${addOut.text}\n${addErr.text}`, exitCode);
                return;
            }
            root.adding = false;
            root.added();
            root.refresh();
        }
    }
}
