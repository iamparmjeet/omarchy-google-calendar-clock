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
