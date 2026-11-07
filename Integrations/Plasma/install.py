#!/usr/bin/env python3
"""Install the native Plasma menu; optionally retire the older KodexBar Suite widget.

Stop plasmashell before --replace-kodexbar-suite so it cannot overwrite its config.
The CodexBar backend must already be installed by Integrations/Linux/install.py.
"""
import argparse
import datetime
import json
import os
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
    args = parser.parse_args()
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
        for name in ['MenuContent.qml', 'MenuMetric.qml']:
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
    print(json.dumps({'installed': str(applets / APP_ID), 'backup': str(backup),
                      'replacedKodexbarSuite': args.replace_kodexbar_suite}))


if __name__ == '__main__':
    main()
