' Twitch HLS parsing shared by the live and VOD Tasks. No network runs on the UI thread.
function playbackAttributes(text as String) as Object
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
    return attributes
end function

function playbackAbsoluteUrl(base as String, path as String) as String
    if Left(path, 8) = "https://" or Left(path, 7) = "http://" then return path
    if Left(path, 2) = "//" then return "https:" + path
    schemeEnd = Instr(1, base, "://")
    if schemeEnd = 0 then return ""
    hostEnd = Instr(schemeEnd + 3, base, "/")
    if hostEnd = 0 then hostEnd = Len(base) + 1
    if Left(path, 1) = "/" then return Left(base, hostEnd - 1) + path
    queryStart = Instr(1, base, "?")
    if queryStart > 0 then base = Left(base, queryStart - 1)
    slash = Len(base)
    while slash > 0 and Mid(base, slash, 1) <> "/"
        slash -= 1
    end while
    return Left(base, slash) + path
end function

function parsePlaybackMaster(text as String, masterUrl as String) as Object
    variants = []
    groups = {}
    pending = invalid
    seen = {}
    for each rawLine in text.Split(Chr(10))
        line = rawLine.Trim()
        if Left(line, 13) = "#EXT-X-MEDIA:"
            media = playbackAttributes(Mid(line, 14))
            if media["GROUP-ID"] <> invalid and media.NAME <> invalid then groups[media["GROUP-ID"]] = media.NAME
        else if Left(line, 18) = "#EXT-X-STREAM-INF:"
            pending = playbackAttributes(Mid(line, 19))
        else if line <> "" and Left(line, 1) <> "#" and pending <> invalid
            height = 0
            if pending.RESOLUTION <> invalid
                dimensions = pending.RESOLUTION.Split("x")
                if dimensions.Count() = 2 then height = Int(Val(dimensions[1]))
            end if
            group = ""
            if pending.VIDEO <> invalid then group = pending.VIDEO
            codecs = ""
            if pending.CODECS <> invalid then codecs = LCase(pending.CODECS)
            ' Exclude audio-only and codecs the Roku AVC path cannot decode.
            isVideo = height > 0
            compatible = codecs = "" or Instr(1, codecs, "avc1") > 0 or Instr(1, codecs, "avc3") > 0
            if isVideo and compatible
                uri = playbackAbsoluteUrl(masterUrl, line)
                if uri <> "" and not seen.DoesExist(uri)
                    frameRate = 30
                    if pending["FRAME-RATE"] <> invalid then frameRate = Int(Val(pending["FRAME-RATE"]) + 0.5)
                    if frameRate <= 0 then frameRate = 30
                    bandwidth = 0
                    if pending.BANDWIDTH <> invalid then bandwidth = Int(Val(pending.BANDWIDTH))
                    label = height.ToStr() + "p"
                    if frameRate > 30 then label += frameRate.ToStr()
                    if groups.DoesExist(group)
                        label = groups[group]
                    else if group = "chunked"
                        label += " (source)"
                    end if
                    variants.Push({name: label, url: uri, height: height, frameRate: frameRate, bandwidth: bandwidth, group: group})
                    seen[uri] = true
                end if
            end if
            pending = invalid
        end if
    end for
    ' Ordered by resolution and frame rate, independent of Twitch's attribute/line order.
    for index = 1 to variants.Count() - 1
        current = variants[index]
        previous = index - 1
        while previous >= 0
            before = variants[previous]
            if before.height > current.height then exit while
            if before.height = current.height and before.frameRate >= current.frameRate then exit while
            variants[previous + 1] = before
            previous -= 1
        end while
        variants[previous + 1] = current
    end for
    return variants
end function

function playbackAutoIndex(variants as Object) as Integer
    ' Avoid starting a fragile decoder at source/60fps. Manual source stays available.
    for index = 0 to variants.Count() - 1
        if variants[index].height <= 720 and variants[index].frameRate <= 30 then return index
    end for
    ' If the channel only provides source, try it once and expose a useful error on failure.
    return variants.Count() - 1
end function

function playbackPreferenceIndex(variants as Object, preference as String) as Integer
    if preference <> "Auto"
        for index = 0 to variants.Count() - 1
            if variants[index].name = preference then return index
        end for
    end if
    return playbackAutoIndex(variants)
end function

function playbackFallbackIndex(variants as Object, current as Integer, tried as Object) as Integer
    if current < 0 or current >= variants.Count() then return -1
    source = variants[current]
    for index = 0 to variants.Count() - 1
        variant = variants[index]
        lowerResolution = variant.height < source.height
        lowerFramerate = variant.height = source.height and variant.frameRate < source.frameRate
        if (lowerResolution or lowerFramerate) and variant.frameRate <= 30 and not tried.DoesExist(index.ToStr()) then return index
    end for
    return -1
end function

