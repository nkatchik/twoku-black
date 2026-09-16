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
    print "PASS opaque HLS routes, shared cache keys, live timelines, map changes, completed segments and restricted CDN references"
end sub
