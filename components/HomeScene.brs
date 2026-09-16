sub init()
    m.loadStatus = m.top.findNode("loadStatus")
    m.browseList = m.top.findNode("browseList")
    m.browseCategoryList = m.top.findNode("browseCategoryList")
    m.browseFollowingList = m.top.findNode("browseFollowingList")
    m.browseOfflineFollowingList = m.top.findNode("browseOfflineFollowingList")

    m.offlineChannelList = m.top.findNode("offlineChannelList")

    m.categoryButton = m.top.findNode("categoryButton")
    m.categoryLine = m.top.findNode("categoryLine")
    m.liveButton = m.top.findNode("liveButton")
    m.liveLine = m.top.findNode("liveLine")
    m.followingButton = m.top.findNode("followingButton")
    m.followingLine = m.top.findNode("followingLine")

    m.searchLabel = m.top.findNode("searchLabel")
    'm.loginButton = m.top.findNode("loggedUserName")'m.top.findNode("loginButton")
    m.headerCursor = m.top.findNode("headerCursor")
    m.followingLiveLabel = m.top.findNode("followingLiveLabel")
    m.offlineChannelsLabel = m.top.findNode("offlineChannelsLabel")


    m.channelPage = m.top.findNode("channelPage")
    m.followBar = {loggedIn: false, focused: false}
    m.browseButtons = m.top.findNode("browseButtons")
    m.browseMain = m.top.findNode("browseMain")

    m.loggedUserGroup = m.top.findNode("loggedUserGroup")
    m.profileImage = m.top.findNode("profileImage")
    m.loggedUserName = m.top.findNode("loggedUserName")

    m.actualBrowseButtons = [ m.categoryButton, m.liveButton, m.followingButton, m.searchLabel, m.loggedUserName ]

    m.browseButtons.observeField("focusedChild", "updateHeaderFocus")

    m.browseList.observeField("itemSelected", "onBrowseItemSelect")
    m.browseCategoryList.observeField("itemSelected", "onBrowseItemSelect")
    m.browseFollowingList.observeField("itemSelected", "onBrowseItemSelect")
    m.browseFollowingList.observeField("itemFocused", "onBrowseFollowing")

    'm.browseOfflineFollowingList.observeField("itemSelected", "onBrowseItemSelect")
    m.offlineChannelList.observeField("channelSelected", "onBrowseItemSelect")

    'm.channelPage.observeField("videoUrl", "onVideoSelectedFromChannel")
    m.channelPage.observeField("streamUrl", "onLiveStreamSelectedFromChannel")


    m.getStreams = createObject("roSGNode", "GetStreams")
    m.getStreams.observeField("searchResults", "onSearchResultChange")

    m.getStuff = createObject("roSGNode", "GetStuff")
    m.getStuff.observeField("streamUrl", "onStreamUrlChange")
    m.getStuff.observeField("state", "onPlaybackRequestStopped")
    m.playbackPending = false
    m.playbackRequestId = 0

    m.getCategories = createObject("roSGNode", "GetCategories")
    m.getCategories.observeField("searchResults", "onCategoryResultChange")
    'm.getCategories = createObject("roSGNode", "GetCategories2")
    'm.getCategories.observeField("searchResults", "onCategoryResultChange")

    m.getOfflineFollowed = createObject("roSGNode", "GetOfflineFollowedChannels")
    m.getOfflineFollowed.observeField("offlineFollowedUsers", "onGetOfflineFollowed")
    m.getOfflineFollowed.observeField("state", "onOfflineStopped")

    m.top.observeField("visible", "onGetFocus")
    m.top.observeField("currentlyLiveStreamerIds", "onGetFollowedStreams")
    m.top.observeField("streamerSelectedName", "onStreamerSelected")


    m.offset = 0
    m.append = false
    m.offsetCategory = 0
    m.appendCategory = false
    m.appLaunchComplete = false

    m.numRowsInFollowingList = 0

    m.currentlySelectedButton = 1
    m.currentlyFocusedButton = 1

    m.followingListIsFocused = true

    m.wasLastScene = false

    m.browseCategoryList.visible = false
    m.browseFollowingList.visible = false
    m.followingLiveLabel.visible = false
    m.browseOfflineFollowingList.visible = false
end sub

sub focusContent()
    ' Called explicitly by MainScene; do not depend on nested focus observers.
    onGetFocus()
    if m.top.visible and not m.top.isInFocusChain()
        print "Home focus failed: no control in the focus chain"
    end if
end sub

function hasRows(list as Object) as Boolean
    if list.content = invalid then return false
    return list.content.getChildCount() > 0
end function

sub showLoadStatus(message as String)
    m.loadStatus.text = message
    m.loadStatus.visible = message <> ""
end sub

sub onStartupError()
    message = m.top.startupError
    if message = ""
        showLoadStatus("Connecting to Twitch...")
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

    if m.currentlySelectedButton = 0
        m.browseCategoryList.visible = false
    else if m.currentlySelectedButton = 1
        m.browseList.visible = false
    else if m.currentlySelectedButton = 2
        m.browseFollowingList.visible = false
    m.followingLiveLabel.visible = false
        m.offlineChannelsLabel.visible = false
        m.offlineChannelList.visible = false
        m.browseOfflineFollowingList.visible = false
    end if
    m.wasLastScene = true
    m.browseMain.visible = false
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
    m.followBar.loggedIn = m.top.loggedInUserName <> ""
    m.loggedUserName.text = m.top.loggedInUserName
    if m.loggedUserName.text = "" then m.loggedUserName.text = "Login"
    m.loggedUserName.translation = [12,7]
    m.loggedUserName.width = 184
    m.profileImage.uri = m.top.loggedInUserProfileImage
    if m.profileImage.uri <> ""
        m.loggedUserName.translation = [46,7]
        m.loggedUserName.width = 152
    end if
end sub

sub onFollowBarLogin()
    m.followBar.focused = false
    m.top.buttonPressed = "login"
end sub

sub onGetFocus()
    if not m.top.visible
        cancelPlaybackRequest()
        return
    end if
    if m.channelPage.visible
        m.browseMain.visible = false
        m.channelPage.callFunc("focusContent")
    else
        m.browseMain.visible = true
        focusActiveGrid()
    end if
end sub

sub onStreamUrlChange()
    if not m.playbackPending or not m.top.visible then return
    if m.getStuff.requestId <> m.playbackRequestId or m.getStuff.streamUrl = "" then return
    m.playbackPending = false
    showLoadStatus("")
    m.top.streamerRequested = m.getStuff.streamerRequested
    m.top.playbackInfo = m.getStuff.playbackInfo
    m.top.streamUrl = m.getStuff.streamUrl
end sub

sub onBrowseItemSelect()
    if m.offlineChannelList.isInFocusChain()
        m.top.streamerSelectedThumbnail = ""
        m.top.streamerSelectedName = m.offlineChannelList.channelSelected
        return
    end if
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
    m.browseCategoryList.visible = false
    m.browseFollowingList.visible = false
    m.followingLiveLabel.visible = false
    m.browseOfflineFollowingList.visible = false
    m.offlineChannelList.visible = false
    m.offlineChannelsLabel.visible = false
    m.browseList.visible = true
    if m.top.isInFocusChain() and not hasRows(m.browseList) then m.browseButtons.setFocus(true)
    if not m.top.apiReady
        m.browseButtons.setFocus(true)
        m.top.retryAuthentication = true
        return
    end if
    if m.getStreams.state = "run" then return
    showLoadStatus("Loading live channels...")
    m.append = false
    m.getStreams.gameRequested = ""
    m.getStreams.offset = "0"
    m.getStreams.pagination = ""
    m.offset = 0
    m.getStreams.control = "RUN"
end sub

sub onSearchResultChange()
    if m.getStreams.errorMessage <> ""
        if m.browseList.visible
            showLoadStatus(m.getStreams.errorMessage + " Select Channels to retry.")
            if m.top.isInFocusChain() then m.browseButtons.setFocus(true)
        end if
        m.append = false
        finishLaunch()
        return
    end if
    lastFocusedRow = 0
    if m.browseList.rowItemFocused[0] <> invalid
        lastFocusedRow = m.browseList.rowItemFocused[0]
    end if
    if m.append = true
        content = m.browseList.content
    else if m.append = false
        content = createObject("roSGNode", "ContentNode")
    end if 
    if m.getStreams.searchResults <> invalid
        row = createObject("RoSGNode", "ContentNode")
        rowItem = invalid
        alreadyAppended = false
        cnt = 0
        for each stream in m.getStreams.searchResults
            alreadyAppended = false
            rowItem = createObject("RoSGNode", "ContentNode")
            rowItem.Title = stream.title
            rowItem.Description = stream.display_name
            rowItem.Categories = stream.game
            rowItem.HDPosterUrl = stream.thumbnail
            rowItem.ShortDescriptionLine1 = stream.name
            rowItem.ShortDescriptionLine2 = numberToText(stream.viewers)
            row.appendChild(rowItem)
            cnt += 1
            if cnt <> 0 and cnt MOD 4 = 0
                content.appendChild(row)
                row = createObject("RoSGNode", "ContentNode")
                alreadyAppended = true
            end if
        end for
        if rowItem <> invalid and cnt <> 0 and alreadyAppended = false
            content.appendChild(row)
        end if
    end if
    if m.browseList.visible = true
        m.browseList.content = content
        if hasRows(m.browseList)
            showLoadStatus("")
        else
            showLoadStatus("No live channels found. Select Channels to retry.")
        end if
    end if
    m.browseList.jumpToItem = lastFocusedRow
    m.append = false
    finishLaunch()
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
    if m.getCategories.errorMessage <> ""
        if m.browseCategoryList.visible
            showLoadStatus(m.getCategories.errorMessage + " Select Games to retry.")
            if m.top.isInFocusChain() then m.browseButtons.setFocus(true)
        end if
        m.appendCategory = false
        finishLaunch()
        return
    end if
    lastFocusedRow = 0
    if m.browseCategoryList.rowItemFocused[0] <> invalid
        lastFocusedRow = m.browseCategoryList.rowItemFocused[0]
    end if
    if m.appendCategory = true
        content = m.browseCategoryList.content
    else if m.appendCategory = false
        content = createObject("roSGNode", "ContentNode")
    end if 
    if m.getCategories.searchResults <> invalid
        row = createObject("RoSGNode", "ContentNode")
        rowItem = invalid
        alreadyAppended = false
        cnt = 0
        for each stream in m.getCategories.searchResults
            alreadyAppended = false
            rowItem = createObject("RoSGNode", "ContentNode")
            rowItem.Title = stream.name
            rowItem.Description = numberToText(stream.viewers)
            rowItem.ShortDescriptionLine1 = stream.id
            rowItem.HDPosterUrl = stream.logo
            row.appendChild(rowItem)
            cnt += 1
            if cnt <> 0 and cnt MOD 4 = 0 and content <> invalid
                content.appendChild(row)
                row = createObject("RoSGNode", "ContentNode")
                alreadyAppended = true
            end if
        end for
        if rowItem <> invalid and alreadyAppended = false
            content.appendChild(row)
        end if
    end if
    m.browseCategoryList.content = content
    if m.browseCategoryList.visible
        if hasRows(m.browseCategoryList)
            showLoadStatus("")
        else
            showLoadStatus("No categories found. Select Games to retry.")
        end if
    end if
    m.browseCategoryList.jumpToItem = lastFocusedRow
    m.appendCategory = false
    finishLaunch()
end sub

sub onCategorySelect()
    m.browseList.visible = false
    m.browseFollowingList.visible = false
    m.followingLiveLabel.visible = false
    m.browseOfflineFollowingList.visible = false
    m.offlineChannelList.visible = false
    m.offlineChannelsLabel.visible = false
    m.browseCategoryList.visible = true
    if m.top.isInFocusChain() and not hasRows(m.browseCategoryList) then m.browseButtons.setFocus(true)
    if not m.top.apiReady
        m.browseButtons.setFocus(true)
        m.top.retryAuthentication = true
        return
    end if
    if m.getCategories.state = "run" then return
    showLoadStatus("Loading categories...")
    m.appendCategory = false
    m.getCategories.pagination = ""
    m.getCategories.searchText = ""
    m.getCategories.offset = "0"
    m.offsetCategory = 0
    m.getCategories.control = "RUN"
end sub

sub onFollowingSelect()
    showLoadStatus("")
    m.browseList.visible = false
    m.browseCategoryList.visible = false
    m.browseFollowingList.visible = true
    m.followingLiveLabel.visible = hasRows(m.browseFollowingList)
    'm.browseOfflineFollowingList.visible = true
    m.offlineChannelsLabel.visible = true
    if not hasRows(m.browseFollowingList)
        if not m.followBar.loggedIn
            showLoadStatus("Sign in to see followed channels. Select Login in the header.")
            m.offlineChannelsLabel.visible = false
        else
            showLoadStatus("No followed live channels to show.")
        end if
        m.browseButtons.setFocus(true)
    end if
    updateFollowingLayout()
    onFollowingError()
end sub

sub getMoreChannels()
    if not m.top.apiReady or m.getStreams.state = "run" then return
    if m.getStreams.pagination = "" then return
    m.offset += 25
    m.append = true
    m.getStreams.gameRequested = ""
    m.getStreams.offset = m.offset.ToStr()
    m.getStreams.control = "RUN"
end sub

sub getMoreCategories()
    if not m.top.apiReady or m.getCategories.state = "run" then return
    if m.getCategories.pagination = "" then return
    if m.offsetCategory = 0
        m.offsetCategory += 25
    else
        m.offsetCategory += 24
    end if
    m.appendCategory = true
    m.getCategories.offset = m.offsetCategory.ToStr()
    m.getCategories.control = "RUN"
end sub

sub requestOfflineFollowing()
    if m.top.followingError <> "" or m.top.loggedInSessionVersion <> m.global.sessionVersion then return
    if m.getOfflineFollowed.state <> "run"
        m.getOfflineFollowed.userId = m.top.loggedInUserId
        m.getOfflineFollowed.sessionVersion = m.global.sessionVersion
        m.getOfflineFollowed.currentlyLiveStreamerIds = m.top.currentlyLiveStreamerIds
        m.getOfflineFollowed.control = "RUN"
    end if
end sub

sub onOfflineStopped()
    if m.getOfflineFollowed.state = "stop" and m.getOfflineFollowed.sessionVersion <> m.global.sessionVersion
        requestOfflineFollowing()
    end if
end sub

sub onGetFollowedStreams()
    requestOfflineFollowing()
    wasFocused = m.browseFollowingList.hasFocus()

    m.numRowsInFollowingList = 0
    lastFocusedRow = 0
    if m.browseFollowingList.rowItemFocused[0] <> invalid
        lastFocusedRow = m.browseFollowingList.rowItemFocused[0]
    end if
    content = createObject("roSGNode", "ContentNode")
    if m.top.followedStreams <> invalid
        row = createObject("RoSGNode", "ContentNode")
        rowItem = invalid
        alreadyAppended = false
        cnt = 0
        for each stream in m.top.followedStreams
            alreadyAppended = false
            rowItem = createObject("RoSGNode", "ContentNode")
            rowItem.Title = stream.title
            rowItem.Description = stream.user_name
            rowItem.Categories = stream.game_id
            rowItem.HDPosterUrl = stream.thumbnail
            rowItem.ShortDescriptionLine1 = stream.login
            rowItem.ShortDescriptionLine2 = numberToText(stream.viewer_count)
            row.appendChild(rowItem)
            cnt += 1
            if cnt <> 0 and cnt MOD 4 = 0
                content.appendChild(row)
                row = createObject("RoSGNode", "ContentNode")
                m.numRowsInFollowingList += 1
                alreadyAppended = true
            end if
        end for
        if cnt > 0 and alreadyAppended = false
            content.appendChild(row)
            m.numRowsInFollowingList += 1
        end if
    end if
    m.browseFollowingList.content = content
    m.browseFollowingList.jumpToItem = lastFocusedRow
    m.numRowsInFollowingList -= 1
    if wasFocused and not hasRows(m.browseFollowingList) then m.browseButtons.setFocus(true)
    if m.browseFollowingList.visible then onFollowingError()
end sub

sub onBrowseFollowing()
    updateFollowingLayout()
end sub

sub onGetOfflineFollowed()
    if m.getOfflineFollowed.sessionVersion <> m.global.sessionVersion then return
    if m.getOfflineFollowed.offlineFollowedUsers = invalid then return
    m.offlineChannelList.offlineChannels = m.getOfflineFollowed.offlineFollowedUsers
    lastFocusedRow = 0
    if m.browseOfflineFollowingList.rowItemFocused[0] <> invalid
        lastFocusedRow = m.browseOfflineFollowingList.rowItemFocused[0]
    end if
    content = createObject("roSGNode", "ContentNode")
    if m.getOfflineFollowed.offlineFollowedUsers <> invalid
        row = createObject("RoSGNode", "ContentNode")
        rowItem = invalid
        alreadyAppended = false
        cnt = 0
        for each stream in m.getOfflineFollowed.offlineFollowedUsers
            alreadyAppended = false
            rowItem = createObject("RoSGNode", "ContentNode")
            rowItem.Title = stream.display_name
            rowItem.ShortDescriptionLine1 = stream.login
            rowItem.HDPosterUrl = stream.profile_image_url
            row.appendChild(rowItem)
            cnt += 1
            if cnt <> 0 and cnt MOD 6 = 0
                content.appendChild(row)
                row = createObject("RoSGNode", "ContentNode")
                alreadyAppended = true
            end if
        end for
        if cnt > 0 and alreadyAppended = false
            content.appendChild(row)
        end if
    end if
    m.browseOfflineFollowingList.content = content
    m.browseOfflineFollowingList.jumpToItem = lastFocusedRow
    updateFollowingLayout()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not m.top.visible or not press then return false
    if m.channelPage.visible
        if key <> "back" then return false
        m.channelPage.callFunc("cancelPlaybackRequest")
        m.channelPage.visible = false
        m.browseMain.visible = true
        m.wasLastScene = false
        focusActiveGrid()
        return true
    end if
    if m.playbackPending and key = "back"
        cancelPlaybackRequest()
        return true
    end if
    if m.browseButtons.hasFocus()
        if key = "left" or key = "right"
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
                focusActiveGrid()
            end if
            updateHeaderFocus()
            return true
        end if
    else if key = "up" or key = "back"
        if m.offlineChannelList.isInFocusChain() and hasRows(m.browseFollowingList)
            m.browseFollowingList.setFocus(true)
            m.followingListIsFocused = true
        else
            m.currentlyFocusedButton = m.currentlySelectedButton
            m.browseButtons.setFocus(true)
        end if
        updateHeaderFocus()
        return true
    else if key = "down"
        if m.browseList.hasFocus()
            getMoreChannels()
        else if m.browseCategoryList.hasFocus()
            getMoreCategories()
        else if m.browseFollowingList.hasFocus() and hasOfflineChannels()
            m.offlineChannelList.visible = true
            m.offlineChannelList.callFunc("focusContent")
            m.followingListIsFocused = false
        end if
        return true
    else if key = "options"
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
    if m.browseFollowingList.visible and m.top.followingError <> ""
        showLoadStatus(m.top.followingError)
    else if m.browseFollowingList.visible
        if hasRows(m.browseFollowingList)
            showLoadStatus("")
        else if m.followBar.loggedIn
            showLoadStatus("No followed live channels to show.")
        end if
    end if
end sub


function activeGrid() as Object
    if m.currentlySelectedButton = 0 then return m.browseCategoryList
    if m.currentlySelectedButton = 2 then return m.browseFollowingList
    return m.browseList
end function

function hasOfflineChannels() as Boolean
    channels = m.offlineChannelList.offlineChannels
    if type(channels) <> "roArray" then return false
    return channels.Count() > 0
end function

sub focusActiveGrid()
    list = activeGrid()
    if hasRows(list)
        list.setFocus(true)
    else if m.currentlySelectedButton = 2 and hasOfflineChannels()
        m.offlineChannelList.visible = true
        m.offlineChannelList.callFunc("focusContent")
    else
        m.browseButtons.setFocus(true)
    end if
    updateHeaderFocus()
end sub

sub updateHeaderFocus()
    m.categoryLine.visible = m.currentlySelectedButton = 0
    m.liveLine.visible = m.currentlySelectedButton = 1
    m.followingLine.visible = m.currentlySelectedButton = 2
    for index = 0 to 4
        m.actualBrowseButtons[index].color = "0xA9A9B2FF"
        if index = m.currentlySelectedButton then m.actualBrowseButtons[index].color = "0xF4F4F7FF"
    end for
    m.headerCursor.visible = m.browseButtons.hasFocus()
    if m.headerCursor.visible
        m.actualBrowseButtons[m.currentlyFocusedButton].color = "0xFFFFFFFF"
        positions = [212,95,305,424,1027]
        widths = [69,93,95,70,210]
        m.headerCursor.translation = [positions[m.currentlyFocusedButton],75]
        m.headerCursor.width = widths[m.currentlyFocusedButton]
    end if
end sub

sub playLiveItem(item as Object)
    if m.getStuff.state = "run" then return
    m.playbackRequestId += 1
    m.playbackPending = true
    m.getStuff.cancelRequested = false
    m.getStuff.requestId = m.playbackRequestId
    m.getStuff.streamerRequested = item.ShortDescriptionLine1
    m.top.liveTitle = item.Title
    m.top.liveName = item.Description
    m.top.liveGame = ""
    if type(item.Categories) = "roArray"
        if item.Categories.Count() > 0 then m.top.liveGame = item.Categories[0]
    end if
    m.top.liveViewers = item.ShortDescriptionLine2
    showLoadStatus("Opening " + item.Description + "...")
    m.getStuff.control = "RUN"
end sub

sub cancelPlaybackRequest()
    m.channelPage.callFunc("cancelPlaybackRequest")
    m.playbackPending = false
    m.playbackRequestId += 1
    m.getStuff.cancelRequested = true
    showLoadStatus("")
end sub

sub onPlaybackRequestStopped()
    if m.getStuff.state <> "stop" or not m.playbackPending then return
    if m.getStuff.requestId <> m.playbackRequestId then return
    m.playbackPending = false
    if m.getStuff.errorMessage <> "" then showLoadStatus(m.getStuff.errorMessage + " Press OK to retry.")
end sub

sub updateFollowingLayout()
    if m.currentlySelectedButton <> 2 then return
    live = hasRows(m.browseFollowingList)
    m.followingLiveLabel.visible = live
    offline = hasOfflineChannels()
    showOffline = not live
    if live then showOffline = m.browseFollowingList.itemFocused = m.numRowsInFollowingList
    m.offlineChannelsLabel.visible = offline and showOffline
    m.offlineChannelList.visible = offline and showOffline
    if live
        m.offlineChannelsLabel.translation = [43,439]
        m.offlineChannelList.translation = [40,480]
    else
        m.offlineChannelsLabel.translation = [43,120]
        m.offlineChannelList.translation = [40,164]
        if offline then showLoadStatus("")
    end if
end sub
