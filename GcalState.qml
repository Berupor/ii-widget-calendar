pragma Singleton

import qs.modules.widgets
import Quickshell
import Quickshell.Io
import QtQuick
import "gcal.js" as Gcal

/** gcalcli behind the view: one fetch in flight, polling only while a view is open. */
Singleton {
    id: root

    readonly property bool enabled: WidgetCatalog.isEnabled("gcal")
    readonly property int refreshMinutes: Math.max(1, WidgetCatalog.option("gcal", "refreshMinutes") || 1)
    readonly property string hiddenCalendars: WidgetCatalog.option("gcal", "hiddenCalendars") ?? ""
    readonly property string addCalendar: (WidgetCatalog.option("gcal", "addCalendar") ?? "").trim()

    property int viewers: 0
    readonly property bool active: root.enabled && root.viewers > 0

    property var now: new Date()
    property var rows: []
    readonly property var days: Gcal.byDay(root.rows, root.hiddenCalendars)

    /// "start end" of the window the view shows, iso days
    property string range: ""
    property string fetchedRange: ""
    property real fetchedAt: 0
    property bool pending: false
    property bool needsAuth: false
    property string errorText: ""
    // A failed run keeps the last rows, a retry reads as loading
    readonly property string status: (root.fetchedRange !== root.range || fetchProc.running && (root.needsAuth || root.errorText !== "")) ? "loading"
        : root.needsAuth ? "noauth" : root.errorText !== "" ? "error" : "ready"

    property bool adding: false
    property string addError: ""
    property string ownCalendar: ""
    property string addText: ""
    signal added

    function want(start, end) {
        const next = `${Gcal.toIso(start)} ${Gcal.toIso(end)}`;
        if (next === root.range)
            return;
        root.range = next;
        root.refresh();
    }

    function refresh() {
        if (!root.active || root.range === "")
            return;
        if (fetchProc.running) {
            root.pending = true;
            return;
        }
        fetchProc.window = root.range;
        fetchProc.command = ["timeout", "60", "gcalcli", "--nocolor", "agenda", "--tsv", ...[].concat(...Gcal.agendaDetails.map(d => ["--details", d])), ...root.range.split(" ")];
        fetchProc.running = true;
    }

    function add(text, day) {
        if (root.adding || text.trim() === "")
            return;
        root.addError = "";
        root.adding = true;
        root.addText = Gcal.quickPlan(text, day, new Date()).text;
        const calendar = root.addCalendar || root.ownCalendar;
        if (calendar)
            root.runAdd(calendar);
        else
            listProc.running = true;
    }

    function runAdd(calendar) {
        addProc.command = ["timeout", "60", "gcalcli", "--nocolor", "--calendar", calendar, "quick", "--", root.addText];
        addProc.running = true;
    }

    function failAdd(output, exitCode) {
        root.adding = false;
        root.needsAuth = Gcal.needsAuth(output);
        root.addError = Gcal.shortError(output, exitCode);
        console.error(`gcal_add_failed exit=${exitCode} message="${root.addError}"`);
    }

    function fail(message, exitCode) {
        root.errorText = message;
        console.error(`gcal_fetch_failed exit=${exitCode} message="${message}"`);
    }

    onActiveChanged: {
        if (root.active && (root.fetchedRange !== root.range || Date.now() - root.fetchedAt > root.refreshMinutes * 60000))
            root.refresh();
    }

    Timer {
        interval: root.refreshMinutes * 60000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.active
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
            const rows = exitCode === 0 ? Gcal.parseAgenda(fetchOut.text) : null;
            root.needsAuth = Gcal.needsAuth(output);
            if (root.needsAuth) {
                root.rows = [];
                root.errorText = "";
            } else if (rows) {
                root.rows = rows;
                root.errorText = "";
                root.fetchedAt = Date.now();
            } else {
                root.fail(exitCode === 0 ? "Unexpected gcalcli output" : Gcal.shortError(output, exitCode), exitCode);
            }
            root.fetchedRange = fetchProc.window;
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
