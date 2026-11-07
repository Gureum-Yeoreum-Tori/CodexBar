# Arch / CachyOS desktop

This fork builds the existing upstream Qt 6 Linux desktop against the installed
Arch libraries. Provider authentication and usage fetching remain in CodexBarCLI;
the macOS implementation is unchanged.

## Build and install

With a working `codexbar` CLI already installed:

```sh
sudo pacman -S --needed base-devel python qt6-base qt6-declarative qt6-svg
bash Integrations/Arch/install.sh --cli "$HOME/.local/bin/codexbar"
~/.local/bin/codexbar-linux --quick-view
```

The helper checks the actual Wayland plugin instead of requiring a package name:
on this CachyOS system Qt 6.12 provides it in `qt6-base`; older installations may
need `qt6-wayland`. It never installs system packages automatically.
`--build-only` skips installation. Other arguments are passed to the upstream
Linux installer, including `--no-autostart` and `--provider codex`.
Quit a running desktop before reinstalling. See the
[Linux guide](../Linux/README.md) for CLI installation and removal instructions.

The installer adds a launcher and login startup entry and backs up existing Linux
preferences. To select a compact tray popup and remaining quota after starting:

```sh
codexbar-linux --configure '{"compactQuickView":true,"quotaDisplay":"remaining","refreshSeconds":300}'
```

## Seeing the same quota on Mac and Arch

Sign into the same provider account and workspace independently on both machines.
For Codex, the upstream [provider implementation](../../docs/codex.md) reads
account quota from the server. Both desktops therefore show the same account's
remaining allowance once refreshed; no file synchronization or always-on Mac is
needed. Refresh both before comparing and compare the same quota window.

This does not synchronize local spending/token history or desktop preferences.
The macOS CloudKit sync implementation is not available in the Linux desktop.
Do not copy `auth.json` or synchronize the credential-bearing CodexBar config
just to display the same remaining quota. Login on each device instead.

## Validation

```sh
bash Integrations/Arch/install.sh --build-only
python3 Integrations/Linux/tests/test_desktop.py
python3 Integrations/Linux/tests/test_package.py
python3 Integrations/Omarchy/test_install.py
```

Runtime tests use a fake CLI and isolated HOME/XDG directories. They need Unix
socket support. No live provider credentials are used by these tests.
