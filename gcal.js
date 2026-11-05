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

function monthOf(day) {
    return new Date(day.getFullYear(), day.getMonth(), 1)
}

function addMonths(view, n) {
    return new Date(view.getFullYear(), view.getMonth() + n, 1)
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

const agendaDetails = ["id", "url", "conference", "calendar"]

/// Rows of `gcalcli agenda --tsv`, null without a header. Title is the only free text, a tab in it stays
function parseAgenda(text) {
    const lines = (text ?? "").split("\n")
    const headAt = lines.findIndex(l => /^(id\t)?start_date\t/.test(l))
    if (headAt < 0)
        return null
    const head = lines[headAt].split("\t")
    const titleAt = head.indexOf("title")
    return lines.slice(headAt + 1).filter(l => l.length > 0).map(line => {
        const f = line.split("\t")
        const extra = f.length - head.length
        if (extra < 0 || titleAt < 0)
            return null
        const get = name => {
            const i = head.indexOf(name)
            const v = i < 0 ? "" : i < titleAt ? f[i] : i > titleAt ? f[i + extra] : f.slice(i, i + extra + 1).join("\t")
            return v.replace(/\\n/g, "\n")
        }
        const allDay = get("start_time") === ""
        const start = at(get("start_date"), get("start_time"))
        const end = at(get("end_date"), get("end_time")) ?? start
        return {
            key: get("id") || `${get("start_date")} ${get("start_time")} ${get("title")}`,
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
    }).filter(ev => ev && ev.start > 0)
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

const enWords = [
    /\b(today|tonight|tomorrow|tmrw|yesterday)\b/,
    /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b/,
    /\b(on|next|this|every)\s+(mon|tues?|wed|thu|thurs?|fri|sat|sun|weekend)\b/,
    /\b(next|this)\s+(week|month|year)\b/,
    /\bin\s+(\d+|a|an|one|two|three)\s+(days?|weeks?|months?)\b/,
    /\bon\s+the\s+\d{1,2}(st|nd|rd|th)\b/,
    /\b\d{4}-\d{1,2}-\d{1,2}\b/,
    /\b(0?[1-9]|1[0-2])\/(0?[1-9]|[12]\d|3[01])(\/\d{2,4})?\b/
]
const enMonth = "(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june?|july?|aug(ust)?|sept?(ember)?|oct(ober)?|nov(ember)?|dec(ember)?)\\.?"
const notTime = "(?![\\d:.]|\\s*(am|pm|a\\.m|p\\.m|h)\\b)"
const enMonthDay = new RegExp(`\\b${enMonth}\\s+(0?[1-9]|[12]\\d|3[01])(st|nd|rd|th)?\\b${notTime}|\\b(0?[1-9]|[12]\\d|3[01])(st|nd|rd|th)?\\s+(of\\s+)?${enMonth}(?![a-z])`)

/// Whether English quick-add text names its own day, the way Google reads it
function namesDay(text) {
    const t = (text ?? "").toLowerCase()
    return enWords.some(re => re.test(t)) || enMonthDay.test(t)
}

function englishDate(day) {
    return `${monthNames[day.getMonth()]} ${day.getDate()} ${day.getFullYear()}`
}

const ruWeekdays = ["воскресенье", "понедельник", "вторник", "среду", "четверг", "пятницу", "субботу"]
const ruMonths = ["январ", "феврал", "март", "апрел", "ма", "июн", "июл", "август", "сентябр", "октябр", "ноябр", "декабр"]
const ruNums = { "один": 1, "одну": 1, "два": 2, "две": 2, "три": 3, "четыре": 4, "пять": 5 }
const ruEdge = "(^|[^а-яёa-z0-9])"
const ruEnd = "(?![а-яёa-z0-9])"
// Google quick-add reads only English, so Russian day phrases become a date
const ruPhrases = [
    [/(сегодня)/, (m, now) => now],
    [/(послезавтра)/, (m, now) => addDays(now, 2)],
    [/(завтра)/, (m, now) => addDays(now, 1)],
    [/через\s+(\d+|один|одну|два|две|три|четыре|пять)?\s*(день|дня|дней|неделю|недели|недель)/, (m, now) => {
        const n = m[1] ? +m[1] || ruNums[m[1]] : 1
        return addDays(now, m[2].startsWith("нед") ? 7 * n : n)
    }],
    [/на\s+следующей\s+неделе/, (m, now) => addDays(now, 7)],
    [/во?\s+(следующ(?:ий|ую|ее)\s+|эт(?:от|у|о)\s+)?(воскресенье|понедельник|вторник|среду|четверг|пятницу|субботу)/, (m, now) => {
        const wd = ruWeekdays.indexOf(m[2])
        if (m[1]?.startsWith("след"))
            return addDays(now, 7 - (now.getDay() + 6) % 7 + (wd + 6) % 7)
        return addDays(now, (wd - now.getDay() + 7) % 7)
    }],
    [/(\d{1,2})\s+(январ[яь]|феврал[яь]|марта?|апрел[яь]|ма[яй]|июн[яь]|июл[яь]|августа?|сентябр[яь]|октябр[яь]|ноябр[яь]|декабр[яь])(?:\s+(\d{4}))?/, (m, now) => {
        const day = new Date(m[3] ? +m[3] : now.getFullYear(), ruMonths.findIndex(p => m[2].startsWith(p)), +m[1])
        return !m[3] && day < new Date(now.getFullYear(), now.getMonth(), now.getDate()) ? new Date(day.getFullYear() + 1, day.getMonth(), day.getDate()) : day
    }],
    [/(\d{1,2})\.(\d{1,2})\.(\d{4})/, m => new Date(+m[3], +m[2] - 1, +m[1])]
].map(([re, resolve]) => [new RegExp(ruEdge + re.source + ruEnd), resolve])

/// Text sent to `gcalcli quick` and the day it lands on, null when Google reads the day from the text
function quickPlan(text, day, now) {
    let t = (text ?? "").trim().replace(/(^|\s)во?\s+(?=\d{1,2}[:.]\d{2}(?!\d))/gi, "$1at ")
    const lower = t.toLowerCase()
    for (const [re, resolve] of ruPhrases) {
        const m = re.exec(lower)
        if (!m)
            continue
        const resolved = resolve([m[0], ...m.slice(2)], now)
        const from = m.index + m[1].length
        const named = new Date(resolved.getFullYear(), resolved.getMonth(), resolved.getDate())
        return { text: `${t.slice(0, from)}${englishDate(named)}${t.slice(m.index + m[0].length)}`, day: named }
    }
    if (namesDay(t) || !day)
        return { text: t, day: null }
    return { text: `${t} ${englishDate(day)}`, day: day }
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

/// Short message for a failed gcalcli run
function shortError(output, exitCode) {
    const out = output ?? ""
    if (exitCode === 124)
        return "gcalcli timed out"
    if (/ServerNotFound|Unable to find the server|NameResolution|Temporary failure in name|Network is unreachable|ConnectionError|ConnectionRefused|TimeoutError|timed out/i.test(out))
        return "Can't reach Google Calendar"
    const http = /HttpError (\d{3})/.exec(out)
    if (http)
        return http[1] >= 500 ? `Google Calendar is down (${http[1]}), try again` : `Google Calendar refused it (${http[1]})`
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
