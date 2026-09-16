# Regression checks

Install the off-device tools outside the channel package, then run:

```sh
npm install --prefix /tmp/twoku-validation --no-audit --no-fund brs@0.45.0 brighterscript@0.73.5
python3 tests/run.py --brs /tmp/twoku-validation/node_modules/.bin/brs
/tmp/twoku-validation/node_modules/.bin/bsc --no-project --create-package false --copy-to-staging false
```

The suites execute production BrightScript functions. Transport, task fields,
and SceneGraph nodes use deterministic doubles; the runner substitutes platform
primitives that the off-device interpreter does not implement. These checks cover
finite request waits, failed async starts, invalid token/JSON responses, a maximum
of one authentication retry, anonymous startup, parent focus routing, empty grids,
partial content rows, and failed or exhausted pagination. Focus doubles enforce
one active target and walk the parent chain. Navigation checks cover the route to
Login, moving between header and grid, and restoring focus after screen display.
Signed-out sidebar checks cover its placeholder, Login action, empty-list arrows,
and returning to the header when Following has no content. They do not validate
Roku scheduling, rendering, remote input delivery, or playback.

QR checks cover the exact prefilled activation link, preserved query parameters,
local rendering, integer module sizes, the four-module quiet zone, image allocation
failure, and hiding expired or cancelled codes. The emitted pixels match frozen
Nayuki qrcodegen 1.8.0 reference matrices. For an independent decoder check, install `pillow` and
`zxing-cpp` in an isolated environment, run the suites, then run
`python tests/verify_qr.py /tmp/twoku-qr-test-output.txt --decode`.

Login suites cover device grant validation, approval polling, slow-down, expiry,
cancellation during polling and validation, late task results, retry, validated
identity/scopes/client ID, form encoding, saved-session restoration, refresh-token
rotation, network failures, and superseded sessions. Follow suites cover modern
endpoints, authenticated user IDs, encoded pagination, repeated cursors, duplicate
streams, sorting, profile batches, empty lists, and failed requests. Home tests
check replacement of followed rows and preserving focus and browse pagination.
The transport tests also verify that user/app tokens use their own client IDs and
that protected requests never fall back to anonymous credentials. External emote
requests carry no Twitch authentication headers.

Live endpoint checks on 2026-09-16 confirmed that Twitch accepts the public client
from `smarttv-twitch` for device-code requests with the requested scopes (HTTP
200, a 30-minute code, five-second polling interval). A deliberately invalid
refresh token returns HTTP 400 `Invalid refresh token`, without requiring a
client secret. These checks did not approve an account or verify a real token
exchange, refresh, or personalized channel response.

At baseline commit `61afe43`, BrighterScript 0.73.5 reports 21 existing errors in
`OfflineChannelList.xml` and `components/web_socket_client/`. The startup patch
must not add diagnostics. Do not interpret that unchanged baseline as a clean
whole-project compile.

## Device acceptance

On Roxton, the user confirmed that `e98d79c` loads content and exits to Roku Home
instantly, but remote navigation remained broken. The user subsequently confirmed that the focus and sidebar build (`2310fc8`)
restored remote navigation. Their login photo showed an HTML error document in
the code label; the retired Heroku register endpoint returned HTTP 404, "No such
app". The user subsequently reported a signed-in profile chip and populated
Following content on Roxton. The first Twellie UI build (`ae58e87`) exposed
misaligned tabs, oversized account controls, square offline avatars, and missing
live rows after returning from a channel page. These are device observations;
token refresh, playback, and the revised layout still need their own verification.

1. Sideload the updated ZIP and launch with no saved login. Confirm the header
   responds immediately and content appears. Press Down to enter the grid.
2. Launch while internet access is unavailable. The app should show a connection
   error after the request deadline (10 seconds per request); the header and Home
   button should remain responsive. Restore connectivity, select Live Channels
   or Categories, and confirm retry succeeds.
3. Switch tabs while loading; try an empty result and a category with fewer than
   seven entries. Confirm rows render and the header remains reachable.
4. Return from Search to Home and confirm focus reaches the header or grid.
5. Select Login and scan the QR with your phone. Confirm Twitch opens with the
   code already filled in, then approve Twellie. Also check manual code entry.
   Confirm Home shows your username, Following shows live/offline follows. An account with no live
   followed channels should retain usable header or offline-grid focus.
6. Press Back while awaiting approval, then reopen Login. Confirm the cancelled
   attempt cannot complete the new one and a fresh code appears. Let a code expire
   and press OK to retry. Try login with the network disconnected: an error must
   replace the waiting state, never HTML in the code label.
7. Relaunch after successful login and confirm the account restores. Verify a
   real expired session refreshes and browsing remains responsive. Confirm
   returning to Home during a login request does not pause remote input.

Capture a launch log from the device's developer console with
`nc DEVICE_IP 8085` before launching. The new request diagnostics include HTTP
status/failure reasons and avoid printing authentication tokens. Hardware checks
remain pending until performed on the affected device.

## Twellie interface and playback regressions

The combined runner also executes the two chat suites. New checks cover
four-column packing, removal of the Settings navigation slot, offline-only
Following focus, category/channel return routes, stale stream/VOD callbacks,
quality names and HLS attribute ordering, audio/codec filtering, Auto selection,
buffering and non-advancing playback, native invalid initial timestamps,
stopped-state handoffs during quick reopen, late callbacks after Back, chat
preference isolation for recorded video, and retained position/pause on switches.
Clip checks cover slugs, actual signed MP4 qualities, query escaping, the exact
seven-day period, cancellation, and exhausted pagination. Chat checks cover
partial IRC lines, message floods, bounded rendering and queue lengths, hidden
startup, cooperative cancellation, and delayed restart after a fast toggle.

The `brs` interpreter does not emulate the native decoder or SceneGraph event
scheduler. It also has a nested-quote FormatJSON bug; request tests inspect the
query structures, and live checks serialize the production query with Python.

On 2026-09-16, the exact production live query and Twitch master returned HTTP
200. The checked stream offered 1080p60, 720p60, 480p30, 360p30 and 160p30; Auto
selected 480p30. The production clip query returned four signed MP4 qualities;
a 1024-byte media-range request returned HTTP 206. No account approval or user
token was involved. The new UI
removed the old OfflineChannelList diagnostic; the compiler now reports the
remaining 20 pre-existing unused WebSocket diagnostics, with no new diagnostics.

Device acceptance for this build:

1. Compare Channels, Games, Following, Search, Login, and the channel/VOD page
   to Twellie. Confirm four-column grids, white focus, no side rails or Settings.
2. Open a live card directly. With chat disabled, confirm full-screen video and
   no chat connection. Toggle Chat on and off; relaunch and check persistence.
3. Open Quality using the on-screen button or `*`. Select 480p, then another
   available quality, then Auto. Verify the selected quality persists across
   streams; Auto steps down when the decoder stalls.
4. Press Back during loading, while the quality menu is open, during a quality
   switch, and after video starts. Confirm each layer closes and browsing
   responds. Reopen another stream quickly while the old decoder stops.
5. Play a VOD and a clip, seek, pause, and change quality. Confirm time and pause
   state survive switching. Verify recorded video never opens live chat.
6. Try a busy live chat, then hide it and leave playback. Confirm no remote lag
   or messages leak into the next stream.

TV rendering, actual codec support, uninterrupted playback, and remote latency
remain device acceptance checks, not claims established by these doubles.

## Account and Following corrections

The additional regressions cover signed-in account display without starting a
new device grant, local logout with stale-session rejection, public follower
counts (including zero and unavailable data), native spinner lifecycle, measured
header geometry, and one combined Following list. Following checks include mixed
four-column live and six-column offline rows, partial rows, duplicate exclusion,
focus preservation across refresh, and returning from a channel page.

On Roxton, verify that tab text is vertically centered and both underlines end
with their labels. Check short and long account names: the chip should fit its
contents and center the avatar/name together. Open the chip while signed in,
press Back, and confirm the account and Following remain intact. Use Log out to
clear the account, then sign in again.

Scroll from live streams through all offline profiles as one surface. Confirm
avatars are circular and their focus ring stays in front. Open both a live
channel's profile with `*` and an offline profile with OK, then press Back and
check that the same item remains selected with live rows still present. Repeat
while a followed-channel refresh is in progress and with no live follows.

While browsing, searching, opening a profile, signing in, or starting playback,
only a spinner should indicate pending work. Completion, failure, cancellation,
and leaving a screen must stop its visible spinner. Game covers now request
285×380 pixels instead of enlarging 136×190 thumbnails.

## In-app fMP4 compatibility

The combined runner includes production fMP4 parsing/patch decisions and media
playlist rewriting. Relay tests cover HTTP requests, byte ranges, partial headers,
connection limits, shared downloads, cache eviction/pinning, deadlines, and cleanup.
Player regressions cover split/direct preparation, cancellation
on Back or a new quality, late results, missing results, bounded preparation
fallback, active relay failure, original URL preservation, and recorded resume
position. Local segment timings must not feed Internet bandwidth adaptation.

Run the additional media proof with `brs`, FFmpeg and ffprobe installed:

```sh
python3 tests/verify_fmp4.py --brs /path/to/brs --server-spans
```

It generates an audio-first fragmented MP4, feeds its bytes to the production
BrightScript parser, applies the returned patches, and compares selected packet
hashes/timestamps plus decoded frame hashes/timestamps. `--server-spans` also
checks production HTTP span construction and partial writes at patch boundaries.
To check an existing combined initialization-and-media capture, add
`--fixture /path/to/capture.mp4`.
Fixtures remain outside the repository. The off-device interpreter substitutes
native byte-array storage, sockets, transfers, and SceneGraph events; it does not
prove native Roku decoder acceptance or on-device CPU cost. See
[device acceptance](../docs/playback-compatibility.md#verification-and-device-acceptance).
