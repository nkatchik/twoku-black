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

This is off-device evidence only. An in-app implementation could use a persistent
Task and a loopback HTTP listener, supported by the documented
[Roku stream-socket API](https://developer.roku.com/dev/docs/rostreamsocket).
It still needs native player validation of the rewritten fragments, synchronized
audio/video, sustained Roxton throughput, responsive Back/Home, bounded caching,
live playlist refreshes, and ad/quality discontinuities. No repair or helper is
currently bundled in the app.
