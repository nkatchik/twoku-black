sub init()
    m.reloadPending = false
    m.channelLoading = false
    m.playbackRequestId = 0
    m.playbackPending = false
    m.liveItem = invalid
    m.channelLiveTask = invalid
    m.channelLiveRequestId = 0
    m.liveStatusTimer = m.top.findNode("liveStatusTimer")
    m.liveStatusTimer.observeField("fire", "onChannelLivePoll")
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
    m.getVodPlayback = CreateObject("roSGNode", "GetVodPlayback")
    m.getVodPlayback.observeField("streamUrl", "onGetVideoUrl")
    m.getVodPlayback.observeField("state", "onPlaybackStopped")
    m.getLivePlayback = CreateObject("roSGNode", "GetLivePlayback")
    m.getLivePlayback.observeField("streamUrl", "onGetLiveUrl")
    m.getLivePlayback.observeField("state", "onLivePlaybackStopped")
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

sub reloadContent()
    if not channelVisible() then return
    m.reloadPending = true
    cancelChannelLiveCheck()
    cancelPlaybackRequest()
    m.busy.active = true
    tryReloadContent()
end sub

sub tryReloadContent()
    if m.reloadPending <> true then return
    if not channelVisible()
        m.reloadPending = false
        return
    end if
    if m.getUserChannel.state = "run" or m.getVideos.state = "run" then return
    m.reloadPending = false
    onSelectedStreamerChange()
end sub

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
    if not channelVisible() then m.reloadPending = false
    if not channelVisible()
        cancelPlaybackRequest()
        cancelChannelLiveCheck()
    else if m.userId <> ""
        m.liveStatusTimer.control = "start"
    end if
    focusContent()
end sub

sub onSelectedStreamerChange()
    cancelChannelLiveCheck()
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
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getUserChannel.state = "stop" and m.requestedLogin <> m.top.streamerSelectedName
        requestUserInfo()
    end if
end sub

sub onGetUserInfo()
    if m.reloadPending = true then return
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
    if channelVisible() then m.liveStatusTimer.control = "start"
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
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getVideos.state = "stop" and m.videosLogin <> m.top.streamerSelectedName
        getVideos()
    end if
    if m.getVideos.state = "stop" and m.getVideos.errorMessage = "" then onGridFocus()
end sub

sub onGetVideos()
    if m.reloadPending = true then return
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
    if m.reloadPending = true then return
    if not channelVisible() or not channelHasVideos() then return
    if gridNeedsMore(m.pastBroadcastsList)
        getMoreVideos()
    end if
end sub

sub onVideoItemSelect()
    if not channelVisible() or not channelHasVideos() or m.getVodPlayback.state = "run" or m.getLivePlayback.state = "run" then return
    index = m.pastBroadcastsList.rowItemSelected
    item = m.pastBroadcastsList.content.getChild(index[0]).getChild(index[1])
    m.top.videoTitle = item.Title
    task = m.getVodPlayback
    if item.playbackKind = "live"
        task = m.getLivePlayback
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
    if m.getVodPlayback.cancelRequested or m.getVodPlayback.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    m.playbackPending = false
    m.busy.active = false
    if not channelVisible() or m.videoLogin <> m.top.streamerSelectedName then return
    if m.getVodPlayback.streamUrl = "" then return
    m.top.thumbnailInfo = m.getVodPlayback.thumbnailInfo
    m.top.playbackInfo = m.getVodPlayback.playbackInfo
    m.top.videoUrl = m.getVodPlayback.streamUrl
end sub

sub onGetLiveUrl()
    if m.getLivePlayback.cancelRequested or m.getLivePlayback.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    m.playbackPending = false
    m.busy.active = false
    if not channelVisible() or m.videoLogin <> m.top.streamerSelectedName then return
    if m.getLivePlayback.streamUrl = ""
        info = m.getLivePlayback.playbackInfo
        if type(info) = "roAssociativeArray"
            if info.liveStatus = "offline" then updateChannelLiveItem(invalid)
        end if
        return
    end if
    m.top.playbackInfo = m.getLivePlayback.playbackInfo
    m.top.streamUrl = m.getLivePlayback.streamUrl
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
    m.getVodPlayback.cancelRequested = true
    m.getVodPlayback.requestId = m.playbackRequestId
    m.getLivePlayback.cancelRequested = true
    m.getLivePlayback.requestId = m.playbackRequestId
    m.playbackStatus.text = ""
end sub

sub onPlaybackStopped()
    finishChannelPlayback(m.getVodPlayback)
end sub

sub onLivePlaybackStopped()
    finishChannelPlayback(m.getLivePlayback)
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

sub cancelChannelLiveCheck()
    m.liveStatusTimer.control = "stop"
    m.channelLiveRequestId += 1
    if m.channelLiveTask <> invalid then m.channelLiveTask.cancelRequested = true
end sub

sub onChannelLivePoll()
    if not channelVisible() or m.userId = "" then return
    if m.channelLoading or m.reloadPending or m.playbackPending then return
    if m.getUserChannel.state = "run" then return
    if m.channelLiveTask <> invalid
        if m.channelLiveTask.state = "run" then return
    end if
    m.channelLiveRequestId += 1
    m.channelLiveTask = CreateObject("roSGNode", "GetLiveStatus")
    m.channelLiveTask.login = LCase(m.top.streamerSelectedName)
    m.channelLiveTask.requestId = m.channelLiveRequestId
    m.channelLiveTask.cancelRequested = false
    m.channelLiveTask.observeField("state", "onChannelLiveStatus")
    m.channelLiveTask.control = "RUN"
end sub

sub onChannelLiveStatus()
    task = m.channelLiveTask
    if task = invalid or not channelVisible() then return
    if task.state <> "stop" or task.cancelRequested then return
    if task.requestId <> m.channelLiveRequestId or task.login <> LCase(m.top.streamerSelectedName) then return
    if task.liveStatus = "live"
        updateChannelLiveItem(task.liveStream)
    else if task.liveStatus = "offline"
        updateChannelLiveItem(invalid)
    end if
end sub

sub updateChannelLiveItem(stream)
    previous = m.liveItem
    m.liveItem = channelLiveItem(stream)
    if previous = invalid and m.liveItem = invalid then return
    if previous <> invalid and m.liveItem <> invalid
        ' Metadata changes leave the grid and its current scroll position intact.
        m.pastBroadcastsList.content.getChild(0).replaceChild(m.liveItem, 0)
        return
    end if
    ' Adding/removing the leading live card shifts VOD indexes by one. Keep the
    ' same recording selected and leave its pagination/request state untouched.
    index = 0
    position = m.pastBroadcastsList.rowItemFocused
    if position.Count() = 2 then index = position[0] * 4 + position[1]
    if previous = invalid
        if m.videoItems.Count() > 0 then index += 1
    else if index > 0
        index -= 1
    end if
    renderChannelItems()
    count = m.videoItems.Count()
    if m.liveItem <> invalid then count += 1
    if count > 0
        if index >= count then index = count - 1
        m.pastBroadcastsList.jumpToRowItem = [Int(index / 4), index MOD 4]
    else if channelVisible()
        focusContent()
    end if
end sub
