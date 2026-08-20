# DECISIONS.md — Architecture Decision Records

## ADR-001 — Hard cut from khal/vdirsyncer to gws

**Status:** Accepted.

**Context:** The plugin was a clone of `omarchy.clock` that read events from a
local khal database kept in sync with Google via vdirsyncer (app-password Basic
auth over CalDAV). This required two extra daemons and two config files, and
offered no Google Tasks support.

**Decision:** Remove khal/vdirsyncer entirely and go all-in on `gws` (Google
Workspace CLI), which does OAuth itself and exposes Calendar **and** Tasks CRUD.
Google data stays server-side; only local mirror/config files are deleted.

**Consequences:** Brief window where the calendar is empty until the first gws
sync completes and OAuth is done once in the browser.

## ADR-002 — gws owns OAuth; plugin never implements OAuth

**Status:** Accepted.

**Decision:** The plugin never stores client secrets, refresh tokens, or
implements OAuth. `gws` owns credentials; the sync engine shells out to it and
reads normalized JSON.

**Consequences:** Large reduction in security surface. Single browser consent
step is the only manual part of setup.

## ADR-003 — Task badge = due-today (configurable)

**Status:** Accepted.

**Decision:** The bar badge shows `☑ N` where N is tasks due today, default
`badgeCount = "dueToday"`, toggleable via `showTaskBadge`. Options: `dueToday`,
`overdue`, `all`.

## ADR-004 — Compact ⇄ expanded two-pane popup

**Status:** Accepted.

**Decision:** Popup opens compact (month grid + today agenda). An expand toggle
widens to two panes: month grid left, selected-day agenda + tasks right.
`defaultView` (compact|expanded) is user-settable.

## ADR-005 — Scripted auto-setup up to one browser consent

**Status:** Accepted.

**Decision:** `scripts/setup.sh` ensures gcloud+gws, runs `gws auth setup
--project omarchy-clock` (enable APIs, ensure OAuth client), then
`gws auth login --services calendar,tasks` (opens the browser once), verifies,
runs first sync, installs+enables the systemd timer. Browser consent is the only
manual step.

## ADR-006 — Builder model: `google/gemini-3.7-flash`

**Status:** Accepted.

**Decision:** One model builds the whole plugin end-to-end. Chosen for cost
(0.75/3.75) at intel score 56 — good enough to follow a fully-specified plan
with tight per-phase gates. Phase 9 adversarial review uses a different model
(`zai-org/GLM-5.3`). Safety valve: promote the build to GLM-5.3 if gemini
repeatedly fails a gate (especially timezone/recurrence in P3).

**Cost table (input/output $/M):**

| Model | Input/Output | Intel | Role |
|---|---|---|---|
| gemini-3.7-flash | 0.75 / 3.75 | 56 | builder |
| glm-5.3 | 1.40 / 4.40 | ~similar | P9 review |
| muse-spark-1.2 | 1.25 / 4.25 | lower | cheap tail only |
| gpt-5.6-luna | cheap | low | docs/fixtures/systemd |
