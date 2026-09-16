function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    return result
end function

sub main()
    m.top = node()
    m.top.visible = true
    m.top.streamerSelectedName = "channel"
    m.pastBroadcastsList = node()
    m.emptyLabel = node()
    m.videosLogin = "channel"
    m.videoItems = []
    m.seenVideos = {}
    m.requestCursor = ""
    m.getVideos = {searchResults: [], pagination: "next", errorMessage: ""}
    for index = 0 to 4
        m.getVideos.searchResults.push({id: index.ToStr(), title: "Video", user_name: "Channel", duration: "1:00", published_at: "Yesterday", thumbnail_url: "thumb", viewer_count: "3 views"})
    end for
    onGetVideos()
    check(m.pastBroadcastsList.content.getChildCount() = 2, "Five VODs form two four-column rows")
    check(m.pastBroadcastsList.content.getChild(1).getChildCount() = 1, "Partial VOD row remains visible")
    check(m.pastBroadcastsList.hasFocus(), "First loaded VOD receives focus from the empty state")
    onGetVideos()
    check(m.videoItems.count() = 5, "Duplicate pagination data does not duplicate VOD cards")
    m.videosLogin = "old-channel"
    m.getVideos.searchResults = [{id: "late"}]
    onGetVideos()
    check(m.videoItems.count() = 5, "Late metadata from a previous channel is ignored")
    m.videoLogin = "channel"
    m.playbackRequestId = 3
    m.getStuffVideo = {requestId: 3, cancelRequested: false, streamUrl: "late-url"}
    m.playbackStatus = node()
    cancelPlaybackRequest()
    onGetVideoUrl()
    check(m.top.videoUrl = invalid, "Cancelled VOD lookup does not publish late playback")
    print "PASS VOD grid, focus after loading, pagination deduplication, stale channel and playback guards"
end sub
