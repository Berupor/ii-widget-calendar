pragma Singleton

import qs.modules.widgets
import Quickshell
import QtQuick
import "calendar.js" as Cal

/** Events of the provider picked in options: one fetch in flight, polling only while a view is open. */
Singleton {
    id: root

    readonly property bool enabled: WidgetCatalog.isEnabled("calendar")
    readonly property string providerName: (WidgetCatalog.option("calendar", "provider") ?? "").trim()
    readonly property int refreshMinutes: Math.max(1, WidgetCatalog.option("calendar", "refreshMinutes") || 1)
    readonly property string hiddenCalendars: WidgetCatalog.option("calendar", "hiddenCalendars") ?? ""
    readonly property string addCalendar: (WidgetCatalog.option("calendar", "addCalendar") ?? "").trim()

    property var provider: null
    readonly property bool canAdd: root.provider?.canAdd ?? false

    property int viewers: 0
    readonly property bool active: root.enabled && root.viewers > 0 && root.provider !== null

    property var now: new Date()
    property var rows: []
    readonly property var days: Cal.byDay(root.rows, root.hiddenCalendars, root.fetchedWindow)

    /// "start end" of the window the view shows, iso days
    property string range: ""
    readonly property int fetchMarginDays: 60
    property string fetchingWindow: ""
    property string fetchedWindow: ""
    property real fetchedAt: 0
    property bool pending: false
    property bool needsSetup: false
    property string failureText: ""
    readonly property string errorText: root.provider ? root.failureText : `Unknown calendar provider "${root.providerName}"`
    readonly property bool covered: Cal.covers(root.fetchedWindow, root.range)
    // A failed run keeps the last rows and the window they cover, a retry reads as loading
    readonly property string status: !root.provider ? "setup"
        : root.fetchingWindow !== "" && (!root.covered || root.needsSetup || root.failureText !== "") ? "loading"
        : root.needsSetup ? "setup" : root.failureText !== "" ? "error" : !root.covered ? "loading" : "ready"

    property bool adding: false
    property string addError: ""
    signal added

    function want(start, end) {
        const next = `${Cal.toIso(start)} ${Cal.toIso(end)}`;
        if (next === root.range)
            return;
        root.range = next;
        if (!root.isFresh() && !(root.fetchingWindow !== "" && Cal.covers(root.fetchingWindow, next)))
            root.refresh();
    }

    function isFresh() {
        return root.covered && Date.now() - root.fetchedAt < root.refreshMinutes * 60000;
    }

    function refresh() {
        if (!root.active || root.range === "")
            return;
        if (root.fetchingWindow !== "") {
            root.pending = true;
            return;
        }
        root.fetchingWindow = Cal.fetchWindow(root.range, root.fetchMarginDays);
        root.provider.fetch(root.fetchingWindow);
    }

    function plan(text, day, now) {
        return root.provider?.plan(text, day, now) ?? { text: text, day: day };
    }

    function add(text, day) {
        if (root.adding || !root.canAdd || text.trim() === "")
            return;
        root.addError = "";
        root.adding = true;
        root.provider.add(text, day, root.now, root.addCalendar);
    }

    onActiveChanged: {
        if (root.active && !root.isFresh())
            root.refresh();
    }
    onProviderNameChanged: {
        root.provider?.destroy();
        const file = Cal.providerFile(root.providerName);
        root.provider = file ? Qt.createComponent(`providers/${file}`).createObject(root) : null;
    }
    Component.onCompleted: providerNameChanged()
    onProviderChanged: {
        root.rows = [];
        root.fetchedWindow = "";
        root.fetchingWindow = "";
        root.pending = false;
        root.needsSetup = false;
        root.failureText = "";
        root.adding = false;
        root.addError = "";
        root.refresh();
    }

    Connections {
        target: root.provider
        function onFetched(window, rows, failure) {
            root.fetchingWindow = "";
            root.needsSetup = failure?.setup ?? false;
            root.failureText = failure?.text ?? "";
            if (rows || root.needsSetup)
                root.fetchedWindow = window;
            if (rows) {
                root.rows = rows;
                root.fetchedAt = Date.now();
            } else if (root.needsSetup) {
                root.rows = [];
            } else {
                console.error(`calendar_fetch_failed provider=${root.providerName} exit=${failure.exitCode} message="${failure.text}"`);
            }
            if (root.pending || !Cal.covers(window, root.range)) {
                root.pending = false;
                root.refresh();
            }
        }
        function onAdded() {
            root.adding = false;
            root.added();
            root.refresh();
        }
        function onAddFailed(failure) {
            root.adding = false;
            root.needsSetup = failure.setup;
            if (failure.setup)
                root.failureText = failure.text;
            root.addError = failure.text;
            console.error(`calendar_add_failed provider=${root.providerName} exit=${failure.exitCode} message="${failure.text}"`);
        }
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
}
