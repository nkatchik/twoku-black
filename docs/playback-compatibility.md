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
provides the listener and ranged byte-array sends. Signed CDN URLs stay inside
the Task; native playlists contain opaque local resource routes. Only Twitch CDN
HTTPS URLs are accepted, with no account credentials attached. Native HTTPS may
follow redirects before returning headers; responses exposing a redirect are
rejected instead of resolving relative segment paths against the wrong base.

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

These checks cannot prove that Roku's native player accepts the repaired views.
The remaining Roxton checks are:

1. Open a currently live affected fMP4 stream and confirm moving video and audio,
   including a selected 1080p60 rendition if offered. Compare a known-working
   MPEG-TS stream such as `asmongold247` when live.
2. Leave playback running across playlist refreshes and an ad/content transition;
   check audio/video synchronization and remote responsiveness.
3. Change quality repeatedly, press Back while preparing and playing, and reopen
   another stream immediately. Home should remain prompt throughout.
4. Exercise VOD seeking and pause through a quality switch, and play a direct MP4
   clip. Toggle chat and confirm the hidden state remains respected.

No hardware playback or CPU-utilization result is claimed by the off-device proof.
