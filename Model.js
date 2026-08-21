// Pure date and format math for the clock widget and its calendar panel.
// Everything here is locale- and Qt-free so it can be unit tested under node
// (test/shell.d/clock-test.sh); the QML owns month/weekday naming through
// Qt.locale().

var MS_PER_DAY = 86400000

// Weekday indices match both JS Date.getDay() and QML's Locale.Sunday…
// Locale.Saturday, so a locale's firstDayOfWeek can be passed straight in.
var WEEKDAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

// ---- Bar label formats. Right-clicking the clock walks these in order and
//      writes the result back to shell.json, so the label the bar shows and
//      the format the config stores are always the same thing.
//
// The locale-shaped time presets are each followed by their 12-hour twin, so
// the walk from a 24-hour label to the same label in AM/PM is a single right
// click rather than a lap of the ring. The ISO preset is deliberately left
// without one: ISO 8601 writes time on a 24-hour clock, so an AM/PM variant
// would contradict the only thing that format is for.
var CLOCK_FORMATS = [
  "dddd HH:mm",
  "dddd h:mm AP",
  "dddd HH:mm:ss",
  "dddd h:mm:ss AP",
  "HH:mm",
  "h:mm AP",
  "ddd d MMM HH:mm",
  "ddd d MMM h:mm AP",
  "d MMMM 'W'ww yyyy",
  "yyyy-MM-dd HH:mm"
]

// Vertical bars have room for a few stacked lines and nothing else, so the
// ring stays short. AM/PM costs a fourth line, which is why only the plain
// time carries it here.
var VERTICAL_CLOCK_FORMATS = [
  "HH\n—\nmm",
  "h\n—\nmm\nAP",
  "dd\nMMM\n'W'ww\n''yy",
  "HH\nmm"
]

// Whether a format prints seconds, so the widget can tick once a second only
// for the formats that show them. Quoted literals go first: the s in a 'Sat'
// is text rather than a token, and an opening quote with no closing one runs
// to the end of the format the way Qt reads it.
function clockNeedsSeconds(format) {
  var text = String(format === undefined || format === null ? "" : format)
  return /s/.test(text.replace(/'[^']*'?/g, ""))
}

function clockFormats(vertical) {
  return vertical ? VERTICAL_CLOCK_FORMATS.slice() : CLOCK_FORMATS.slice()
}

// The presets in a fixed order, plus the configured alternate and current
// format when they are something else. The order must not depend on which
// entry is current: cycling writes the result back to shell.json, and a ring
// that reshuffled itself around the current value would bounce between two
// entries instead of walking.
function clockFormatRing(configured, configuredAlt, presets) {
  var ring = []
  var candidates = (presets || []).concat([configuredAlt, configured])
  for (var i = 0; i < candidates.length; i++) {
    var format = String(candidates[i] === undefined || candidates[i] === null ? "" : candidates[i])
    if (format === "" || ring.indexOf(format) !== -1) continue
    ring.push(format)
  }
  return ring.length > 0 ? ring : ["HH:mm"]
}

// Next entry after `current`. An unknown current format (a hand-written one
// that is not in the ring) starts the walk at the top.
function nextClockFormat(ring, current) {
  if (!ring || ring.length === 0) return ""
  var index = ring.indexOf(String(current === undefined || current === null ? "" : current))
  return ring[(index + 1) % ring.length]
}

// Two-digit ISO week, substituted into a format's 'ww' token before Qt
// formats it -- Qt has no ISO week specifier of its own.
function isoWeekLiteral(year, month, day) {
  return pad2(isoWeek(year, month, day))
}

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

// Stable "yyyy-MM-dd" identity for a day, so a grid cell can be compared
// against today without dragging Date objects through bindings.
function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate())
}

// Key for an ISO "YYYY-MM-DD" string, so event records from fetch_events.py
// can be bucketed without reconstructing Date objects.
function keyForIso(iso) {
  var text = String(iso || "")
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
  if (!m) return text
  return dateKey(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10))
}

// Every ISO date between two inclusive ISO dates, used to mark multi-day
// events across the grid.
function dayRange(startIso, endIso) {
  var out = []
  var start = new Date(Date.UTC(
    parseInt(startIso.slice(0, 4), 10),
    parseInt(startIso.slice(5, 7), 10) - 1,
    parseInt(startIso.slice(8, 10), 10)
  ))
  var end = new Date(Date.UTC(
    parseInt(endIso.slice(0, 4), 10),
    parseInt(endIso.slice(5, 7), 10) - 1,
    parseInt(endIso.slice(8, 10), 10)
  ))
  if (isNaN(start.getTime()) || isNaN(end.getTime()) || end < start) return [startIso]
  while (start <= end) {
    out.push(dateKey(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()))
    start.setUTCDate(start.getUTCDate() + 1)
  }
  return out
}

function coerceWeekStart(value) {
  if (value === undefined || value === null) return null
  if (typeof value === "number")
    return isFinite(value) ? ((Math.round(value) % 7) + 7) % 7 : null

  var text = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
  if (text === "") return null

  for (var i = 0; i < WEEKDAY_NAMES.length; i++)
    if (WEEKDAY_NAMES[i] === text || WEEKDAY_NAMES[i].substr(0, 3) === text) return i

  var parsed = parseInt(text, 10)
  return isFinite(parsed) ? ((parsed % 7) + 7) % 7 : null
}

// Configured week start, falling back to the locale's own first day when
// the setting is missing or nonsense.
function normalizedWeekStart(value, fallback) {
  var configured = coerceWeekStart(value)
  if (configured !== null) return configured
  var fallbackStart = coerceWeekStart(fallback)
  return fallbackStart === null ? 1 : fallbackStart
}

function weekStartSettingName(index) {
  return WEEKDAY_NAMES[normalizedWeekStart(index, 1)]
}

// The toggle flips between the two conventions people actually switch
// between. A calendar configured to any other start (Saturday, say) is
// shown as-is and lands on Monday the first time it is toggled.
function toggledWeekStart(index) {
  return normalizedWeekStart(index, 1) === 1 ? 0 : 1
}

function weekdayOrder(weekStart) {
  var start = normalizedWeekStart(weekStart, 1)
  var out = []
  for (var i = 0; i < 7; i++) out.push((start + i) % 7)
  return out
}

// ISO-8601 week number: the week owning the Thursday of that date's
// Monday-based week. Mirrors the clock widget's 'ww' format token.
function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
}

function dayOfYear(year, month, day) {
  return Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / MS_PER_DAY) + 1
}

function daysInYear(year) {
  return dayOfYear(year, 11, 31)
}

// Share of the year already behind you: whole days completed over days in
// the year, so January 1 reads 0% and December 31 reads 100%.
function yearProgress(year, month, day) {
  var total = daysInYear(year)
  if (total <= 0) return 0
  return Math.max(0, Math.min(1, (dayOfYear(year, month, day) - 1) / total))
}

function yearProgressPercent(year, month, day) {
  return Math.round(yearProgress(year, month, day) * 100)
}

// Memento mori. The default span is a round number rather than anything from
// an actuarial table: the point of the bar is the reminder, not the
// arithmetic, and whoever wants a different number can say so.
var DEFAULT_LIFE_EXPECTANCY = 90

// A birth year rather than an age, so the bar keeps counting on its own
// instead of going stale the moment it is entered. 0 means "not set", which
// is also what a blank, malformed, future, or implausibly distant year means.
function parseBirthYear(value, currentYear) {
  var now = Math.round(Number(currentYear))
  if (!isFinite(now)) return 0
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d{4}$/.test(text)) return 0
  var year = parseInt(text, 10)
  if (!isFinite(year) || year > now || year < now - 120) return 0
  return year
}

// Whole years, the way people say their age: born in 1979 makes you 47 for
// all of 2026, whichever side of your birthday today falls.
function ageFromBirthYear(birthYear, currentYear) {
  var born = parseBirthYear(birthYear, currentYear)
  if (born <= 0) return 0
  return Math.round(Number(currentYear)) - born
}

// 0 means "not set", which is also what a blank, negative, fractional, or
// absurd entry means — the life bar simply stays hidden.
function parseAge(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d+$/.test(text)) return 0
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 120) return 0
  return years
}

// Unset or nonsense falls back to the default rather than to zero, so the
// bar always has something to measure against.
function parseLifeExpectancy(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d+$/.test(text)) return DEFAULT_LIFE_EXPECTANCY
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 150) return DEFAULT_LIFE_EXPECTANCY
  return years
}

function lifeProgress(age, expectancy) {
  var years = parseAge(age)
  var span = parseLifeExpectancy(expectancy)
  if (years <= 0 || span <= 0) return 0
  return Math.max(0, Math.min(1, years / span))
}

function lifeProgressPercent(age, expectancy) {
  return Math.round(lifeProgress(age, expectancy) * 100)
}

// Always six rows of seven days. A fixed grid keeps the popup exactly the
// same height in every month, so stepping through the year never makes the
// panel jump under the pointer.
function monthGrid(year, month, weekStart, todayKey) {
  var start = normalizedWeekStart(weekStart, 1)
  var leading = (new Date(year, month, 1).getDay() - start + 7) % 7
  var cursor = new Date(year, month, 1 - leading)
  var today = String(todayKey || "")
  var weeks = []

  for (var w = 0; w < 6; w++) {
    var days = []
    var thursday = null
    for (var d = 0; d < 7; d++) {
      var cellYear = cursor.getFullYear()
      var cellMonth = cursor.getMonth()
      var cellDay = cursor.getDate()
      var weekday = cursor.getDay()
      var key = dateKey(cellYear, cellMonth, cellDay)
      if (weekday === 4) thursday = { year: cellYear, month: cellMonth, day: cellDay }
      days.push({
        key: key,
        year: cellYear,
        month: cellMonth,
        day: cellDay,
        weekday: weekday,
        inMonth: cellMonth === month && cellYear === year,
        weekend: weekday === 0 || weekday === 6,
        today: key === today
      })
      cursor.setDate(cursor.getDate() + 1)
    }
    // Number every row by the ISO week owning its Thursday. That is the
    // definition itself for Monday-start weeks, and the only answer that
    // stays stable for the other starts, where a row straddles two ISO
    // weeks but shares all of Monday through Thursday with one of them.
    var anchor = thursday || days[0]
    weeks.push({
      week: isoWeek(anchor.year, anchor.month, anchor.day),
      days: days
    })
  }
  return weeks
}

function stepMonth(year, month, delta) {
  var target = new Date(year, Number(month) + Number(delta), 1)
  return { year: target.getFullYear(), month: target.getMonth() }
}

// ---- Calendar state model (provider-independent). These functions read the
//      normalized v1 state document produced by sync/sync.py (see
//      docs/ARCHITECTURE.md) and answer the questions the QML asks. They never
//      touch gws, Google, or the filesystem — pure functions only, so they are
//      unit-testable under node.

// Index the state's events into { dateKey: [event, ...] }, expanding all-day
// and multi-day events across every day they span. dateKey is already local.
function eventIndex(events) {
  var index = {}
  var list = events || []
  for (var i = 0; i < list.length; i++) {
    var ev = list[i]
    var days = dayRange(ev.dateKey, ev.allDay ? ev.end : ev.dateKey)
    for (var d = 0; d < days.length; d++) {
      var key = days[d]
      if (!index[key]) index[key] = []
      index[key].push(ev)
    }
  }
  return index
}

// Events on a given day, sorted by start time (all-day first).
function eventsForDate(index, dateKey) {
  var list = (index && index[dateKey]) || []
  return list.slice().sort(compareEvents)
}

function compareEvents(a, b) {
  var da = (a.dateKey || "").localeCompare(b.dateKey || "")
  if (da !== 0) return da
  if (a.allDay && !b.allDay) return -1
  if (!a.allDay && b.allDay) return 1
  return (a.start || "").localeCompare(b.start || "")
}

// Task's due date (already normalized to YYYY-MM-DD by the sync engine), or
// "" when the task has no due date.
function taskDueDate(task) {
  var due = (task && task.due) || ""
  if (typeof due !== "string") return ""
  var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(due)
  return m ? due.slice(0, 10) : ""
}

// Incomplete tasks due on a given day.
function tasksForDate(tasks, dateKey) {
  var out = []
  var list = tasks || []
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (t.status === "completed") continue
    if (taskDueDate(t) === dateKey) out.push(t)
  }
  return out
}

// Count of incomplete tasks matching `mode`, relative to todayKey.
//   "dueToday" — due exactly today (default)
//   "overdue"  — due today or earlier
//   "all"      — every incomplete task, regardless of due date
function badgeCount(tasks, mode, todayKey) {
  var m = mode || "dueToday"
  var count = 0
  var list = tasks || []
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (t.status === "completed") continue
    var due = taskDueDate(t)
    if (m === "all") {
      count++
    } else if (m === "overdue") {
      if (due !== "" && due <= todayKey) count++
    } else { // dueToday
      if (due === todayKey) count++
    }
  }
  return count
}

// The next event whose start is at or after `now`, or null. `now` may be an
// ISO string or a Date. All-day events are considered to start at 00:00.
function nextEvent(events, now) {
  var ref = typeof now === "string" ? Date.parse(now) : now.getTime()
  if (isNaN(ref)) return null
  var list = events || []
  var best = null
  for (var i = 0; i < list.length; i++) {
    var ev = list[i]
    var t = eventStartTime(ev)
    if (isNaN(t)) continue
    if (t < ref) continue
    if (best === null || t < eventStartTime(best)) best = ev
  }
  return best
}

function eventStartTime(ev) {
  if (!ev) return NaN
  if (ev.allDay && ev.dateKey) return Date.parse(ev.dateKey + "T00:00:00")
  if (ev.start) return Date.parse(ev.start)
  return NaN
}

// Human countdown like "in 18m" / "in 2h" / "in 3d", or "" when negative/absent.
function countdown(event, now) {
  if (!event) return ""
  var ref = typeof now === "string" ? Date.parse(now) : now.getTime()
  var start = eventStartTime(event)
  if (isNaN(ref) || isNaN(start)) return ""
  var ms = start - ref
  if (ms <= 0) return ""
  var minutes = Math.round(ms / 60000)
  if (minutes < 1) return "now"
  if (minutes < 60) return "in " + minutes + "m"
  var hours = Math.round(minutes / 60)
  if (hours < 24) return "in " + hours + "h"
  var days = Math.round(hours / 24)
  return "in " + days + "d"
}

// Stale if the last successful sync is older than `thresholdMin` minutes.
function isStale(syncStatus, now, thresholdMin) {
  if (!syncStatus || syncStatus.state === "never") return true
  var last = syncStatus.lastOk
  if (!last) return syncStatus.state !== "ok"
  var ref = typeof now === "string" ? Date.parse(now) : now.getTime()
  var t = Date.parse(last)
  if (isNaN(ref) || isNaN(t)) return true
  return (ref - t) / 60000 > thresholdMin
}

// Parse the raw text of state.json into a safe state object. Never throws;
// missing/garbage input yields empty arrays and a "never" sync status.
function parseState(text) {
  var s = null
  try { s = JSON.parse(String(text || "")) } catch (e) { s = null }
  if (!s || typeof s !== "object") s = {}
  var ss = s.syncStatus
  return {
    timezone: s.timezone || "",
    calendars: Array.isArray(s.calendars) ? s.calendars : [],
    events: Array.isArray(s.events) ? s.events : [],
    tasklists: Array.isArray(s.tasklists) ? s.tasklists : [],
    tasks: Array.isArray(s.tasks) ? s.tasks : [],
    syncStatus: (ss && typeof ss === "object")
      ? ss
      : { state: "never", message: "", lastOk: null }
  }
}

// Calendar color hex for a calendarId, or "" when unknown.
function calendarColor(calendars, calendarId) {
  var list = calendars || []
  for (var i = 0; i < list.length; i++)
    if (list[i].id === calendarId) return list[i].color || ""
  return ""
}

// A short, human "synced Nm ago" / "auth needed" / "never synced" label.
function syncStatusLabel(syncStatus, now) {
  if (!syncStatus || syncStatus.state === "never") return "Never synced"
  if (syncStatus.state === "auth") return "Auth needed — run setup"
  if (syncStatus.state === "error") return syncStatus.message || "Sync error"
  var last = syncStatus.lastOk
  if (!last) return "Synced"
  var ref = typeof now === "string" ? Date.parse(now) : now.getTime()
  var t = Date.parse(last)
  if (isNaN(ref) || isNaN(t)) return "Synced"
  var mins = Math.max(0, Math.round((ref - t) / 60000))
  if (mins < 1) return "Synced just now"
  if (mins < 60) return "Synced " + mins + "m ago"
  var hours = Math.round(mins / 60)
  if (hours < 24) return "Synced " + hours + "h ago"
  return "Synced " + Math.round(hours / 24) + "d ago"
}

// ---- Additional helpers for week/upcoming/task grouping (pill views) ----

function parseDateKey(key) {
  var text = String(key === undefined || key === null ? "" : key)
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
  if (!m) return null
  return { year: parseInt(m[1], 10), month: parseInt(m[2], 10) - 1, day: parseInt(m[3], 10) }
}

function dayDistance(aKey, bKey) {
  var a = parseDateKey(aKey)
  var b = parseDateKey(bKey)
  if (!a || !b) return NaN
  var da = Date.UTC(a.year, a.month, a.day)
  var db = Date.UTC(b.year, b.month, b.day)
  return Math.round((da - db) / MS_PER_DAY)
}

function relativeDayLabel(key, todayKey) {
  var d = dayDistance(key, todayKey)
  if (isNaN(d)) return ""
  if (d === 0) return "Today"
  if (d === 1) return "Tomorrow"
  if (d === -1) return "Yesterday"
  return ""
}

function overdueDueLabel(dueKey, todayKey) {
  var d = dayDistance(todayKey, dueKey)
  if (isNaN(d)) return ""
  if (d === 0) return "today"
  if (d === 1) return "yesterday"
  if (d < 7) return d + "d ago"
  var w = Math.round(d / 7)
  if (w < 1) w = 1
  return w + "w ago"
}

function overdueTasks(tasks, todayKey) {
  var out = []
  var list = tasks || []
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (t.status === "completed") continue
    var due = taskDueDate(t)
    if (due === "" || due >= todayKey) continue
    // strictly overdue: due < todayKey
    if (due < todayKey) out.push(t)
  }
  out.sort(function(a, b) { return taskDueDate(a).localeCompare(taskDueDate(b)) })
  return out
}

function eventPhase(ev, now) {
  if (!ev || ev.allDay) return ""
  var s = ev.start || ""
  var e = ev.end || ""
  if (!s || !e) return ""
  var start = Date.parse(s)
  var end = Date.parse(e)
  var ref = typeof now === "string" ? Date.parse(now) : (now && now.getTime ? now.getTime() : NaN)
  if (isNaN(start) || isNaN(end) || isNaN(ref)) return ""
  if (ref < start) return "upcoming"
  if (ref >= start && ref < end) return "ongoing"
  if (ref >= end) return "past"
  return ""
}

function weekKeysFor(key, weekStart) {
  var p = parseDateKey(key)
  if (!p) return []
  var ws = normalizedWeekStart(weekStart, 1)
  var d = new Date(p.year, p.month, p.day)
  var dow = d.getDay()
  var delta = (dow - ws + 7) % 7
  var start = new Date(p.year, p.month, p.day - delta)
  var out = []
  for (var i = 0; i < 7; i++) {
    var cur = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
    out.push(dateKey(cur.getFullYear(), cur.getMonth(), cur.getDate()))
  }
  return out
}

function upcomingGroups(index, startKey, days) {
  var p = parseDateKey(startKey)
  if (!p) return []
  var n = Number(days)
  if (!isFinite(n) || n <= 0) n = 14
  var out = []
  var base = new Date(p.year, p.month, p.day)
  for (var d = 0; d < n; d++) {
    var dt = new Date(base.getFullYear(), base.getMonth(), base.getDate() + d)
    var k = dateKey(dt.getFullYear(), dt.getMonth(), dt.getDate())
    var evs = eventsForDate(index, k)
    if (evs.length > 0) out.push({ key: k, events: evs })
  }
  return out
}

function taskGroups(tasks, todayKey) {
  var overdue = []
  var todayArr = []
  var upcoming = []
  var undated = []
  var list = tasks || []
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (t.status === "completed") continue
    var due = taskDueDate(t)
    if (due === "") undated.push(t)
    else if (due < todayKey) overdue.push(t)
    else if (due === todayKey) todayArr.push(t)
    else upcoming.push(t)
  }
  overdue.sort(function(a,b){ return taskDueDate(a).localeCompare(taskDueDate(b)) })
  todayArr.sort(function(a,b){ return (a.title||"").localeCompare(b.title||"") })
  upcoming.sort(function(a,b){ return taskDueDate(a).localeCompare(taskDueDate(b)) })
  undated.sort(function(a,b){ return (a.title||"").localeCompare(b.title||"") })
  return { overdue: overdue, today: todayArr, upcoming: upcoming, undated: undated }
}

// ---- View-facing helpers used by the QML (kept here so they are node-testable).
//      Qt.formatDate formatting stays in the QML; everything else — parsing,
//      grouping, time-text extraction — lives here.

// A local-midnight Date for a YYYY-MM-DD key, or null. The QML wraps this in
// Qt.formatDate(); constructing the Date here keeps parsing testable.
function keyToDate(key) {
  var p = parseDateKey(key)
  if (!p) return null
  return new Date(p.year, p.month, p.day)
}

function dayNum(key) {
  var p = parseDateKey(key)
  return p ? p.day : 0
}

function isWeekendKey(key) {
  var p = parseDateKey(key)
  if (!p) return false
  var dow = new Date(p.year, p.month, p.day).getDay()
  return dow === 0 || dow === 6
}

// "HH:MM" for an event's start, "" when it has no parseable time.
function startTimeText(ev) {
  var m = /T(\d{2}:\d{2})/.exec(String((ev && ev.start) || ""))
  return m ? m[1] : ""
}

// "HH:MM–HH:MM" (en dash) for a timed event, "HH:MM" when no end, "" when
// neither parses.
function eventTimeRange(ev) {
  var s = startTimeText(ev)
  if (s === "") return ""
  var e = /T(\d{2}:\d{2})/.exec(String((ev && ev.end) || ""))
  return e ? s + "–" + e[1] : s
}

// The key `delta` weeks away from `key`, on the same weekday.
function stepWeek(key, delta) {
  var d = keyToDate(key)
  if (!d) return key
  d.setDate(d.getDate() + delta * 7)
  return dateKey(d.getFullYear(), d.getMonth(), d.getDate())
}

// {week, startKey, endKey} for a 7-key week array (as weekKeysFor returns),
// or null for an empty/short array. The QML formats the keys for the heading.
function weekHeadingParts(weekKeys) {
  if (!weekKeys || weekKeys.length < 7) return null
  var start = keyToDate(weekKeys[0])
  if (!start) return null
  return {
    week: isoWeek(start.getFullYear(), start.getMonth(), start.getDate()),
    startKey: weekKeys[0],
    endKey: weekKeys[6]
  }
}

// The next half-hour boundary after `date` as "HH:MM", with hour rollover.
// (10:15 -> "10:30", 10:45 -> "11:00", 10:00 -> "10:30".)
function nextHalfHourHHMM(date) {
  var h = date.getHours()
  var m = date.getMinutes()
  if (m <= 30) return pad2(h) + ":30"
  return pad2((h + 1) % 24) + ":00"
}

// eventsForDate with calendars hidden via shell.json applied.
function visibleEventsOn(index, dateKey, hiddenCalendars) {
  var hidden = hiddenCalendars || []
  return eventsForDate(index, dateKey).filter(function(ev) {
    return hidden.indexOf(ev.calendarId) === -1
  })
}

// upcomingGroups with hidden calendars applied — the model behind the
// UPCOMING view (only days that have at least one visible event).
function visibleUpcomingGroups(index, startKey, days, hiddenCalendars) {
  var hidden = hiddenCalendars || []
  return upcomingGroups(index, startKey, days).map(function(g) {
    return {
      key: g.key,
      events: g.events.filter(function(ev) { return hidden.indexOf(ev.calendarId) === -1 })
    }
  }).filter(function(g) { return g.events.length > 0 })
}

// Flat list of visible upcoming events (first `limit`), for the summary card.
function upcomingSummary(index, startKey, days, hiddenCalendars, limit) {
  var out = []
  var groups = visibleUpcomingGroups(index, startKey, days, hiddenCalendars)
  for (var i = 0; i < groups.length; i++) {
    var evs = groups[i].events
    for (var j = 0; j < evs.length; j++) out.push(evs[j])
  }
  if (typeof limit === "number" && out.length > limit) return out.slice(0, limit)
  return out
}


if (typeof module !== "undefined") {
  module.exports = {
    dateKey: dateKey,
    keyForDate: keyForDate,
    keyForIso: keyForIso,
    dayRange: dayRange,
    normalizedWeekStart: normalizedWeekStart,
    weekStartSettingName: weekStartSettingName,
    toggledWeekStart: toggledWeekStart,
    weekdayOrder: weekdayOrder,
    isoWeek: isoWeek,
    dayOfYear: dayOfYear,
    daysInYear: daysInYear,
    yearProgress: yearProgress,
    yearProgressPercent: yearProgressPercent,
    parseAge: parseAge,
    parseBirthYear: parseBirthYear,
    ageFromBirthYear: ageFromBirthYear,
    parseLifeExpectancy: parseLifeExpectancy,
    lifeProgress: lifeProgress,
    lifeProgressPercent: lifeProgressPercent,
    monthGrid: monthGrid,
    stepMonth: stepMonth,
    clockFormats: clockFormats,
    clockNeedsSeconds: clockNeedsSeconds,
    clockFormatRing: clockFormatRing,
    nextClockFormat: nextClockFormat,
    isoWeekLiteral: isoWeekLiteral,
    eventIndex: eventIndex,
    eventsForDate: eventsForDate,
    taskDueDate: taskDueDate,
    tasksForDate: tasksForDate,
    badgeCount: badgeCount,
    nextEvent: nextEvent,
    countdown: countdown,
    isStale: isStale,
    parseState: parseState,
    calendarColor: calendarColor,
    syncStatusLabel: syncStatusLabel,
    parseDateKey: parseDateKey,
    dayDistance: dayDistance,
    relativeDayLabel: relativeDayLabel,
    overdueDueLabel: overdueDueLabel,
    overdueTasks: overdueTasks,
    eventPhase: eventPhase,
    weekKeysFor: weekKeysFor,
    upcomingGroups: upcomingGroups,
    taskGroups: taskGroups,
    keyToDate: keyToDate,
    dayNum: dayNum,
    isWeekendKey: isWeekendKey,
    startTimeText: startTimeText,
    eventTimeRange: eventTimeRange,
    stepWeek: stepWeek,
    weekHeadingParts: weekHeadingParts,
    nextHalfHourHHMM: nextHalfHourHHMM,
    visibleEventsOn: visibleEventsOn,
    visibleUpcomingGroups: visibleUpcomingGroups,
    upcomingSummary: upcomingSummary
  }
}
