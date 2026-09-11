# Privacy Policy — omarchy-google-calendar-clock

This page covers the `omarchy-clock` Google OAuth client used by the
[omarchy-google-calendar-clock](https://github.com/iamparmjeet/omarchy-google-calendar-clock)
bar widget (a personal, self-hosted Linux desktop plugin).

## What data is accessed

With your consent, the plugin accesses your Google Calendar events
(scope `https://www.googleapis.com/auth/calendar`) and Google Tasks
(scope `https://www.googleapis.com/auth/tasks`) via the Google Calendar
and Tasks APIs. No other Google user data is requested or accessed.

## How we use Google user data

- Your Google Calendar data is used only to display your events in the
  desktop widget (month, week, and upcoming views) and to create, edit,
  and delete events when you explicitly use the widget's add, edit, and
  delete controls.
- Your Google Tasks data is used only to display tasks due on each day
  alongside your events and to add, complete, and delete tasks when you
  explicitly use the widget's task controls.
- Google user data is never used for advertising, never sold, never used
  for profiling or analytics, and never used to train models. The app's
  use of information received from Google APIs adheres to the Google API
  Services User Data Policy, including the Limited Use requirements.
- No AI processing: your Google user data is never sent to any
  third-party AI service, aggregator, gateway, or model, and no AI model
  — self-hosted or otherwise — is used anywhere in this app.

## Sharing, transfer, and disclosure of Google user data

- Your Google user data is shared only with Google LLC via the Google
  Calendar and Tasks APIs, for the sole purpose of providing the calendar
  and task features described above.
- We do not share, transfer, or disclose your Google user data to the
  plugin author, to any other third party, service provider, or
  affiliate, except as required by applicable law (in which case you will
  be notified unless legally prohibited).

## Data protection mechanisms

- Data in transit is encrypted with TLS (HTTPS) for all communication
  between your machine and Google's APIs.
- OAuth tokens are stored **only on your own machine**, in your operating
  system's keyring (e.g. `gnome-keyring`) and `~/.config/gws`, and are
  never transmitted anywhere except to Google's OAuth and API endpoints.
- A local cache of your events and tasks is kept at
  `~/.local/state/parm.clock/state.json` with private file permissions
  (`0600`, directory `0700`), readable only by your user account.
- The app requests only the two scopes listed above, accesses only the
  calendars and task lists you authorize, and performs writes only when
  you explicitly trigger them in the widget.

## Data retention and deletion

Cached data lives on your machine until you remove it
(`scripts/uninstall.sh --purge-data` in the repository). Revoking access at
[myaccount.google.com/permissions](https://myaccount.google.com/permissions)
immediately stops all future access; server-side data is yours and is never
deleted by this plugin.

## Contact

Questions about this policy: `iamparmjeetmishra@gmail.com` (the developer
of this open-source plugin).

Last updated: September 10, 2026.
