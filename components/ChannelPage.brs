sub init()
    m.channelLoading = false
    m.playbackRequestId = 0
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
    m.pastBroadcastsList.observeField("itemSelected", "onVideoItemSelect")
    m.pastBroadcastsList.observeField("rowItemFocused", "onGridFocus")
    m.top.observeField("streamerSelectedName", "onSelectedStreamerChange")
    m.top.observeField("visible", "onGetFocus")
    m.requestedLogin = ""
    m.videosLogin = ""
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
    m.videoItems = []
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
    getVideos()
end sub

sub getVideos()
    if m.getVideos.state = "run" or m.userId = "" then return
    m.videosLogin = m.top.streamerSelectedName
    m.getVideos.userId = m.userId
    m.getVideos.pagination = ""
    m.requestCursor = ""
    m.getVideos.control = "RUN"
end sub

sub onVideosStopped()
    if m.getVideos.state = "stop" and m.videosLogin <> m.top.streamerSelectedName
        getVideos()
    end if
end sub

sub onGetVideos()
    if m.videosLogin <> m.top.streamerSelectedName then return
    m.channelLoading = false
    m.busy.active = false
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
                item.addFields({channelAvatar: m.avatar.uri})
                item.ShortDescriptionLine1 = m.top.streamerSelectedName
                item.ShortDescriptionLine2 = video.viewer_count
                m.videoItems.push(item)
            end if
        end for
    end if
    m.moreVideos = m.getVideos.pagination <> "" and m.getVideos.pagination <> m.requestCursor
    content = CreateObject("roSGNode", "ContentNode")
    row = invalid
    for index = 0 to m.videoItems.count() - 1
        if index MOD 4 = 0
            row = CreateObject("roSGNode", "ContentNode")
            content.appendChild(row)
        end if
        row.appendChild(m.videoItems[index])
    end for
    position = m.pastBroadcastsList.rowItemFocused
    wasEmpty = not channelHasVideos()
    m.pastBroadcastsList.content = content
    m.pastBroadcastsList.jumpToRowItem = position
    m.emptyLabel.visible = not channelHasVideos()
    m.emptyLabel.text = "No videos available"
    if m.getVideos.errorMessage <> "" then m.emptyLabel.text = m.getVideos.errorMessage
    if wasEmpty and channelVisible() then focusContent()
end sub

sub getMoreVideos()
    if m.getVideos.state = "run" or not m.moreVideos then return
    m.requestCursor = m.getVideos.pagination
    m.getVideos.control = "RUN"
end sub

sub onGridFocus()
    if not channelVisible() or not channelHasVideos() then return
    if m.pastBroadcastsList.rowItemFocused[0] >= m.pastBroadcastsList.content.getChildCount() - 2
        getMoreVideos()
    end if
end sub

sub onVideoItemSelect()
    if not channelHasVideos() or m.getStuffVideo.state = "run" then return
    index = m.pastBroadcastsList.rowItemSelected
    item = m.pastBroadcastsList.content.getChild(index[0]).getChild(index[1])
    m.top.videoTitle = item.Title
    m.getStuffVideo.videoId = item.Rating
    m.videoLogin = m.top.streamerSelectedName
    m.playbackRequestId += 1
    m.getStuffVideo.requestId = m.playbackRequestId
    m.getStuffVideo.cancelRequested = false
    m.getStuffVideo.errorMessage = ""
    m.playbackStatus.text = ""
    m.busy.active = true
    m.getStuffVideo.control = "RUN"
end sub

sub onGetVideoUrl()
    if m.getStuffVideo.cancelRequested or m.getStuffVideo.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    m.busy.active = false
    if not channelVisible() or m.videoLogin <> m.top.streamerSelectedName then return
    if m.getStuffVideo.streamUrl = "" then return
    m.top.thumbnailInfo = m.getStuffVideo.thumbnailInfo
    m.top.playbackInfo = m.getStuffVideo.playbackInfo
    m.top.videoUrl = m.getStuffVideo.streamUrl
end sub

function onKeyEvent(key, press) as Boolean
    if not press or not channelVisible() then return false
    if key = "OK" and not channelHasVideos()
        onSelectedStreamerChange()
        return true
    end if
    return false
end function

sub cancelPlaybackRequest()
    m.busy.active = m.channelLoading
    m.playbackRequestId += 1
    m.getStuffVideo.cancelRequested = true
    m.getStuffVideo.requestId = m.playbackRequestId
    m.playbackStatus.text = ""
end sub

sub onPlaybackStopped()
    if not channelVisible() or m.getStuffVideo.state <> "stop" then return
    if m.getStuffVideo.cancelRequested or m.getStuffVideo.requestId <> m.playbackRequestId then return
    m.busy.active = false
    if m.getStuffVideo.errorMessage <> ""
        m.playbackStatus.text = m.getStuffVideo.errorMessage
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
