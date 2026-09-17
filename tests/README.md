# Regression checks

The [Tests workflow](../.github/workflows/tests.yml) runs on every push and pull
request, and can also be started manually. It compiles the app and runs 32 BrightScript suites,
release packaging tests, font checks, independent QR decoding, and the generated
fMP4 packet/frame proof with HTTP span checks. No Roku or Twitch account is needed.

To run the same checks locally with Node.js, Python 3 and FFmpeg installed:

```sh
python3 -m venv /tmp/twoku-test-python
/tmp/twoku-test-python/bin/python -m pip install -r tests/requirements.txt
npm install --prefix /tmp/twoku-validation --no-audit --no-fund brs@0.45.0 brighterscript@0.73.5
/tmp/twoku-validation/node_modules/.bin/bsc --no-project --create-package false --copy-to-staging false
/tmp/twoku-test-python/bin/python tests/run.py --brs /tmp/twoku-validation/node_modules/.bin/brs
/tmp/twoku-test-python/bin/python tests/release.py
/tmp/twoku-test-python/bin/python tests/fonts.py
/tmp/twoku-test-python/bin/python tests/verify_qr.py /tmp/twoku-qr-test-output.txt --decode
/tmp/twoku-test-python/bin/python tests/media_probe.py
/tmp/twoku-test-python/bin/python tests/verify_fmp4.py --brs /tmp/twoku-validation/node_modules/.bin/brs --server-spans
```

Release packaging checks verify the requested Git commit, manifest version,
archive contents, and checksum while preserving the checkout. The release workflow
takes major/minor integers and uses `github.run_number` for the build number;
retries keep the same version. Only the packaged manifest is stamped, with the
build padded to at least five digits. Tags use `vMAJOR.MINOR.BUILD` without padding.
The checks also cover repeatable builds, advancing run numbers, and invalid inputs.

Font coverage and packaging references have a separate asset check:
`python tests/fonts.py` with `fonttools==4.65.0`. See
[fonts/README.md](../fonts/README.md) for setup and reproducible generation.
The coverage check reads real glyph outlines; Roku rendering still needs a
device check. On Roxton K806X / Roku OS 15.3.4, the replacement font rendered
CJK, Korean, accented Latin/Greek/Cyrillic, Thai, and common monochrome emoji;
the Channels grid also displayed live Japanese titles and display names.

Pagination checks cover the visible-window threshold plus two reserve rows,
pending Task startup, continuing after Task completion, overlapping/empty pages,
repeated cursors, errors, hidden views, and retaining content identity and focus
while pages arrive. Channels, Games, game streams, clips, and profile recordings
share the append helper. Existing rows stay attached; only initial content moves
the cursor to the first cell. On Roxton, rapid Down presses through multiple
pages with an injected two-second delay produced no backward focus movement in
Channels, Games, or game streams. Additional requests started at row 2 of 6 for
Channels and row 3 of 6 for Games/game streams. Diagnostic delays and logging
are excluded from the shipped app.

The suites execute production BrightScript functions. Transport, task fields,
and SceneGraph nodes use deterministic doubles; the runner substitutes platform
primitives that the off-device interpreter does not implement. These checks cover
finite request waits, failed async starts, invalid token/JSON responses, a maximum
of one authentication retry, anonymous startup, parent focus routing, empty grids,
partial content rows, and failed or exhausted pagination. Focus doubles enforce
one active target and walk the parent chain. Navigation checks cover the route to
Login, moving between header and grid, and restoring focus after screen display.
Following checks cover its shared scrolling view, focus, empty states, and
returning to the header when there is no content. These tests do not validate
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

The device notes below record earlier builds and their test counts. The unused
WebSocket implementation and its 20 compiler errors have since been removed;
the current app compiles cleanly, and CI checks compilation on every push.

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
Decoder lifecycle checks include repeated Back/visibility/scene cleanup before
native state changes, twenty opens canceled before their first buffering event,
hidden shutdown completion, error/finished states awaiting stop, and cancellation
between the stopped acknowledgement and deferred restart.
Clip checks cover slugs, actual signed MP4 qualities, query escaping, the exact
seven-day period, cancellation, and exhausted pagination. Chat checks cover
partial IRC lines, message floods, bounded rendering and queue lengths, hidden
startup, cooperative cancellation, and delayed restart after a fast toggle.
They also reproduce a native socket that remains `IsConnected=false` with status
115 (`EINPROGRESS`) after becoming writable. Connection refusal, DNS failure,
failed/partial/stalled sends, missing or split channel acknowledgements, handshake
deadlines, and retry backoff are covered without sending account tokens or chat
messages.

On 2026-09-16, the supplied K806X device reproduced the stale connection flag:
`Connect()` returned true and `IsWritable()` was true after ten seconds, while
`IsConnected()` remained false with status 115. Using writable readiness allowed
the anonymous IRC handshake to complete. The corrected build displayed live chat
messages for `eliasn97` during native playback; hiding and reopening chat also
restored messages without an endless spinner. Developer screenshots confirmed
the chat UI, and the native player continued reporting advancing playback.

The `brs` interpreter does not emulate the native decoder or SceneGraph event
scheduler. It also has a nested-quote FormatJSON bug; request tests inspect the
query structures, and live checks serialize the production query with Python.

The UI follow-up on 2026-09-16 covers a late login refresh after Channels has
loaded, results arriving before Task stop, short pages filling existing rows,
background feed completion, and Following focus during both animation axes.
Stream pages now request 24 items, while packing handles any returned count.
Initial native screenshots confirmed that logged-in startup no longer leaves a
spinner and offline Following rings remain complete. The later refinement below
replaces that build's crossfade with a single moving cursor.

VOD token variables use lowercase `vodid` in both the query and serialized map.
Native BrightScript lowercases associative-array literal keys, unlike the test
interpreter; GraphQL variable names must match exactly. See the
[Roku explanation of literal key casing](https://forum.developer.roku.com/t/formatjson-results-in-a-lower-case-string/7753/2).
On the device, a recording selected from the offline Asmongold profile played
with `is_live=false`, `error=false`, and position advancing from 5,115 to 36,059 ms.
Player screenshots confirmed the 96-pixel photo aligned with the metadata and
image-based quality chevrons in place of missing font glyphs.
Live playback also displayed the enlarged aligned photo and a button labeled
`Chat` while messages were visible. The chat heading reached the top and both
side edges of its rail, retaining its bottom gap. Empty status text uses a
centered label spanning the chat body; no empty-chat native screenshot was taken.
The final build passes all 34 deterministic suites (plus the rerun of the final
focus guard); compilation retains the same twenty legacy WebSocket diagnostics.

The subsequent UI refinement on 2026-09-16 uses one fully opaque Following cursor
above the RowList. Horizontal position follows native `currFocusColumn`; vertical
movement hides it until the destination row settles. Native screenshots show one
circle between adjacent avatars during horizontal movement, a centered complete
ring after settling, and no intermediate vertical ring. No followed live channels
were available during this check; mixed-row rectangle geometry and cursor state
were covered by the deterministic suite.

Player screenshots confirmed 24 pixels of top padding, aligned 96-pixel artwork,
and a uniform two-pixel quality-panel outline. Twitch's public metadata returned
`/_404/404_processing_...` for a newest recording. The device showed channel artwork
for that processing card while retaining real thumbnails on older recordings.
Failed image loads use the same fallback. The account avatar has no opacity
reduction in its render chain, and the inspected source image itself was opaque
RGB with pale, pixelated artwork.

Seek regressions cover the IR initial-repeat gap, accumulation across stale
position notifications, only one outstanding native seek, release debounce,
queued direction changes, decoder-stop guards, and pause intent surviving late
playing events. `seekMode=accurate` requests native precision where supported.
On this device, `autoplayAfterSeek=false` left some paused seeks buffering; the
final code lets native buffering finish and restores pause after position
acknowledgment, including a playing event that arrives after that acknowledgment.
It re-arms an unchanged pause command through `control=none` before `pause`.

The final native remote-API test started paused at 4.099 seconds. Ten forward
presses (with a 500 ms initial gap, then 80 ms repeat gaps) settled paused at
104.000 seconds. Four backward presses settled paused at 64.000 seconds; explicit
resume returned to playing at 65.017 seconds. Every sampled player result had
`error=false`. This verifies real decoder behavior with synthetic remote input,
not the physical IR handset's delivery timing. All 34 suites passed, with the
final pause-ordering additions rerun in the player suite; compilation retains
the same twenty pre-existing diagnostics in the unused WebSocket implementation.

The 2026-09-17 follow-up replaces `currFocusColumn` for Following cursor placement.
Settled item indices are authoritative; the incoming item's `focusPercent` drives
horizontal interpolation. Outgoing items cannot pull the cursor back, and vertical
movement still snaps after settlement. The live outline is four three-pixel
rectangles inside the 292-by-164 thumbnail, offset six pixels from the native
reported item origin. A regular Poster does not render the grid's nine-patch
focus artwork with the same geometry.

No followed channels were live during verification, so a temporary native scene
used the unchanged production Following components with four local live cards
and six local avatar cards. The device reported focus `offline6`, `live4`,
`offline6`, then `offline5` after Left; OK selected `offline5`. Screenshots matched
every settled item, showed a solid circle between items during motion, and showed
the final rectangular border aligned to all four thumbnail edges. The temporary
scene performed no network or account writes; the normal app was restored.

Channel profiles now prepend a live card from a fresh Helix stream lookup. Tests
cover live/offline/failed status, live and VOD request routing, stale results,
recording IDs after insertion, and preserving the playback spinner when metadata
arrives. On the device, the eliasn97 profile displayed the live card and recordings;
the new card reached native `play` with `is_live=true` and `error=false`. An older
recording from the same grid reached `play` with `is_live=false` and `error=false`.
The account button uses four pixels of outer padding and fully opaque white idle
text, verified in its native header screenshot. All 34 suites pass; compilation
still reports only the same twenty legacy WebSocket diagnostics.

The later 2026-09-17 UI build (`96f4f4b`) was installed and checked on the Roxton.
Native screenshots confirm the compact account avatar/name gap, the Channels
and Games grid edges aligned with the header, and the centered seek track sharing
the photo and Channel button's left edge. Following's live cards use the same
left edge. The package uses the existing text-free TV icon for its splash; native
startup reported a 27 ms splash with no forced display delay.

Following now follows native `currFocusColumn` during horizontal motion, while
settled item notifications remain authoritative across rows. Rapid remote-API
direction reversals at 40 ms intervals settled on one complete ring; opening the
profile selected the visibly focused channel. Moving from offline column six to
the two-item live row selected live column two. Down then settled on offline
column three; Left selected column two, matching the displayed ring and opened
profile. Both live thumbnail borders and offline rings were complete in the
settled screenshots. These checks used the normal app and real followed channels.

A single remote-API Right key-down held for two seconds, followed by key-up,
advanced a paused VOD from 30.320 to 140.033 seconds. The decoder stayed at the old
position during the hold and received one seek on release. A 1.1-second Left hold
then landed at 90.033 seconds. Both operations restored pause, remained stable
after release, and reported `error=false`. Resume advanced playback to 91.047
seconds; Back returned to browsing with the decoder closed. This verifies held
input through Roku's remote API, not the physical IR handset's event timing.
The installed production build was left on Following. All 34 deterministic suites
passed before deployment; no source changes were needed during this device check.

Held seeking now ramps from 10-second steps to 30 seconds at 1.5 seconds held,
60 seconds at 3 seconds, and 120 seconds at 5 seconds. A monotonic clock controls
the ramp; the preview timer keeps its existing cadence. Deterministic checks cover
thresholds, delayed timer callbacks, duplicate IR events, reversing direction,
fresh holds, release cancellation, endpoint clamping, and one native seek on
release. Taps still move ten seconds, and reversal restarts at the slow rate.

The next focus refinement uses the same nine-patch for focused and unfocused
grid states, with the unfocused bitmap transparent. This prevents the initial
frame from inheriting different default margins. First-selection screenshots
on Channels, Games, and a game's streams confirm symmetric borders before any
horizontal movement. Following's live frame now matches their four-pixel stroke
and three-pixel thumbnail gap, with clipping expanded to contain the border.

Following shows its frame as soon as `rowFocusPercent` reaches one rather than
waiting again for `rowItemFocused`. A local-content device probe recorded the
frame becoming visible 16–65 ms before that later notification. It also verified
offline column six → live column four → offline column six → Left → column five;
OK selected the fifth offline channel. The native screenshot showed the live
border separated from every thumbnail edge. The added delayed-notification
regression and all 34 suites pass; compilation still has the same twenty unused
WebSocket diagnostics.

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
While the relay is active, its SceneGraph node is made unavailable to catch field
access that would wait for the render thread on a device. Cancellation is delivered
through copied node events, including events arriving around the input snapshot.
Player tests require the ready observer to return before native content/control
changes, reject callback shortcuts around the deferred start, and cancel late timer
events on Back or a quality change. Other player regressions cover split/direct preparation, cancellation
on Back or a new quality, late results, missing results, bounded preparation
fallback, active relay failure, original URL preservation, and recorded resume
position. Local segment timings must not feed Internet bandwidth adaptation.
Filesystem doubles reproduce Roku's empty `Stat` result before a download file
exists; tests distinguish waiting for file creation from a missing completed file
without comparing an absent size to a number.

Run the additional media proof with `brs`, FFmpeg and ffprobe installed:

```sh
python3 tests/verify_fmp4.py --brs /path/to/brs --server-spans
```

It generates an audio-first fragmented MP4, feeds its bytes to the production
BrightScript parser, applies the returned patches, and compares selected packet
hashes/timestamps plus decoded frame hashes/timestamps. `--server-spans` also
checks production HTTP span construction and partial writes at patch boundaries.
FFprobe 6.1 may omit the first audio packet's duration; the verifier derives
missing durations from decoded sample counts at the packet's timestamp. Explicit
durations and decoded frame timing remain part of the comparison. `tests/media_probe.py`
checks this fallback and verifies that changed packet fields still differ.
To check an existing combined initialization-and-media capture, add
`--fixture /path/to/capture.mp4`.
Fixtures remain outside the repository. The off-device interpreter substitutes
native byte-array storage, sockets, transfers, and SceneGraph events; it does not
prove native Roku decoder acceptance or on-device CPU cost. See
[device acceptance](../docs/playback-compatibility.md#verification-and-device-acceptance).
