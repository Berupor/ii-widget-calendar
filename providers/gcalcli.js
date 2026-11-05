.pragma library
.import "../calendar.js" as Cal

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
        const title = get("title").replace(/\n+/g, " ")
        const allDay = get("start_time") === ""
        const start = Cal.at(get("start_date"), get("start_time"))
        const end = Cal.at(get("end_date"), get("end_time")) ?? start
        return {
            key: get("id") ? `${get("calendar")}/${get("id")}` : `${get("start_date")} ${get("start_time")} ${title}`,
            title: title,
            calendar: get("calendar"),
            link: get("html_link"),
            call: get("hangout_link") !== "" ? "Google Meet" : get("conference_uri") !== "" ? "Video call" : "",
            allDay: allDay,
            startText: get("start_time"),
            endText: get("end_time"),
            start: start ? start.getTime() : 0,
            end: end ? end.getTime() : 0
        }
    }).filter(ev => ev && ev.start > 0)
}

/// Rows or failure of a finished `agenda` run; a run that exited 0 with a header is a success whatever the titles say
function agendaResult(stdout, stderr, exitCode) {
    const rows = exitCode === 0 ? parseAgenda(stdout) : null
    if (rows)
        return { rows: rows, failure: null }
    const found = failure(`${stdout}\n${stderr}`, exitCode)
    const shown = exitCode === 0 && !found.setup ? { setup: false, text: "Unexpected gcalcli output" } : found
    return { rows: null, failure: Object.assign(shown, { exitCode: exitCode }) }
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

/// Google answers 503 to a 24h time followed straight by a date ("19:00 December 20 2026"), "on" avoids it
function onEnglishDate(day) {
    return `on ${Cal.monthNames[day.getMonth()]} ${day.getDate()} ${day.getFullYear()}`
}

const ruWeekdays = ["воскресенье", "понедельник", "вторник", "среду", "четверг", "пятницу", "субботу"]
const ruMonths = ["январ", "феврал", "март", "апрел", "ма", "июн", "июл", "август", "сентябр", "октябр", "ноябр", "декабр"]
const ruNums = { "один": 1, "одну": 1, "два": 2, "две": 2, "три": 3, "четыре": 4, "пять": 5 }
const ruEdge = "(^|[^а-яёa-z0-9])"
const ruEnd = "(?![а-яёa-z0-9])"
/// The date, null when the day does not exist in that month ("31 февраля" must not roll over)
function realDate(year, month, date) {
    const d = new Date(year, month, date)
    return d.getMonth() === month && d.getDate() === date ? d : null
}

// Google quick-add reads only English, so Russian day phrases become a date
const ruPhrases = [
    [/(сегодня)/, (m, now) => now],
    [/(послезавтра)/, (m, now) => Cal.addDays(now, 2)],
    [/(завтра)/, (m, now) => Cal.addDays(now, 1)],
    [/через\s+(\d+|один|одну|два|две|три|четыре|пять)?\s*(день|дня|дней|неделю|недели|недель)/, (m, now) => {
        const n = m[1] ? /^\d+$/.test(m[1]) ? +m[1] : ruNums[m[1]] : 1
        return Cal.addDays(now, m[2].startsWith("нед") ? 7 * n : n)
    }],
    [/на\s+следующей\s+неделе/, (m, now) => Cal.addDays(now, 7)],
    [/во?\s+(следующ(?:ий|ую|ее)\s+|эт(?:от|у|о)\s+)?(воскресенье|понедельник|вторник|среду|четверг|пятницу|субботу)/, (m, now) => {
        const wd = ruWeekdays.indexOf(m[2])
        if (m[1]?.startsWith("след"))
            return Cal.addDays(now, 7 - (now.getDay() + 6) % 7 + (wd + 6) % 7)
        return Cal.addDays(now, (wd - now.getDay() + 7) % 7)
    }],
    [/(\d{1,2})\s+(январ[яь]|феврал[яь]|марта?|апрел[яь]|ма[яй]|июн[яь]|июл[яь]|августа?|сентябр[яь]|октябр[яь]|ноябр[яь]|декабр[яь])(?:\s+(\d{4}))?/, (m, now) => {
        const month = ruMonths.findIndex(p => m[2].startsWith(p))
        const day = realDate(m[3] ? +m[3] : now.getFullYear(), month, +m[1])
        return day && !m[3] && day < new Date(now.getFullYear(), now.getMonth(), now.getDate()) ? realDate(day.getFullYear() + 1, month, +m[1]) : day
    }],
    [/(\d{1,2})\.(\d{1,2})\.(\d{4})/, m => realDate(+m[3], +m[2] - 1, +m[1])]
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
        if (!resolved)
            continue
        const from = m.index + m[1].length
        const named = new Date(resolved.getFullYear(), resolved.getMonth(), resolved.getDate())
        return { text: `${t.slice(0, from)}${onEnglishDate(named)}${t.slice(m.index + m[0].length)}`, day: named }
    }
    if (namesDay(t) || !day)
        return { text: t, day: null }
    return { text: `${t} ${onEnglishDate(day)}`, day: day }
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

/// `setup` when gcalcli is missing or not signed in: events are cleared, the hint says what to run
function failure(output, exitCode) {
    if (exitCode === 127)
        return { setup: true, text: "Install gcalcli" }
    if (/Not yet authenticated|invalid_grant|RefreshError/.test(output ?? ""))
        return { setup: true, text: "Run gcalcli init in a terminal" }
    return { setup: false, text: shortError(output, exitCode) }
}
