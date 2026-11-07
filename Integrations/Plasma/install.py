#!/usr/bin/env python3
"""Install the native Plasma menu; optionally retire the older KodexBar Suite widget.

Stop plasmashell before --replace-kodexbar-suite so it cannot overwrite its config.
The CodexBar backend must already be installed by Integrations/Linux/install.py.
"""
import argparse
import datetime
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[2]
APP_ID = 'io.github.GureumYeoreumTori.codexbar'
OLD_ID = 'org.kde.plasma.kodexbar'


def xdg(variable, fallback):
    value = Path(os.environ.get(variable, ''))
    return value if value.is_absolute() else fallback


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--replace-kodexbar-suite', action='store_true')
    parser.add_argument('--mac-host', help='Opt in to aggregate-only cost sync from an already trusted SSH host')
    args = parser.parse_args()
    if args.mac_host and not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.@:-]{0,200}', args.mac_host):
        parser.error('Invalid SSH host')
    home = Path.home()
    data = xdg('XDG_DATA_HOME', home / '.local/share')
    config = xdg('XDG_CONFIG_HOME', home / '.config')
    applets = data / 'plasma/plasmoids'
    applets.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup = data / 'codexbar/backups' / stamp
    backup.mkdir(parents=True, mode=0o700)
    layout = config / 'plasma-org.kde.plasma.desktop-appletsrc'
    text = layout.read_text() if layout.exists() else ''
    if args.replace_kodexbar_suite:
        running = subprocess.run(['pgrep', '-x', 'plasmashell'], capture_output=True)
        if running.returncode == 0:
            parser.error('Stop plasmashell before replacing the old widget; restart it after installation.')
    with tempfile.TemporaryDirectory(dir=applets, prefix='.codexbar-stage-') as temporary:
        stage = Path(temporary) / APP_ID
        shutil.copytree(REPO / 'Integrations/Plasma/contents', stage / 'contents')
        shutil.copy2(REPO / 'Integrations/Plasma/metadata.json', stage / 'metadata.json')
        menu = stage / 'contents/ui/menu'
        menu.mkdir()
        for name in ['MenuContent.qml', 'MenuMetric.qml', 'MenuCosts.qml']:
            shutil.copy2(REPO / 'Integrations/Linux/qml' / name, menu / name)
        shared = stage / 'contents/ui/Shared'
        shared.mkdir()
        shutil.copy2(REPO / 'Integrations/Linux/Shared/Usage.js', shared / 'Usage.js')
        icons = stage / 'contents/ui/icons'
        icons.mkdir()
        for source in (REPO / 'Sources/CodexBar/Resources').glob('ProviderIcon-*.svg'):
            shutil.copy2(source, icons / source.name)
        target = applets / APP_ID
        if target.exists():
            shutil.move(str(target), backup / APP_ID)
        stage.rename(target)
    if args.replace_kodexbar_suite:
        if layout.exists():
            shutil.copy2(layout, backup / layout.name)
            updated = text.replace('plugin=' + OLD_ID + '\n', 'plugin=' + APP_ID + '\n')
            target_layout = layout.resolve()
            fd, temporary = tempfile.mkstemp(dir=target_layout.parent, prefix='.codexbar-layout-')
            with os.fdopen(fd, 'w') as stream:
                stream.write(updated)
            os.chmod(temporary, target_layout.stat().st_mode & 0o777)
            os.replace(temporary, target_layout)
        old = applets / OLD_ID
        if old.exists():
            shutil.move(str(old), backup / OLD_ID)
        # Retire only KodexBar launch points, leaving shared AI CLI tools untouched.
        launchers = backup / 'old-launchers'
        launchers.mkdir()
        for folder, pattern in [(home / '.local/bin', 'kodexbar-*'),
                                (data / 'applications', '*kodexbar*.desktop'),
                                (config / 'autostart', '*kodexbar*.desktop')]:
            for path in folder.glob(pattern):
                name = path.name
                destination = launchers / (folder.name + '-' + name)
                shutil.move(str(path), destination)
    if args.mac_host:
        binary = home / '.local/bin/codexbar-mac-costs'
        binary.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / 'Integrations/Linux/mac_costs.py', binary)
        binary.chmod(0o755)
        preferences = config / 'codexbar/mac-sync.json'
        preferences.parent.mkdir(parents=True, exist_ok=True)
        if preferences.exists():
            shutil.copy2(preferences, backup / 'mac-sync.json')
        preferences.write_text(json.dumps({'host': args.mac_host}) + '\n')
        preferences.chmod(0o600)
        units = config / 'systemd/user'
        units.mkdir(parents=True, exist_ok=True)
        (units / 'codexbar-mac-costs.service').write_text(
            '[Unit]\nDescription=Sync Mac CodexBar daily aggregates\n[Service]\nType=oneshot\n'
            'ExecStart=%h/.local/bin/codexbar-mac-costs\nTimeoutStartSec=120\nUMask=0077\n')
        (units / 'codexbar-mac-costs.timer').write_text(
            '[Unit]\nDescription=Refresh Mac CodexBar aggregates\n[Timer]\n'
            'OnStartupSec=20\nOnUnitActiveSec=5min\n[Install]\nWantedBy=timers.target\n')
        subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
        subprocess.run(['systemctl', '--user', 'enable', '--now', 'codexbar-mac-costs.timer'], check=True)
    print(json.dumps({'installed': str(applets / APP_ID), 'backup': str(backup),
                      'replacedKodexbarSuite': args.replace_kodexbar_suite}))


if __name__ == '__main__':
    main()
