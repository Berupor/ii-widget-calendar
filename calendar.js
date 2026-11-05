.pragma library

const weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

/// The `provider` option -> its file in providers/
const providers = { "gcalcli": "Gcalcli.qml" }

function providerFile(name) {
    return Object.prototype.hasOwnProperty.call(providers, name) ? providers[name] : ""
}

function sameDay(a, b) {
    return !!a && !!b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

function addDays(day, n) {
    return new Date(day.getFullYear(), day.getMonth(), day.getDate() + n)
}

function pad(n) {
    return n < 10 ? `0${n}` : `${n}`
}

function toIso(day) {
    return `${day.getFullYear()}-${pad(day.getMonth() + 1)}-${pad(day.getDate())}`
}

function fromIso(iso) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso ?? "")
    return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null
}

function monthOf(day) {
    return new Date(day.getFullYear(), day.getMonth(), 1)
}

function addMonths(view, n) {
    return new Date(view.getFullYear(), view.getMonth() + n, 1)
}

/// `weekDays` starting at `weekStart`, 0 is Sunday and 1 Monday as in Date.getDay() and Qt.locale().firstDayOfWeek
function weekHeader(weekStart = 1) {
    const at = (weekStart + 6) % 7
    return weekDays.slice(at).concat(weekDays.slice(0, at))
}

/// First cell of the 6-week grid, the `weekStart` day on or before the 1st
function gridStart(view, weekStart = 1) {
    const first = new Date(view.getFullYear(), view.getMonth(), 1)
    return addDays(first, -(((first.getDay() - weekStart) % 7 + 7) % 7))
}

function monthCells(view, now, weekStart = 1) {
    const start = gridStart(view, weekStart)
    const cells = []
    for (let i = 0; i < 42; i++) {
        const d = addDays(start, i)
        cells.push({ date: d, iso: toIso(d), day: d.getDate(), inMonth: d.getMonth() === view.getMonth(), today: sameDay(d, now) })
    }
    return cells
}

function rowOf(view, day, weekStart = 1) {
    if (!day)
        return -1
    const idx = Math.round((day - gridStart(view, weekStart)) / 86400000)
    return idx < 0 || idx >= 42 ? -1 : Math.floor(idx / 7)
}

/// "start end" iso days of a fetch around a view range, `margin` days further each way
function fetchWindow(range, margin) {
    const [start, end] = range.split(" ").map(fromIso)
    return `${toIso(addDays(start, -margin))} ${toIso(addDays(end, margin))}`
}

/// Whether the "start end" iso range `outer` holds `inner`
function covers(outer, inner) {
    const [outerStart, outerEnd] = outer.split(" ")
    const [innerStart, innerEnd] = inner.split(" ")
    return outerStart <= innerStart && innerEnd <= outerEnd
}

function at(date, time) {
    const d = fromIso(date)
    if (!d)
        return null
    const [h, m] = (time || "00:00").split(":").map(Number)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, m)
}

/// Events keyed by iso day, multi-day ones on every day they touch inside the "start end" iso `window`, all of them without one; all-day first
function byDay(rows, hidden, window) {
    const skip = (hidden ?? "").split(",").map(s => s.trim().toLowerCase()).filter(s => s.length > 0)
    const [from, to] = (window ?? "").split(" ").map(fromIso)
    const days = {}
    for (const ev of rows ?? []) {
        if (skip.includes(ev.calendar.toLowerCase()))
            continue
        let day = new Date(ev.start)
        day = new Date(day.getFullYear(), day.getMonth(), day.getDate())
        if (from && day < from) {
            day = from
            if (day.getTime() >= ev.end)
                continue
        }
        while (!to || day <= to) {
            const iso = toIso(day)
            ;(days[iso] = days[iso] ?? []).push(ev)
            day = addDays(day, 1)
            if (day.getTime() >= ev.end)
                break
        }
    }
    for (const iso in days)
        days[iso].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start) || a.title.localeCompare(b.title))
    return days
}

function dayItems(days, day) {
    return day ? days?.[toIso(day)] ?? [] : []
}

/// An all-day event is past once the shown day ends
function isPast(ev, day, now) {
    const dayEnd = addDays(day, 1).getTime()
    return (ev.allDay ? Math.min(ev.end, dayEnd) : ev.end) <= now.getTime()
}

/// Where today's now line goes: before the first unfinished timed event, -1 for none
function nowIndex(list, day, now) {
    if (!sameDay(day, now) || !list.some(ev => !ev.allDay && isPast(ev, day, now)))
        return -1
    const idx = list.findIndex(ev => !ev.allDay && !isPast(ev, day, now))
    return idx < 0 ? list.length : idx
}

/// "HH:MM" of the first time in quick-add text ("13:00", "1:30pm", "5 pm"), "" when it has none
function quickTime(text) {
    const clock = /(?:^|[^\d:.])(\d{1,2})(?::([0-5]\d))?(?:\s*([ap])\.?m\b\.?)?(?![\d:])/gi
    let m
    while ((m = clock.exec(text ?? "")) !== null) {
        const [, h, min, meridiem] = m
        if (!min && !meridiem)
            continue
        const hour = +h
        if (meridiem ? hour < 1 || hour > 12 : hour > 23)
            continue
        const h24 = meridiem ? hour % 12 + (meridiem.toLowerCase() === "p" ? 12 : 0) : hour
        return `${String(h24).padStart(2, "0")}:${min ?? "00"}`
    }
    return ""
}

