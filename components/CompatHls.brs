' The relay serves only opaque local routes. Signed upstream URLs remain in its
' Task-local registry and are never copied into a playlist sent to Video.
function compatParseMedia(text as String, baseUrl as String) as Object
    result = {valid: false, error: "", entries: [], lines: [], hasMap: false,
        firstInitUrl: "", targetDuration: 0, mediaSequence: 0, endList: false}
    if Len(text) > 262144 then return compatMediaError(result, "Media playlist is too large.")
    if not compatUpstreamUrlAllowed(baseUrl) then return compatMediaError(result, "Unsupported media host.")
    rawLines = text.Split(Chr(10))
    if rawLines.Count() = 0 then return compatMediaError(result, "Empty media playlist.")
    if rawLines[0].Trim() <> "#EXTM3U" then return compatMediaError(result, "Invalid media playlist header.")
    result.lines.Push({kind: "line", text: "#EXTM3U"})
    ' fMP4 EXT-X-MAP requires HLS version 6; one fixed version also avoids
    ' preserving an inconsistent version from a low-latency source playlist.
    result.lines.Push({kind: "line", text: "#EXT-X-VERSION:7"})
    pendingDuration = -1.0
    initUrl = ""
    segmentCount = 0
    unmappedSegments = false
    for index = 1 to rawLines.Count() - 1
        line = rawLines[index].Trim()
        if line <> ""
            colon = Instr(1, line, ":")
            tag = line
            value = ""
            if colon > 0
                tag = Left(line, colon - 1)
                value = Mid(line, colon + 1)
            end if
            if Left(line, 1) <> "#"
                if pendingDuration < 0 then return compatMediaError(result, "Media segment is missing its duration.")
                url = compatAbsoluteUrl(baseUrl, line)
                if url = "" then return compatMediaError(result, "Unsupported media segment URL.")
                if initUrl = "" then unmappedSegments = true
                entry = {kind: "segment", url: url, initUrl: initUrl, duration: pendingDuration}
                result.entries.Push(entry)
                result.lines.Push(entry)
                segmentCount += 1
                if segmentCount > 512 then return compatMediaError(result, "Media playlist contains too many segments.")
                pendingDuration = -1.0
            else if tag = "#EXTINF"
                if pendingDuration >= 0 then return compatMediaError(result, "Media segment URL is missing.")
                durationText = value.Split(",")[0]
                if not compatUnsignedNumber(durationText) then return compatMediaError(result, "Invalid media segment duration.")
                pendingDuration = Val(durationText)
                if pendingDuration <= 0 then return compatMediaError(result, "Invalid media segment duration.")
                ' EXTINF titles are unnecessary and may contain upstream URLs.
                result.lines.Push({kind: "line", text: "#EXTINF:" + durationText + ","})
            else if tag = "#EXT-X-MAP"
                attrs = compatHlsAttributes(value)
                if attrs = invalid then return compatMediaError(result, "Invalid initialization map.")
                if attrs.BYTERANGE <> invalid then return compatMediaError(result, "Byte-range media requires direct playback.")
                if attrs.URI = invalid then return compatMediaError(result, "Initialization map URL is missing.")
                initUrl = compatAbsoluteUrl(baseUrl, attrs.URI)
                if initUrl = "" then return compatMediaError(result, "Unsupported initialization map URL.")
                if result.firstInitUrl = "" then result.firstInitUrl = initUrl
                result.hasMap = true
                entry = {kind: "init", url: initUrl, initUrl: initUrl, duration: 0}
                result.entries.Push(entry)
                result.lines.Push(entry)
            else if tag = "#EXT-X-BYTERANGE"
                return compatMediaError(result, "Byte-range media requires direct playback.")
            else if tag = "#EXT-X-KEY" or tag = "#EXT-X-SESSION-KEY"
                attrs = compatHlsAttributes(value)
                if attrs = invalid then return compatMediaError(result, "Invalid media encryption declaration.")
                if attrs.METHOD <> "NONE" then return compatMediaError(result, "Encrypted media requires direct playback.")
            else if tag = "#EXT-X-SKIP"
                return compatMediaError(result, "Delta media playlists require direct playback.")
            else if tag = "#EXT-X-STREAM-INF" or tag = "#EXT-X-MEDIA" or tag = "#EXTM3U"
                return compatMediaError(result, "Expected a media playlist.")
            else if tag = "#EXT-X-TARGETDURATION"
                if not compatUnsignedInteger(value) then return compatMediaError(result, "Invalid media target duration.")
                result.targetDuration = Val(value)
                result.lines.Push({kind: "line", text: line})
            else if tag = "#EXT-X-MEDIA-SEQUENCE" or tag = "#EXT-X-DISCONTINUITY-SEQUENCE"
                if not compatUnsignedInteger(value) then return compatMediaError(result, "Invalid media sequence.")
                if tag = "#EXT-X-MEDIA-SEQUENCE" then result.mediaSequence = Val(value)
                result.lines.Push({kind: "line", text: line})
            else if tag = "#EXT-X-ENDLIST"
                result.endList = true
                result.lines.Push({kind: "line", text: tag})
            else if tag = "#EXT-X-DISCONTINUITY" or tag = "#EXT-X-INDEPENDENT-SEGMENTS" or tag = "#EXT-X-GAP"
                result.lines.Push({kind: "line", text: tag})
            else if tag = "#EXT-X-PROGRAM-DATE-TIME"
                if compatSafeDateTime(value) then result.lines.Push({kind: "line", text: line})
            else if tag = "#EXT-X-PLAYLIST-TYPE"
                if value = "EVENT" or value = "VOD" then result.lines.Push({kind: "line", text: line})
            end if
            ' Drop partial segments, preload/prefetch hints, server-control and
            ' rendition reports. Only completed EXTINF segments are advertised.
            ' Unknown tags are omitted rather than leaking a URI attribute.
        end if
    end for
    if pendingDuration >= 0 then return compatMediaError(result, "Media segment URL is missing.")
    if segmentCount = 0 then return compatMediaError(result, "Media playlist has no completed segments.")
    if result.targetDuration <= 0 then return compatMediaError(result, "Media target duration is missing.")
    if result.hasMap and unmappedSegments then return compatMediaError(result, "Mixed media containers require direct playback.")
    result.valid = true
    return result
end function

function compatMediaError(result as Object, message as String) as Object
    result.valid = false
    result.error = message
    return result
end function

function compatRewriteMedia(text as String, baseUrl as String, track as String, registry as Object) as Object
    result = compatParseMedia(text, baseUrl)
    result.text = ""
    result.resourceIds = []
    if not result.valid then return result
    if track <> "audio" and track <> "video" then return compatMediaError(result, "Invalid media track.")
    if not result.hasMap then return compatMediaError(result, "Media playlist does not need container repair.")
    for each entry in result.lines
        if entry.kind = "line"
            result.text += entry.text + Chr(10)
        else
            localUrl = compatRegisterResource(registry, entry.url, entry.kind, entry.initUrl, track)
            if localUrl = "" then return compatMediaError(result, "Invalid local media registry.")
            id = Mid(localUrl, Len(registry.baseUrl) + 11)
            result.resourceIds.Push(id)
            if entry.kind = "init"
                result.text += "#EXT-X-MAP:URI=" + Chr(34) + localUrl + Chr(34) + Chr(10)
            else
                result.text += localUrl + Chr(10)
            end if
        end if
    end for
    return result
end function

function compatRegisterResource(registry as Object, url as String, kind as String, initUrl as String, track as String) as String
    if not compatUpstreamUrlAllowed(url) then return ""
    if initUrl <> "" and not compatUpstreamUrlAllowed(initUrl) then return ""
    if kind <> "init" and kind <> "segment" then return ""
    if track <> "audio" and track <> "video" then return ""
    if registry.baseUrl = invalid or registry.baseUrl = "" then return ""
    if registry.resources = invalid then registry.resources = {}
    if registry.idmap = invalid then registry.idmap = {}
    ' URL paths and signed query values are case-sensitive, unlike default AAs.
    registry.idmap.SetModeCaseSensitive()
    if registry.counter = invalid then registry.counter = 0
    ' Length prefixes prevent an upstream URL from colliding with another key.
    key = kind + ":" + track + ":" + Len(url).ToStr() + ":" + url + ":" + initUrl
    id = registry.idmap[key]
    if id = invalid or registry.resources[id] = invalid
        registry.counter += 1
        id = registry.counter.ToStr()
        registry.resources[id] = {id: id, url: url, kind: kind, initUrl: initUrl, track: track, cacheKey: url, registryKey: key}
        registry.idmap[key] = id
    end if
    return registry.baseUrl + "/resource/" + id
end function

function compatMasterPlaylist(videoUrl as String, audioUrl as String, variant = invalid) as String
    q = Chr(34)
    result = "#EXTM3U" + Chr(10) + "#EXT-X-VERSION:7" + Chr(10)
    result += "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=" + q + "audio" + q + ",NAME=" + q + "Audio" + q + ",DEFAULT=YES,AUTOSELECT=YES,URI=" + q + audioUrl + q + Chr(10)
    bandwidth = 10000000
    if variant <> invalid and variant.bandwidth <> invalid
        if variant.bandwidth > 0 then bandwidth = Int(variant.bandwidth * 2)
    end if
    ' The local track views retain the same payload; Video downloads both.
    result += "#EXT-X-STREAM-INF:BANDWIDTH=" + bandwidth.ToStr() + ",AUDIO=" + q + "audio" + q
    if variant <> invalid
        if variant.width <> invalid and variant.height <> invalid
            if variant.width > 0 and variant.height > 0 then result += ",RESOLUTION=" + Int(variant.width).ToStr() + "x" + Int(variant.height).ToStr()
        end if
        if variant.frameRate <> invalid
            if variant.frameRate > 0 then result += ",FRAME-RATE=" + variant.frameRate.ToStr()
        end if
    end if
    return result + Chr(10) + videoUrl + Chr(10)
end function

function compatHlsAttributes(text as String)
    attributes = {}
    key = ""
    value = ""
    inValue = false
    quoted = false
    for index = 1 to Len(text) + 1
        char = ","
        if index <= Len(text) then char = Mid(text, index, 1)
        if char = Chr(34)
            quoted = not quoted
        else if char = "=" and not inValue
            inValue = true
        else if char = "," and not quoted
            if inValue then attributes[UCase(key.Trim())] = value.Trim()
            key = ""
            value = ""
            inValue = false
        else if inValue
            value += char
        else
            key += char
        end if
    end for
    if quoted then return invalid
    return attributes
end function

function compatAbsoluteUrl(baseUrl as String, reference as String) as String
    if reference = "" then return ""
    if Instr(1, reference, Chr(92)) > 0 then return ""
    for index = 1 to Len(reference)
        code = Asc(Mid(reference, index, 1))
        if code <= 32 or code = 127 then return ""
    end for
    if Left(reference, 2) = "//"
        url = "https:" + reference
    else if Instr(1, reference, "://") > 0
        url = reference
    else
        if not compatUpstreamUrlAllowed(baseUrl) then return ""
        hostEnd = Instr(9, baseUrl, "/")
        query = Instr(9, baseUrl, "?")
        if hostEnd = 0 then hostEnd = Len(baseUrl) + 1
        if query > 0 and query < hostEnd then hostEnd = query
        origin = Left(baseUrl, hostEnd - 1)
        basePath = Mid(baseUrl, hostEnd)
        query = Instr(1, basePath, "?")
        if query > 0 then basePath = Left(basePath, query - 1)
        if Left(reference, 1) = "/"
            url = origin + reference
        else if Left(reference, 1) = "?"
            url = origin + basePath + reference
        else
            slash = Len(basePath)
            while slash > 0 and Mid(basePath, slash, 1) <> "/"
                slash -= 1
            end while
            directory = Left(basePath, slash)
            if directory = "" then directory = "/"
            url = origin + directory + reference
        end if
    end if
    if not compatUpstreamUrlAllowed(url) then return ""
    hostEnd = Instr(9, url, "/")
    if hostEnd = 0 then return url
    origin = Left(url, hostEnd - 1)
    path = Mid(url, hostEnd)
    queryText = ""
    query = Instr(1, path, "?")
    if query > 0
        queryText = Mid(path, query)
        path = Left(path, query - 1)
    end if
    parts = []
    for each part in path.Split("/")
        if part = ".."
            if parts.Count() > 0 then parts.Pop()
        else if part <> "."
            parts.Push(part)
        end if
    end for
    normalized = parts.Join("/")
    if Left(normalized, 1) <> "/" then normalized = "/" + normalized
    return origin + normalized + queryText
end function

function compatUpstreamUrlAllowed(url as String) as Boolean
    if LCase(Left(url, 8)) <> "https://" then return false
    if Instr(1, url, Chr(92)) > 0 or Instr(1, url, "#") > 0 then return false
    for index = 1 to Len(url)
        code = Asc(Mid(url, index, 1))
        if code <= 32 or code = 127 then return false
    end for
    authority = Mid(url, 9).Split("/")[0].Split("?")[0]
    if Instr(1, authority, "@") > 0 then return false
    host = LCase(authority)
    colon = Instr(1, host, ":")
    if colon > 0
        if Mid(host, colon) <> ":443" then return false
        host = Left(host, colon - 1)
    end if
    if Left(host, 1) = "." or Instr(1, host, "..") > 0 then return false
    for index = 1 to Len(host)
        if Instr(1, "abcdefghijklmnopqrstuvwxyz0123456789.-", Mid(host, index, 1)) = 0 then return false
    end for
    for each suffix in ["ttvnw.net", "twitchcdn.net"]
        if host = suffix or Right(host, Len(suffix) + 1) = "." + suffix then return true
    end for
    return false
end function

function compatUnsignedInteger(text as String) as Boolean
    if text = "" then return false
    for index = 1 to Len(text)
        char = Mid(text, index, 1)
        if char < "0" or char > "9" then return false
    end for
    return true
end function

function compatUnsignedNumber(text as String) as Boolean
    parts = text.Split(".")
    if parts.Count() > 2 or parts.Count() = 0 then return false
    for each part in parts
        if not compatUnsignedInteger(part) then return false
    end for
    return true
end function

function compatSafeDateTime(text as String) as Boolean
    if Len(text) < 19 or Len(text) > 40 then return false
    for index = 1 to Len(text)
        char = Mid(text, index, 1)
        if Instr(1, "0123456789-:.+TZ", char) = 0 then return false
    end for
    return true
end function
