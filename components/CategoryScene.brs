sub init()
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
    m.getStreams = CreateObject("roSGNode", "GetStreams")
    m.getStreams.observeField("searchResults", "onSearchResultChange")
    m.getStreams.observeField("state", "onStreamsStopped")
    m.getClips = CreateObject("roSGNode", "GetClips")
    m.getClips.observeField("searchResults", "insertClips")
    m.getClips.observeField("state", "onClipsStopped")
    m.getStuff = CreateObject("roSGNode", "GetStuff")
    m.getStuff.observeField("streamUrl", "onStreamUrlChange")
    m.getStuff.observeField("state", "onPlaybackStopped")
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
    m.streamRows = []
    m.clipRows = []
    m.seenStreams = {}
    m.seenClips = {}
    m.offset = 0
    m.append = false
    m.newCategory = false
    m.wasLastScene = false
end sub

sub updateCategoryHeader()
    name = m.top.findNode("categoryName")
    cover = m.top.findNode("categoryCover")
    if name = invalid or cover = invalid then return
    name.text = m.top.currentCategoryName
    if name.text = "" then name.text = "Live channels"
    cover.uri = m.top.currentCategoryImage
end sub

function categoryHasRows(list) as Boolean
    if list.content = invalid then return false
    return list.content.getChildCount() > 0
end function

sub focusContent()
    if not m.top.visible then return
    if m.clipLine.visible and categoryHasRows(m.browseClipsList)
        m.browseClipsList.setFocus(true)
    else if m.liveLine.visible and categoryHasRows(m.browseList)
        m.browseList.setFocus(true)
    else
        m.browseButtons.setFocus(true)
    end if
end sub

sub onGetFocus()
    if not m.top.visible then cancelPlaybackRequest()
    if m.top.visible
        m.browseList.visible = m.liveLine.visible
        m.browseClipsList.visible = m.clipLine.visible
        focusContent()
    end if
end sub

sub onCategoryChange()
    cancelPlaybackRequest()
    m.streamRows = []
    m.clipRows = []
    m.seenStreams = {}
    m.seenClips = {}
    m.browseList.content = invalid
    m.browseClipsList.content = invalid
    m.offset = 0
    m.append = false
    m.newCategory = true
    m.liveLine.visible = true
    m.clipLine.visible = false
    m.liveButton.color = "0xF4F4F7FF"
    m.clipButton.color = "0xA9A9B2FF"
    m.browseList.visible = true
    m.browseClipsList.visible = false
    m.emptyLabel.text = "Loading streams…"
    m.emptyLabel.visible = true
    updateCategoryHeader()
    startCategoryStreams()
end sub

sub startCategoryStreams()
    if m.getStreams.state = "run" then return
    m.streamsCategory = m.top.currentCategory
    m.getStreams.gameRequested = m.streamsCategory
    m.getStreams.pagination = ""
    m.getStreams.offset = "0"
    m.getStreams.control = "RUN"
end sub

sub onStreamsStopped()
    if m.getStreams.state = "stop" and m.streamsCategory <> m.top.currentCategory
        startCategoryStreams()
    end if
end sub

sub onClipsStopped()
    if m.getClips.state = "stop" and m.clipLine.visible and m.clipsCategory <> m.top.currentCategory
        onClipsLoad()
    end if
end sub

sub onClipsLoad()
    m.browseList.visible = false
    m.browseClipsList.visible = true
    if categoryHasRows(m.browseClipsList) then return
    m.emptyLabel.visible = true
    m.emptyLabel.text = "Loading clips…"
    if m.getClips.state = "run" then return
    m.clipsCategory = m.top.currentCategory
    m.getClips.gameRequested = m.clipsCategory
    m.getClips.pagination = ""
    m.getClips.control = "RUN"
end sub

function numberToText(number) as String
    if number = invalid then return ""
    if number >= 1000000 then return (Int(number / 100000) / 10).ToStr() + "M"
    if number >= 1000 then return (Int(number / 100) / 10).ToStr() + "K"
    return number.ToStr().Trim()
end function

function categoryGrid(items) as Object
    content = CreateObject("roSGNode", "ContentNode")
    row = invalid
    for index = 0 to items.count() - 1
        if index MOD 4 = 0
            row = CreateObject("roSGNode", "ContentNode")
            content.appendChild(row)
        end if
        row.appendChild(items[index])
    end for
    return content
end function

sub onSearchResultChange()
    if m.streamsCategory <> m.top.currentCategory then return
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
                m.streamRows.push(item)
            end if
        end for
    end if
    focused = m.browseList.rowItemFocused
    m.browseList.content = categoryGrid(m.streamRows)
    if not m.newCategory then m.browseList.jumpToRowItem = focused
    m.newCategory = false
    m.append = false
    if m.liveLine.visible
        m.emptyLabel.visible = not categoryHasRows(m.browseList)
        m.emptyLabel.text = "No live channels in this category"
        if m.getStreams.errorMessage <> "" then m.emptyLabel.text = m.getStreams.errorMessage
    end if
end sub

sub insertClips()
    if m.clipsCategory <> m.top.currentCategory then return
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
                m.clipRows.push(item)
            end if
        end for
    end if
    focused = m.browseClipsList.rowItemFocused
    m.browseClipsList.content = categoryGrid(m.clipRows)
    m.browseClipsList.jumpToRowItem = focused
    m.append = false
    if m.clipLine.visible
        m.emptyLabel.visible = not categoryHasRows(m.browseClipsList)
        m.emptyLabel.text = "No clips in this category"
        if m.getClips.errorMessage <> "" then m.emptyLabel.text = m.getClips.errorMessage
    end if
end sub

sub onStreamUrlChange()
    if m.getStuff.cancelRequested or m.getStuff.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    if not m.top.visible or m.getStuff.streamUrl = "" then return
    m.top.streamerRequested = m.getStuff.streamerRequested
    m.top.playbackInfo = m.getStuff.playbackInfo
    m.top.streamUrl = m.getStuff.streamUrl
end sub

sub onBrowseItemSelect()
    if not m.browseList.visible or not categoryHasRows(m.browseList) then return
    if m.getStuff.state = "run" then return
    index = m.browseList.rowItemSelected
    item = m.browseList.content.getChild(index[0]).getChild(index[1])
    m.top.liveTitle = item.Title
    m.top.liveName = item.Description
    m.top.liveGame = itemCategoryText(item.Categories)
    m.top.liveViewers = item.ShortDescriptionLine2
    m.getStuff.streamerRequested = item.ShortDescriptionLine1
    m.playbackRequestId += 1
    m.getStuff.requestId = m.playbackRequestId
    m.getStuff.cancelRequested = false
    m.getStuff.errorMessage = ""
    m.playbackStatus.text = "Opening video…"
    m.getStuff.control = "RUN"
    m.wasLastScene = true
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
    m.playbackStatus.text = "Opening clip…"
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
    m.top.fromClip = true
    m.top.clipUrl = m.getClipPlayback.streamUrl
end sub

sub onClipPlaybackStopped()
    if not m.top.visible or m.getClipPlayback.state <> "stop" then return
    if m.getClipPlayback.cancelRequested or m.getClipPlayback.requestId <> m.playbackRequestId then return
    if m.getClipPlayback.errorMessage <> "" then m.playbackStatus.text = m.getClipPlayback.errorMessage
end sub

sub onGridFocus()
    if m.browseList.hasFocus() and categoryHasRows(m.browseList)
        if m.browseList.rowItemFocused[0] >= m.browseList.content.getChildCount() - 2 then getMoreChannels()
    else if m.browseClipsList.hasFocus() and categoryHasRows(m.browseClipsList)
        if m.browseClipsList.rowItemFocused[0] >= m.browseClipsList.content.getChildCount() - 2 then getMoreClips()
    end if
end sub

sub getMoreChannels()
    if m.getStreams.state = "run" or m.append then return
    if m.getStreams.pagination = "" then return
    m.offset += 24
    m.append = true
    m.getStreams.offset = m.offset.ToStr()
    m.getStreams.control = "RUN"
end sub

sub getMoreClips()
    if m.getClips.state = "run" or m.append then return
    if m.getClips.pagination = "" then return
    m.append = true
    m.getClips.control = "RUN"
end sub

sub onSceneLoad()
    onCategoryChange()
end sub

function onKeyEvent(key, press) as Boolean
    if not press or not m.top.visible then return false
    if m.browseButtons.hasFocus()
        if key = "left" or key = "right" or key = "OK"
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
            return true
        else if key = "down"
            focusContent()
            return true
        end if
    else if key = "up"
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
    m.getStuff.cancelRequested = true
    m.getStuff.requestId = m.playbackRequestId
    if m.getClipPlayback <> invalid
        m.getClipPlayback.cancelRequested = true
        m.getClipPlayback.requestId = m.playbackRequestId
    end if
    m.playbackStatus.text = ""
end sub

sub onPlaybackStopped()
    if not m.top.visible or m.getStuff.state <> "stop" then return
    if m.getStuff.cancelRequested or m.getStuff.requestId <> m.playbackRequestId then return
    if m.getStuff.errorMessage <> ""
        m.playbackStatus.text = m.getStuff.errorMessage
    end if
end sub
