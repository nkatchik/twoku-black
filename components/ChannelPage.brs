sub init()
    m.channelLoading = false
    m.playbackRequestId = 0
    m.playbackPending = false
    m.liveItem = invalid
    m.playbackStatus = m.top.findNode("playbackStatus")
    m.top.focusable = true
    m.avatar = m.top.findNode("avatar")
    m.username = m.top.findNode("username")
    m.description = m.top.findNode("description")
    m.followers = m.top.findNode("followers")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.busy = m.top.findNode("busy")
    m.pastBroadcastsList = m.top.findNode("pastBroadcastsList")
    m.getUserChannel = CreateObject("roSGNode", "GetUserChannel")
    m.getUserChannel.includeFollowers = true
    m.getUserChannel.observeField("searchResults", "onGetUserInfo")
    m.getUserChannel.observeField("state", "onUserStopped")
    m.getVideos = CreateObject("roSGNode", "GetVideos")
    m.getVideos.observeField("searchResults", "onGetVideos")
    m.getVideos.observeField("state", "onVideosStopped")
    m.getStuffVideo = CreateObject("roSGNode", "GetStuffVideo")
    m.getStuffVideo.observeField("streamUrl", "onGetVideoUrl")
    m.getStuffVideo.observeField("state", "onPlaybackStopped")
    m.getStuffLive = CreateObject("roSGNode", "GetStuff")
    m.getStuffLive.observeField("streamUrl", "onGetLiveUrl")
    m.getStuffLive.observeField("state", "onLivePlaybackStopped")
    m.pastBroadcastsList.observeField("rowItemSelected", "onVideoItemSelect")
    m.pastBroadcastsList.observeField("rowItemFocused", "onGridFocus")
    m.top.observeField("streamerSelectedName", "onSelectedStreamerChange")
    m.top.observeField("visible", "onGetFocus")
    m.requestedLogin = ""
    m.videosLogin = ""
    m.videosPending = false
    m.videoItems = []
    m.seenVideos = {}
    m.moreVideos = true
    m.userId = ""
end sub

function channelHasVideos() as Boolean
    if m.pastBroadcastsList.content = invalid then return false
    return m.pastBroadcastsList.content.getChildCount() > 0
end function

sub focusContent()
    if not channelVisible() then return
    m.top.streamItemFocused = false
    if channelHasVideos()
        m.pastBroadcastsList.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

sub onGetFocus()
    m.busy.enabled = channelVisible()
    if not channelVisible() then cancelPlaybackRequest()
    focusContent()
end sub

sub onSelectedStreamerChange()
    cancelPlaybackRequest()
    m.username.text = m.top.streamerSelectedName
    m.avatar.uri = ""
    m.description.text = ""
    m.followers.text = ""
    m.channelLoading = true
    m.emptyLabel.text = ""
    m.emptyLabel.visible = false
    m.busy.enabled = channelVisible()
    m.busy.active = true
    m.pastBroadcastsList.content = invalid
    m.videosPending = false
    m.videoItems = []
    m.liveItem = invalid
    m.seenVideos = {}
    m.moreVideos = true
    m.userId = ""
    requestUserInfo()
    focusContent()
end sub

sub requestUserInfo()
    if m.getUserChannel.state = "run" then return
    m.requestedLogin = m.top.streamerSelectedName
    m.getUserChannel.loginRequested = m.requestedLogin
    m.getUserChannel.control = "RUN"
end sub

sub onUserStopped()
    if m.getUserChannel.state = "stop" and m.requestedLogin <> m.top.streamerSelectedName
        requestUserInfo()
    end if
end sub

sub onGetUserInfo()
    if m.requestedLogin <> m.top.streamerSelectedName then return
    user = m.getUserChannel.searchResults
    if user = invalid or user.id = invalid
        m.emptyLabel.text = "Couldn't load this channel. Press OK to retry."
        m.emptyLabel.visible = true
        m.channelLoading = false
        m.busy.active = false
        return
    end if
    m.userId = user.id
    m.username.text = user.display_name
    m.avatar.uri = user.profile_image_url
    m.description.text = user.description
    m.followers.text = channelFollowerLabel(user.followers)
    m.top.streamDurationSeconds = m.getUserChannel.streamDurationSeconds
    m.liveItem = channelLiveItem(user.live_stream)
    renderChannelItems()
    getVideos()
end sub

function channelLiveItem(stream) as Dynamic
    if type(stream) <> "roAssociativeArray" then return invalid
    if stream.type <> "live" then return invalid
    item = CreateObject("roSGNode", "ContentNode")
    item.addFields({playbackKind: "live"})
    item.Title = stream.title
    item.Description = stream.user_name
    item.Categories = stream.game_name
    item.ShortDescriptionLine1 = stream.user_login
    item.ShortDescriptionLine2 = channelViewerLabel(stream.viewer_count)
    if stream.thumbnail_url <> invalid then item.HDPosterUrl = stream.thumbnail_url.Replace("{width}", "320").Replace("{height}", "180")
    return item
end function

function channelViewerLabel(count) as String
    if count = invalid then return ""
    if count >= 1000000 then return (Int(count / 100000) / 10).ToStr() + "M"
    if count >= 1000 then return (Int(count / 100) / 10).ToStr() + "K"
    return count.ToStr().Trim()
end function

sub getVideos()
    if m.getVideos.state = "run" or m.userId = "" then return
    m.videosLogin = m.top.streamerSelectedName
    m.getVideos.userId = m.userId
    m.getVideos.pagination = ""
    m.requestCursor = ""
    m.videosPending = true
    m.getVideos.control = "RUN"
end sub

sub onVideosStopped()
    if m.getVideos.state = "stop" and m.videosLogin <> m.top.streamerSelectedName
        getVideos()
    end if
    if m.getVideos.state = "stop" and m.getVideos.errorMessage = "" then onGridFocus()
end sub

sub onGetVideos()
    if m.videosLogin <> m.top.streamerSelectedName then return
    m.channelLoading = false
    m.videosPending = false
    m.busy.active = m.playbackPending
    items = []
    results = m.getVideos.searchResults
    if results <> invalid
        for each video in results
            if not m.seenVideos.DoesExist(video.id)
                m.seenVideos[video.id] = true
                item = CreateObject("roSGNode", "ContentNode")
                item.Title = video.title
                item.Description = video.user_name
                item.Categories = video.duration
                item.ReleaseDate = video.published_at
                item.Rating = video.id
                item.HDPosterUrl = video.thumbnail_url
                item.addFields({channelAvatar: m.avatar.uri, playbackKind: "vod"})
                item.ShortDescriptionLine1 = m.top.streamerSelectedName
                item.ShortDescriptionLine2 = video.viewer_count
                m.videoItems.push(item)
                items.Push(item)
            end if
        end for
    end if
    if m.getVideos.errorMessage <> "" then m.getVideos.pagination = m.requestCursor
    finishGridPage(m.getVideos, m.requestCursor, items.Count())
    m.moreVideos = m.getVideos.pagination <> ""
    renderChannelItems(items)
    if m.getVideos.errorMessage = "" then onGridFocus()
end sub

sub renderChannelItems(newItems = invalid)
    reset = newItems = invalid
    if reset
        newItems = []
        if m.liveItem <> invalid then newItems.Push(m.liveItem)
        for each item in m.videoItems
            newItems.Push(item)
        end for
    end if
    wasEmpty = not channelHasVideos()
    appendGridItems(m.pastBroadcastsList, newItems, reset)
    m.emptyLabel.visible = not channelHasVideos() and not m.channelLoading
    m.emptyLabel.text = "No videos available"
    if m.getVideos.errorMessage <> "" then m.emptyLabel.text = m.getVideos.errorMessage
    if wasEmpty and channelVisible() then focusContent()
end sub

sub getMoreVideos()
    if m.videosLogin <> m.top.streamerSelectedName then return
    if m.channelLoading or m.videosPending or m.getVideos.state = "run" or not m.moreVideos then return
    if m.getVideos.pagination = "" then return
    m.requestCursor = m.getVideos.pagination
    m.videosPending = true
    m.getVideos.control = "RUN"
end sub

sub onGridFocus()
    if not channelVisible() or not channelHasVideos() then return
    if gridNeedsMore(m.pastBroadcastsList)
        getMoreVideos()
    end if
end sub

sub onVideoItemSelect()
    if not channelVisible() or not channelHasVideos() or m.getStuffVideo.state = "run" or m.getStuffLive.state = "run" then return
    index = m.pastBroadcastsList.rowItemSelected
    item = m.pastBroadcastsList.content.getChild(index[0]).getChild(index[1])
    m.top.videoTitle = item.Title
    task = m.getStuffVideo
    if item.playbackKind = "live"
        task = m.getStuffLive
        task.streamerRequested = item.ShortDescriptionLine1
        m.top.streamViewers = item.ShortDescriptionLine2
    else
        task.videoId = item.Rating
    end if
    m.videoLogin = m.top.streamerSelectedName
    m.playbackRequestId += 1
    m.playbackPending = true
    task.requestId = m.playbackRequestId
    task.cancelRequested = false
    task.errorMessage = ""
    m.playbackStatus.text = ""
    m.busy.active = true
    task.control = "RUN"
end sub

sub onGetVideoUrl()
    if m.getStuffVideo.cancelRequested or m.getStuffVideo.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    m.playbackPending = false
    m.busy.active = false
    if not channelVisible() or m.videoLogin <> m.top.streamerSelectedName then return
    if m.getStuffVideo.streamUrl = "" then return
    m.top.thumbnailInfo = m.getStuffVideo.thumbnailInfo
    m.top.playbackInfo = m.getStuffVideo.playbackInfo
    m.top.videoUrl = m.getStuffVideo.streamUrl
end sub

sub onGetLiveUrl()
    if m.getStuffLive.cancelRequested or m.getStuffLive.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    m.playbackPending = false
    m.busy.active = false
    if not channelVisible() or m.videoLogin <> m.top.streamerSelectedName then return
    if m.getStuffLive.streamUrl = "" then return
    m.top.playbackInfo = m.getStuffLive.playbackInfo
    m.top.streamUrl = m.getStuffLive.streamUrl
end sub

function onKeyEvent(key, press) as Boolean
    if not press or not channelVisible() then return false
    if key = "down"
        onGridFocus()
        return true
    end if
    if key = "OK" and not channelHasVideos()
        onSelectedStreamerChange()
        return true
    end if
    return false
end function

sub cancelPlaybackRequest()
    m.playbackPending = false
    m.busy.active = m.channelLoading
    m.playbackRequestId += 1
    m.getStuffVideo.cancelRequested = true
    m.getStuffVideo.requestId = m.playbackRequestId
    m.getStuffLive.cancelRequested = true
    m.getStuffLive.requestId = m.playbackRequestId
    m.playbackStatus.text = ""
end sub

sub onPlaybackStopped()
    finishChannelPlayback(m.getStuffVideo)
end sub

sub onLivePlaybackStopped()
    finishChannelPlayback(m.getStuffLive)
end sub

sub finishChannelPlayback(task)
    if not channelVisible() or task.state <> "stop" then return
    if task.cancelRequested or task.requestId <> m.playbackRequestId then return
    m.playbackPending = false
    m.busy.active = m.channelLoading
    if task.errorMessage <> ""
        m.playbackStatus.text = task.errorMessage
    end if
end sub

function channelFollowerLabel(count) as String
    kind = LCase(type(count))
    if kind <> "integer" and kind <> "roint" and kind <> "float" and kind <> "double" and kind <> "longinteger" and kind <> "rolonginteger" then return ""
    if count < 0 then return ""
    digits = Int(count).ToStr()
    label = ""
    for index = 1 to Len(digits)
        if index > 1 and (Len(digits) - index + 1) MOD 3 = 0 then label += ","
        label += Mid(digits, index, 1)
    end for
    if count = 1 then return label + " follower"
    return label + " followers"
end function

function channelVisible() as Boolean
    return m.top.visible and m.top.parentVisible
end function
