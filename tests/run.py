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
    'network': functions('UrlFunctions.brs', ['createHttpUrl', 'createUrl', 'GETJSON', 'requestText', 'getApiJson', 'twitchClientId', 'nonEmptyString']),
    'auth': functions('GetAuth.brs', ['authenticate', 'validDeviceGrant', 'waitForLoginPoll', 'failLogin']) + '\n\n' + functions('UrlFunctions.brs', ['twitchClientId', 'twitchScopes', 'nonEmptyString', 'validTokenPair', 'oauthError']),
    'session': functions('UrlFunctions.brs', ['twitchClientId', 'nonEmptyString', 'validTokenPair', 'createHttpUrl', 'oauthUrl', 'oauthPost', 'validateUserToken', 'restoreUserSession', 'getRefreshToken', 'saveLogin']),
    'loginpage': functions('LoginPage.brs', ['startLogin', 'onVisible', 'onKeyEvent', 'onAuthUpdate', 'whenFinished', 'onAuthStopped']),
    'follows': functions('GetUser.brs', ['getSearchResults']) + '\n\n' + functions('UrlFunctions.brs', ['getTwitchPages', 'getUserProfiles', 'nonEmptyString']),
    'offline': functions('GetOfflineFollowedChannels.brs', ['getSearchResults']) + '\n\n' + functions('UrlFunctions.brs', ['getTwitchPages', 'getUserProfiles', 'nonEmptyString']),
    'token': functions('GetToken.brs', ['getStreamLink']),
    'streams': functions('GetStreams.brs', ['getSearchResults']),
    'categories': functions('GetCategories.brs', ['getSearchResults']),
    'home': functions('HomeScene.brs', ['hasRows', 'focusContent', 'onGetFocus', 'onApiReady', 'onStartupError', 'showLoadStatus', 'finishLaunch', 'onHomeLoad', 'onSearchResultChange', 'numberToText', 'onCategorySelect', 'onCategoryResultChange', 'getMoreChannels', 'getMoreCategories', 'onKeyEvent', 'onFollowingSelect', 'onFollowingError', 'onGetFollowedStreams', 'requestOfflineFollowing', 'onOfflineStopped', 'onGetOfflineFollowed', 'onFollowBarLogin']),
    'sidebar': functions('FollowedStreamsBar.brs', ['updateEmptyState', 'onKeyEvent']),
    'entry': (ROOT / 'source/main.brs').read_text(),
    'startup': functions('MainScene.brs', ['startAuthentication', 'onTokenStateChanged', 'refreshFollows', 'onUserLogin', 'onUserStopped', 'focusHome', 'onScreenShown']),
}
with tempfile.TemporaryDirectory(prefix='twoku-tests-') as directory:
    for name, source in suites.items():
        # Replace only platform primitives unavailable in the off-device interpreter.
        source = re.sub(r'(?i)\bCreateObject\(', 'testCreateObject(', source)
        if name in ['network', 'entry', 'auth']:
            source = re.sub(r'(?i)\bwait\(', 'testWait(', source)
            source = re.sub(r'(?i)\btype\(', 'testType(', source)
        test = (ROOT / f'tests/{name}.brs').read_text()
        path = Path(directory) / f'{name}.brs'
        support = shared
        if name in ['follows', 'offline']:
            support += '\n' + (ROOT / 'tests/following_support.brs').read_text()
        path.write_text(support + '\n' + source + '\n' + test)
        result = subprocess.run([args.brs, '--root', directory, str(path)], capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        if result.returncode or 'FAIL:' in output or 'PASS' not in output:
            Path('/tmp/twoku-failed-' + name + '.brs').write_text(path.read_text())
            raise SystemExit(f'{name} failed:\n{output}')
        print(f'{name}: ' + next(line for line in output.splitlines() if line.startswith('PASS')))
