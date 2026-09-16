function testCreateObject(kind, name = invalid)
    if kind = "roDeviceInfo"
        return {
            GetVideoMode: function()
                return "1080p60"
            end function,
            CanDecodeVideo: function(format)
                return {result: Val(format.level) <= 4.1}
            end function
        }
    end if
    return node()
end function

function createHttpUrl()
    return {
        AddHeader: sub(key, value)
            if key = "Authorization" then check(false, "Clip GraphQL must stay anonymous")
        end sub,
        SetUrl: sub(url)
            check(url = "https://gql.twitch.tv/gql", "Clip metadata uses Twitch over HTTPS")
        end sub
    }
end function

function requestText(transfer, payload, timeout, logFailure)
    check(timeout = 10000, "Clip resolution has a finite deadline")
    ' brs 0.45 does not escape nested quotes in FormatJSON; Roku does.
    check(Instr(1, payload, "videoQualities") > 0 and Instr(1, payload, "playbackAccessToken") > 0, "Actual signed MP4 qualities requested")
    if m.cancelDuringRequest then m.top.cancelRequested = true
    return m.response
end function

sub main()
    clip = {title: "A clip", broadcaster: {login: "streamer", displayName: "Streamer", profileImageURL: "avatar"}, playbackAccessToken: {signature: "sig+", value: "token&"}, videoQualities: [
        {quality: "480", frameRate: 30, sourceURL: "https://cdn/480.mp4?existing=true"},
        {quality: "1080", frameRate: 60, sourceURL: "https://cdn/source.mp4"},
        {quality: "720", frameRate: 30, sourceURL: "https://cdn/720.mp4"},
        {quality: "480", frameRate: 30, sourceURL: "https://cdn/480.mp4?existing=true"},
        {quality: "0", frameRate: 30, sourceURL: "https://cdn/audio"}
    ]}
    variants = clipPlaybackVariants(clip)
    check(variants.Count() = 3, "Clip variants exclude invalid and duplicate renditions")
    check(variants[0].name = "1080p60" and variants[2].name = "480p", "Clip quality order uses numeric height and frame rate")
    check(variants[2].url = "https://cdn/480.mp4?existing=true&sig=sig%2B&token=token%26", "Signed clip URL preserves existing query and escapes credentials")
    check(variants[1].streamFormat = "mp4", "Quality switching retains clip MP4 format")
    check(variants[1].metadataEstimated and variants[1].width = 1280 and variants[1].codecs = "avc1", "Clip dimensions and AVC assumption are marked explicitly")
    m.top = {cancelRequested: false, clipId: "Slug", requestId: 1, streamUrl: ""}
    m.global = {preferredQuality: "Auto"}
    m.cancelDuringRequest = false
    m.response = {error: "", body: FormatJSON({data: {clip: clip}})}
    result = requestClipPlayback("Slug")
    check(result.initialIndex = 1 and result.title = "A clip" and result.login = "streamer", "Auto chooses compatible clip quality and forwards metadata")
    check(result.capabilities.supported[result.url], "Clip player receives the same native capability decision as its resolver")
    m.global.preferredQuality = "480p"
    result = requestClipPlayback("Slug")
    check(result.initialIndex = 2, "Saved manual clip quality is honored")
    m.cancelDuringRequest = true
    getClipPlayback()
    check(m.top.streamUrl = "", "Cancelled clip request cannot publish playback")
    m.top.cancelRequested = false
    m.cancelDuringRequest = false
    clip.videoQualities = [{quality: "1080", frameRate: 59.94, sourceURL: "https://cdn/source.mp4"}]
    variants = clipPlaybackVariants(clip)
    check(Abs(variants[0].frameRate - 59.94) < 0.001 and variants[0].name = "1080p60", "Clip eligibility preserves fractional FPS while rounding only the display label")
    m.response = {error: "", body: FormatJSON({data: {clip: clip}})}
    result = requestClipPlayback("Slug")
    check(result.initialIndex = 0 and result.url <> "" and result.capabilities.allowUnverified, "An unconfirmed clip decoder hint permits a native playback attempt")
    clip.videoQualities[0].quality = "2160"
    m.response = {error: "", body: FormatJSON({data: {clip: clip}})}
    result = requestClipPlayback("Slug")
    check(result.initialIndex = 0 and result.url <> "" and result.error = "", "Auto can attempt an available clip above the reported output hint")
    m.response = {error: "offline", body: ""}
    result = requestClipPlayback("Slug")
    check(result.url = "" and result.error <> "", "Failed clip request provides a retryable error")
    m.response = {error: "", body: "<html>error</html>"}
    result = requestClipPlayback("Slug")
    check(result.url = "" and result.error <> "", "Malformed clip response never creates a playback URL")
    print "PASS signed clip qualities, sorting, Auto/manual choice, MP4 switching, metadata, cancellation, error recovery"
end sub
