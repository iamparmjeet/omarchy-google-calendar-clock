# Privacy Policy — omarchy-google-calendar-clock

This page covers the `omarchy-clock` Google OAuth client used by the
[omarchy-google-calendar-clock](https://github.com/iamparmjeet/omarchy-google-calendar-clock)
bar widget (a personal, self-hosted Linux desktop plugin).

## What data is accessed

With your consent, the plugin reads and writes your Google Calendar events
and Google Tasks via the Google Calendar and Tasks APIs. No other Google
data is requested or accessed.

## Where your data lives

- OAuth tokens are stored **only on your own machine**, in your operating
  system's keyring (e.g. `gnome-keyring`) and `~/.config/gws`.
- A local cache of your events and tasks is kept at
  `~/.local/state/parm.clock/state.json` with private file permissions
  (`0600`, directory `0700`).
- Your data is transmitted **only between your machine and Google's APIs**
  over HTTPS. It is never sent to the plugin author or any third party,
  never sold, and never used for advertising.

## Data retention and deletion

Cached data lives on your machine until you remove it
(`scripts/uninstall.sh --purge-data` in the repository). Revoking access at
[myaccount.google.com/permissions](https://myaccount.google.com/permissions)
immediately stops all future access; server-side data is yours and is never
deleted by this plugin.

## Contact

Questions about this policy: `iamparmjeetmishra@gmail.com` (the developer,
and the only user of this OAuth client).
