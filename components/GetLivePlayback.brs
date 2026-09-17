sub init()
    m.top.functionName = "onStreamerChange"
end sub

sub onStreamerChange()
    requested = m.top.streamerRequested
    requestId = m.top.requestId
    result = requestPlayback(requested, "", false)
    if m.top.cancelRequested or m.top.requestId <> requestId or m.top.streamerRequested <> requested then return
    m.top.errorMessage = result.error
    m.top.playbackInfo = result
    ' Metadata is published before the URL notification that starts playback.
    m.top.streamUrl = result.url
end sub
