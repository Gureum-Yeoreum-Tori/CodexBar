import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

INSTALLER = Path(__file__).with_name('install.py')
APP_ID = 'io.github.GureumYeoreumTori.codexbar'


class InstallationTests(unittest.TestCase):
    def test_replaces_only_old_widget_and_backs_up_launchers(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            data = home / '.local/share'
            config = home / '.config'
            config.mkdir()
            layout = config / 'plasma-org.kde.plasma.desktop-appletsrc'
            original = '[Containments][23][Applets][50]\nplugin=org.kde.plasma.kodexbar\n\n[Other]\nkeep=yes\n'
            layout.write_text(original)
            old = data / 'plasma/plasmoids/org.kde.plasma.kodexbar'
            old.mkdir(parents=True)
            (old / 'marker').write_text('old widget')
            bin_dir = home / '.local/bin'
            bin_dir.mkdir(parents=True)
            (bin_dir / 'kodexbar-tray').symlink_to('/missing/old-target')
            (bin_dir / 'ai').write_text('keep shared AI tools')
            fake = home / 'tools'
            fake.mkdir()
            (fake / 'pgrep').write_text('#!/bin/sh\nexit 1\n')
            (fake / 'pgrep').chmod(0o755)
            env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(config),
                       PATH=str(fake) + ':' + os.environ['PATH'])
            result = subprocess.run(['python3', str(INSTALLER), '--replace-kodexbar-suite'],
                                    env=env, capture_output=True, text=True, check=True)
            report = json.loads(result.stdout)
            backup = Path(report['backup'])
            self.assertEqual((backup / layout.name).read_text(), original)
            self.assertIn('plugin=' + APP_ID, layout.read_text())
            self.assertIn('keep=yes', layout.read_text())
            self.assertTrue((Path(report['installed']) / 'contents/ui/menu/MenuContent.qml').exists())
            self.assertFalse(old.exists())
            self.assertTrue((backup / 'org.kde.plasma.kodexbar/marker').exists())
            self.assertTrue((backup / 'old-launchers/bin-kodexbar-tray').is_symlink())
            self.assertTrue((bin_dir / 'ai').exists())


if __name__ == '__main__':
    unittest.main()
