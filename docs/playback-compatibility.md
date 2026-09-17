# Twitch delivery compatibility investigation

Checked on 2026-09-16. These findings concern media packaging, not the advisory
device-capability checks used to rank Auto quality. No quality is blocked on the
basis of these findings.

## Alternate delivery checks

`solo` was offline during this investigation: its stream metadata was null and
all five tested master requests returned HTTP 404. Earlier captures included
preroll, so they alone could not establish the broadcaster's underlying format.

An active stream, `zubarefff`, provided a non-ad example of the same combined
audio/video fMP4 packaging. Each request below returned five video qualities.
Both the 1080p60 and 480p30 playlists had `EXT-X-MAP`, and their initialization
segments contained both `soun` and `vide` tracks. None declared a separate audio
rendition for video playback.

| Request | Result |
| --- | --- |
| Existing `/api/channel/hls/`, H.264 | Combined audio/video fMP4 |
| `/api/v2/channel/hls/`, same parameters | Combined audio/video fMP4 |
| v2, Streamlink's embed/site token and `multigroup_video=true` | Combined audio/video fMP4 |
| v2, advertising `av1,h265,h264` | Combined audio/video fMP4 |
| v1, TV token (`web_tv`/`pulsar`), `transcode_mode=cbr_v1` | Combined audio/video fMP4 |

For comparison, inspected `asmongold247` renditions used MPEG-TS on both v1 and
v2, confirmed by transport-stream sync bytes. Changing endpoint did not change
the packaging of either active channel.

This does not prove that every undocumented Twitch parameter behaves identically.
It provides no evidence for a working URL-only compatibility fallback.

Primary-source context:

- [Roku streaming specifications](https://developer.roku.com/dev/docs/media)
  exclude combined audio/video CMAF renditions.
- [Streamlink's Twitch documentation](https://streamlink.github.io/cli/plugins/twitch.html#higher-quality-streams)
  explains that Enhanced Broadcasting's lower-quality transcodes also use fMP4.
- [The Usher v2 change](https://github.com/streamlink/streamlink/pull/6840)
  describes no functional changes; [multigroup video support](https://github.com/streamlink/streamlink/commit/cedd6e781032f2ba00ee576ed18dc3b96a51f393)
  adds landscape/portrait selection.

## Local repair experiment

Replacing the unwanted track's `trak`, `trex`, and `traf` box types with
same-size `free` boxes produced separate audio/video views while preserving
all media bytes and offsets. This is a packaging transformation, not transcoding.

The experiment passed for five earlier captures (four unique payloads) and a
fresh non-ad 1080p60 sample from `zubarefff`. For the latter, each view changed
62 bytes in a 1,893,048-byte capture. Validation confirmed:

- Exactly one audio or video stream in each view.
- Identical selected packet hashes, timestamps, durations, and sizes.
- Identical decoded frame hashes and timestamps: 120 video and 94 audio frames.
- Unchanged `mdat` payloads and no FFmpeg/ffprobe decoding errors.

## In-app prototype

`PlaybackCompatibility` is a persistent SceneGraph Task that prepares the selected
HLS leaf before `CustomVideo` starts the native decoder. It uses asynchronous
native HTTPS transfers and a loopback listener bound to `127.0.0.1` with an
operating-system-assigned port. The [Roku stream-socket API](https://developer.roku.com/dev/docs/rostreamsocket)
provides the listener and ranged byte-array sends. In split mode, signed CDN URLs
stay inside the Task and native playlists contain opaque local resource routes. Only Twitch CDN
HTTPS URLs are accepted, with no account credentials attached. Native HTTPS may
follow redirects before returning headers; responses exposing a redirect are
rejected instead of resolving relative segment paths against the wrong base.

For MPEG-TS, the Task serves only a single-rendition master carrying the selected
quality's bitrate, resolution, frame rate, and codecs. Its media-playlist URL is
the original signed Twitch CDN URL. Native HLS downloads all playlists and media
directly; BrightScript neither proxies nor decodes their payloads. This keeps
manual quality selection exact and preserves real CDN throughput measurements.

For a verified combined audio/video initialization segment, the Task creates one
master and two media playlists. `Fmp4Compat.brs` returns four-byte box-type patches;
the HTTP writer interleaves those patches with ranges of the original byte array.
Audio and video requests share the upstream cache. No encoded media is modified
or decoded by BrightScript, and there are no byte-by-byte loops over media payloads.

This first version deliberately retains the full original payload in each track
view. Local delivery therefore carries roughly twice the stream bitrate, while
shared cached segments avoid a second Internet download. The original media cache
is capped at 12 MiB, with at most eight media and four initialization entries;
pending native downloads and HTTP metadata add overhead. This is a bounded design,
not a measured Roxton CPU or total-memory figure.

Live refreshes preserve media sequence numbers, discontinuities, initialization
map changes, and completed segment durations. Each segment uses its own map's
track IDs. Partial segments and low-latency hints are omitted, which can add live
latency. Encrypted, byte-range, delta, and unrecognized layouts are left to direct
playback when detected during preparation. Unsupported changes after a relay has
started go through the player's finite recovery path.

Back/Home and quality changes invalidate the request and cancel the Task without
waiting for its cleanup. Preparation has a 15-second player-side fallback to the
original URL. Manual qualities remain selectable. Native loopback download timings
are excluded from Internet bandwidth decisions; the existing buffering and stalled
position watchdogs remain active.

## Roxton freeze follow-up

The first prototype froze the app when the user opened `zubarefff` on Roxton.
The relay was polling its Task fields and publishing statistics while serving
localhost requests. [Roku's threading documentation](https://developer.roku.com/dev/docs/threads)
confirms that these operations synchronously wait for the render thread, including
access to a Task's own fields. Its ready-result observer also started Video before
returning, leaving a circular dependency if native startup waited for that server.

The follow-up build snapshots inputs once and consumes cancellation/request changes
from message-port events. It performs no SceneGraph field access while serving.
Sockets, transfers, and temporary files close before terminal fields are published.
The player defers startup to a separate timer event; other callbacks cannot bypass
that boundary, and Back or a quality change invalidates the pending start.

A regression now makes the Task's `m.top` unavailable from readiness until the
listener closes, so a field access anywhere in the active serving path fails the
test. Fixed stage names and numeric diagnostics help distinguish preparation,
serving, native startup, and cleanup without printing signed URLs. That change
removed a threading hazard, but the user reported the same freeze afterward.

Connecting to the device console then established the actual crash: during
`AsyncGetToFile` startup, `roFileSystem.Stat()` returned an empty associative array.
Comparing its missing `size` with the download limit raised a BrightScript type
mismatch and suspended all threads in the debugger. The native filesystem contract
only supplies [a size for file entries](https://developer.roku.com/dev/docs/iffilesystem);
it does not guarantee `invalid` for a missing path.

`compatStatSize` now validates the numeric size before either polling or completion
logic uses it. An unknown pending size keeps waiting; an unknown size after transfer
completion produces a handled file error. Regression tests reproduce the empty
native result, delayed file creation, and a missing completed file.

## Device verification on 2026-09-16

The corrected package was installed directly on the supplied device, which reports
model K806X and Roku OS 15.3.4. `zubarefff` entered the split compatibility path,
completed native startup, and played across repeated live playlist refreshes without
a new debugger error. The native player reported HLS with AAC audio and H.264 video.

- At 1920×1080, playback advanced from 31,736 to 36,783 ms across a five-second check.
- Switching to 852×480 also resumed playback; position advanced from 11,042 to
  15,079 ms, and later segment reports confirmed the 480p video dimensions.
- Auto was restored, and playback was reopened successfully.
- Back changed the native player to `close` in approximately 327 ms.
- Home reached the Roku home screen in approximately 1,023 ms from active playback.
- Twoku was relaunched afterward, leaving the corrected build installed.

Those timings include the local network command and status-query overhead.
A single one-second `query/chanperf` sample during 1080p playback reported 2.3% user
and 0.8% system CPU for the app process, with about 119 MB resident memory. This is
an app-wide snapshot, not a sustained benchmark or the relay's isolated cost.
The developer screenshot omitted the video plane, so visual motion, audible audio,
and synchronization still need the user's confirmation.

## Decoder failure after repeated stream changes

Later on 2026-09-16, the device entered a state where every attempted rendition
failed with native error `-3`, category `mediaplayer`, detail `17`: "Failed to
create decoder". This occurred on direct HLS deliveries as well, so the split
relay was not required for the failure. Restarting Twoku created a fresh process
but reproduced the same error on another live channel and every quality.
Reinstalling the app also left the failure intact. A full TV system restart
cleared the failure and allowed native playback to advance again.

The lifecycle audit found two application defects: Back, visibility changes and
scene cleanup could each issue a native stop for the same close; terminal
`error`/`finished` states were accepted as idle before explicit shutdown completed.
Native tracing confirmed that stopping from `error` does produce a `stopped`
acknowledgement on this device. [Roku's asynchronous stop contract](https://developer.roku.com/dev/docs/video)
requires shutdown to complete before another load uses the media player.

`CustomVideo` now tracks decoder ownership before submitting play, makes stop
idempotent, consumes shutdown completion even while hidden, and releases old
content only after acknowledgement. Queued playback starts on a later render
event. Back can cancel that queued start. Error recovery and manual quality
switches use the same handoff, without removing any quality choices.

After the system restart, the corrected build passed twelve consecutive native
close/reopen cycles alternating between live streams. Every cycle reached
`play` with `error=false` and advancing position. Selection-to-play times ranged
from 1,722 to 2,456 ms, including ECP round trips and polling. Console traces
showed paired stop requests/completions without new native or runtime errors.
Four additional loads were canceled during native buffering; each stopped once
and acknowledged completion. A final reopen advanced from 10,049 to 13,568 ms
with `error=false`, and playback was left running.
All 33 deterministic suites passed; the compiler still reports the same twenty
pre-existing diagnostics in the unused legacy WebSocket code.

The persistent native failure is established; its original trigger inside Roku's
decoder is not. The lifecycle changes remove concrete races but do not establish
that those races caused the device-level failure or that it cannot recur.

## Verification and device acceptance

The deterministic BrightScript suites cover container bounds and offsets, HLS
rewriting, relay request handling, sparse delivery, cache limits, cancellation,
late callbacks, direct fallback, and retained VOD position. The production parser
and patch generator are also exercised by `tests/verify_fmp4.py`, with ffprobe
packet hashes and FFmpeg decoded frame/timestamp comparisons. `--server-spans`
additionally checks the production writer under partial writes and backpressure.
The recorded 1,893,048-byte Twitch 1080p60 sample passed with 94 audio and 120 video
packets/decoded frames preserved; each view uses 21 four-byte patches. The default
fixture is generated locally, so no downloaded stream recording is required.

The off-device checks are separate from the native results above. Remaining
acceptance checks cover visible motion and audible sound, synchronization across
an ad/content transition, sustained throughput/CPU usage, and VOD seeking/pause,
MP4 clips, and chat behavior during compatibility playback.

## MPEG-TS frame freeze on K806X (2026-09-17)

`stariy_bog` reproduced a distinct failure on the supplied TV. Source was
1920x1080 at 60 fps, AVC High level 4.2, approximately 6.9 Mbps, in MPEG-TS.
A fresh session included a 30 fps preroll followed by the 60 fps broadcast;
the media container remained MPEG-TS throughout. The fMP4 relay was not active.

Temporary native instrumentation enabled `Video.enableDecoderStats` and sampled
`decoderStats` each watchdog tick. With the bare rendition URL, `renderCount`
stopped at 2661 while playback position advanced through the 60–70 second range.
Video later crawled forward while position stopped at 93 seconds, eventually
triggering the existing `progress-timeout` recovery. Native HLS reported the
rendition bitrate as 128000 bps despite the advertised 6.9 Mbps source.

Passing Twitch's full master instead kept source frames rendering beyond two
minutes and exposed the actual rendition bitrate in `streamingSegment`. The
production fix retains that metadata in a local master containing exactly one
selected rendition. No global resolution/frame-rate restriction or transcoding
is introduced. The master-only listener uses the existing deferred startup and
cancellation lifecycle; unsupported preparation still permits the original URL.

Regression coverage includes exact rendition metadata and URL preservation,
master-only HTTP routing without media downloads, cancellation without Task/render
rendezvous, and retained native CDN bandwidth samples. The separate browse-focus
fix covers delayed first results, header navigation while loading, hidden views,
pagination, and returning from playback.

The selected-rendition master then passed a 210-second device capture (182 seconds
of reported playback after install/startup): `renderCount` reached 9761, video
continued advancing beyond the original freeze window, and no buffering timeout,
progress timeout, or native-error recovery occurred. Tests used temporary logging;
the shipping build does not enable decoder-stat sampling. Frame counters confirm
render progress, but rounded epoch timestamps in the log are not a measurement of
audio/video synchronization or a substitute for watching the TV.

All 34 deterministic suites pass. Native compilation succeeded. BrighterScript
still reports the same 20 errors confined to the legacy `web_socket_client`
sources; no new diagnostics were introduced.
