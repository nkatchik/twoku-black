#!/usr/bin/env python3
"""Exercise the production chat lifecycle and IRC transport off-device."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--brs', default='brs')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='twoku-chat-tests-') as directory:
    for name, component in [('chat', 'Chat'), ('chat_transport', 'ChatTransport')]:
        source = (ROOT / f'components/{component}.brs').read_text()
        source = re.sub(r'(?ims)^sub init\(\).*?^end sub\s*', '', source)
        source = re.sub(r'(?i)\bCreateObject\(', 'testCreateObject(', source)
        source = re.sub(r'(?i)\bwait\(', 'testWait(', source)
        path = Path(directory) / (name + '.brs')
        path.write_text((ROOT / 'tests/support.brs').read_text() + '\n' + source + '\n' + (ROOT / f'tests/{name}.brs').read_text())
        result = subprocess.run([args.brs, '--root', directory, str(path)], capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        if result.returncode or 'FAIL:' in output or 'PASS' not in output:
            Path('/tmp/twoku-failed-' + name + '.brs').write_text(path.read_text())
            raise SystemExit(f'{name} failed:\n{output}')
        print(name + ': ' + next(line for line in output.splitlines() if line.startswith('PASS')))
