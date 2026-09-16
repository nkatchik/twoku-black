function playbackTokenPayload(login as String, videoId as String, isVod as Boolean) as Object
    q = Chr(34)
    params = "params: {platform: " + q + "web" + q + ", playerBackend: " + q + "mediaplayer" + q + ", playerType: " + q + "site" + q + "}"
    if isVod
        ' Unquoted BrightScript AA keys serialize in lowercase. GraphQL variables
        ' are case-sensitive, so use the same lowercase spelling in both places.
        query = "query PlaybackAccessToken($vodid: ID!) { videoPlaybackAccessToken(id: $vodid, " + params + ") { value signature } }"
        variables = {vodid: videoId}
    else
        query = "query PlaybackAccessToken($login: String!) { streamPlaybackAccessToken(channelName: $login, " + params + ") { value signature } }"
        variables = {login: login}
    end if
    return {operationName: "PlaybackAccessToken", query: query, variables: variables}
end function

function requestPlayback(login as String, videoId as String, isVod as Boolean) as Object
    result = {masterUrl: "", variants: [], isLive: not isVod, initialIndex: -1, url: "", error: ""}
    if m.top.cancelRequested then return result
    payload = playbackTokenPayload(login, videoId, isVod)
    transfer = createHttpUrl()
    transfer.AddHeader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.SetUrl("https://gql.twitch.tv/gql")
    response = requestText(transfer, FormatJson(payload), 10000, false)
    if m.top.cancelRequested then return result
    if response.error <> ""
        result.error = "Could not contact Twitch. Please try again."
        return result
    end if
    data = ParseJson(response.body)
    token = invalid
    if type(data) = "roAssociativeArray"
        if type(data.data) = "roAssociativeArray"
            if isVod
                token = data.data.videoPlaybackAccessToken
            else
                token = data.data.streamPlaybackAccessToken
            end if
        end if
    end if
    if type(token) <> "roAssociativeArray"
        result.error = "This stream is offline or unavailable."
        if isVod then result.error = "This recording is unavailable or restricted."
        return result
    end if
    if not nonEmptyString(token.value) or not nonEmptyString(token.signature)
        result.error = "Twitch did not return a playback token."
        return result
    end if
    path = "api/channel/hls/" + login.EncodeUriComponent()
    if isVod then path = "vod/" + videoId.EncodeUriComponent()
    masterUrl = "https://usher.ttvnw.net/" + path + ".m3u8?allow_source=true&allow_audio_only=false&playlist_include_framerate=true&supported_codecs=h264&player_backend=mediaplayer&sig=" + token.signature.EncodeUriComponent() + "&token=" + token.value.EncodeUriComponent()
    transfer = createHttpUrl()
    transfer.SetUrl(masterUrl)
    response = requestText(transfer, invalid, 10000, false)
    if m.top.cancelRequested then return result
    if response.error <> ""
        result.error = "The stream could not be loaded. It may be offline or restricted."
        if isVod then result.error = "This recording could not be loaded. It may be unavailable or restricted."
        return result
    end if
    variants = parsePlaybackMaster(response.body, masterUrl)
    if variants.Count() = 0
        result.error = "No video quality is available for this stream."
        return result
    end if
    preference = "Auto"
    if nonEmptyString(m.global.preferredQuality) then preference = m.global.preferredQuality
    capabilities = playbackDeviceCapabilities(variants)
    selected = playbackPreferenceIndex(variants, preference, capabilities)
    result.masterUrl = masterUrl
    result.variants = variants
    result.capabilities = capabilities
    result.initialIndex = selected
    if selected < 0
        result.error = "No video quality is available for this stream."
        return result
    end if
    result.url = variants[selected].url
    return result
end function
