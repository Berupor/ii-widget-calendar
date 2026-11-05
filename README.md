# Google Calendar widget

Google Calendar events in the Calendar tab of the right sidebar, for the
[illogical-impulse extensions fork](https://github.com/Berupor/dots-hyprland-extensions).
The month grid gets a dot under every day with events; click a day and the
month folds to its week with that day's events below, click the month name to
unfold it. The + button adds an event in Google's quick-add syntax.

| Month | Day | Add | Not signed in |
|---|---|---|---|
| ![Month](docs/month.png) | ![Day](docs/day.png) | ![Add](docs/add.png) | ![Not signed in](docs/noauth.png) |

## Setup

Talks to Google through [gcalcli](https://github.com/insanum/gcalcli), which
has to be installed and signed in once from a terminal:

```sh
uv tool install gcalcli
gcalcli init
```

`gcalcli init` asks for an OAuth client of your own, see gcalcli's
[api-auth.md](https://github.com/insanum/gcalcli/blob/HEAD/docs/api-auth.md).
The widget never reads the token, it only runs `gcalcli agenda` and
`gcalcli quick`. Until gcalcli is signed in the tab says so instead of
showing a blank day.

## How it works

- Events of the six weeks on screen are fetched in one `gcalcli agenda --tsv`
  run, again on month change, after adding, and every few minutes while the
  tab is open; opening it refetches if the data is older than that. A failed
  run keeps the last events and turns the header into a retry button, signing
  out clears them.
- All-day events come first, finished ones are dimmed, today has a line at the
  current time. Clicking an event opens it in the browser.
- Scroll changes the month. The arrows and PageUp/PageDown change the month,
  or the week once a day is open.
- Adding passes the text to `gcalcli quick`. Google reads days only in English:
  "friday 5pm", "May 3", "next week" are left to it, text without a day
  ("Lunch with Anna 1pm") gets the picked day appended. Russian day phrases
  ("завтра", "в пятницу", "3 ноября", "через 3 дня", "10.11.2026") are
  replaced with the English date. The dialog shows which day the event lands
  on.

## Options

- Hidden calendars: names as gcalcli lists them, comma-separated.
- Refresh interval in minutes, 10 by default.
- Calendar for new events. Empty means the first calendar you own.

## Files

| File | What it is there for |
|---|---|
| `Manifest.qml` | id, slot, options, the `gcalcli` dependency |
| `GcalView.qml` | the `calendarView` slot: grid, day list, add dialog |
| `MonthGrid.qml`, `DayButton.qml`, `HeaderButton.qml` | the grid and its header |
| `EventList.qml` | a day's events, or what is missing |
| `AddEventLayer.qml` | the + button and the dialog |
| `GcalState.qml` + `qmldir` | the singleton running gcalcli |
| `gcal.js` | parsing, grouping by day, the quick-add date check |
| `demo/` | the scene for the tests and the pictures, on stub events |

## Working on it

```sh
tests/widget-probe.sh gcal calendarView -x ~/Projects/ii-widget-gcal -H sidebar -g 354x350 -p surface=true
tests/qml-cases.sh    -x ~/Projects/ii-widget-gcal
tests/widget-shots.sh -x ~/Projects/ii-widget-gcal
```

`-p selected=2026-11-04` opens a day, `-p status=noauth` or `error` draws
the other states. `git config core.hooksPath .githooks` runs the cases and
redraws the shots on push.

## Install

Settings → Widgets → Install a widget, paste:

```
https://github.com/Berupor/ii-widget-gcal.git
```

Needs shell contract 1.6, which added the `calendarView` slot.

GPL-3.0, same as the shell it plugs into.
