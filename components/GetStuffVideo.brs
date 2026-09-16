sub init()
    m.top.functionName = "onStreamerChange"
end sub

sub onStreamerChange()
    requested = m.top.videoId
    requestId = m.top.requestId
    result = requestPlayback("", requested, true)
    if m.top.cancelRequested or m.top.requestId <> requestId or m.top.videoId <> requested then return
    m.top.errorMessage = result.error
    m.top.thumbnailInfo = {video_id: requested}
    m.top.playbackInfo = result
    m.top.streamUrl = result.url
end sub
