# Native KDE Plasma menu

This adapter uses the same MenuContent QML as the Qt desktop. It displays a
percent-only panel label with variable width and opens an anchored Plasma popup,
rather than squeezing text into a square system-tray icon or opening a separate
window. A single enabled provider has no provider switcher, matching the macOS
`addProviderSwitcherIfNeeded` rule. The menu uses macOS's 310-point baseline width,
20-point content padding, compact headings, quota/reset rows and footer actions.
System font rendering, native popup materials and window shadows remain KDE's.

Build/install the Linux desktop first, then run `python3 Integrations/Plasma/install.py`.
Add the **CodexBar** widget to a panel. The backend starts at login via the existing
Linux installer. To reuse a KodexBar Suite slot, stop plasmashell, run the installer
with `--replace-kodexbar-suite`, and restart plasmashell. This explicitly retires
that old widget and its launchers; all displaced files and panel configuration are
backed up in the user data directory under `codexbar/backups/<timestamp>`.

The adapter polls a private local socket through `codexbar-linux --menu-snapshot`.
Polling does not fetch provider quota; the desktop's existing refresh loop does.
While expanded, optional spending requests use the existing five-minute cache.
This explicit menu endpoint includes the account label only if Show identity is
on, plus an allowlist of display preferences. It never exports CLI paths or auth
configuration. The ordinary `--snapshot` endpoint remains identity-free.

This is a native menu port, not macOS API emulation. Managed-account editing,
CloudKit, Sparkle updates and macOS-only submenus are not implemented. No Mac
credentials or screen contents are copied.

## Mac cost history

The menu includes today/30-day costs and tokens, a 30-day chart with cost/token
selection, and four calendar-based seven-day summaries. These summaries are not
quota-reset windows: the CLI does not export the macOS app's observed reset
boundaries or hourly cost slices. Unknown values stay unknown. Mac and Arch
histories are selectable. An optional Total view sums their daily values and totals;
it explicitly warns that replicated histories can overlap. It is not deduplicated
account billing, and missing amounts remain unknown.

For opt-in Mac history, run this installer with `--mac-host user@trusted-host`.
SSH key login and a verified known-host entry must already work. The Mac needs
`/opt/homebrew/bin/codexbar` and `/usr/bin/python3`. A user systemd timer fetches
aggregates every five minutes. The exporter filters on the Mac before transport:
only daily numeric costs/tokens, aggregate totals, display currency and its cached
exchange rate cross SSH. Chat content, project paths, account labels and auth files
are excluded. A missing exchange rate falls back to labeled USD. A failed fetch
retains the last successful private cache and the menu shows its collection time.

Disable synchronization with `systemctl --user disable --now codexbar-mac-costs.timer`.
The host lives only in `~/.config/codexbar/mac-sync.json`; the private cache is
`~/.cache/codexbar/mac-costs.json`.
