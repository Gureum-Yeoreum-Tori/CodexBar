#!/usr/bin/env python3
"""Opt-in SSH collector. Transfers numeric Codex cost aggregates, never chat/auth files."""
import datetime
import json
import math
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile


def numeric(value):
    return value if isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value) and value >= 0 else None


def project(rows, preferences=None):
    preferences = preferences or {}
    currency = preferences.get('preferredCurrencyCode', 'USD')
    rates = preferences.get('CodexBar.CurrencyExchangeRates', {})
    rate = numeric(rates.get(currency)) if isinstance(rates, dict) else None
    if currency == 'USD':
        rate = 1
    if not rate or not re.fullmatch(r'[A-Z]{3}', str(currency)):
        currency, rate = 'USD', 1
    result = []
    for row in rows:
        if row.get('provider') != 'codex' or row.get('error'):
            continue
        safe = {key: numeric(row.get(key)) for key in ['sessionTokens', 'sessionCostUSD', 'last30DaysTokens', 'last30DaysCostUSD']}
        safe.update(provider='codex', device='mac', currency=currency, exchangeRate=rate,
                    collectedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    historyCoverageIsEstablished=row.get('historyCoverageIsEstablished') is True,
                    provenance='listPriceEstimate' if row.get('provenance') == 'listPriceEstimate' else 'unknown')
        safe['daily'] = []
        for day in row.get('daily', [])[-30:]:
            if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', str(day.get('date', ''))):
                continue
            safe['daily'].append(dict(date=day['date'], **{key: numeric(day.get(key)) for key in ['totalCost', 'totalTokens']}))
        safe['totals'] = {key: numeric(row.get('totals', {}).get(key)) for key in ['inputTokens', 'outputTokens', 'cacheReadTokens']}
        result.append(safe)
    if not result:
        raise ValueError('No Codex cost aggregates')
    return result


def export():
    command = ['/opt/homebrew/bin/codexbar', 'cost', '--provider', 'codex', '--format', 'json', '--days', '30']
    raw = subprocess.run(command, check=True, capture_output=True, text=True, timeout=90)
    prefs = subprocess.run(['defaults', 'export', 'com.steipete.codexbar', '-'], capture_output=True, timeout=5)
    preferences = plistlib.loads(prefs.stdout) if prefs.returncode == 0 else {}
    print(json.dumps(project(json.loads(raw.stdout), preferences), allow_nan=False))


def collect():
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'codexbar/mac-sync.json'
    host = json.loads(config.read_text())['host']
    if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.@:-]{0,200}', host):
        raise ValueError('Invalid SSH host')
    output = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'codexbar/mac-costs.json'
    command = ['ssh', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=8',
               '-o', 'ServerAliveInterval=10', '-o', 'ServerAliveCountMax=2', host, '/usr/bin/python3', '-', '--export']
    response = subprocess.run(command, input=Path(__file__).read_bytes(), capture_output=True, timeout=110, check=True)
    if len(response.stdout) > 100000:
        raise ValueError('Oversized aggregate response')
    rows = json.loads(response.stdout)
    if not isinstance(rows, list) or not rows or rows[0].get('device') != 'mac':
        raise ValueError('Invalid aggregate response')
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=output.parent, prefix='.mac-costs-')
    with os.fdopen(fd, 'wb') as stream:
        stream.write(response.stdout)
    os.replace(temporary, output)
    print('Updated Mac daily cost and token aggregates.')


if __name__ == '__main__':
    try:
        export() if '--export' in sys.argv else collect()
    except Exception:
        print('Mac cost sync unavailable; keeping the last successful snapshot.', file=sys.stderr)
        sys.exit(1)
