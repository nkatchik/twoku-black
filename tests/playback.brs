function testCreateObject(kind, name = invalid)
    if kind = "roDeviceInfo" then return GetGlobalAA().device
    return {}
end function

function capabilityDevice(mode as String, maxLevel as Integer, highestOnly = false)
    return {
        mode: mode, maxLevel: maxLevel, highestOnly: highestOnly, queries: [],
        GetVideoMode: function()
            return m.mode
        end function,
        GetDisplayMode: function()
            check(false, "UI resolution must never limit the video decoder")
        end function,
        CanDecodeVideo: function(format)
            m.queries.Push(format)
            check(format.codec = "mpeg4 avc" or format.codec = "h264", "Native decoder probe tries the AVC names used by Roku clients")
            check(format.profile = "main" or format.profile = "high", "Native probe preserves the actual AVC profile")
            level = Int(Val(format.level) * 10 + 0.5)
            if level > m.maxLevel then return {result: false, updated: "level", level: [playbackLevelString(m.maxLevel)]}
            if m.highestOnly and level <> m.maxLevel then return {result: false, updated: "level", level: [playbackLevelString(m.maxLevel)]}
            return {result: true}
        end function
    }
end function

function testVariant(height, rate, bandwidth, width = 0)
    if width = 0 then width = Int(height * 16 / 9 + 0.5)
    return {name: height.ToStr() + "p" + rate.ToStr(), width: width, height: height, frameRate: rate,
        bandwidth: bandwidth, averageBandwidth: 0, codecs: "avc1.4d401f,mp4a.40.2",
        url: "https://cdn/" + width.ToStr() + "-" + height.ToStr() + "-" + rate.ToStr()}
end function

sub main()
    attrs = playbackAttributes("CODECS=" + Chr(34) + "avc1.4D401F,mp4a.40.2" + Chr(34) + ", FRAME-RATE=59.94, VIDEO=" + Chr(34) + "chunked" + Chr(34))
    check(attrs.CODECS = "avc1.4D401F,mp4a.40.2", "Quoted codec commas remain one attribute")
    check(attrs["FRAME-RATE"] = "59.94", "Spaced attributes preserve actual frame rate")
    q = Chr(34)
    codec = "CODECS=" + q + "avc1.4D401F,mp4a.40.2" + q + ","
    playlist = "#EXTM3U" + Chr(10)
    playlist += "#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID=" + q + "chunked" + q + ",NAME=" + q + "1080p60 (source)" + q + Chr(10)
    playlist += "#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID=" + q + "720p30" + q + ",NAME=" + q + "720p" + q + Chr(10)
    playlist += "#EXT-X-STREAM-INF:" + codec + "BANDWIDTH=6000000,AVERAGE-BANDWIDTH=5400000,RESOLUTION=1920x1080,FRAME-RATE=59.94,VIDEO=" + q + "chunked" + q + Chr(10)
    playlist += "#EXT-X-TWITCH-INFO:EXTRA=1" + Chr(10) + Chr(10) + "https://cdn.example/source.m3u8" + Chr(13) + Chr(10)
    playlist += "#EXT-X-STREAM-INF:" + codec + "VIDEO=" + q + "480p30" + q + ",RESOLUTION=852x480,FRAME-RATE=30,BANDWIDTH=1400000" + Chr(10) + "/480.m3u8" + Chr(10)
    playlist += "#EXT-X-STREAM-INF:" + codec + "VIDEO=" + q + "720p30" + q + ",RESOLUTION=1280x720,FRAME-RATE=30,BANDWIDTH=2800000" + Chr(10) + "720.m3u8" + Chr(10)
    playlist += "#EXT-X-STREAM-INF:" + codec + "VIDEO=" + q + "720p60" + q + ",RESOLUTION=1280x720,FRAME-RATE=60,BANDWIDTH=4200000" + Chr(10) + "//cdn.example/72060.m3u8" + Chr(10)
    playlist += "#EXT-X-STREAM-INF:" + codec + "RESOLUTION=640x360,FRAME-RATE=30,BANDWIDTH=900000" + Chr(10) + "360.m3u8" + Chr(10)
    playlist += "#EXT-X-STREAM-INF:BANDWIDTH=128000,VIDEO=" + q + "audio_only" + q + Chr(10) + "audio.m3u8" + Chr(10)
    playlist += "#EXT-X-STREAM-INF:RESOLUTION=1280x720" + Chr(10) + "720.m3u8" + Chr(10)
    variants = parsePlaybackMaster(playlist, "https://usher.example/path/master.m3u8?token=x")
    check(variants.Count() = 5, "Manifest parser excludes audio-only renditions and duplicate URLs")
    check(variants[0].name = "1080p60 (source)" and Abs(variants[0].frameRate - 59.94) < 0.001, "Source preserves its fractional FPS without rounding up")
    check(variants[0].width = 1920 and variants[0].profile = "main" and variants[0].level = 31 and variants[0].profileLevelId = "4d401f", "Width and advertised AVC profile, constraints, and level remain available")
    check(variants[0].bandwidth = 6000000 and variants[0].averageBandwidth = 5400000, "Peak and average HLS bandwidth remain separate bits/second values")
    check(variants[1].height = 720 and variants[1].frameRate = 60, "Variants sort by resolution then frame rate")
    check(variants[2].name = "720p" and variants[2].url = "https://usher.example/path/720.m3u8", "Group names and master-relative URLs survive unrelated declarations")
    check(variants[3].url = "https://usher.example/480.m3u8" and variants[1].url = "https://cdn.example/72060.m3u8", "Root and scheme relative URLs resolve correctly")
    check(playbackAvcRequiredLevel(1920,1080,59.94) = 42 and playbackAvcRequiredLevel(1280,720,60) = 32, "Required level distinguishes 1080p60 from 720p60 even when CODECS understates the level")
    check(playbackAvcRequiredLevel(1920,1080,30) = 40, "1080p30 does not inherit the 60fps level requirement")
    device = capabilityDevice("1080p", 42)
    capabilities = playbackDeviceCapabilities(variants, device)
    check(playbackAutoIndex(variants, capabilities) = 0, "A capable 1080p60 decoder starts at source despite its 720p UI")
    check(device.queries[0].level = "4.2", "Source decoder probe uses corrected minimum level, not falsely advertised 3.1")
    device = capabilityDevice("1080p", 41, true)
    capabilities = playbackDeviceCapabilities(variants, device)
    check(playbackAutoIndex(variants, capabilities) = 1, "A level 4.1 decoder retains supported 720p60 instead of dropping to 720p30")
    check(not playbackVariantRecommended(variants[0], capabilities), "An insufficient returned level never authorizes the rejected source")
    check(playbackPreferenceIndex(variants, "1080p60 (source)", capabilities) = 0, "An explicit saved quality remains playable despite advisory decoder rejection")
    check(playbackPreferenceIndex(variants, "720p", capabilities) = 2, "Supported explicit quality remains selectable")
    check(playbackFallbackIndex(variants,1,{"1":true},capabilities) = 2, "Generic fallback retains resolution before reducing it")
    check(playbackFallbackIndex(variants,4,{"4":true},capabilities) = -1, "An exhausted ladder cannot retry above its current quality")
    check(playbackBandwidthIndex(variants,1,4000000,{"1":true},capabilities) = 2, "Measured bandwidth downshift retains the best resolution within 80% throughput")
    check(playbackBandwidthIndex(variants,1,1800000,{"1":true},capabilities) = 3, "A tighter measured budget selects 480p rather than inventing decoder incapability")
    check(playbackBandwidthIndex(variants,1,0,{},capabilities) = -1, "Missing throughput cannot be treated as low bandwidth")
    check(playbackBandwidthIndex(variants,1,500000,{},capabilities) = -1, "A budget below every variant returns no candidate")
    check(playbackVariantRecommended(variants[1],capabilities), "Bandwidth adaptation never changes decoder eligibility")

    candidates = [testVariant(720,60,4000000), testVariant(1080,30,5000000), testVariant(1080,60,6500000)]
    capabilities = playbackDeviceCapabilities(candidates, capabilityDevice("1080p",41,true))
    check(playbackAutoIndex(candidates,capabilities) = 1, "Resolution takes priority over FPS on an unsorted ladder: 1080p30 beats 720p60")
    capabilities = playbackDeviceCapabilities(candidates, capabilityDevice("1080p30",42))
    check(playbackAutoIndex(candidates,capabilities) = 1 and not playbackVariantRecommended(candidates[0],capabilities), "No lower-resolution candidate may exceed the output FPS ceiling")
    capabilities = playbackDeviceCapabilities(candidates, capabilityDevice("720p",42))
    check(playbackAutoIndex(candidates,capabilities) = 0, "Exact 720p60 output match beats variants above the output resolution")
    check(playbackAutoIndex([candidates[1]],capabilities) = 0, "Auto attempts the available source when no rendition matches the output hint")
    capabilities.maxFrameRate = 59.94
    check(not playbackVariantRecommended(candidates[0],capabilities) and playbackAutoIndex(candidates,capabilities) = 2, "Unmatched FPS stays unconfirmed while Auto still attempts the best available video")
    check(playbackAutoIndex([],capabilities) = -1, "An empty ladder has no playable index")
    unknown = testVariant(480,30,1400000)
    unknown.codecs = "avc1"
    capabilities = playbackDeviceCapabilities([unknown],capabilityDevice("1080p",41,true))
    check(playbackAutoIndex([unknown],capabilities) = 0 and capabilities.allowUnverified and not capabilities.supported[unknown.url], "Unknown HLS profile permits a native attempt without claiming verified support")
    unknown.profile = "high"
    unknown.metadataEstimated = true
    capabilities = playbackDeviceCapabilities([unknown],capabilityDevice("1080p",41,true))
    check(playbackAutoIndex([unknown],capabilities) = 0, "Explicitly estimated clip metadata probes its own minimum level rather than inventing level 4.2")
    unknown.frameRate = 0
    capabilities = playbackDeviceCapabilities([unknown],capabilityDevice("1080p",42))
    check(playbackAutoIndex([unknown],capabilities) = 0 and unknown.frameRate = 0, "Missing FPS stays unknown without preventing playback")
    limits = playbackVideoModeLimits("2160p60b10")
    check(limits.maxWidth = 3840 and limits.maxHeight = 2160 and limits.maxFrameRate = 60, "Video output parsing preserves resolution/FPS independently of bit-depth suffix")
    limits = playbackVideoModeLimits("unknown")
    check(limits.maxWidth = 0 and limits.maxFrameRate = 0, "Unknown output capability remains unreported rather than a zero-pixel ceiling")
    device = capabilityDevice("1080p",42)
    device.CanDecodeVideo = function(format)
        return invalid
    end function
    capabilities = playbackDeviceCapabilities(variants,device)
    check(playbackAutoIndex(variants,capabilities) = 0 and capabilities.allowUnverified and not capabilities.supported[variants[0].url], "Unavailable decoder metadata permits source playback without asserting native support")
    device.CanDecodeVideo = function(format)
        return {result: false}
    end function
    capabilities = playbackDeviceCapabilities(variants,device)
    check(playbackAutoIndex(variants,capabilities) = 0 and capabilities.allowUnverified, "A negative-only capability implementation cannot veto the whole AVC ladder")
    device.mode = "720p"
    capabilities = playbackDeviceCapabilities(variants,device)
    check(playbackAutoIndex(variants,capabilities) = 1 and not playbackVariantRecommended(variants[0],capabilities), "Unverified fallback still enforces known output resolution")
    device.mode = "1080p30"
    capabilities = playbackDeviceCapabilities(variants,device)
    check(playbackAutoIndex(variants,capabilities) = 2, "Unverified fallback still enforces known output FPS")
    device.mode = "unknown"
    capabilities = playbackDeviceCapabilities(variants,device)
    check(playbackAutoIndex(variants,capabilities) = 0, "Missing output metadata cannot block every rendition")
    device.mode = "1080p"
    device.CanDecodeVideo = function(format)
        return {result: format.codec = "h264"}
    end function
    capabilities = playbackDeviceCapabilities(variants,device)
    check(playbackAutoIndex(variants,capabilities) = 0 and not capabilities.allowUnverified, "A device accepting only the h264 alias confirms 1080p60")
    device.CanDecodeVideo = function(format)
        if format.level = "4.2" then return {result: true}
        return {result: false, updated: "profile,level", profile: ["main", "high"], level: [4.2]}
    end function
    capabilities = playbackDeviceCapabilities(variants,device)
    check(capabilities.supported[variants[1].url] and not capabilities.allowUnverified, "Combined closest-format changes and numeric levels can confirm a rendition")
    otherCodecs = parsePlaybackMaster("#EXT-X-STREAM-INF:RESOLUTION=3840x2160,FRAME-RATE=60,CODECS=" + q + "hvc1.1.6,mp4a.40.2" + q + Chr(10) + "hevc.m3u8", "https://cdn/master.m3u8")
    check(otherCodecs.Count() = 1 and playbackAutoIndex(otherCodecs,capabilities) = 0, "Codec metadata cannot hide a rendition or prevent an Auto playback attempt")
    capabilities = {maxWidth: 1280, maxHeight: 720, maxFrameRate: 30, supported: {}}
    check(playbackFallbackIndex(variants,0,{"0":true},capabilities) = 1, "Recovery can try an unconfirmed lower rendition instead of blocking it")
    check(playbackBandwidthIndex(variants,0,4000000,{"0":true},capabilities) = 2, "Bandwidth adaptation can select a fitting bitrate despite negative decoder hints")
    missingRate = parsePlaybackMaster("#EXT-X-STREAM-INF:" + codec + "RESOLUTION=1280x720" + Chr(10) + "unknown.m3u8", "https://cdn/master.m3u8")
    check(missingRate.Count() = 1 and missingRate[0].frameRate = 0, "An absent manifest FPS is preserved as unknown")
    print "PASS all video renditions, advisory device probes, unverified fallback, manual choices and bandwidth ranking"
end sub
