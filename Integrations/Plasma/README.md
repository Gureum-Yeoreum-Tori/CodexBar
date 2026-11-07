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
