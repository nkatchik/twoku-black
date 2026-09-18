#!/usr/bin/env python3
"""Run production BrightScript with deterministic transport and node doubles."""
import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from verify_qr import verify as verify_qr

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
    'qr': '\n\n'.join(p.read_text() for p in sorted((ROOT / 'components/qr').glob('*.brs'))) + '\n\n' + (ROOT / 'components/LoginQr.brs').read_text(),
    'network': functions('UrlFunctions.brs', ['createHttpUrl', 'createUrl', 'GETJSON', 'requestText', 'getApiJson', 'twitchClientId', 'nonEmptyString']),
    'auth': functions('GetAuth.brs', ['authenticate', 'validDeviceGrant', 'waitForLoginPoll', 'failLogin']) + '\n\n' + functions('LoginQr.brs', ['loginActivationUri']) + '\n\n' + functions('UrlFunctions.brs', ['twitchClientId', 'twitchScopes', 'nonEmptyString', 'validTokenPair', 'oauthError']),
    'session': functions('UrlFunctions.brs', ['twitchClientId', 'nonEmptyString', 'validTokenPair', 'createHttpUrl', 'oauthUrl', 'oauthPost', 'validateUserToken', 'restoreUserSession', 'getRefreshToken', 'saveLogin']),
    'loginpage': functions('LoginPage.brs', ['startLogin', 'onVisible', 'onKeyEvent', 'onAuthUpdate', 'whenFinished', 'onAuthStopped', 'clearLoginQr', 'showAccount', 'updateAccountFocus']),
    'account': functions('MainScene.brs', ['onHeaderButtonPress','onLogoutRequested','focusHome','onLoginBack','closeLoginPage']) + '\n\n' + functions('Logout.brs', ['revokeSession']),
    'livestatus': (ROOT / 'components/GetLiveStatus.brs').read_text(),
    'channelinfo': (ROOT / 'components/GetUserChannel.brs').read_text(),
    'timedlabel': (ROOT / 'components/TimedLabel.brs').read_text(),
    'loading': (ROOT / 'components/LoadingIndicator.brs').read_text() + '\n\n' + functions('CategoryScene.brs', ['updateCategoryBusy','startCategoryStreams','onStreamsStopped','onClipsStopped','onClipsLoad','categoryHasRows','onPlaybackStopped','onGridFocus','getMoreChannels','getMoreClips']) + '\n\n' + functions('KeyboardGroup.brs', ['updateSearchBusy','onSearchTextChange','onSearchStopped','onChannelSearchResultChange','onCategorySearchResultChange','onSearchResultChange']),
    'follows': functions('GetUser.brs', ['getSearchResults']) + '\n\n' + functions('UrlFunctions.brs', ['getTwitchPages', 'getUserProfiles', 'nonEmptyString']),
    'offline': functions('GetOfflineFollowedChannels.brs', ['getSearchResults']) + '\n\n' + functions('UrlFunctions.brs', ['getTwitchPages', 'getUserProfiles', 'nonEmptyString']),
    'token': functions('GetToken.brs', ['getStreamLink']),
    'streams': functions('GetStreams.brs', ['getSearchResults']),
    'categories': functions('GetCategories.brs', ['getSearchResults']),
    'home': (ROOT / 'components/HomeScene.brs').read_text(),
    'search': (ROOT / 'components/KeyboardGroup.brs').read_text(),
    'followingview': (ROOT / 'components/FollowingView.brs').read_text(),
    'followingitem': (ROOT / 'components/FollowingItem.brs').read_text(),
    'focusmotion': (ROOT / 'components/FocusMotion.brs').read_text(),
    'entry': (ROOT / 'source/main.brs').read_text(),
    'videofeed': functions('GetVideos.brs', ['getSearchResults']),
    'playback': (ROOT / 'components/Playback.brs').read_text(),
    'fmp4compat': (ROOT / 'components/Fmp4Compat.brs').read_text(),
    'compathls': (ROOT / 'components/CompatHls.brs').read_text(),
    'compatserver': '\n\n'.join((ROOT / 'components' / name).read_text() for name in ['PlaybackCompatibility.brs', 'CompatHls.brs', 'Fmp4Compat.brs']) + '\n\n' + functions('UrlFunctions.brs', ['createHttpUrl']),
    'player': (ROOT / 'components/Playback.brs').read_text() + '\n\n' + (ROOT / 'components/CustomVideo.brs').read_text(),
    'playbackrequest': (ROOT / 'components/Playback.brs').read_text() + '\n\n' + (ROOT / 'components/PlaybackRequest.brs').read_text(),
    'clipfeed': functions('GetClips.brs', ['getStartDate', 'getSearchResults']) + '\n\n' + functions('UrlFunctions.brs', ['nonEmptyString']),
    'clips': functions('GetClipPlayback.brs', ['getClipPlayback', 'requestClipPlayback', 'clipPlaybackVariants']) + '\n\n' + (ROOT / 'components/Playback.brs').read_text() + '\n\n' + functions('UrlFunctions.brs', ['nonEmptyString']),
    'categorypage': (ROOT / 'components/CategoryScene.brs').read_text(),
    'channelpage': (ROOT / 'components/ChannelPage.brs').read_text(),
    'playback_routes': functions('MainScene.brs', ['onKeyEvent', 'closeLoginPage', 'reloadVisibleContent', 'reloadFollowing', 'onUserStopped', 'beginPlayback', 'closePlayback', 'onToggleStreamLayout', 'onToggleChat', 'onPlayerStreamEnded', 'onPlayerLiveStatus', 'onVideoPlayerBack', 'onQualityPreference', 'onStreamChange', 'onStreamChangeFromChannelPage', 'onPlayerChannelRequested', 'onStreamerSelected']),
    'startup': functions('MainScene.brs', ['startAuthentication', 'onTokenStateChanged', 'refreshFollows', 'onUserLogin', 'onUserStopped', 'focusHome', 'onScreenShown']),
}
with tempfile.TemporaryDirectory(prefix='twoku-tests-') as directory:
    for name, source in suites.items():
        if name in ['home', 'categorypage', 'channelpage', 'loading']:
            source += '\n' + (ROOT / 'components/GridPagination.brs').read_text()
        if name in ['home', 'loginpage', 'player']:
            source += '\n' + (ROOT / 'components/ButtonFocus.brs').read_text()
        if name == 'followingitem':
            source += '\n' + (ROOT / 'components/FocusMotion.brs').read_text()
        # Replace only platform primitives unavailable in the off-device interpreter.
        source = re.sub(r'(?i)\bCreateObject\(', 'testCreateObject(', source)
        if name in ['network', 'entry', 'auth', 'compatserver']:
            source = re.sub(r'(?i)\bwait\(', 'testWait(', source)
            source = re.sub(r'(?i)\btype\(', 'testType(', source)
        if name == 'compatserver':
            # brs lacks native byte-array storage; keep all relay decisions intact.
            source = source.replace('bytes.FromAsciiString(text)', 'testBytesFromAsciiString(bytes, text)')
            source = source.replace('bytes.ReadFile(job.filename)', 'testReadBytes(bytes, job.filename)')
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
        if name == 'qr':
            verify_qr(output)
            Path('/tmp/twoku-qr-test-output.txt').write_text(output)
        print(f'{name}: ' + next(line for line in output.splitlines() if line.startswith('PASS')))

# Chat has a separate runner because its transport substitutes timed waits.
subprocess.run([sys.executable, str(ROOT / 'tests/run_chat.py'), '--brs', args.brs], check=True)
