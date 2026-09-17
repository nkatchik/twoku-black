function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    result.addFields = function(fields)
        for each key in fields
            m[key] = fields[key]
        end for
    end function
    return result
end function

sub main()
    m.top = node()
    m.top.visible = true
    m.top.parentVisible = true
    m.busy = node()
    m.avatar = {uri: "avatar"}
    m.channelLoading = false
    m.playbackPending = false
    m.liveItem = invalid
    m.getStuffLive = node()
    m.getStuffVideo = node()
    m.playbackRequestId = 0
    m.playbackStatus = node()
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
    m.liveItem = channelLiveItem({type:"live",title:"Live now",user_name:"Channel",user_login:"channel",game_name:"Game",viewer_count:1234,thumbnail_url:"https://image/{width}x{height}.jpg"})
    renderChannelItems()
    first = m.pastBroadcastsList.content.getChild(0).getChild(0)
    check(first.playbackKind = "live" and first.HDPosterUrl = "https://image/320x180.jpg", "Live card leads the profile with a correctly sized thumbnail")
    check(m.pastBroadcastsList.content.getChild(0).getChild(1).Rating = "0", "Recordings retain their video IDs after the live card is prepended")
    m.pastBroadcastsList.rowItemSelected = [0,0]
    onVideoItemSelect()
    check(m.getStuffLive.control = "RUN" and m.getStuffLive.streamerRequested = "channel", "Live card starts the live playback request")
    check(m.getStuffVideo.control <> "RUN" and m.top.streamViewers = "1.2K", "Live selection does not start a VOD token request")
    m.getStuffLive.streamUrl = "live-url"
    m.getStuffLive.playbackInfo = {variants: []}
    onGetLiveUrl()
    check(m.top.streamUrl = "live-url" and m.top.videoUrl = invalid, "Live playback publishes through the live route")
    m.pastBroadcastsList.rowItemSelected = [0,1]
    onVideoItemSelect()
    check(m.getStuffVideo.videoId = "0" and m.getStuffVideo.control = "RUN", "Recording selection still requests the correct VOD")
    m.getStuffLive.streamUrl = "stale-live-url"
    onGetLiveUrl()
    check(m.top.streamUrl = "live-url", "An older live result cannot replace a newer VOD request")
    m.playbackPending = true
    onGetVideos()
    check(m.busy.active, "Recording metadata arrival does not clear a pending live/VOD playback spinner")
    check(channelLiveItem(invalid) = invalid and channelLiveItem({type:""}) = invalid, "Offline and unknown status do not fabricate a live card")
    m.liveItem = invalid
    renderChannelItems()
    check(m.pastBroadcastsList.content.getChild(0).getChild(0).Rating = "0", "Offline profiles begin with recordings")
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
    m.top.parentVisible = false
    m.pastBroadcastsList.setFocus(false)
    focusContent()
    check(not m.pastBroadcastsList.hasFocus(), "Hidden Home ancestor prevents late channel results stealing player focus")
    check(channelFollowerLabel(1234567) = "1,234,567 followers", "Actual follower counts are grouped without losing precision")
    check(channelFollowerLabel(0) = "0 followers" and channelFollowerLabel(invalid) = "", "Unknown follower count is distinct from real zero")
    testVideoPreload()
    print "PASS follower labels, ancestor focus, VOD grid, focus after loading, pagination deduplication, stale channel and playback guards"
end sub

sub testVideoPreload()
    m.top.parentVisible = true
    m.top.visible = true
    m.channelLoading = false
    m.playbackPending = false
    m.videoItems = []
    m.seenVideos = {}
    m.liveItem = invalid
    m.videosLogin = "channel"
    m.requestCursor = ""
    m.pastBroadcastsList = node()
    m.pastBroadcastsList.numRows = 2
    m.getVideos = node()
    m.getVideos.pagination = "vod2"
    m.getVideos.searchResults = []
    for index = 0 to 23
        m.getVideos.searchResults.Push({id:index.ToStr(),title:"VOD",user_name:"C",duration:"1:00",published_at:"Today",thumbnail_url:"thumb",viewer_count:"1"})
    end for
    onGetVideos()
    m.pastBroadcastsList.rowItemFocused = [2, 3]
    onGridFocus()
    check(m.videosPending and m.requestCursor = "vod2", "Profile recordings use the same early preload window")
    original = m.pastBroadcastsList.content
    m.getVideos.state = "run"
    m.pastBroadcastsList.rowItemFocused = [5, 3]
    m.pastBroadcastsList.jumpToRowItem = invalid
    m.getVideos.searchResults = [{id:"new",title:"New VOD",user_name:"C",duration:"1:00",published_at:"Today",thumbnail_url:"thumb",viewer_count:"1"}]
    m.getVideos.pagination = "vod3"
    onGetVideos()
    check(original.testId = m.pastBroadcastsList.content.testId and original.getChildCount() = 7, "VOD append retains existing rows")
    check(m.pastBroadcastsList.jumpToRowItem = invalid and m.pastBroadcastsList.rowItemFocused[1] = 3, "A VOD response preserves the latest native selection")
    m.getVideos.state = "stop"
    onVideosStopped()
    check(m.videosPending and m.requestCursor = "vod3", "A short VOD page catches up once its Task has stopped")
    m.getVideos.errorMessage = "offline"
    m.getVideos.searchResults = []
    m.getVideos.pagination = ""
    onGetVideos()
    onVideosStopped()
    check(not m.videosPending and m.getVideos.pagination = "vod3" and m.pastBroadcastsList.hasFocus(), "Failed VOD preloading preserves cards, focus, and a retryable cursor without looping")
end sub
