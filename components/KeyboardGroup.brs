sub init()
    m.playbackRequestId = 0
    m.playbackStatus = m.top.findNode("playbackStatus")
    m.keyboard = m.top.findNode("keyboard")
    m.browseButtons = m.top.findNode("browseButtons")
    m.searchResultList = m.top.findNode("resultList")
    m.resultCategoryList = m.top.findNode("resultCategoryList")
    m.liveButton = m.top.findNode("liveButton")
    m.liveLine = m.top.findNode("liveLine")
    m.categoryButton = m.top.findNode("categoryButton")
    m.categoryLine = m.top.findNode("categoryLine")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.searchResultList.observeField("itemSelected", "onSearchItemSelect")
    m.resultCategoryList.observeField("itemSelected", "onSearchItemSelect")
    m.getSearch = CreateObject("roSGNode", "GetSearch")
    m.getSearch.observeField("searchResults", "onSearchResultChange")
    m.getSearch.observeField("state", "onSearchStopped")
    m.getCategorySearch = CreateObject("roSGNode", "GetCategorySearch")
    m.getCategorySearch.observeField("searchResults", "onSearchResultChange")
    m.getCategorySearch.observeField("state", "onSearchStopped")
    m.getStuff = CreateObject("roSGNode", "GetStuff")
    m.getStuff.observeField("streamUrl", "onStreamUrlChange")
    m.getStuff.observeField("state", "onPlaybackStopped")
    m.top.observeField("visible", "onGetFocus")
    m.streamQuery = ""
    m.categoryQuery = ""
    m.wasLastScene = false
end sub

sub focusContent()
    if m.top.visible then m.keyboard.setFocus(true)
end sub

sub onGetFocus()
    if not m.top.visible then cancelPlaybackRequest()
    focusContent()
end sub

function searchHasRows(list) as Boolean
    if list.content = invalid then return false
    return list.content.getChildCount() > 0
end function

sub onSearchTextChange()
    if m.keyboard = invalid then return
    query = m.keyboard.text.Trim()
    m.emptyLabel.visible = true
    if query = ""
        m.searchResultList.content = invalid
        m.resultCategoryList.content = invalid
        m.emptyLabel.text = "Enter a channel or game name"
        return
    end if
    m.emptyLabel.text = "Searching…"
    if m.liveLine.visible
        if m.getSearch.state = "run" then return
        m.streamQuery = query
        m.getSearch.searchText = query
        m.getSearch.control = "RUN"
    else
        if m.getCategorySearch.state = "run" then return
        m.categoryQuery = query
        m.getCategorySearch.searchText = query
        m.getCategorySearch.control = "RUN"
    end if
end sub

sub onSearchStopped()
    query = m.keyboard.text.Trim()
    if query = "" then return
    if m.liveLine.visible and m.getSearch.state = "stop" and m.streamQuery <> query
        onSearchTextChange()
    else if m.categoryLine.visible and m.getCategorySearch.state = "stop" and m.categoryQuery <> query
        onSearchTextChange()
    end if
end sub

sub onSearchResultChange()
    query = m.keyboard.text.Trim()
    if query = "" then return
    content = CreateObject("roSGNode", "ContentNode")
    if m.liveLine.visible
        if m.streamQuery <> query then return
        results = m.getSearch.searchResults
        if results <> invalid
            for each channel in results
                child = content.createChild("ContentNode")
                child.url = channel.logo
                child.title = channel.name
                child.description = channel.login
                child.categories = channel.game
                child.ShortDescriptionLine1 = channel.title
                child.addFields({isLive: channel.is_live})
            end for
        end if
        m.searchResultList.content = content
    else
        if m.categoryQuery <> query then return
        results = m.getCategorySearch.searchResults
        if results <> invalid
            for each game in results
                child = content.createChild("ContentNode")
                child.url = game.logo
                child.categories = game.id.ToStr()
                child.title = game.name
            end for
        end if
        m.resultCategoryList.content = content
    end if
    m.emptyLabel.visible = content.getChildCount() = 0
    m.emptyLabel.text = "No results found"
end sub

sub onSearchItemSelect()
    if m.categoryLine.visible
        if not searchHasRows(m.resultCategoryList) then return
        item = m.resultCategoryList.content.getChild(m.resultCategoryList.itemSelected)
        m.top.categorySelectedName = item.title
        m.top.categorySelectedImage = item.url
        m.top.categorySelected = itemCategoryText(item.categories)
        return
    end if
    if not searchHasRows(m.searchResultList) then return
    item = m.searchResultList.content.getChild(m.searchResultList.itemSelected)
    if item.isLive
        if m.getStuff.state = "run" then return
        m.top.liveTitle = item.ShortDescriptionLine1
        m.top.liveName = item.title
        m.top.liveGame = itemCategoryText(item.categories)
        m.top.liveViewers = ""
        m.getStuff.streamerRequested = item.description
        m.playbackRequestId += 1
    m.getStuff.requestId = m.playbackRequestId
    m.getStuff.cancelRequested = false
    m.getStuff.errorMessage = ""
    m.playbackStatus.text = "Opening video…"
    m.getStuff.control = "RUN"
    else
        m.top.streamerSelectedName = item.description
    end if
    m.wasLastScene = true
end sub

sub onStreamUrlChange()
    if m.getStuff.cancelRequested or m.getStuff.requestId <> m.playbackRequestId then return
    m.playbackStatus.text = ""
    if not m.top.visible or m.getStuff.streamUrl = "" then return
    m.top.streamerRequested = m.getStuff.streamerRequested
    m.top.playbackInfo = m.getStuff.playbackInfo
    m.top.streamUrl = m.getStuff.streamUrl
end sub

function onKeyEvent(key, press) as Boolean
    if not m.top.visible or not press then return false
    if m.browseButtons.hasFocus()
        if key = "left" or key = "right" or key = "OK"
            m.liveLine.visible = not m.liveLine.visible
            m.categoryLine.visible = not m.liveLine.visible
            m.searchResultList.visible = m.liveLine.visible
            m.resultCategoryList.visible = m.categoryLine.visible
            if m.liveLine.visible
                m.liveButton.color = "0xF4F4F7FF"
                m.categoryButton.color = "0xA9A9B2FF"
            else
                m.liveButton.color = "0xA9A9B2FF"
                m.categoryButton.color = "0xF4F4F7FF"
            end if
            onSearchTextChange()
            return true
        else if key = "down"
            m.keyboard.setFocus(true)
            return true
        end if
    else if key = "right" and m.keyboard.isInFocusChain()
        if m.liveLine.visible and searchHasRows(m.searchResultList)
            m.searchResultList.setFocus(true)
        else if m.categoryLine.visible and searchHasRows(m.resultCategoryList)
            m.resultCategoryList.setFocus(true)
        end if
        return true
    else if key = "left" and (m.searchResultList.hasFocus() or m.resultCategoryList.hasFocus())
        m.keyboard.setFocus(true)
        return true
    else if key = "up"
        m.browseButtons.setFocus(true)
        return true
    else if key = "options" and m.searchResultList.hasFocus() and searchHasRows(m.searchResultList)
        m.top.streamerSelectedName = m.searchResultList.content.getChild(m.searchResultList.itemFocused).description
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
    m.playbackStatus.text = ""
end sub

sub onPlaybackStopped()
    if not m.top.visible or m.getStuff.state <> "stop" then return
    if m.getStuff.cancelRequested or m.getStuff.requestId <> m.playbackRequestId then return
    if m.getStuff.errorMessage <> ""
        m.playbackStatus.text = m.getStuff.errorMessage
    end if
end sub
