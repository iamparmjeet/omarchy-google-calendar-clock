# parm.clock — Google Calendar/Tasks Clock (gws-powered)

Hard engineering rules. These are non-negotiable and bind whichever model builds
the plugin. The full plan lives in `docs/PLAN.md`; phase tickets and acceptance
gates in `docs/TASKS.md`; per-phase prompts in `docs/PROMPTS.md`.

## Hard architecture boundary
- Google-specific logic lives ONLY in `sync/`. QML NEVER calls `gws` or Google.
- QML reads `~/.local/state/parm.clock/state.json`. Writes go through gws, then
  trigger a re-sync. The UI never talks to Google directly.
- UI consumes normalized local state. No OAuth/tokens/credentials in the plugin.

## gws
- NEVER guess gws args. Inspect first: `gws schema <service.resource.method>`.
- Parse JSON output. Classify failures: auth (`401`/`authError`) vs API vs network.
- Use the absolute path to gws in systemd units (PATH differs from an
  interactive shell).

## Data
- All persisted state validates against the v1 schema (`docs/ARCHITECTURE.md`).
- NEVER overwrite a valid `state.json` with failed or partial state.
- Writes are atomic: temp file → fsync → rename.

## Time
- Preserve timezone info. Never hand-roll timezone arithmetic (use `zoneinfo`).
- `dateKey` is local `YYYY-MM-DD` in the user's timezone.

## Testing
- Every date/time transformation, recurrence expansion, badge count, and
  next-event calc has a unit test + fixture. Tests must pass before the phase
  is done.

## Security
- Never store OAuth tokens/secrets in `state.json`, logs, or plugin files.
- gws owns credentials. The plugin only reads normalized events/tasks.

## Systemd
- User service + timer. No overlap, clean exit codes, journal logging, timeout.

## Scope discipline
- Implement ONLY the current phase. Do not refactor unrelated code.
- Stop at each phase's acceptance gate. Append what you changed to
  `docs/AGENT_LOG.md` before continuing.

## Stock-clock provenance
- `BarWidget.qml`, `Panel.qml`, and `Model.js` derive from `omarchy.clock` (MIT).
  Keep stock behaviors: format cycling, week-start toggle, month stepping,
  memento-mori bar. Keep the MIT license + attribution.
