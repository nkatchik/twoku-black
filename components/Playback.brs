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
            width = 0
            height = 0
            if pending.RESOLUTION <> invalid
                dimensions = LCase(pending.RESOLUTION).Split("x")
                if dimensions.Count() = 2
                    width = Int(playbackNumber(Val(dimensions[0])))
                    height = Int(playbackNumber(Val(dimensions[1])))
                end if
            end if
            group = ""
            if pending.VIDEO <> invalid then group = pending.VIDEO
            codecs = ""
            if pending.CODECS <> invalid then codecs = LCase(pending.CODECS)
            ' Exclude audio-only and codecs the Roku AVC path cannot decode.
            isVideo = width > 0 and height > 0
            compatible = codecs = "" or Instr(1, codecs, "avc1") > 0 or Instr(1, codecs, "avc3") > 0
            if isVideo and compatible
                uri = playbackAbsoluteUrl(masterUrl, line)
                if uri <> "" and not seen.DoesExist(uri)
                    frameRate = 0.0
                    if pending["FRAME-RATE"] <> invalid then frameRate = playbackNumber(Val(pending["FRAME-RATE"]))
                    bandwidth = 0
                    if pending.BANDWIDTH <> invalid then bandwidth = Int(playbackNumber(Val(pending.BANDWIDTH)))
                    averageBandwidth = 0
                    if pending["AVERAGE-BANDWIDTH"] <> invalid then averageBandwidth = Int(playbackNumber(Val(pending["AVERAGE-BANDWIDTH"])))
                    codecInfo = playbackAvcCodec(codecs)
                    label = height.ToStr() + "p"
                    if frameRate > 30 then label += frameRate.ToStr()
                    if groups.DoesExist(group)
                        label = groups[group]
                    else if group = "chunked"
                        label += " (source)"
                    end if
                    variants.Push({name: label, url: uri, width: width, height: height, frameRate: frameRate,
                        bandwidth: bandwidth, averageBandwidth: averageBandwidth, group: group, codecs: codecs,
                        videoCodec: codecInfo.videoCodec, profile: codecInfo.profile, level: codecInfo.level,
                        profileLevelId: codecInfo.profileLevelId})
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
            if not playbackHigherQuality(current, before) then exit while
            variants[previous + 1] = before
            previous -= 1
        end while
        variants[previous + 1] = current
    end for
    return variants
end function

function playbackAutoIndex(variants as Object, capabilities = invalid) as Integer
    best = -1
    for index = 0 to variants.Count() - 1
        if playbackVariantSupported(variants[index], capabilities)
            if best < 0
                best = index
            else if playbackHigherQuality(variants[index], variants[best])
                best = index
            end if
        end if
    end for
    return best
end function

function playbackPreferenceIndex(variants as Object, preference as String, capabilities = invalid) as Integer
    if preference <> "Auto"
        for index = 0 to variants.Count() - 1
            if variants[index].name = preference and playbackVariantSupported(variants[index], capabilities) then return index
        end for
    end if
    return playbackAutoIndex(variants, capabilities)
end function

function playbackFallbackIndex(variants as Object, current as Integer, tried as Object, capabilities = invalid) as Integer
    if current < 0 or current >= variants.Count() then return -1
    source = variants[current]
    best = -1
    for index = 0 to variants.Count() - 1
        variant = variants[index]
        if playbackHigherQuality(source, variant) and not tried.DoesExist(index.ToStr()) and playbackVariantSupported(variant, capabilities)
            if best < 0
                best = index
            else if playbackHigherQuality(variant, variants[best])
                best = index
            end if
        end if
    end for
    return best
end function

function playbackHigherQuality(candidate, other) as Boolean
    if candidate.height <> other.height then return candidate.height > other.height
    if playbackNumber(candidate.width) <> playbackNumber(other.width) then return playbackNumber(candidate.width) > playbackNumber(other.width)
    return candidate.frameRate > other.frameRate
end function

' Network adaptation is separate from decoder eligibility. A measured download
' rate is bits/second, not a Video.downloaded bitrate or a connection type.
function playbackBandwidthIndex(variants as Object, current as Integer, measuredBps, tried as Object, capabilities = invalid) as Integer
    if current < 0 or current >= variants.Count() then return -1
    rate = playbackNumber(measuredBps)
    if rate <= 0 then return -1
    budget = rate * 0.8
    currentRate = playbackVariantBandwidth(variants[current])
    if currentRate <= 0 then return -1
    best = -1
    for index = 0 to variants.Count() - 1
        variant = variants[index]
        bitrate = playbackVariantBandwidth(variant)
        if index <> current and not tried.DoesExist(index.ToStr()) and bitrate > 0 and bitrate < currentRate and bitrate <= budget
            if playbackVariantSupported(variant, capabilities)
                if best < 0
                    best = index
                else if playbackHigherQuality(variant, variants[best])
                    best = index
                end if
            end if
        end if
    end for
    return best
end function

function playbackVariantBandwidth(variant)
    bandwidth = playbackNumber(variant.averageBandwidth)
    if bandwidth <= 0 then bandwidth = playbackNumber(variant.bandwidth)
    return bandwidth
end function

function playbackNumber(value)
    kind = type(value)
    if kind = "roInt" or kind = "Integer" or kind = "roFloat" or kind = "Float" or kind = "roDouble" or kind = "Double" or kind = "roLongInteger" or kind = "LongInteger"
        if value >= 0 and value < 1000000000000.0 then return value
    end if
    return 0
end function

function playbackAvcCodec(codecs as String) as Object
    result = {videoCodec: "", profile: "", level: 0, profileLevelId: ""}
    for each rawCodec in codecs.Split(",")
        codec = LCase(rawCodec.Trim())
        if codec = "avc1" or codec = "avc3"
            result.videoCodec = codec
            return result
        end if
        if Left(codec, 5) = "avc1." or Left(codec, 5) = "avc3."
            result.videoCodec = codec
            if Len(codec) = 11
                result.profileLevelId = Mid(codec, 6)
                profile = playbackHexByte(Mid(codec, 6, 2))
                if profile = 66 then result.profile = "baseline"
                if profile = 77 then result.profile = "main"
                if profile = 88 then result.profile = "extended"
                if profile = 100 then result.profile = "high"
                if profile = 110 then result.profile = "high 10"
                if profile = 122 then result.profile = "high 4:2:2"
                if profile = 244 then result.profile = "high 4:4:4"
                level = playbackHexByte(Right(codec, 2))
                if level > 0 then result.level = level
            end if
            return result
        end if
    end for
    return result
end function

function playbackHexByte(value as String) as Integer
    if Len(value) <> 2 then return -1
    result = 0
    for index = 1 to 2
        digit = Instr(1, "0123456789abcdef", LCase(Mid(value, index, 1))) - 1
        if digit < 0 then return -1
        result = result * 16 + digit
    end for
    return result
end function

' ITU-T H.264 Annex A limits: coded macroblocks per frame and per second.
' A mislabeled 1080p60 stream still requires level 4.2, not its claimed 3.1.
function playbackAvcRequiredLevel(width, height, frameRate) as Integer
    if width <= 0 or height <= 0 or frameRate <= 0 then return 0
    columns = Int((width + 15) / 16)
    rows = Int((height + 15) / 16)
    macroblocks = columns * rows
    rate = macroblocks * frameRate
    limits = [[10,99,1485], [11,396,3000], [12,396,6000], [13,396,11880], [20,396,11880],
        [21,792,19800], [22,1620,20250], [30,1620,40500], [31,3600,108000], [32,5120,216000],
        [40,8192,245760], [41,8192,245760], [42,8704,522240], [50,22080,589824],
        [51,36864,983040], [52,36864,2073600]]
    for each limit in limits
        if macroblocks <= limit[1] and rate <= limit[2] and columns * columns <= 8 * limit[1] and rows * rows <= 8 * limit[1] then return limit[0]
    end for
    return 0
end function

' GetVideoMode describes video output. GetDisplayMode/GetUIResolution describe
' graphics and must never be used as decoder ceilings for this 720p UI.
function playbackVideoModeLimits(mode as String) as Object
    limits = {maxWidth: 0, maxHeight: 0, maxFrameRate: 0, videoMode: mode, supported: {}}
    mode = LCase(mode)
    height = Int(playbackNumber(Val(mode)))
    widths = {"480": 720, "576": 720, "720": 1280, "1080": 1920, "2160": 3840, "4320": 7680}
    if not widths.DoesExist(height.ToStr()) then return limits
    scan = Instr(1, mode, "p")
    interlaced = false
    if scan = 0
        scan = Instr(1, mode, "i")
        interlaced = true
    end if
    if scan = 0 then return limits
    rate = 60
    suffix = Mid(mode, scan + 1)
    if suffix <> "" then rate = playbackNumber(Val(suffix))
    if rate <= 0 then return limits
    if interlaced and height >= 1080 then rate /= 2
    limits.maxWidth = widths[height.ToStr()]
    limits.maxHeight = height
    limits.maxFrameRate = rate
    return limits
end function

function playbackVariantSupported(variant, capabilities = invalid) as Boolean
    ' The optional form keeps pure ranking useful to callers with an already
    ' filtered list. Production resolvers always provide a fresh capability set.
    if capabilities = invalid then return true
    width = playbackNumber(variant.width)
    height = playbackNumber(variant.height)
    rate = playbackNumber(variant.frameRate)
    if width <= 0 or height <= 0 or rate <= 0 then return false
    if width > playbackNumber(capabilities.maxWidth) or height > playbackNumber(capabilities.maxHeight) or rate > playbackNumber(capabilities.maxFrameRate) then return false
    if type(capabilities.supported) <> "roAssociativeArray" then return false
    if not capabilities.supported.DoesExist(variant.url) then return false
    return capabilities.supported[variant.url] = true
end function

function playbackDeviceCapabilities(variants as Object, device = invalid) as Object
    if device = invalid then device = CreateObject("roDeviceInfo")
    capabilities = playbackVideoModeLimits(device.GetVideoMode())
    capabilities.probes = []
    for each variant in variants
        capabilities.supported[variant.url] = false
        width = playbackNumber(variant.width)
        height = playbackNumber(variant.height)
        rate = playbackNumber(variant.frameRate)
        if width > 0 and height > 0 and rate > 0 and width <= capabilities.maxWidth and height <= capabilities.maxHeight and rate <= capabilities.maxFrameRate
            ' Twitch is requested in AVC. Unknown codec/profile metadata is not
            ' an assertion of hardware support; keep it out of Auto.
            codec = {videoCodec: "", profile: "", level: 0}
            if type(variant.codecs) = "roString" or type(variant.codecs) = "String" then codec = playbackAvcCodec(variant.codecs)
            if variant.metadataEstimated = true and codec.videoCodec <> "" and codec.profile = ""
                if variant.profile = "main" or variant.profile = "high" then codec.profile = variant.profile
            end if
            required = playbackAvcRequiredLevel(width, height, rate)
            if codec.videoCodec <> "" and codec.profile <> "" and required > 0
                if codec.level > required then required = codec.level
                format = {codec: "mpeg4 avc", profile: codec.profile, level: playbackLevelString(required)}
                response = device.CanDecodeVideo(format)
                supported = playbackDecodeResponse(response)
                ' Some Roku versions report only their highest supported level.
                ' A confirmed higher level also covers a lower-level stream.
                if not supported and type(response) = "roAssociativeArray"
                    if response.updated = "level" and type(response.level) = "roArray"
                        for each level in response.level
                            number = 0
                            if type(level) = "roString" or type(level) = "String" then number = Val(level)
                            if Int(number * 10 + 0.5) >= required
                                higher = {codec: "mpeg4 avc", profile: codec.profile, level: level}
                                if playbackDecodeResponse(device.CanDecodeVideo(higher))
                                    supported = true
                                    exit for
                                end if
                            end if
                        end for
                    end if
                end if
                capabilities.supported[variant.url] = supported
                capabilities.probes.Push({width: width, height: height, frameRate: rate, profile: codec.profile, level: format.level, supported: supported})
            end if
        end if
    end for
    return capabilities
end function

function playbackLevelString(level as Integer) as String
    return Int(level / 10).ToStr() + "." + (level MOD 10).ToStr()
end function

function playbackDecodeResponse(response) as Boolean
    if type(response) <> "roAssociativeArray" then return false
    return response.result = true
end function
