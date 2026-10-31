.pragma library

const weekDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

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

function viewDate(shift, now) {
    return new Date(now.getFullYear(), now.getMonth() + shift, 1)
}

function monthShiftOf(day, now) {
    return (day.getFullYear() - now.getFullYear()) * 12 + day.getMonth() - now.getMonth()
}

/// First cell of the 6-week grid, a Monday
function gridStart(view) {
    const first = new Date(view.getFullYear(), view.getMonth(), 1)
    return addDays(first, -((first.getDay() + 6) % 7))
}

function monthCells(view, now) {
    const start = gridStart(view)
    const cells = []
    for (let i = 0; i < 42; i++) {
        const d = addDays(start, i)
        cells.push({ date: d, iso: toIso(d), day: d.getDate(), inMonth: d.getMonth() === view.getMonth(), today: sameDay(d, now) })
    }
    return cells
}

function rowOf(view, day) {
    if (!day)
        return -1
    const idx = Math.round((day - gridStart(view)) / 86400000)
    return idx < 0 || idx >= 42 ? -1 : Math.floor(idx / 7)
}

function at(date, time) {
    const d = fromIso(date)
    if (!d)
        return null
    const [h, m] = (time || "00:00").split(":").map(Number)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, m)
}

/// Rows of `gcalcli agenda --tsv --details=all`, columns by header name
function parseAgenda(text) {
    const lines = (text ?? "").split("\n").filter(l => l.length > 0)
    const head = (lines.shift() ?? "").split("\t")
    const col = name => head.indexOf(name)
    if (col("start_date") < 0)
        return []
    return lines.map(line => {
        const f = line.split("\t")
        const get = name => (col(name) >= 0 ? f[col(name)] ?? "" : "").replace(/\\n/g, "\n")
        const allDay = get("start_time") === ""
        const start = at(get("start_date"), get("start_time"))
        const end = at(get("end_date"), get("end_time")) ?? start
        return {
            id: get("id"),
            title: get("title"),
            calendar: get("calendar"),
            link: get("html_link"),
            meet: get("hangout_link") !== "",
            call: get("conference_uri") !== "",
            allDay: allDay,
            startText: get("start_time"),
            endText: get("end_time"),
            start: start ? start.getTime() : 0,
            end: end ? end.getTime() : 0
        }
    }).filter(ev => ev.start > 0)
}

/// Events keyed by iso day, multi-day ones on every day they touch; all-day first
function byDay(rows, hidden) {
    const skip = (hidden ?? "").split(",").map(s => s.trim().toLowerCase()).filter(s => s.length > 0)
    const days = {}
    for (const ev of rows ?? []) {
        if (skip.includes(ev.calendar.toLowerCase()))
            continue
        let day = new Date(ev.start)
        day = new Date(day.getFullYear(), day.getMonth(), day.getDate())
        do {
            const iso = toIso(day)
            ;(days[iso] = days[iso] ?? []).push(ev)
            day = addDays(day, 1)
        } while (day.getTime() < ev.end)
    }
    for (const iso in days)
        days[iso].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start) || a.title.localeCompare(b.title))
    return days
}

/// A day's list with `past` flags and a now line after the last finished event
function dayItems(days, day, now) {
    if (!day)
        return []
    const dayEnd = addDays(day, 1).getTime()
    const list = (days?.[toIso(day)] ?? []).map(ev => Object.assign({}, ev, { past: (ev.allDay ? Math.min(ev.end, dayEnd) : ev.end) <= now.getTime() }))
    if (!sameDay(day, now) || !list.some(ev => !ev.allDay && ev.past))
        return list
    const idx = list.findIndex(ev => !ev.allDay && !ev.past)
    const line = { nowLine: true }
    return idx < 0 ? [...list, line] : [...list.slice(0, idx), line, ...list.slice(idx)]
}

const dayWordsEn = /\b(today|tonight|tomorrow|tmrw|yesterday|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun|january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\b/
const dayWordsRu = /(^|[^а-я])(сегодня|завтра|послезавтра|понедельник\S*|вторник\S*|сред[аеуы]|четверг\S*|пятниц[аеуы]|суббот[аеуы]|воскресень[еяю]|январ[ьяе]|феврал[ьяе]|март[ае]?|апрел[ьяе]|ма[йяе]|июн[ьяе]|июл[ьяе]|август[ае]?|сентябр[ьяе]|октябр[ьяе]|ноябр[ьяе]|декабр[ьяе]|пн|вт|ср|чт|пт|сб|вс)(?![а-я])/
const datePatterns = /\b(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}(st|nd|rd|th))\b/
const dayMonth = /\b(\d{1,2})([./])(\d{1,2})([./]\d{2,4})?\b/g

/// Whether quick-add text names its own day. 13.00 and 12.30 are times, 10.11 a date
function namesDay(text) {
    const t = (text ?? "").toLowerCase()
    if (dayWordsEn.test(t) || dayWordsRu.test(t) || datePatterns.test(t))
        return true
    dayMonth.lastIndex = 0
    let m
    while ((m = dayMonth.exec(t)) !== null) {
        const [a, b] = [+m[1], +m[3]]
        if (a >= 1 && b >= 1 && ((a <= 31 && b <= 12) || (m[2] === "/" && a <= 12 && b <= 31)))
            return true
    }
    return false
}

/// Quick-add text, with the selected day appended unless it names one
function quickText(text, day) {
    const t = (text ?? "").trim()
    if (namesDay(t) || !day)
        return t
    return `${t} ${monthNames[day.getMonth()]} ${day.getDate()} ${day.getFullYear()}`
}

/// Short message for a failed gcalcli run
function shortError(output, exitCode) {
    const out = output ?? ""
    if (exitCode === 124)
        return "gcalcli timed out"
    if (/ServerNotFound|Unable to find the server|NameResolution|Temporary failure in name|Network is unreachable|ConnectionError|ConnectionRefused|TimeoutError|timed out/i.test(out))
        return "Can't reach Google Calendar"
    if (/Specify calendar/.test(out))
        return "Set a calendar for new events in the widget options"
    if (/No available calendar|Invalid selection/.test(out))
        return "No calendar by that name"
    const last = out.trim().split("\n").filter(l => l.trim() !== "").pop() ?? ""
    return last ? last.trim().slice(0, 70) : `gcalcli failed (${exitCode})`
}

function needsAuth(output) {
    return /Not yet authenticated|invalid_grant|RefreshError/.test(output ?? "")
}
