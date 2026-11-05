import Quickshell
import Quickshell.Io
import QtQuick
import "gcalcli.js" as Gcalcli

/** Google Calendar through gcalcli: `agenda --tsv` to read, `quick` to add. */
Scope {
    id: root

    readonly property bool canAdd: true
    property string ownCalendar: ""
    property string addText: ""
    signal fetched(string window, var rows, var failure)
    signal added
    signal addFailed(var failure)

    function fetch(window) {
        fetchProc.window = window;
        fetchProc.command = ["timeout", "60", "gcalcli", "--nocolor", "agenda", "--tsv", ...[].concat(...Gcalcli.agendaDetails.map(d => ["--details", d])), ...window.split(" ")];
        fetchProc.running = true;
    }

    function plan(text, day, now) {
        return Gcalcli.quickPlan(text, day, now);
    }

    function add(text, day, calendar) {
        root.addText = Gcalcli.quickPlan(text, day, new Date()).text;
        const target = calendar || root.ownCalendar;
        if (target)
            root.runAdd(target);
        else
            listProc.running = true;
    }

    function runAdd(calendar) {
        addProc.command = ["timeout", "60", "gcalcli", "--nocolor", "--calendar", calendar, "quick", "--", root.addText];
        addProc.running = true;
    }

    function failAdd(output, exitCode) {
        root.addFailed(Object.assign(Gcalcli.failure(output, exitCode), { exitCode: exitCode }));
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
            let failure = Gcalcli.failure(output, exitCode);
            const rows = exitCode === 0 && !failure.setup ? Gcalcli.parseAgenda(fetchOut.text) : null;
            if (exitCode === 0 && !failure.setup && !rows)
                failure = { setup: false, text: "Unexpected gcalcli output" };
            root.fetched(fetchProc.window, rows, rows ? null : Object.assign(failure, { exitCode: exitCode }));
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
            if (exitCode === 0)
                root.added();
            else
                root.failAdd(`${addOut.text}\n${addErr.text}`, exitCode);
        }
    }
}
