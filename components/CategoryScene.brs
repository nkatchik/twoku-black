sub init()
    m.reloadPending = false
    m.busy = m.top.findNode("busy")
    m.streamsLoading = false
    m.clipsLoading = false
    m.playbackLoading = false
    m.playbackRequestId = 0
    m.playbackStatus = m.top.findNode("playbackStatus")
    m.browseList = m.top.findNode("browseList")
    m.browseClipsList = m.top.findNode("browseClipsList")
    m.browseButtons = m.top.findNode("browseButtons")
    m.liveButton = m.top.findNode("liveButton")
    m.liveLine = m.top.findNode("liveLine")
    m.clipButton = m.top.findNode("clipButton")
    m.clipLine = m.top.findNode("clipLine")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.categoryHeader = m.top.findNode("categoryHeader")
    m.categoryHeader.content = CreateObject("roSGNode", "ContentNode")
    m.categoryDescription = ""
    m.categoryInfoVersion = 0
    m.categoryInfoPending = false
    m.getCategoryInfo = CreateObject("roSGNode", "GetCategoryInfo")
    m.getCategoryInfo.observeField("state", "onCategoryInfoStopped")
    m.getStreams = CreateObject("roSGNode", "GetStreams")
    m.getStreams.observeField("searchResults", "onSearchResultChange")
    m.getStreams.observeField("state", "onStreamsStopped")
    m.getClips = CreateObject("roSGNode", "GetClips")
    m.getClips.observeField("searchResults", "insertClips")
    m.getClips.observeField("state", "onClipsStopped")
    m.getLivePlayback = CreateObject("roSGNode", "GetLivePlayback")
    m.getLivePlayback.observeField("streamUrl", "onStreamUrlChange")
    m.getLivePlayback.observeField("state", "onPlaybackStopped")
    m.getClipPlayback = CreateObject("roSGNode", "GetClipPlayback")
    m.getClipPlayback.observeField("streamUrl", "onClipPlaybackUrl")
    m.getClipPlayback.observeField("state", "onClipPlaybackStopped")
    m.browseList.observeField("itemSelected", "onBrowseItemSelect")
    m.browseClipsList.observeField("itemSelected", "onBrowseClipsItemSelect")
    m.browseList.observeField("rowItemFocused", "onGridFocus")
    m.browseClipsList.observeField("rowItemFocused", "onGridFocus")
    m.top.observeField("visible", "onGetFocus")
    m.streamsCategory = ""
    m.clipsCategory = ""
    m.seenStreams = {}
    m.seenClips = {}
    m.pendingGridFocus = ""
    layoutTabs()
    updateCategoryBusy()
end sub

sub updateCategoryHeader()
    if m.categoryHeader = invalid then return
    headers = [m.categoryHeader.content]
    for each list in [m.browseList, m.browseClipsList]
        if categoryHasRows(list) then headers.Push(list.content.getChild(0))
    end for
    for each header in headers
        header.Title = m.top.currentCategoryName
        header.HDPosterUrl = m.top.currentCategoryImage
        header.Description = m.categoryDescription
    end for
end sub

sub requestCategoryDescription()
    if m.getCategoryInfo = invalid then return
    m.categoryInfoVersion += 1
    m.getCategoryInfo.cancelRequested = true
    m.categoryInfoPending = true
    startCategoryDescription()
end sub

sub startCategoryDescription()
    if not m.categoryInfoPending or m.getCategoryInfo.state = "run" then return
    m.categoryInfoPending = false
    m.getCategoryInfo.categoryId = m.top.currentCategory
    m.getCategoryInfo.requestId = m.categoryInfoVersion
    m.getCategoryInfo.cancelRequested = false
    m.getCategoryInfo.info = {}
    m.getCategoryInfo.control = "RUN"
end sub

sub onCategoryInfoStopped()
    if m.getCategoryInfo.state <> "stop" then return
    if m.categoryInfoPending
        startCategoryDescription()
        return
    end if
    if m.getCategoryInfo.cancelRequested or m.getCategoryInfo.requestId <> m.categoryInfoVersion then return
    if m.getCategoryInfo.categoryId <> m.top.currentCategory then return
    info = m.getCategoryInfo.info
    if type(info) <> "roAssociativeArray" then return
    if info.id <> m.top.currentCategory then return
    m.categoryDescription = info.description
    updateCategoryHeader()
end sub

sub reloadContent()
    if not m.top.visible then return
    m.reloadPending = true
    cancelPlaybackRequest()
    requestCategoryDescription()
    m.busy.active = true
    tryReloadContent()
end sub

sub tryReloadContent()
    if m.reloadPending <> true then return
    if not m.top.visible
        m.reloadPending = false
        return
    end if
    if m.getStreams.state = "run" or m.getClips.state = "run" then return
    m.reloadPending = false
    m.streamsLoading = false
    m.clipsLoading = false
    m.emptyLabel.visible = false
    m.emptyLabel.text = ""
    if m.clipLine.visible
        m.browseClipsList.content = invalid
        m.seenClips = {}
        onClipsLoad()
    else
        m.browseList.content = invalid
        m.seenStreams = {}
        startCategoryStreams()
    end if
    focusContent()
end sub

function categoryHasRows(list) as Boolean
    if list.content = invalid then return false
    return list.content.getChildCount() > 0
end function

sub focusContent()
    if not m.top.visible then return
    m.pendingGridFocus = ""
    if m.clipLine.visible and categoryHasRows(m.browseClipsList)
        m.browseClipsList.setFocus(true)
    else if m.liveLine.visible and categoryHasRows(m.browseList)
        m.browseList.setFocus(true)
    else
        m.pendingGridFocus = "live"
        if m.clipLine.visible then m.pendingGridFocus = "clips"
        m.browseButtons.setFocus(true)
    end if
end sub

sub completeCategoryFocus(feed as String)
    if m.pendingGridFocus <> feed then return
    m.pendingGridFocus = ""
    if not m.top.visible or not m.browseButtons.hasFocus() then return
    if feed = "live" and not m.liveLine.visible then return
    if feed = "clips" and not m.clipLine.visible then return
    focusContent()
end sub

sub onGetFocus()
    if not m.top.visible
        m.reloadPending = false
        m.pendingGridFocus = ""
        cancelPlaybackRequest()
    end if
    if m.top.visible
        m.browseList.visible = m.liveLine.visible
        m.browseClipsList.visible = m.clipLine.visible
        focusContent()
    end if
    updateCategoryBusy()
end sub

sub onCategoryChange()
    cancelPlaybackRequest()
    m.seenStreams = {}
    m.seenClips = {}
    m.browseList.content = invalid
    m.browseClipsList.content = invalid
    m.categoryDescription = ""
    m.pendingGridFocus = "live"
    m.liveLine.visible = true
    m.clipLine.visible = false
    m.liveButton.color = "0xF4F4F7FF"
    m.clipButton.color = "0xA9A9B2FF"
    m.browseList.visible = true
    m.browseClipsList.visible = false
    m.emptyLabel.text = ""
    m.emptyLabel.visible = false
    m.streamsLoading = true
    m.clipsLoading = false
    updateCategoryBusy()
    updateCategoryHeader()
    requestCategoryDescription()
    startCategoryStreams()
end sub

sub startCategoryStreams()
    if m.getStreams.state = "run" then return
    m.streamsCategory = m.top.currentCategory
    m.getStreams.gameRequested = m.streamsCategory
    m.streamsCursor = ""
    m.getStreams.pagination = ""
    m.streamsLoading = true
    updateCategoryBusy()
    m.getStreams.control = "RUN"
end sub

sub onStreamsStopped()
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getStreams.state = "stop" and m.streamsCategory = m.top.currentCategory then m.streamsLoading = false
    updateCategoryBusy()
    if m.getStreams.state = "stop" and m.streamsCategory <> m.top.currentCategory
        startCategoryStreams()
    end if
    if m.getStreams.state = "stop" and m.getStreams.errorMessage = "" and m.liveLine.visible then onGridFocus()
end sub

sub onClipsStopped()
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getClips.state = "stop" and m.clipsCategory = m.top.currentCategory then m.clipsLoading = false
    updateCategoryBusy()
    if m.getClips.state = "stop" and m.clipLine.visible and m.clipsCategory <> m.top.currentCategory
        onClipsLoad()
    end if
    if m.getClips.state = "stop" and m.getClips.errorMessage = "" and m.clipLine.visible then onGridFocus()
end sub

sub onClipsLoad()
    m.browseList.visible = false
    m.browseClipsList.visible = true
    m.emptyLabel.visible = false
    if categoryHasRows(m.browseClipsList) then return
    m.emptyLabel.text = ""
    m.clipsLoading = true
    updateCategoryBusy()
    if m.getClips.state = "run" then return
    m.clipsCategory = m.top.currentCategory
    m.getClips.gameRequested = m.clipsCategory
    m.clipsCursor = ""
    m.getClips.pagination = ""
    m.getClips.control = "RUN"
end sub

function numberToText(number) as String
    if number = invalid then return ""
    if number >= 1000000 then return (Int(number / 100000) / 10).ToStr() + "M"
    if number >= 1000 then return (Int(number / 100) / 10).ToStr() + "K"
    return number.ToStr().Trim()
end function

sub onSearchResultChange()
    if m.reloadPending = true then return
    if m.streamsCategory <> m.top.currentCategory then return
    m.streamsLoading = false
    updateCategoryBusy()
    items = []
    if m.getStreams.searchResults <> invalid
        for each stream in m.getStreams.searchResults
            if not m.seenStreams.DoesExist(stream.name)
                m.seenStreams[stream.name] = true
                item = CreateObject("roSGNode", "ContentNode")
                item.Title = stream.title
                item.Description = stream.display_name
                item.Categories = stream.game
                item.HDPosterUrl = stream.thumbnail
                item.ShortDescriptionLine1 = stream.name
                item.ShortDescriptionLine2 = numberToText(stream.viewers)
                items.Push(item)
            end if
        end for
    end if
    appendGridItems(m.browseList, items)
    updateCategoryHeader()
    updateCategoryBusy()
    finishGridPage(m.getStreams, m.streamsCursor, items.Count())
    completeCategoryFocus("live")
    if m.liveLine.visible
        m.emptyLabel.visible = not categoryHasRows(m.browseList)
        m.emptyLabel.text = "No live channels in this category"
        if m.getStreams.errorMessage <> "" then m.emptyLabel.text = m.getStreams.errorMessage
    end if
    if m.getStreams.errorMessage = "" then onGridFocus()
end sub

sub insertClips()
    if m.reloadPending = true then return
    if m.clipsCategory <> m.top.currentCategory then return
    m.clipsLoading = false
    updateCategoryBusy()
    items = []
    if m.getClips.searchResults <> invalid
        for each clip in m.getClips.searchResults
            if not m.seenClips.DoesExist(clip.thumbnail_url)
                m.seenClips[clip.thumbnail_url] = true
                item = CreateObject("roSGNode", "ContentNode")
                item.Title = clip.title
                item.Description = clip.broadcaster_name
                item.HDPosterUrl = clip.thumbnail_url
                item.ShortDescriptionLine1 = clip.id
                item.ShortDescriptionLine2 = numberToText(clip.viewer_count)
                items.Push(item)
            end if
        end for
    end if
    appendGridItems(m.browseClipsList, items)
    updateCategoryHeader()
    updateCategoryBusy()
    finishGridPage(m.getClips, m.clipsCursor, items.Count())
    completeCategoryFocus("clips")
    if m.clipLine.visible
        m.emptyLabel.visible = not categoryHasRows(m.browseClipsList)
        m.emptyLabel.text = "No clips in this category"
        if m.getClips.errorMessage <> "" then m.emptyLabel.text = m.getClips.errorMessage
    end if
    if m.getClips.errorMessage = "" then onGridFocus()
end sub

sub onStreamUrlChange()
    if m.getLivePlayback.cancelRequested or m.getLivePlayback.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    m.playbackLoading = false
    updateCategoryBusy()
    if not m.top.visible or m.getLivePlayback.streamUrl = "" then return
    m.top.streamerRequested = m.getLivePlayback.streamerRequested
    m.top.playbackInfo = m.getLivePlayback.playbackInfo
    m.top.streamUrl = m.getLivePlayback.streamUrl
end sub

sub onBrowseItemSelect()
    if not m.browseList.visible or not categoryHasRows(m.browseList) then return
    if m.getLivePlayback.state = "run" then return
    index = m.browseList.rowItemSelected
    item = m.browseList.content.getChild(index[0]).getChild(index[1])
    m.top.liveTitle = item.Title
    m.top.liveName = item.Description
    m.top.liveGame = itemCategoryText(item.Categories)
    m.top.liveViewers = item.ShortDescriptionLine2
    m.getLivePlayback.streamerRequested = item.ShortDescriptionLine1
    m.playbackRequestId += 1
    m.getLivePlayback.requestId = m.playbackRequestId
    m.getLivePlayback.cancelRequested = false
    m.getLivePlayback.errorMessage = ""
    m.playbackStatus.text = ""
    m.playbackLoading = true
    updateCategoryBusy()
    m.getLivePlayback.control = "RUN"
end sub

sub onBrowseClipsItemSelect()
    if not m.browseClipsList.visible or not categoryHasRows(m.browseClipsList) then return
    if m.getClipPlayback.state = "run" then return
    index = m.browseClipsList.rowItemSelected
    item = m.browseClipsList.content.getChild(index[0]).getChild(index[1])
    m.top.liveTitle = item.Title
    m.top.liveName = item.Description
    m.top.liveViewers = item.ShortDescriptionLine2
    m.top.liveGame = m.top.currentCategoryName
    m.playbackRequestId += 1
    m.getClipPlayback.requestId = m.playbackRequestId
    m.getClipPlayback.clipId = item.ShortDescriptionLine1
    m.getClipPlayback.cancelRequested = false
    m.getClipPlayback.errorMessage = ""
    m.playbackStatus.text = ""
    m.playbackLoading = true
    updateCategoryBusy()
    m.getClipPlayback.control = "RUN"
end sub

sub onClipPlaybackUrl()
    if not m.top.visible or m.getClipPlayback.cancelRequested then return
    if m.getClipPlayback.requestId <> m.playbackRequestId or m.getClipPlayback.streamUrl = "" then return
    info = m.getClipPlayback.playbackInfo
    m.top.streamerRequested = info.login
    m.top.liveTitle = info.title
    m.top.liveName = info.name
    m.top.playbackInfo = info
    m.playbackStatus.text = ""
    m.playbackLoading = false
    updateCategoryBusy()
    m.top.fromClip = true
    m.top.clipUrl = m.getClipPlayback.streamUrl
end sub

sub onClipPlaybackStopped()
    if not m.top.visible or m.getClipPlayback.state <> "stop" then return
    if m.getClipPlayback.cancelRequested or m.getClipPlayback.requestId <> m.playbackRequestId then return
    m.playbackLoading = false
    updateCategoryBusy()
    if m.getClipPlayback.errorMessage <> "" then m.playbackStatus.text = m.getClipPlayback.errorMessage
end sub

sub onGridFocus()
    if m.reloadPending = true then return
    if not m.top.visible then return
    if m.liveLine.visible and gridNeedsMore(m.browseList)
        getMoreChannels()
    else if m.clipLine.visible and gridNeedsMore(m.browseClipsList)
        getMoreClips()
    end if
end sub

sub getMoreChannels()
    if m.streamsCategory <> m.top.currentCategory or m.streamsLoading or m.getStreams.state = "run" then return
    if m.getStreams.pagination = "" then return
    m.streamsCursor = m.getStreams.pagination
    m.streamsLoading = true
    updateCategoryBusy()
    m.getStreams.control = "RUN"
end sub

sub getMoreClips()
    if m.clipsCategory <> m.top.currentCategory or m.clipsLoading or m.getClips.state = "run" then return
    if m.getClips.pagination = "" then return
    m.clipsCursor = m.getClips.pagination
    m.clipsLoading = true
    updateCategoryBusy()
    m.getClips.control = "RUN"
end sub

function onKeyEvent(key, press) as Boolean
    if not press or not m.top.visible then return false
    if m.browseButtons.hasFocus()
        if key = "left" or key = "right" or key = "OK"
            cancelPlaybackRequest()
            m.pendingGridFocus = ""
            m.liveLine.visible = not m.liveLine.visible
            m.clipLine.visible = not m.liveLine.visible
            if m.clipLine.visible
                m.clipButton.color = "0xF4F4F7FF"
                m.liveButton.color = "0xA9A9B2FF"
                onClipsLoad()
            else
                m.liveButton.color = "0xF4F4F7FF"
                m.clipButton.color = "0xA9A9B2FF"
                m.browseClipsList.visible = false
                m.browseList.visible = true
                m.emptyLabel.visible = not categoryHasRows(m.browseList)
                m.emptyLabel.text = "No live channels in this category"
            end if
            updateCategoryBusy()
            return true
        else if key = "down"
            focusContent()
            return true
        end if
    else if key = "down"
        onGridFocus()
        return true
    else if key = "up"
        m.pendingGridFocus = ""
        m.browseButtons.setFocus(true)
        return true
    else if key = "options" and m.browseList.hasFocus() and categoryHasRows(m.browseList)
        index = m.browseList.rowItemFocused
        item = m.browseList.content.getChild(index[0]).getChild(index[1])
        m.top.streamerSelectedName = item.ShortDescriptionLine1
        m.top.streamerSelectedThumbnail = item.HDPosterUrl
        return true
    end if
    return false
end function

function itemCategoryText(value) as String
    if type(value) = "roString" or type(value) = "String" then return value
    if type(value) = "roArray"
        if value.count() > 0 then return value[0]
    end if
    return ""
end function

sub cancelPlaybackRequest()
    m.playbackRequestId += 1
    m.getLivePlayback.cancelRequested = true
    m.getLivePlayback.requestId = m.playbackRequestId
    if m.getClipPlayback <> invalid
        m.getClipPlayback.cancelRequested = true
        m.getClipPlayback.requestId = m.playbackRequestId
    end if
    m.playbackStatus.text = ""
    m.playbackLoading = false
    updateCategoryBusy()
end sub

sub onPlaybackStopped()
    if not m.top.visible or m.getLivePlayback.state <> "stop" then return
    if m.getLivePlayback.cancelRequested or m.getLivePlayback.requestId <> m.playbackRequestId then return
    m.playbackLoading = false
    updateCategoryBusy()
    if m.getLivePlayback.errorMessage <> ""
        m.playbackStatus.text = m.getLivePlayback.errorMessage
    end if
end sub

sub updateCategoryBusy()
    if m.busy = invalid then return
    if m.categoryHeader <> invalid
        list = m.browseList
        if m.clipLine.visible then list = m.browseClipsList
        ' Before the first row arrives (or for an empty feed), show the same header.
        m.categoryHeader.visible = not categoryHasRows(list)
    end if
    loading = false
    if m.liveLine.visible and m.streamsLoading and not categoryHasRows(m.browseList) then loading = true
    if m.clipLine.visible and m.clipsLoading and not categoryHasRows(m.browseClipsList) then loading = true
    m.busy.enabled = m.top.visible
    m.busy.active = loading and not m.playbackLoading
    if loading then m.emptyLabel.visible = false
end sub

sub layoutTabs()
    if m.liveButton = invalid or m.clipButton = invalid then return
    width = m.liveButton.localBoundingRect().width
    m.liveLine.width = width
    nextX = width + 24
    m.clipButton.translation = [nextX, 61]
    m.clipLine.translation = [nextX, 75]
    m.clipLine.width = m.clipButton.localBoundingRect().width
end sub
