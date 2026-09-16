#!/usr/bin/env python3
"""Run production BrightScript with deterministic transport and node doubles."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def functions(file, names):
    source = (ROOT / 'components' / file).read_text()
    selected = []
    for name in names:
        pattern = r'(?ims)^(?:function|sub)\s+' + name + r'\([^\n]*\n.*?^end (?:function|sub)'
        match = re.search(pattern, source)
        if not match:
            raise ValueError(f'Missing function {file}:{name}')
        selected.append(match.group())
    return '\n\n'.join(selected)


parser = argparse.ArgumentParser()
parser.add_argument('--brs', default='brs')
args = parser.parse_args()
shared = (ROOT / 'tests/support.brs').read_text()
suites = {
    'network': functions('UrlFunctions.brs', ['createUrl', 'requestText', 'getApiJson', 'refreshToken', 'getRefreshToken']),
    'token': functions('GetToken.brs', ['getStreamLink']),
    'streams': functions('GetStreams.brs', ['getSearchResults']),
    'categories': functions('GetCategories.brs', ['getSearchResults']),
    'home': functions('HomeScene.brs', ['hasRows', 'onHomeFocusChanged', 'onGetFocus', 'onApiReady', 'onStartupError', 'showLoadStatus', 'finishLaunch', 'onHomeLoad', 'onSearchResultChange', 'numberToText', 'onCategorySelect', 'onCategoryResultChange', 'getMoreChannels', 'getMoreCategories', 'onKeyEvent', 'onFollowingSelect']),
    'startup': functions('MainScene.brs', ['startAuthentication', 'onTokenStateChanged', 'refreshFollows', 'onUserLogin']),
}
with tempfile.TemporaryDirectory(prefix='twoku-tests-') as directory:
    for name, source in suites.items():
        # Replace only platform primitives unavailable in the off-device interpreter.
        source = re.sub(r'(?i)\bCreateObject\(', 'testCreateObject(', source)
        if name == 'network':
            source = re.sub(r'(?i)\bwait\(', 'testWait(', source)
            source = re.sub(r'(?i)\btype\(', 'testType(', source)
        test = (ROOT / f'tests/{name}.brs').read_text()
        path = Path(directory) / f'{name}.brs'
        path.write_text(shared + '\n' + source + '\n' + test)
        result = subprocess.run([args.brs, '--root', directory, str(path)], capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        if result.returncode or 'FAIL:' in output or 'PASS' not in output:
            raise SystemExit(f'{name} failed:\n{output}')
        print(f'{name}: ' + next(line for line in output.splitlines() if line.startswith('PASS')))
