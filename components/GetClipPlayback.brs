sub init()
    m.top.functionName = "getClipPlayback"
end sub

sub getClipPlayback()
    requested = m.top.clipId
    version = m.top.requestId
    result = requestClipPlayback(requested)
    if m.top.cancelRequested or m.top.requestId <> version or m.top.clipId <> requested then return
    m.top.playbackInfo = result
    m.top.errorMessage = result.error
    m.top.streamUrl = result.url
end sub

function requestClipPlayback(slug as String) as Object
    result = {variants: [], isLive: false, initialIndex: -1, url: "", error: "", title: "Clip", login: "", name: "", avatar: ""}
    if m.top.cancelRequested then return result
    query = "{ clip(slug: " + FormatJSON(slug) + ") { title broadcaster { login displayName profileImageURL(width: 70) } playbackAccessToken(params: { platform: " + Chr(34) + "web" + Chr(34) + ", playerBackend: " + Chr(34) + "mediaplayer" + Chr(34) + ", playerType: " + Chr(34) + "clips_discovery" + Chr(34) + " }) { value signature } videoQualities { frameRate quality sourceURL } } }"
    transfer = createHttpUrl()
    transfer.AddHeader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.SetUrl("https://gql.twitch.tv/gql")
    response = requestText(transfer, FormatJSON({query: query}), 10000, false)
    if m.top.cancelRequested then return result
    if response.error <> ""
        result.error = "Could not load this clip. Please try again."
        return result
    end if
    data = ParseJSON(response.body)
    clip = invalid
    if type(data) = "roAssociativeArray"
        if type(data.data) = "roAssociativeArray" then clip = data.data.clip
    end if
    if type(clip) <> "roAssociativeArray"
        result.error = "This clip is unavailable."
        return result
    end if
    variants = clipPlaybackVariants(clip)
    if variants.Count() = 0
        result.error = "No playable quality is available for this clip."
        return result
    end if
    preference = "Auto"
    if nonEmptyString(m.global.preferredQuality) then preference = m.global.preferredQuality
    capabilities = playbackDeviceCapabilities(variants)
    selected = playbackPreferenceIndex(variants, preference, capabilities)
    result.variants = variants
    result.capabilities = capabilities
    result.initialIndex = selected
    if selected < 0
        result.error = "No clip quality fits this device's video limits."
        return result
    end if
    result.url = variants[selected].url
    if nonEmptyString(clip.title) then result.title = clip.title
    if type(clip.broadcaster) = "roAssociativeArray"
        if nonEmptyString(clip.broadcaster.login) then result.login = clip.broadcaster.login
        if nonEmptyString(clip.broadcaster.displayName) then result.name = clip.broadcaster.displayName
        if nonEmptyString(clip.broadcaster.profileImageURL) then result.avatar = clip.broadcaster.profileImageURL
    end if
    return result
end function

function clipPlaybackVariants(clip as Object) as Object
    variants = []
    if type(clip.videoQualities) <> "roArray" then return variants
    token = clip.playbackAccessToken
    if type(token) <> "roAssociativeArray" then return variants
    if not nonEmptyString(token.signature) or not nonEmptyString(token.value) then return variants
    seen = {}
    for each quality in clip.videoQualities
        if type(quality) = "roAssociativeArray"
            if nonEmptyString(quality.sourceURL) and nonEmptyString(quality.quality)
                height = Int(Val(quality.quality))
                if height > 0 and Left(quality.sourceURL, 8) = "https://" and not seen.DoesExist(quality.sourceURL)
                    rate = 30
                    if quality.frameRate <> invalid then rate = Val(quality.frameRate.ToStr())
                    if rate <= 0 then rate = 30
                    label = height.ToStr() + "p"
                    if rate > 30 then label += Int(rate + 0.5).ToStr()
                    separator = "?"
                    if Instr(1, quality.sourceURL, "?") > 0 then separator = "&"
                    url = quality.sourceURL + separator + "sig=" + token.signature.EncodeUriComponent() + "&token=" + token.value.EncodeUriComponent()
                    ' Clips expose a rendition height/FPS, not HLS codec/dimension metadata.
                    ' Mark the standard 16:9 AVC estimate explicitly; never borrow the UI size.
                    width = Int(height * 16 / 9 + 0.5)
                    variants.Push({name: label, url: url, width: width, height: height, frameRate: rate, codecs: "avc1", profile: "high", metadataEstimated: true, bandwidth: 0, group: "", streamFormat: "mp4"})
                    seen[quality.sourceURL] = true
                end if
            end if
        end if
    end for
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
