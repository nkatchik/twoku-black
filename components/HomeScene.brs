sub init()
    m.reloadPending = false
    m.loadStatus = m.top.findNode("loadStatus")
    m.busy = m.top.findNode("busy")
    m.browseList = m.top.findNode("browseList")
    m.browseCategoryList = m.top.findNode("browseCategoryList")
    m.followingView = m.top.findNode("followingView")
    m.followingView.observeField("selectedItem", "onFollowingItemSelected")
    m.followingView.observeField("channelRequested", "onFollowingChannelRequested")
    m.followingView.observeField("hasItems", "updateFollowingLayout")
    m.categoryButton = m.top.findNode("categoryButton")
    m.categoryLine = m.top.findNode("categoryLine")
    m.liveButton = m.top.findNode("liveButton")
    m.liveLine = m.top.findNode("liveLine")
    m.followingButton = m.top.findNode("followingButton")
    m.followingLine = m.top.findNode("followingLine")
    m.searchLabel = m.top.findNode("searchLabel")
    m.headerCursor = m.top.findNode("headerCursor")
    m.channelPage = m.top.findNode("channelPage")
    m.loggedIn = false
    m.browseButtons = m.top.findNode("browseButtons")
    m.browseMain = m.top.findNode("browseMain")
    m.loggedUserGroup = m.top.findNode("loggedUserGroup")
    m.profileImage = m.top.findNode("profileImage")
    m.profileCover = m.top.findNode("profileCover")
    m.accountBackground = m.top.findNode("accountBackground")
    m.loggedUserName = m.top.findNode("loggedUserName")
    m.actualBrowseButtons = [m.categoryButton,m.liveButton,m.followingButton,m.searchLabel,m.loggedUserName]
    m.browseButtons.observeField("focusedChild", "updateHeaderFocus")
    m.browseList.observeField("rowItemFocused", "onGridFocus")
    m.browseCategoryList.observeField("rowItemFocused", "onGridFocus")
    m.browseList.observeField("itemSelected", "onBrowseItemSelect")
    m.browseCategoryList.observeField("itemSelected", "onBrowseItemSelect")
    m.channelPage.observeField("streamUrl", "onLiveStreamSelectedFromChannel")
    m.getStreams = CreateObject("roSGNode", "GetStreams")
    m.getStreams.observeField("searchResults", "onSearchResultChange")
    m.getStreams.observeField("state", "onChannelsStopped")
    m.getCategories = CreateObject("roSGNode", "GetCategories")
    m.getCategories.observeField("searchResults", "onCategoryResultChange")
    m.getCategories.observeField("state", "onCategoriesStopped")
    m.getLivePlayback = CreateObject("roSGNode", "GetLivePlayback")
    m.getLivePlayback.observeField("streamUrl", "onStreamUrlChange")
    m.getLivePlayback.observeField("state", "onPlaybackRequestStopped")
    m.getOfflineFollowed = CreateObject("roSGNode", "GetOfflineFollowedChannels")
    m.getOfflineFollowed.observeField("offlineFollowedUsers", "onGetOfflineFollowed")
    m.getOfflineFollowed.observeField("state", "onOfflineStopped")
    m.top.observeField("visible", "onGetFocus")
    m.top.observeField("currentlyLiveStreamerIds", "onGetFollowedStreams")
    m.top.observeField("streamerSelectedName", "onStreamerSelected")
    m.append = false
    m.appendCategory = false
    m.channelsPending = false
    m.categoriesPending = false
    m.appLaunchComplete = false
    m.pendingGridFocus = 1
    m.currentlySelectedButton = 1
    m.currentlyFocusedButton = 1
    m.playbackPending = false
    m.playbackRequestId = 0
    m.offlinePending = false
    m.offlineError = ""
    m.offlineLoaded = false
    m.browseCategoryList.visible = false
    layoutHeader()
    onNewUser()
    showBusy()
end sub

sub focusContent()
    ' Called explicitly by MainScene; do not depend on nested focus observers.
    onGetFocus()
    if m.top.visible and not m.top.isInFocusChain()
        print "Home focus failed: no control in the focus chain"
    end if
end sub

sub reloadContent()
    if not m.top.visible then return
    if m.channelPage.visible
        m.channelPage.callFunc("reloadContent")
        return
    end if
    m.reloadPending = true
    cancelPlaybackRequest()
    showBusy()
    tryReloadContent()
end sub

sub tryReloadContent()
    if m.reloadPending <> true then return
    if not m.top.visible or m.channelPage.visible
        m.reloadPending = false
        return
    end if
    if m.getStreams.state = "run" or m.getCategories.state = "run" or m.getOfflineFollowed.state = "run" then return
    m.reloadPending = false
    m.channelsPending = false
    m.categoriesPending = false
    if m.currentlySelectedButton = 0
        m.browseCategoryList.content = invalid
        onCategorySelect()
    else if m.currentlySelectedButton = 1
        m.browseList.content = invalid
        onHomeLoad()
    else
        m.followingView.liveStreams = []
        m.followingView.offlineChannels = []
        m.pendingFollowingFocus = true
        m.offlineLoaded = false
        m.offlinePending = false
        m.offlineError = ""
        m.top.followingError = ""
        m.top.reloadFollowingRequested = true
        updateFollowingLayout()
    end if
    focusActiveGrid(true)
end sub

function hasRows(list as Object) as Boolean
    if list.content = invalid then return false
    return list.content.getChildCount() > 0
end function

sub showLoadStatus(message as String)
    m.busy.active = false
    m.loadStatus.text = message
    m.loadStatus.visible = message <> ""
end sub

sub onStartupError()
    message = m.top.startupError
    if message = ""
        if m.top.apiReady
            showActiveSurface()
        else
            showBusy()
        end if
    else
        showLoadStatus(message + " Select Channels or Games to retry.")
        finishLaunch()
    end if
end sub

sub onApiReady()
    if not m.top.apiReady then return
    if m.currentlySelectedButton = 0
        onCategorySelect()
    else if m.currentlySelectedButton = 1
        onHomeLoad()
    else
        showLoadStatus("")
        finishLaunch()
    end if
end sub

sub finishLaunch()
    if not m.appLaunchComplete
        m.top.signalBeacon("AppLaunchComplete")
        m.appLaunchComplete = true
    end if
end sub

sub onStreamerSelected()
    m.channelPage.streamerSelectedName = m.top.streamerSelectedName
    m.channelPage.streamerSelectedThumbnail = m.top.streamerSelectedThumbnail
    m.channelPage.streamItemFocused = false
    ' Hide only the parent: child visibility, content and native focus positions survive Back.
    m.browseMain.visible = false
    m.busy.enabled = false
    m.channelPage.visible = true
end sub

sub onLiveStreamSelectedFromChannel()
    m.top.playbackInfo = m.channelPage.playbackInfo
    m.top.liveTitle = m.channelPage.videoTitle
    m.top.liveName = m.channelPage.channelUsername
    m.top.liveGame = ""
    m.top.liveViewers = m.channelPage.streamViewers
    m.top.streamerRequested = m.top.streamerSelectedName
    m.top.streamUrl = m.channelPage.streamUrl
end sub

sub onNewUser()
    if m.loggedUserName = invalid then return
    m.loggedIn = m.top.loggedInUserName <> ""
    m.loggedUserName.text = m.top.loggedInUserName
    if m.loggedUserName.text = "" then m.loggedUserName.text = "Log In"
    m.profileImage.uri = m.top.loggedInUserProfileImage
    layoutAccount()
    updateHeaderFocus()
end sub

sub onGetFocus()
    m.channelPage.parentVisible = m.top.visible
    if not m.top.visible
        m.reloadPending = false
        m.pendingGridFocus = invalid
        cancelPlaybackRequest()
        m.busy.enabled = false
        return
    end if
    layoutHeader()
    if m.channelPage.visible
        m.browseMain.visible = false
        m.busy.enabled = false
        m.channelPage.callFunc("focusContent")
    else
        m.browseMain.visible = true
        m.busy.enabled = true
        showActiveSurface()
        focusActiveGrid()
    end if
end sub

sub onStreamUrlChange()
    if not m.playbackPending or not m.top.visible then return
    if m.getLivePlayback.requestId <> m.playbackRequestId or m.getLivePlayback.streamUrl = "" then return
    m.playbackPending = false
    showLoadStatus("")
    m.top.streamerRequested = m.getLivePlayback.streamerRequested
    m.top.playbackInfo = m.getLivePlayback.playbackInfo
    m.top.streamUrl = m.getLivePlayback.streamUrl
end sub

sub onBrowseItemSelect()
    list = activeGrid()
    if not hasRows(list) then return
    selected = list.rowItemSelected
    row = list.content.getChild(selected[0])
    if row = invalid then return
    item = row.getChild(selected[1])
    if item = invalid then return
    if m.currentlySelectedButton = 0
        m.top.categorySelectedName = item.Title
        m.top.categorySelectedImage = item.HDPosterUrl
        m.top.categorySelected = item.ShortDescriptionLine1
    else
        playLiveItem(item)
    end if
end sub

sub onHomeLoad()
    m.followingView.visible = false
    m.browseCategoryList.visible = false
    m.browseList.visible = true
    if m.top.isInFocusChain() and not hasRows(m.browseList) then m.browseButtons.setFocus(true)
    if not m.top.apiReady
        m.browseButtons.setFocus(true)
        m.top.retryAuthentication = true
        return
    end if
    if m.getStreams.state = "run"
        showActiveSurface()
        return
    end if
    m.channelsPending = true
    showBusy()
    m.append = false
    m.getStreams.gameRequested = ""
    m.channelsCursor = ""
    m.getStreams.pagination = ""
    m.getStreams.control = "RUN"
end sub

sub onSearchResultChange()
    if m.reloadPending = true then return
    m.channelsPending = false
    if m.getStreams.errorMessage <> ""
        if m.browseList.visible
            showLoadStatus(m.getStreams.errorMessage + " Select Channels to retry.")
            if not m.append and m.top.isInFocusChain() then m.browseButtons.setFocus(true)
        end if
        m.append = false
        finishLaunch()
        return
    end if
    items = []
    if not m.append or m.channelIds = invalid then m.channelIds = {}
    if m.getStreams.searchResults <> invalid
        for each stream in m.getStreams.searchResults
            if not m.channelIds.DoesExist(stream.name)
                m.channelIds[stream.name] = true
                rowItem = createObject("RoSGNode", "ContentNode")
                rowItem.Title = stream.title
                rowItem.Description = stream.display_name
                rowItem.Categories = stream.game
                rowItem.HDPosterUrl = stream.thumbnail
                rowItem.ShortDescriptionLine1 = stream.name
                rowItem.ShortDescriptionLine2 = numberToText(stream.viewers)
                items.Push(rowItem)
            end if
        end for
    end if
    appendGridItems(m.browseList, items, not m.append)
    finishGridPage(m.getStreams, m.channelsCursor, items.Count())
    if m.browseList.visible = true
        if hasRows(m.browseList)
            showLoadStatus("")
        else
            showLoadStatus("No live channels found. Select Channels to retry.")
        end if
    end if
    completeGridFocus(1)
    m.append = false
    finishLaunch()
    onGridFocus()
end sub

sub numberToText(number) as Object
    s = StrI(number)
    result = ""
    if number >=100000 and number < 1000000
        result = Left(s, 4) + "K"
    else if number >=10000 and number < 100000
        result = Left(s, 3) + "." + Mid(s, 4, 1) + "K"
    else if number >=1000 and number < 10000
        result = Left(s, 2) + "." + Mid(s, 3, 1) + "K"
    else if number < 1000
        result = s
    end if
    return result + " viewers"
end sub

sub onCategoryResultChange()
    if m.reloadPending = true then return
    m.categoriesPending = false
    if m.getCategories.errorMessage <> ""
        if m.browseCategoryList.visible
            showLoadStatus(m.getCategories.errorMessage + " Select Games to retry.")
            if not m.appendCategory and m.top.isInFocusChain() then m.browseButtons.setFocus(true)
        end if
        m.appendCategory = false
        finishLaunch()
        return
    end if
    items = []
    if not m.appendCategory or m.categoryIds = invalid then m.categoryIds = {}
    if m.getCategories.searchResults <> invalid
        for each stream in m.getCategories.searchResults
            if not m.categoryIds.DoesExist(stream.id)
                m.categoryIds[stream.id] = true
                rowItem = createObject("RoSGNode", "ContentNode")
                rowItem.Title = stream.name
                rowItem.Description = numberToText(stream.viewers)
                rowItem.ShortDescriptionLine1 = stream.id
                rowItem.HDPosterUrl = stream.logo
                items.Push(rowItem)
            end if
        end for
    end if
    appendGridItems(m.browseCategoryList, items, not m.appendCategory)
    finishGridPage(m.getCategories, m.categoriesCursor, items.Count())
    if m.browseCategoryList.visible
        if hasRows(m.browseCategoryList)
            showLoadStatus("")
        else
            showLoadStatus("No categories found. Select Games to retry.")
        end if
    end if
    completeGridFocus(0)
    m.appendCategory = false
    finishLaunch()
    onGridFocus()
end sub

sub onCategorySelect()
    m.followingView.visible = false
    m.browseList.visible = false
    m.browseCategoryList.visible = true
    if m.top.isInFocusChain() and not hasRows(m.browseCategoryList) then m.browseButtons.setFocus(true)
    if not m.top.apiReady
        m.browseButtons.setFocus(true)
        m.top.retryAuthentication = true
        return
    end if
    if m.getCategories.state = "run"
        showActiveSurface()
        return
    end if
    m.categoriesPending = true
    showBusy()
    m.appendCategory = false
    m.categoriesCursor = ""
    m.getCategories.pagination = ""
    m.getCategories.control = "RUN"
end sub

sub onFollowingSelect()
    m.browseList.visible = false
    m.browseCategoryList.visible = false
    m.followingView.visible = true
    if m.offlineError <> "" and not m.offlinePending then requestOfflineFollowing()
    updateFollowingLayout()
end sub

sub onGridFocus()
    if m.reloadPending = true then return
    if not m.top.visible or not m.browseMain.visible or m.channelPage.visible then return
    if m.currentlySelectedButton = 1 and gridNeedsMore(m.browseList)
        getMoreChannels()
    else if m.currentlySelectedButton = 0 and gridNeedsMore(m.browseCategoryList)
        getMoreCategories()
    end if
end sub

sub onChannelsStopped()
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getStreams.state <> "stop" or m.getStreams.errorMessage <> "" then return
    if m.currentlySelectedButton = 1 then onGridFocus()
end sub

sub onCategoriesStopped()
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getCategories.state <> "stop" or m.getCategories.errorMessage <> "" then return
    if m.currentlySelectedButton = 0 then onGridFocus()
end sub

sub getMoreChannels()
    if not m.top.apiReady or m.channelsPending or m.getStreams.state = "run" then return
    if m.getStreams.pagination = "" then return
    m.channelsCursor = m.getStreams.pagination
    m.append = true
    m.channelsPending = true
    m.getStreams.gameRequested = ""
    m.getStreams.control = "RUN"
end sub

sub getMoreCategories()
    if not m.top.apiReady or m.categoriesPending or m.getCategories.state = "run" then return
    if m.getCategories.pagination = "" then return
    m.categoriesCursor = m.getCategories.pagination
    m.appendCategory = true
    m.categoriesPending = true
    m.getCategories.control = "RUN"
end sub

sub requestOfflineFollowing()
    if m.top.loggedInUserId = "" then return
    if m.top.followingError <> "" or m.top.loggedInSessionVersion <> m.global.sessionVersion then return
    if m.getOfflineFollowed.state = "run" then return
    m.offlinePending = true
    m.offlineError = ""
    m.getOfflineFollowed.userId = m.top.loggedInUserId
    m.getOfflineFollowed.sessionVersion = m.global.sessionVersion
    m.getOfflineFollowed.currentlyLiveStreamerIds = m.top.currentlyLiveStreamerIds
    m.getOfflineFollowed.control = "RUN"
    updateFollowingLayout()
end sub

sub onOfflineStopped()
    if m.reloadPending = true
        tryReloadContent()
        return
    end if
    if m.getOfflineFollowed.state <> "stop" then return
    if m.getOfflineFollowed.sessionVersion <> m.global.sessionVersion
        m.offlinePending = false
        requestOfflineFollowing()
        return
    end if
    if m.offlinePending
        m.offlinePending = false
        m.offlineError = m.getOfflineFollowed.errorMessage
        if m.offlineError = "" then m.offlineError = "Couldn't load followed channels. Select Following to retry."
    end if
    updateFollowingLayout()
end sub

sub onGetFollowedStreams()
    if m.reloadPending = true then return
    if m.top.loggedInSessionVersion <> m.global.sessionVersion then return
    m.followingView.liveStreams = m.top.followedStreams
    requestOfflineFollowing()
    updateFollowingLayout()
end sub

sub onGetOfflineFollowed()
    if m.reloadPending = true then return
    if m.getOfflineFollowed.sessionVersion <> m.global.sessionVersion then return
    m.offlinePending = false
    m.offlineError = m.getOfflineFollowed.errorMessage
    if m.getOfflineFollowed.offlineFollowedUsers <> invalid
        m.followingView.offlineChannels = m.getOfflineFollowed.offlineFollowedUsers
        m.offlineLoaded = true
    else if m.offlineError = ""
        m.offlineError = "Couldn't load followed channels. Select Following to retry."
    end if
    updateFollowingLayout()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not m.top.visible or not press then return false
    if m.channelPage.visible
        if key <> "back" then return false
        m.channelPage.callFunc("cancelPlaybackRequest")
        m.channelPage.visible = false
        m.browseMain.visible = true
        m.busy.enabled = true
        showActiveSurface()
        focusActiveGrid()
        return true
    end if
    if m.playbackPending and key = "back"
        cancelPlaybackRequest()
        return true
    end if
    if m.browseButtons.hasFocus()
        if key = "left" or key = "right"
            m.pendingGridFocus = invalid
            order = [1,0,2,3,4]
            index = 0
            for i = 0 to order.Count() - 1
                if order[i] = m.currentlyFocusedButton then index = i
            end for
            if key = "right" and index < 4 then index += 1
            if key = "left" and index > 0 then index -= 1
            m.currentlyFocusedButton = order[index]
            updateHeaderFocus()
            return true
        else if key = "down"
            focusActiveGrid()
            return true
        else if key = "OK"
            m.pendingGridFocus = invalid
            if m.currentlyFocusedButton = 3
                m.top.buttonPressed = "search"
            else if m.currentlyFocusedButton = 4
                m.top.buttonPressed = "login"
            else
                m.currentlySelectedButton = m.currentlyFocusedButton
                if m.currentlySelectedButton = 0
                    onCategorySelect()
                else if m.currentlySelectedButton = 1
                    onHomeLoad()
                else
                    onFollowingSelect()
                end if
                focusActiveGrid(true)
            end if
            updateHeaderFocus()
            return true
        end if
    else if key = "up" or key = "back"
        m.pendingGridFocus = invalid
        m.currentlyFocusedButton = m.currentlySelectedButton
        m.browseButtons.setFocus(true)
        updateHeaderFocus()
        return true
    else if key = "down"
        onGridFocus()
        return true
    else if key = "options"
        if m.currentlySelectedButton = 2 then return true
        list = activeGrid()
        if m.currentlySelectedButton <> 0 and hasRows(list)
            focused = list.rowItemFocused
            row = list.content.getChild(focused[0])
            if row <> invalid
                item = row.getChild(focused[1])
                if item <> invalid
                    m.top.streamerSelectedThumbnail = item.HDPosterUrl
                    m.top.streamerSelectedName = item.ShortDescriptionLine1
                end if
            end if
        end if
        return true
    else if key = "left" or key = "right"
        ' RowList handles moves inside a row. At the edge, retain grid focus.
        return true
    end if
    return false
end function

sub onFollowingError()
    updateFollowingLayout()
end sub


function activeGrid() as Object
    if m.currentlySelectedButton = 0 then return m.browseCategoryList
    return m.browseList
end function

sub focusActiveGrid(first = false as Boolean)
    m.pendingGridFocus = invalid
    if m.currentlySelectedButton = 2
        if m.followingView.hasItems
            m.followingView.callFunc("focusContent")
        else
            m.browseButtons.setFocus(true)
        end if
    else if hasRows(activeGrid())
        if first then activeGrid().jumpToRowItem = [0, 0]
        activeGrid().setFocus(true)
    else
        m.pendingGridFocus = m.currentlySelectedButton
        m.browseButtons.setFocus(true)
    end if
    updateHeaderFocus()
end sub

sub completeGridFocus(feed as Integer)
    if m.pendingGridFocus = invalid or m.pendingGridFocus <> feed then return
    m.pendingGridFocus = invalid
    if not m.top.visible or m.channelPage.visible or not m.browseMain.visible then return
    if m.currentlySelectedButton <> feed or not m.browseButtons.hasFocus() then return
    focusActiveGrid(true)
end sub

sub updateHeaderFocus()
    if m.actualBrowseButtons = invalid then return
    m.categoryLine.visible = m.currentlySelectedButton = 0
    m.liveLine.visible = m.currentlySelectedButton = 1
    m.followingLine.visible = m.currentlySelectedButton = 2
    for index = 0 to 3
        m.actualBrowseButtons[index].color = "0xA9A9B2FF"
        if index = m.currentlySelectedButton then m.actualBrowseButtons[index].color = "0xF4F4F7FF"
    end for
    focused = m.browseButtons.hasFocus()
    accountFocused = focused and m.currentlyFocusedButton = 4
    m.headerCursor.visible = focused and not accountFocused
    if m.headerCursor.visible
        label = m.actualBrowseButtons[m.currentlyFocusedButton]
        label.color = "0xFFFFFFFF"
        m.headerCursor.translation = [label.translation[0],75]
        m.headerCursor.width = label.localBoundingRect().width
    end if
    applyButtonFocus(m.loggedUserGroup, m.accountBackground, m.loggedUserName, accountFocused)
    m.profileCover.blendColor = m.accountBackground.color
end sub

sub playLiveItem(item as Object)
    if m.getLivePlayback.state = "run" then return
    m.playbackRequestId += 1
    m.playbackPending = true
    m.getLivePlayback.cancelRequested = false
    m.getLivePlayback.requestId = m.playbackRequestId
    m.getLivePlayback.streamerRequested = item.ShortDescriptionLine1
    m.top.liveTitle = item.Title
    m.top.liveName = item.Description
    m.top.liveGame = ""
    if type(item.Categories) = "roArray"
        if item.Categories.Count() > 0 then m.top.liveGame = item.Categories[0]
    end if
    m.top.liveViewers = item.ShortDescriptionLine2
    showBusy()
    m.getLivePlayback.control = "RUN"
end sub

sub cancelPlaybackRequest()
    m.channelPage.callFunc("cancelPlaybackRequest")
    m.playbackPending = false
    m.playbackRequestId += 1
    m.getLivePlayback.cancelRequested = true
    showLoadStatus("")
end sub

sub onPlaybackRequestStopped()
    if m.getLivePlayback.state <> "stop" or not m.playbackPending then return
    if m.getLivePlayback.requestId <> m.playbackRequestId then return
    m.playbackPending = false
    if m.getLivePlayback.errorMessage <> "" then showLoadStatus(m.getLivePlayback.errorMessage + " Press OK to retry.")
end sub

sub updateFollowingLayout()
    if m.currentlySelectedButton <> 2 then return
    if m.followingView.hasItems
        showLoadStatus("")
        if m.pendingFollowingFocus = true and m.top.visible and not m.channelPage.visible
            m.pendingFollowingFocus = false
            m.followingView.callFunc("focusContent")
        end if
    else if not m.loggedIn
        showLoadStatus("Sign in to see followed channels. Select Log In in the header.")
    else if m.top.followingError <> ""
        showLoadStatus(m.top.followingError)
    else if m.offlinePending
        showBusy()
    else if m.offlineError <> ""
        showLoadStatus(m.offlineError)
    else if m.offlineLoaded
        showLoadStatus("No followed channels to show.")
    else
        showBusy()
    end if
    if not m.followingView.hasItems and m.followingView.isInFocusChain() then m.browseButtons.setFocus(true)
end sub

sub showBusy()
    m.loadStatus.visible = false
    m.loadStatus.text = ""
    m.busy.enabled = m.top.visible and m.browseMain.visible
    m.busy.active = true
end sub

sub showActiveSurface()
    m.browseList.visible = m.currentlySelectedButton = 1
    m.browseCategoryList.visible = m.currentlySelectedButton = 0
    m.followingView.visible = m.currentlySelectedButton = 2
    if m.currentlySelectedButton = 2
        updateFollowingLayout()
    else if m.playbackPending
        showBusy()
    else if m.currentlySelectedButton = 1 and m.channelsPending and not m.append
        showBusy()
    else if m.currentlySelectedButton = 0 and m.categoriesPending and not m.appendCategory
        showBusy()
    else
        m.busy.active = false
    end if
end sub

sub layoutHeader()
    x = 95
    labels = [m.liveButton,m.categoryButton,m.followingButton,m.searchLabel]
    lines = [m.liveLine,m.categoryLine,m.followingLine]
    for index = 0 to 3
        label = labels[index]
        label.translation = [x,61]
        width = label.localBoundingRect().width
        if index < 3
            lines[index].translation = [x,75]
            lines[index].width = width
        end if
        x += width + 24
    end for
    layoutAccount()
end sub

sub layoutAccount()
    ' Measure the rendered Label after clearing its old width constraint.
    m.loggedUserName.width = 0
    width = m.loggedUserName.localBoundingRect().width
    if width > 180 then width = 180
    m.loggedUserName.width = width
    avatar = m.profileImage.uri <> ""
    m.profileImage.visible = avatar
    m.profileCover.visible = avatar
    textX = 4
    if avatar then textX = 36
    m.loggedUserName.translation = [textX,0]
    rightPadding = 4
    chipWidth = textX + width + rightPadding
    m.accountBackground.width = chipWidth
    m.loggedUserGroup.translation = [1237 - chipWidth,43]
    m.loggedUserGroup.scaleRotateCenter = [chipWidth / 2,18]
end sub

sub onFollowingItemSelected()
    item = m.followingView.selectedItem
    if item = invalid then return
    if item.followKind = "live"
        playLiveItem(item)
    else
        openFollowingChannel(item)
    end if
end sub

sub onFollowingChannelRequested()
    item = m.followingView.channelRequested
    if item <> invalid then openFollowingChannel(item)
end sub

sub openFollowingChannel(item)
    m.top.streamerSelectedThumbnail = item.HDPosterUrl
    m.top.streamerSelectedName = item.ShortDescriptionLine1
end sub

sub clearAccount()
    m.loggedIn = false
    m.followingView.liveStreams = []
    m.followingView.offlineChannels = []
    m.offlinePending = false
    m.offlineLoaded = false
    m.offlineError = ""
    m.currentlySelectedButton = 1
    m.currentlyFocusedButton = 1
    m.channelPage.visible = false
    m.browseMain.visible = true
    showActiveSurface()
    onNewUser()
    showLoadStatus("")
    if not hasRows(m.browseList) then onHomeLoad()
    focusActiveGrid()
end sub
