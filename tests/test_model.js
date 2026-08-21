// Unit tests for the calendar-state model (Model.js). Run: node tests/test_model.js
const assert = require("assert");
const path = require("path");
const fs = require("fs");

const Model = require(path.join(__dirname, "..", "Model.js"));

// Load the golden state fixture written by the sync engine tests.
const state = JSON.parse(
  fs.readFileSync(path.join(__dirname, "fixtures", "state.golden.json"), "utf8")
);

// A small synthetic state with tasks spanning due-today / overdue / no-due.
const tasks = [
  { id: "t1", title: "Due today", status: "needsAction", due: "2026-08-20" },
  { id: "t2", title: "Overdue", status: "needsAction", due: "2026-08-10" },
  { id: "t3", title: "No due", status: "needsAction", due: "" },
  { id: "t4", title: "Done", status: "completed", due: "2026-08-20" },
];

const events = [
  { id: "e1", title: "Timed", allDay: false, dateKey: "2026-08-20",
    start: "2026-08-20T09:00:00+05:30", end: "2026-08-20T10:00:00+05:30" },
  { id: "e2", title: "Multi-day", allDay: true, dateKey: "2026-08-18", end: "2026-08-20" },
  { id: "e3", title: "Later", allDay: false, dateKey: "2026-08-21",
    start: "2026-08-21T09:00:00+05:30", end: "2026-08-21T10:00:00+05:30" },
];

// ---- eventIndex / eventsForDate ------------------------------------------

function testEventIndex() {
  const idx = Model.eventIndex(events);
  // Multi-day all-day event spans 08-18, 08-19, 08-20.
  assert.deepStrictEqual(
    idx["2026-08-19"].map((e) => e.id),
    ["e2"]
  );
  // Raw index preserves insertion order; sorting is eventsForDate's job.
  assert.deepStrictEqual(
    idx["2026-08-20"].map((e) => e.id),
    ["e1", "e2"]
  );
}

function testEventsForDateAllDayFirst() {
  const idx = Model.eventIndex(events);
  const on20 = Model.eventsForDate(idx, "2026-08-20");
  // all-day (e2) sorts before timed (e1) on the same date.
  assert.strictEqual(on20[0].id, "e2");
  assert.strictEqual(on20[1].id, "e1");
}

// ---- taskDueDate / tasksForDate ------------------------------------------

function testTaskDueDate() {
  assert.strictEqual(Model.taskDueDate(tasks[0]), "2026-08-20");
  assert.strictEqual(Model.taskDueDate(tasks[2]), "");
  // Accepts RFC3339 too (defensive), truncating to the date.
  assert.strictEqual(Model.taskDueDate({ due: "2026-08-20T00:00:00Z" }), "2026-08-20");
}

function testTasksForDate() {
  assert.strictEqual(Model.tasksForDate(tasks, "2026-08-20").length, 1);
  // Completed task is excluded.
  assert.strictEqual(Model.tasksForDate(tasks, "2026-08-20")[0].id, "t1");
}

// ---- badgeCount -----------------------------------------------------------

function testBadgeDueToday() {
  assert.strictEqual(Model.badgeCount(tasks, "dueToday", "2026-08-20"), 1);
}

function testBadgeOverdue() {
  assert.strictEqual(Model.badgeCount(tasks, "overdue", "2026-08-20"), 2);
}

function testBadgeAll() {
  assert.strictEqual(Model.badgeCount(tasks, "all", "2026-08-20"), 3);
}

function testBadgeCompletedExcluded() {
  assert.strictEqual(Model.badgeCount(tasks, "all", "2026-08-20"), 3); // t4 is completed
}

// ---- nextEvent / countdown ------------------------------------------------

function testNextEvent() {
  const now = "2026-08-20T08:00:00+05:30";
  const next = Model.nextEvent(events, now);
  assert.strictEqual(next.id, "e1");
}

function testNextEventSkipsPast() {
  const now = "2026-08-20T12:00:00+05:30";
  const next = Model.nextEvent(events, now);
  assert.strictEqual(next.id, "e3");
}

function testCountdown() {
  assert.strictEqual(Model.countdown(events[0], "2026-08-20T08:30:00+05:30"), "in 30m");
  assert.strictEqual(Model.countdown(events[0], "2026-08-19T09:00:00+05:30"), "in 1d");
}

// ---- isStale --------------------------------------------------------------

function testIsStale() {
  const now = "2026-08-20T18:05:00Z";
  // lastOk 5 min ago, threshold 10 -> fresh.
  assert.strictEqual(Model.isStale({ state: "ok", lastOk: "2026-08-20T18:00:00Z" }, now, 10), false);
  // lastOk 11 min ago -> stale.
  assert.strictEqual(Model.isStale({ state: "ok", lastOk: "2026-08-20T17:54:00Z" }, now, 10), true);
  // never -> stale.
  assert.strictEqual(Model.isStale({ state: "never", lastOk: null }, now, 10), true);
  // auth state with no lastOk -> stale.
  assert.strictEqual(Model.isStale({ state: "auth", lastOk: null }, now, 10), true);
}

// ---- parseState / calendarColor / syncStatusLabel -------------------------

function testParseState() {
  const s = Model.parseState(JSON.stringify(state));
  assert.strictEqual(s.timezone, "Asia/Kolkata");
  assert.strictEqual(s.events.length, 2);
  assert.strictEqual(s.tasks.length, 1);
}

function testParseStateGarbage() {
  const s = Model.parseState("not json {{");
  assert.strictEqual(s.events.length, 0);
  assert.strictEqual(s.syncStatus.state, "never");
}

function testParseStateEmpty() {
  const s = Model.parseState("");
  assert.deepStrictEqual(s.events, []);
}

function testCalendarColor() {
  const cals = [{ id: "primary", color: "#4285F4" }];
  assert.strictEqual(Model.calendarColor(cals, "primary"), "#4285F4");
  assert.strictEqual(Model.calendarColor(cals, "missing"), "");
}

function testSyncStatusLabel() {
  const now = "2026-08-20T18:05:00Z";
  assert.strictEqual(Model.syncStatusLabel({ state: "ok", lastOk: "2026-08-20T18:00:00Z" }, now), "Synced 5m ago");
  assert.strictEqual(Model.syncStatusLabel({ state: "never", lastOk: null }, now), "Never synced");
  assert.strictEqual(Model.syncStatusLabel({ state: "auth", lastOk: null }, now), "Auth needed — run setup");
}

// ---- parseDateKey / dayDistance / relativeDayLabel / overdue helpers ------

function testParseDateKey() {
  assert.deepStrictEqual(Model.parseDateKey("2026-08-20"), { year: 2026, month: 7, day: 20 });
  assert.strictEqual(Model.parseDateKey("2026-08-20T09:00:00"), null);
  assert.strictEqual(Model.parseDateKey(""), null);
  assert.strictEqual(Model.parseDateKey(null), null);
}

function testDayDistance() {
  assert.strictEqual(Model.dayDistance("2026-08-20", "2026-08-20"), 0);
  assert.strictEqual(Model.dayDistance("2026-08-21", "2026-08-20"), 1);
  assert.strictEqual(Model.dayDistance("2026-08-10", "2026-08-20"), -10);
  // Month and year boundaries.
  assert.strictEqual(Model.dayDistance("2026-09-01", "2026-08-31"), 1);
  assert.strictEqual(Model.dayDistance("2027-01-01", "2026-12-31"), 1);
  assert.ok(isNaN(Model.dayDistance("garbage", "2026-08-20")));
}

function testRelativeDayLabel() {
  assert.strictEqual(Model.relativeDayLabel("2026-08-20", "2026-08-20"), "Today");
  assert.strictEqual(Model.relativeDayLabel("2026-08-21", "2026-08-20"), "Tomorrow");
  assert.strictEqual(Model.relativeDayLabel("2026-08-19", "2026-08-20"), "Yesterday");
  assert.strictEqual(Model.relativeDayLabel("2026-08-25", "2026-08-20"), "");
  assert.strictEqual(Model.relativeDayLabel("bad", "2026-08-20"), "");
}

function testOverdueDueLabel() {
  assert.strictEqual(Model.overdueDueLabel("2026-08-19", "2026-08-20"), "yesterday");
  assert.strictEqual(Model.overdueDueLabel("2026-08-17", "2026-08-20"), "3d ago");
  assert.strictEqual(Model.overdueDueLabel("2026-08-06", "2026-08-20"), "2w ago");
  assert.strictEqual(Model.overdueDueLabel("2026-08-20", "2026-08-20"), "today");
}

function testOverdueTasks() {
  const overdue = Model.overdueTasks(tasks, "2026-08-20");
  // t2 (due 08-10) only; completed and no-due tasks are excluded.
  assert.deepStrictEqual(overdue.map((t) => t.id), ["t2"]);
  // Oldest due first when several are overdue.
  const many = [
    { id: "b", status: "needsAction", due: "2026-08-15" },
    { id: "a", status: "needsAction", due: "2026-08-01" },
    { id: "c", status: "needsAction", due: "2026-08-20" },
  ];
  assert.deepStrictEqual(
    Model.overdueTasks(many, "2026-08-20").map((t) => t.id),
    ["a", "b"]
  );
}

function testEventPhase() {
  const ev = events[0]; // 09:00–10:00 +05:30 on 2026-08-20
  assert.strictEqual(Model.eventPhase(ev, "2026-08-20T08:00:00+05:30"), "upcoming");
  assert.strictEqual(Model.eventPhase(ev, "2026-08-20T09:30:00+05:30"), "ongoing");
  assert.strictEqual(Model.eventPhase(ev, "2026-08-20T11:00:00+05:30"), "past");
  // All-day and malformed events phase as "" — the UI leaves them alone.
  assert.strictEqual(Model.eventPhase(events[1], "2026-08-19T10:00:00+05:30"), "");
  assert.strictEqual(Model.eventPhase(null, "2026-08-20T10:00:00+05:30"), "");
}

function testWeekKeysFor() {
  // Monday-start week containing Wed 2026-08-20 (a Thursday-ish check too).
  assert.deepStrictEqual(
    Model.weekKeysFor("2026-08-20", 1),
    ["2026-08-17", "2026-08-18", "2026-08-19", "2026-08-20", "2026-08-21", "2026-08-22", "2026-08-23"]
  );
  // Sunday start pulls the previous Sunday.
  assert.strictEqual(Model.weekKeysFor("2026-08-20", 0)[0], "2026-08-16");
  // Week boundaries roll across months correctly.
  assert.deepStrictEqual(
    Model.weekKeysFor("2026-09-01", 1).slice(0, 2),
    ["2026-08-31", "2026-09-01"]
  );
  assert.deepStrictEqual(Model.weekKeysFor("bad", 1), []);
}

function testUpcomingGroups() {
  const idx = Model.eventIndex(events);
  const groups = Model.upcomingGroups(idx, "2026-08-19", 14);
  // Days with no events are skipped; multi-day e2 covers 08-19 and 08-20.
  assert.deepStrictEqual(groups.map((g) => g.key), ["2026-08-19", "2026-08-20", "2026-08-21"]);
  assert.strictEqual(groups[0].events[0].id, "e2");
}

function testTaskGroups() {
  const g = Model.taskGroups(tasks, "2026-08-20");
  assert.deepStrictEqual(g.overdue.map((t) => t.id), ["t2"]);
  assert.deepStrictEqual(g.today.map((t) => t.id), ["t1"]);
  assert.deepStrictEqual(g.upcoming.map((t) => t.id), []);
  assert.deepStrictEqual(g.undated.map((t) => t.id), ["t3"]);
  // Completed tasks land nowhere.
  assert.ok(![].concat(g.overdue, g.today, g.upcoming, g.undated).some((t) => t.id === "t4"));
}

// --------------------------------------------------------------------------

const tests = [
  testEventIndex,
  testEventsForDateAllDayFirst,
  testTaskDueDate,
  testTasksForDate,
  testBadgeDueToday,
  testBadgeOverdue,
  testBadgeAll,
  testBadgeCompletedExcluded,
  testNextEvent,
  testNextEventSkipsPast,
  testCountdown,
  testIsStale,
  testParseState,
  testParseStateGarbage,
  testParseStateEmpty,
  testCalendarColor,
  testSyncStatusLabel,
  testParseDateKey,
  testDayDistance,
  testRelativeDayLabel,
  testOverdueDueLabel,
  testOverdueTasks,
  testEventPhase,
  testWeekKeysFor,
  testUpcomingGroups,
  testTaskGroups,
];

let failed = 0;
for (const t of tests) {
  try {
    t();
    console.log("ok - " + t.name);
  } catch (e) {
    failed++;
    console.error("FAIL - " + t.name);
    console.error("  " + e.message);
  }
}

if (failed) {
  process.exit(1);
}
console.log(`\n${tests.length} tests passed`);
