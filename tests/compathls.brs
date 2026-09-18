sub main()
    nl = Chr(10)
    q = Chr(34)
    base = "https://video-edge-a.hls.ttvnw.net/channel/path/index.m3u8?token=secret"
    header = "#EXTM3U" + nl + "#EXT-X-VERSION:9" + nl + "#EXT-X-TARGETDURATION:2" + nl
    playlist = header + "#EXT-X-MEDIA-SEQUENCE:12345" + nl + "#EXT-X-DISCONTINUITY-SEQUENCE:9" + nl
    playlist += "#EXT-X-MAP:URI=" + q + "../init.mp4?sig=first" + q + nl
    playlist += "#EXT-X-PROGRAM-DATE-TIME:2026-09-16T12:30:00.000Z" + nl + "#EXTINF:2.000,private title https://example.test" + nl + "first.m4s?sig=one" + nl
    playlist += "#EXT-X-DISCONTINUITY" + nl + "#EXT-X-MAP:URI=" + q + "/ad/init.mp4?sig=second" + q + nl
    playlist += "#EXTINF:1.500," + nl + "//video-edge-b.hls.ttvnw.net/ad/second.m4s" + nl
    playlist += "#EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES" + nl + "#EXT-X-PART-INF:PART-TARGET=0.2" + nl
    playlist += "#EXT-X-PART:DURATION=0.2,URI=" + q + "part.m4s" + q + nl + "#EXT-X-PRELOAD-HINT:TYPE=PART,URI=" + q + "next.m4s" + q + nl
    playlist += "#EXT-X-TWITCH-PREFETCH:https://video-edge-a.hls.ttvnw.net/future.m4s" + nl
    playlist += "#EXT-X-RENDITION-REPORT:URI=" + q + "other.m3u8" + q + nl + "#EXT-X-ENDLIST" + nl
    parsed = compatParseMedia(playlist, base)
    check(parsed.valid and parsed.hasMap and parsed.endList, "Completed fMP4 playlist parses")
    check(parsed.entries.Count() = 4 and parsed.mediaSequence = 12345 and parsed.targetDuration = 2, "Segments, initialization maps and timing remain available")
    check(parsed.firstInitUrl = "https://video-edge-a.hls.ttvnw.net/channel/init.mp4?sig=first", "Relative init URL resolves dot segments without copying the playlist token")
    check(parsed.entries[1].url = "https://video-edge-a.hls.ttvnw.net/channel/path/first.m4s?sig=one", "Relative segment URL preserves its signed query")
    check(parsed.entries[1].initUrl = parsed.entries[0].url and parsed.entries[3].initUrl = parsed.entries[2].url, "Each segment retains its own initialization map across ad discontinuities")
    check(parsed.entries[3].url = "https://video-edge-b.hls.ttvnw.net/ad/second.m4s", "Scheme-relative trusted media host resolves")
    registry = {baseUrl: "http://127.0.0.1:32123", resources: {}, idmap: {}, counter: 0}
    video = compatRewriteMedia(playlist, base, "video", registry)
    audio = compatRewriteMedia(playlist, base, "audio", registry)
    check(video.valid and audio.valid and registry.counter = 8, "Each track has a distinct opaque resource view")
    check(Instr(1, video.text, "https://") = 0 and Instr(1, audio.text, "secret") = 0 and Instr(1, video.text, "sig=") = 0, "Native playlists contain no upstream URLs or signed queries")
    check(Instr(1, video.text, "#EXT-X-MEDIA-SEQUENCE:12345") > 0 and Instr(1, video.text, "#EXT-X-DISCONTINUITY-SEQUENCE:9") > 0, "Media and discontinuity sequence values survive rewriting")
    check(Instr(1, video.text, "#EXT-X-DISCONTINUITY" + nl) > 0 and Instr(1, video.text, "#EXT-X-PROGRAM-DATE-TIME:2026-09-16T12:30:00.000Z") > 0, "Track timelines preserve discontinuities and program date time")
    check(Instr(1, video.text, "#EXT-X-ENDLIST") > 0 and Instr(1, video.text, "#EXTINF:1.500,") > 0, "Completed playlist and exact durations survive rewriting")
    check(Instr(1, video.text, "PART") = 0 and Instr(1, video.text, "PREFETCH") = 0 and Instr(1, video.text, "REPORT") = 0 and Instr(1, video.text, "SERVER-CONTROL") = 0, "Partial segments and low-latency hints are not advertised")
    check(Instr(1, video.text, "#EXT-X-VERSION:7") > 0 and Instr(1, video.text, "private title") = 0, "Compatible HLS version replaces source version and unused EXTINF titles")
    check(video.resourceIds[0] = "1" and video.resourceIds[3] = "4", "Resource identifiers expose neither upstream URLs nor query parameters")
    check(registry.resources[video.resourceIds[1]].cacheKey = registry.resources[audio.resourceIds[1]].cacheKey, "Audio and video views share one upstream segment cache key")
    check(registry.idmap[registry.resources[video.resourceIds[1]].registryKey] = video.resourceIds[1], "Resource carries its registry key for bounded paired pruning")
    repeated = compatRewriteMedia(playlist, base, "video", registry)
    check(repeated.text = video.text and registry.counter = 8, "Manifest refresh keeps stable resource IDs")
    deletedId = video.resourceIds[0]
    registry.resources.Delete(deletedId)
    repeated = compatRewriteMedia(playlist, base, "video", registry)
    check(repeated.valid and registry.counter = 9 and repeated.resourceIds[0] <> deletedId, "Registry pruning can remove a resource without reusing an expired ID")
    newMap = compatRegisterResource(registry, parsed.entries[1].url, "segment", parsed.entries[2].url, "video")
    check(newMap <> "http://127.0.0.1:32123/resource/" + video.resourceIds[1], "A reused segment URL with a different init map has a distinct track association")
    upperUrl = compatRegisterResource(registry, "https://video.ttvnw.net/segment.m4s?sig=A", "segment", parsed.entries[2].url, "video")
    lowerUrl = compatRegisterResource(registry, "https://video.ttvnw.net/segment.m4s?sig=a", "segment", parsed.entries[2].url, "video")
    check(upperUrl <> lowerUrl, "Case-sensitive signed URLs never collide in Roku's normally case-insensitive dictionaries")
    master = compatMasterPlaylist("http://127.0.0.1:32123/video.m3u8", "http://127.0.0.1:32123/audio.m3u8", {width: 1920, height: 1080, frameRate: 59.94, bandwidth: 8000000})
    check(Instr(1, master, "TYPE=AUDIO") > 0 and Instr(1, master, "AUDIO=" + q + "audio" + q) > 0, "Synthetic master associates one video stream with its separate audio rendition")
    check(Instr(1, master, "BANDWIDTH=16000000") > 0 and Instr(1, master, "RESOLUTION=1920x1080") > 0, "Master accounts for two local payload views without changing resolution")
    check(not compatParseMedia("", base).valid and not compatParseMedia(header, base).valid, "Empty and segment-free playlists fail safely")
    check(not compatParseMedia(header + "#EXTINF:2," + nl, base).valid, "Incomplete segment declaration fails safely")
    check(not compatParseMedia(header + "stream.ts" + nl, base).valid, "Bare media URI without EXTINF is rejected")
    check(not compatParseMedia(header + "#EXT-X-STREAM-INF:BANDWIDTH=1" + nl + "stream.m3u8" + nl, base).valid, "Master playlist cannot be mistaken for a media playlist")
    check(not compatParseMedia(playlist.Replace("#EXTINF:2.000,", "#EXT-X-BYTERANGE:100@0" + nl + "#EXTINF:2.000,"), base).valid, "Segment byte ranges explicitly require native fallback")
    check(not compatParseMedia(playlist.Replace("../init.mp4?sig=first" + q, "../init.mp4?sig=first" + q + ",BYTERANGE=" + q + "100@0" + q), base).valid, "Init byte ranges explicitly require native fallback")
    check(not compatParseMedia(header + "#EXT-X-KEY:METHOD=AES-128,URI=" + q + "key" + q + nl + "#EXTINF:2," + nl + "stream.ts" + nl, base).valid, "Encrypted playlists are never silently rewritten")
    check(not compatParseMedia(playlist.Replace("#EXT-X-MEDIA-SEQUENCE:12345", "#EXT-X-SKIP:SKIPPED-SEGMENTS=2"), base).valid, "Delta playlists cannot lose skipped initialization or timeline state")
    check(not compatParseMedia(playlist.Replace("../init.mp4?sig=first", "https://example.test/init.mp4"), base).valid, "Unknown media hosts are rejected before registry insertion")
    check(compatAbsoluteUrl(base, "../../other.m4s?q=1") = "https://video-edge-a.hls.ttvnw.net/other.m4s?q=1", "Parent path segments resolve against the source directory")
    check(compatAbsoluteUrl(base, "?refresh=1") = "https://video-edge-a.hls.ttvnw.net/channel/path/index.m3u8?refresh=1", "Query-only URI references retain the source path")
    check(compatAbsoluteUrl("https://video-edge-a.hls.ttvnw.net", "one.m4s") = "https://video-edge-a.hls.ttvnw.net/one.m4s", "Host-only base URLs resolve a root segment")
    for each url in ["http://video.hls.ttvnw.net/a", "https://ttvnw.net.evil.test/a", "https://evilttvnw.net/a", "https://user@video.ttvnw.net/a", "https://video.ttvnw.net:444/a", "https://video.ttvnw.net/a#fragment", "https://video.ttvnw.net/" + Chr(10) + "bad", "https://video.ttvnw.net" + Chr(92) + "@evil.test/a", "https://user%40video.ttvnw.net/a", "https://.ttvnw.net/a", "https://a..ttvnw.net/a"]
        check(not compatUpstreamUrlAllowed(url), "Scheme, host boundaries and malformed URL checks reject unsafe upstream references")
    end for
    check(compatUpstreamUrlAllowed("https://video.ttvnw.net:443/a") and compatUpstreamUrlAllowed("https://media.twitchcdn.net/a"), "Trusted CDN subdomains and explicit HTTPS port remain supported")
    ts = compatParseMedia(header + "#EXTINF:2," + nl + "stream.ts" + nl, base)
    check(ts.valid and not ts.hasMap, "Ordinary transport-stream media is recognized for untouched direct playback")
    variant = {bandwidth: 6921052, width: 1920, height: 1080, frameRate: 60, codecs: "avc1.64002a,mp4a.40.2"}
    directMaster = compatDirectMasterPlaylist(base, variant)
    check(Instr(1, directMaster, "BANDWIDTH=6921052,RESOLUTION=1920x1080,FRAME-RATE=60,CODECS=" + q + variant.codecs + q) > 0, "Direct rendition retains source bitrate, resolution, frame rate, and both codecs")
    check(Right(directMaster, Len(base) + 1) = base + nl, "Native HLS receives the original signed CDN playlist unchanged")
    check(directMaster.Split("#EXT-X-STREAM-INF:").Count() = 2, "Single-quality master cannot silently select a different rendition")
    check(compatDirectMasterPlaylist(base, invalid) = "" and compatDirectMasterPlaylist(base, {}) = "", "Missing metadata falls back to the playable original URL")
    variant.codecs = "avc1" + Chr(10) + "#EXT-X-ENDLIST"
    check(compatDirectMasterPlaylist(base, variant) = "", "Codec metadata cannot insert another playlist line")
    repeatedMaps = header
    for index = 1 to 513
        repeatedMaps += "#EXT-X-MAP:URI=" + q + "init" + index.ToStr() + ".mp4" + q + nl
    end for
    bounded = compatParseMedia(repeatedMaps + "#EXTINF:2," + nl + "stream.m4s" + nl, base)
    check(not bounded.valid and bounded.error = "Media playlist contains too many resources.", "Initialization-map declarations cannot bypass the resource bound")
    repeatedComments = header
    for index = 1 to 65536
        repeatedComments += "#ignored" + nl
    end for
    check(not compatParseMedia(repeatedComments, base).valid, "Even dropped source declarations have a bounded line count")
    vodBase = "https://dgeft87wbj63p.cloudfront.net/archive/chunked/index.m3u8"
    check(compatUpstreamUrlAllowed(vodBase), "Twitch archive CDN is supported")
    check(not compatUpstreamUrlAllowed("https://cloudfront.net.evil.test/vod") and not compatUpstreamUrlAllowed("https://evilcloudfront.net/vod"), "Archive CDN checks respect exact hostname boundaries")
    vodLines = ["#EXTM3U", "#EXT-X-TARGETDURATION:10", "#EXT-X-MEDIA-SEQUENCE:0", "#EXT-X-PLAYLIST-TYPE:EVENT", "#EXT-X-MAP:URI=" + q + "init-0.mp4" + q]
    for index = 0 to 1599
        vodLines.Push("#EXT-X-PROGRAM-DATE-TIME:2026-09-17T10:48:35.925Z")
        vodLines.Push("#EXTINF:10.000,")
        vodLines.Push(index.ToStr() + ".mp4")
    end for
    vodLines.Push("#EXT-X-ENDLIST")
    archive = compatParseMedia(vodLines.Join(nl), vodBase)
    check(archive.valid and archive.endList and archive.entries.Count() = 1601, "A four-hour recording exceeds former live playlist limits without losing its timeline")
    vodRegistry = {baseUrl: "http://127.0.0.1:32123", resources: {}, idmap: {}, counter: 0}
    vodAudio = compatRewriteParsedMedia(archive, "audio", vodRegistry)
    vodVideo = compatRewriteParsedMedia(archive, "video", vodRegistry)
    check(vodAudio.valid and vodVideo.valid and vodRegistry.counter = 3202, "Both full-length recording tracks share one validated parse")
    check(vodVideo.text.Split("#EXTINF:10.000,").Count() = 1601 and Instr(1, vodVideo.text, "#EXT-X-ENDLIST") > 0, "Rewriting keeps every duration and the final end marker for seeking")
    firstVideo = vodRegistry.resources[vodVideo.resourceIds[1]]
    lastVideo = vodRegistry.resources[vodVideo.resourceIds[1600]]
    check(firstVideo.url = "https://dgeft87wbj63p.cloudfront.net/archive/chunked/0.mp4" and lastVideo.url = "https://dgeft87wbj63p.cloudfront.net/archive/chunked/1599.mp4", "First and last recording segments resolve without truncation")
    check(archive.lines.Count() > 4800 and archive.entries.Count() = 1601, "Track rewriting does not mutate the shared parsed archive")
    print "PASS opaque HLS routes, shared cache keys, live timelines, map changes, completed segments and restricted CDN references"
end sub

function testCreateObject(kind, pattern, flags)
    return CreateObject(kind, pattern, flags)
end function
