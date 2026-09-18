function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    return result
end function

function measuredLabel(width)
    result = node()
    result.measuredWidth = width
    result.translation = [0,0]
    result.localBoundingRect = function()
        return {x: 0,y: -12,width: m.measuredWidth,height: 24}
    end function
    return result
end function

sub setup()
    m.reloadPending = false
    m.top = node()
    m.top.visible = true
    m.top.setFocus(true)
    m.top.apiReady = false
    m.top.followingError = ""
    m.top.loggedInUserId = "123"
    m.top.loggedInUserName = ""
    m.top.loggedInUserProfileImage = ""
    m.top.loggedInSessionVersion = 1
    m.global = {sessionVersion: 1}
    m.top.retryAuthentication = false
    m.loadStatus = node()
    m.playbackStatus = node()
    m.busy = node()
    m.browseButtons = node()
    m.browseList = node()
    m.browseList.visible = true
    m.browseCategoryList = node()
    m.followingView = node()
    m.followingView.hasItems = false
    m.followingView.callFunc = function(name)
        if name = "focusContent" then m.setFocus(true)
    end function
    m.loggedIn = false
    m.channelPage = node()
    m.channelPage.callFunc = function(name)
        if name = "focusContent" then m.setFocus(true)
    end function
    m.getStreams = node()
    m.getCategories = node()
    m.getOfflineFollowed = node()
    m.getLivePlayback = node()
    m.currentlySelectedButton = 1
    m.currentlyFocusedButton = 1
    m.actualBrowseButtons = [measuredLabel(58.5), measuredLabel(84.75), measuredLabel(88.25), measuredLabel(63.5), measuredLabel(46.25)]
    m.browseMain = node()
    m.browseMain.visible = true
    m.top.appendChild(m.browseMain)
    for each child in [m.browseButtons,m.browseList,m.browseCategoryList,m.followingView]
        m.browseMain.appendChild(child)
    end for
    m.top.appendChild(m.channelPage)
    m.categoryButton = m.actualBrowseButtons[0]
    m.liveButton = m.actualBrowseButtons[1]
    m.followingButton = m.actualBrowseButtons[2]
    m.searchLabel = m.actualBrowseButtons[3]
    m.loggedUserName = m.actualBrowseButtons[4]
    m.loggedUserName.font = {size: 18}
    m.loggedUserGroup = node()
    m.profileImage = node()
    m.profileImage.uri = ""
    m.profileCover = node()
    m.accountBackground = node()
    m.accountBackground.width = 117
    m.accountBackground.height = 36
    m.headerCursor = node()
    m.categoryLine = node()
    m.liveLine = node()
    m.followingLine = node()
    m.playbackPending = false
    m.playbackRequestId = 0
    m.offlinePending = false
    m.offlineError = ""
    m.offlineLoaded = false
    m.appLaunchComplete = false
    m.pendingGridFocus = 1
    m.append = false
    m.appendCategory = false
    m.channelsCursor = ""
    m.categoriesCursor = ""
    m.channelsPending = false
    m.categoriesPending = false
end sub

sub testReloadHome()
    setup()
    m.top.apiReady = true
    m.getStreams.state = "run"
    m.browseList.content = node()
    previous = m.browseList.content.testId
    reloadContent()
    check(m.reloadPending and m.busy.active, "Reload waits for a running grid request")
    m.getStreams.searchResults = streamPage(0, 24)
    onSearchResultChange()
    check(m.browseList.content.testId = previous, "Superseded page cannot replace the grid while reload waits")
    m.getStreams.state = "stop"
    onChannelsStopped()
    check(not m.reloadPending and m.getStreams.control = "RUN" and m.getStreams.pagination = "", "Channels reload requests page one after the old task stops")
    check(m.browseList.content = invalid and m.pendingGridFocus = 1, "Reload clears old pages and restores focus when fresh cards arrive")
    setup()
    m.top.apiReady = true
    m.currentlySelectedButton = 0
    reloadContent()
    check(m.getCategories.control = "RUN" and m.getCategories.pagination = "" and m.currentlySelectedButton = 0, "Games reload keeps the selected tab")
    setup()
    m.currentlySelectedButton = 2
    m.loggedIn = true
    reloadContent()
    check(m.top.reloadFollowingRequested and not m.offlineLoaded and m.busy.active, "Following reload requests fresh live and offline follows")
    m.followingView.hasItems = true
    updateFollowingLayout()
    check(m.followingView.hasFocus(), "Fresh Following content receives focus after reload")
    setup()
    m.channelPage.visible = true
    m.channelPage.callFunc = sub(name)
        m.reloaded = name = "reloadContent"
    end sub
    reloadContent()
    check(m.channelPage.reloaded, "A visible profile reloads instead of the hidden home grid")
end sub

sub main()
    testQuietPlaybackRequest()
    setup()
    focusContent()
    check(m.browseButtons.hasFocus(), "Empty Home gives focus to usable header")
    check(onKeyEvent("down",true) and not m.browseList.hasFocus(), "Empty grid cannot steal focus")
    check(onKeyEvent("right",true) and m.currentlyFocusedButton = 0, "Channels moves to Games")
    check(onKeyEvent("right",true) and m.currentlyFocusedButton = 2, "Games moves to Following")
    check(onKeyEvent("right",true) and m.currentlyFocusedButton = 3, "Following moves to Search")
    check(onKeyEvent("right",true) and m.currentlyFocusedButton = 4, "Account follows Search without settings")
    check(onKeyEvent("OK",true) and m.top.buttonPressed = "login", "Account click keeps the MainScene account action")
    check(m.accountBackground.color = "0xF4F4F7FF" and not m.headerCursor.visible, "Focused account uses its chip instead of a long underline")
    check(m.loggedUserName.font.size = 22 and m.accountBackground.height = 44 and m.profileImage.width = 34, "Selected account renders larger text and avatar at native size")
    selectedCenter = m.loggedUserGroup.translation[0] + m.accountBackground.width / 2
    m.currentlyFocusedButton = 3
    updateHeaderFocus()
    check(m.loggedUserName.font.size = 18 and m.accountBackground.height = 36 and m.loggedUserName.color = "0xFFFFFFFF", "Unselected account restores its original size and opaque white text")
    check(m.loggedUserGroup.translation[0] + m.accountBackground.width / 2 = selectedCenter and m.loggedUserGroup.translation[1] = 43, "Focus growth preserves the account center")
    layoutHeader()
    check(m.liveLine.width = m.liveButton.localBoundingRect().width, "Channels underline matches rendered glyph extent")
    check(m.categoryLine.width = m.categoryButton.localBoundingRect().width, "Games underline uses its own rendered extent")
    check(m.categoryButton.translation[0] = m.liveButton.translation[0] + m.liveButton.localBoundingRect().width + 24, "Tab spacing follows rendered width")
    m.liveButton.measuredWidth = 61.125
    layoutHeader()
    check(m.liveLine.width = 61.125 and m.categoryButton.translation[0] = 95 + 61.125 + 24, "Font metrics changes update underline and neighboring position together")
    check(m.loggedUserGroup.translation[0] + m.accountBackground.width = 1237, "Account chip remains flush with the right page edge")
    check(m.accountBackground.width = m.loggedUserName.localBoundingRect().width + 8, "Short Log In chip has only measured text and balanced padding")
    m.profileImage.uri = "avatar"
    m.loggedUserName.measuredWidth = 400
    layoutAccount()
    check(m.loggedUserName.width = 180 and m.accountBackground.width = 220, "Long account names truncate within a compact chip")
    check((4 + m.loggedUserName.translation[0] + m.loggedUserName.width) / 2 = m.accountBackground.width / 2, "Avatar and name content midpoint equals chip midpoint")
    check(m.profileImage.visible and m.profileCover.visible and m.loggedUserName.translation[0] = 36, "Avatar/name gap matches four-pixel outer padding")

    onHomeLoad()
    check(m.getStreams.control = "" and m.top.retryAuthentication, "No feed request before authentication")
    m.top.apiReady = true
    onApiReady()
    check(m.getStreams.control = "RUN" and m.busy.active and not m.loadStatus.visible, "Content request displays spinner without loading text")
    m.getStreams.state = "run"
    m.top.visible = false
    onGetFocus()
    m.top.visible = true
    onGetFocus()
    check(m.busy.active and m.busy.enabled, "Returning while the selected feed is running restores its spinner")
    showLoadStatus("Following message")
    onHomeLoad()
    check(m.busy.active and not m.loadStatus.visible, "Switching to an existing in-flight Channels request restores its spinner")
    m.getStreams.state = "stop"
    m.getStreams.searchResults = [{title: "A",display_name: "A",game: "G",thumbnail: "x",name: "a",viewers: 1}]
    onSearchResultChange()
    check(m.browseList.content.getChildCount() = 1 and m.browseList.content.children[0].getChildCount() = 1, "Partial browse row contains every result exactly once")
    check(not m.busy.active and not m.loadStatus.visible and m.appLaunchComplete, "Success stops spinner and completes launch")
    m.getStreams.state = "run"
    m.top.startupError = ""
    onStartupError()
    showActiveSurface()
    check(not m.busy.active, "Late login success and feed focus cannot restart the spinner after results arrive before Task stop")
    m.getStreams.state = "stop"
    focusActiveGrid()
    check(m.browseList.hasFocus(), "Populated browse grid receives focus")
    check(onKeyEvent("up",true) and m.browseButtons.hasFocus(), "Boundary Up returns to tabs")
    m.getStreams.errorMessage = "offline"
    m.append = true
    onSearchResultChange()
    check(hasRows(m.browseList) and m.loadStatus.visible and not m.busy.active, "Failed pagination keeps cards and replaces spinner with error")
    m.getStreams.errorMessage = ""
    m.append = false
    m.getStreams.searchResults = []
    onSearchResultChange()
    check(not hasRows(m.browseList) and m.loadStatus.visible, "Empty successful response has an explicit empty state")
    m.getStreams.control = ""
    m.getStreams.pagination = ""
    getMoreChannels()
    check(m.getStreams.control = "", "Exhausted pagination makes no request")
    m.getStreams.pagination = "next"
    m.getStreams.state = "run"
    getMoreChannels()
    check(m.getStreams.control = "", "Scrolling cannot start concurrent requests")

    setup()
    m.currentlySelectedButton = 0
    m.top.apiReady = true
    onApiReady()
    check(m.getCategories.control = "RUN" and m.busy.active, "Selected Games loads after authentication")
    m.getCategories.state = "run"
    showLoadStatus("Following message")
    onCategorySelect()
    check(m.busy.active and not m.loadStatus.visible, "Switching to an existing in-flight Games request restores its spinner")
    focusActiveGrid(true)
    m.getCategories.state = "stop"
    m.getCategories.searchResults = [{id: "1",name: "Game",logo: "x",viewers: 0}]
    onCategoryResultChange()
    check(hasRows(m.browseCategoryList) and not m.busy.active, "Category completion stops the spinner")
    check(m.browseCategoryList.hasFocus() and m.browseCategoryList.jumpToRowItem[0] = 0 and m.browseCategoryList.jumpToRowItem[1] = 0, "Games selects its first cell when asynchronous results arrive")
    m.top.startupError = "offline"
    onStartupError()
    check(m.loadStatus.visible and not m.busy.active and m.appLaunchComplete, "Authentication failure has a finite error state")

    setup()
    focusContent()
    m.getStreams.searchResults = [{title: "A",display_name: "A",game: "G",thumbnail: "x",name: "a",viewers: 1}]
    m.browseList.rowItemFocused = []
    onSearchResultChange()
    check(m.browseList.hasFocus() and m.browseList.jumpToRowItem[0] = 0 and m.browseList.jumpToRowItem[1] = 0, "Cold launch focuses first channel without an extra remote press")
    m.browseList.jumpToRowItem = invalid
    m.browseList.rowItemFocused = [2, 3]
    m.append = true
    onSearchResultChange()
    check(m.browseList.jumpToRowItem = invalid and m.browseList.rowItemFocused[1] = 3, "Pagination leaves native focus and animation alone")
    focusActiveGrid()
    check(m.browseList.jumpToRowItem = invalid, "Returning from playback preserves selection")
    focusActiveGrid(true)
    check(m.browseList.jumpToRowItem[0] = 0, "Explicit tab selection starts at the first cell")

    setup()
    focusContent()
    onKeyEvent("right", true)
    m.getStreams.searchResults = [{title: "A",display_name: "A",game: "G",thumbnail: "x",name: "a",viewers: 1}]
    onSearchResultChange()
    check(m.browseButtons.hasFocus() and m.currentlyFocusedButton = 0, "Late Channels results do not steal focus after header navigation")
    m.pendingGridFocus = 1
    m.top.visible = false
    onSearchResultChange()
    check(m.browseButtons.hasFocus(), "Hidden feed completion cannot take focus")

    setup()
    m.currentlySelectedButton = 2
    onFollowingSelect()
    focusActiveGrid()
    check(m.followingView.visible and m.browseButtons.hasFocus() and m.loadStatus.visible, "Signed-out Following stays navigable at the header")
    m.loggedIn = true
    m.top.followedStreams = []
    m.top.currentlyLiveStreamerIds = {}
    m.append = true
    onGetFollowedStreams()
    check(m.append and m.followingView.liveStreams.Count() = 0, "Follow replacement does not corrupt public pagination state")
    check(m.offlinePending and m.getOfflineFollowed.control = "RUN" and m.busy.active, "Empty live result waits for offline follow data with spinner")
    m.getOfflineFollowed.sessionVersion = 1
    m.getOfflineFollowed.errorMessage = "Offline follow request failed"
    m.getOfflineFollowed.offlineFollowedUsers = invalid
    onGetOfflineFollowed()
    check(not m.offlinePending and not m.busy.active and m.loadStatus.text = "Offline follow request failed", "Offline failure cannot leave spinner running or claim no follows")
    m.getOfflineFollowed.errorMessage = ""
    m.offlinePending = true
    m.getOfflineFollowed.state = "stop"
    onOfflineStopped()
    check(not m.offlinePending and not m.busy.active and m.offlineError <> "", "Unexpected task stop ends pending state with retry guidance")
    m.followingView.hasItems = true
    m.followingView.offlineChannels = [{login: "offline"}]
    m.followingView.savedSelection = [3,4]
    m.followingView.setFocus(true)
    m.top.streamerSelectedName = "offline"
    m.top.streamerSelectedThumbnail = "avatar"
    onStreamerSelected()
    check(not m.browseMain.visible and m.followingView.visible, "Channel page hides parent without clearing Following child visibility")
    m.channelPage.setFocus(true)
    check(onKeyEvent("back",true), "Back closes channel page")
    check(m.browseMain.visible and m.followingView.visible and m.followingView.hasFocus(), "Back restores the same unified Following surface and focus")
    check(m.followingView.savedSelection[0] = 3 and m.followingView.savedSelection[1] = 4, "Channel Back leaves cached row and item unchanged")
    m.top.visible = false
    onGetFocus()
    check(not m.channelPage.parentVisible and not m.busy.enabled, "Ancestor hide disables child loading animation")
    m.top.visible = true
    m.top.loggedInUserId = ""
    m.top.loggedInUserName = ""
    m.top.loggedInUserProfileImage = ""
    m.followingView.hasItems = false
    m.append = false
    m.getStreams.searchResults = [{title: "A",display_name: "A",game: "G",thumbnail: "x",name: "a",viewers: 1}]
    m.browseList.visible = true
    onSearchResultChange()
    clearAccount()
    check(m.currentlySelectedButton = 1 and not m.followingView.visible, "Logout clears account cache and returns to Channels")
    check(m.followingView.liveStreams.Count() = 0 and m.followingView.offlineChannels.Count() = 0, "Logout cannot show previous account follows")
    testFeedPacking()
    testPreload()
    testReloadHome()
    print "PASS measured header, compact account, feed packing, spinner lifecycle, unified Following return, logout"
end sub

sub testFeedPacking()
    setup()
    m.getStreams.searchResults = []
    for index = 0 to 16
        m.getStreams.searchResults.Push({title: index.ToStr(),display_name: "A",game: "G",thumbnail: "x",name: index.ToStr(),viewers: 1})
    end for
    onSearchResultChange()
    m.browseList.jumpToRowItem = invalid
    m.browseList.rowItemFocused = [4,0]
    m.append = true
    m.getStreams.searchResults = [{title:"next",display_name:"B",game:"G",thumbnail:"x",name:"next",viewers:1}]
    onSearchResultChange()
    check(m.browseList.content.getChildCount() = 5 and m.browseList.content.getChild(4).getChildCount() = 2, "A short Channels page fills the previous partial row")
    check(m.browseList.content.getChild(4).getChild(1).Title = "next" and m.browseList.jumpToRowItem = invalid, "Pagination preserves card order without replaying a focus snapshot")
    m.browseList.visible = false
    m.append = false
    onSearchResultChange()
    check(m.browseList.content.getChildCount() = 1, "A feed completing in another tab still caches its content")
    m.getCategories.searchResults = [{name:"a",id:"a",logo:"x",viewers:0}]
    onCategoryResultChange()
    m.appendCategory = true
    m.getCategories.searchResults = [{name:"b",id:"b",logo:"x",viewers:0}]
    onCategoryResultChange()
    check(m.browseCategoryList.content.getChildCount() = 1 and m.browseCategoryList.content.getChild(0).getChildCount() = 2, "Games also fills a partial row between short pages")
end sub

function streamPage(first, count)
    result = []
    for index = first to first + count - 1
        result.Push({title: index.ToStr(),display_name: "A",game: "G",thumbnail: "x",name: index.ToStr(),viewers: 1})
    end for
    return result
end function

sub testPreload()
    setup()
    m.getStreams.searchResults = streamPage(0, 24)
    m.getStreams.pagination = "page2"
    onSearchResultChange()
    m.top.apiReady = true
    m.browseList.setFocus(true)
    onGridFocus()
    check(not m.channelsPending, "A full initial page does not fetch the entire directory")
    m.browseList.navigationRow = 1
    onGridFocus()
    check(m.browseList.rowItemFocused[0] = 0, "Settled focus can remain behind a requested held-scroll row")
    check(m.channelsPending and m.channelsCursor = "page2", "Channels preloads with two rows beyond the visible window")
    m.getStreams.pagination = "changed-before-task-start"
    onGridFocus()
    check(m.channelsCursor = "page2", "Repeated focus notifications cannot race the pending Task startup")
    showActiveSurface()
    check(not m.busy.active, "Background preloading does not cover existing cards with a spinner")
    m.getStreams.state = "run"
    original = m.browseList.content
    firstRow = original.getChild(0)
    m.browseList.rowItemFocused = [4, 2]
    m.browseList.jumpToRowItem = invalid
    m.getStreams.searchResults = streamPage(23, 25)
    m.getStreams.pagination = "page3"
    onSearchResultChange()
    check(m.browseList.content.testId = original.testId and original.getChild(0).testId = firstRow.testId, "Appending retains root, rows, and existing cards")
    check(original.getChildCount() = 12 and original.getChild(6).getChild(0).Title = "24", "Overlapping Twitch pages are deduplicated without leaving gaps")
    check(m.browseList.rowItemFocused[0] = 4 and m.browseList.rowItemFocused[1] = 2 and m.browseList.jumpToRowItem = invalid, "Scrolling during a request is not rewound by its response")
    check(not m.channelsPending, "Result arriving before Task stop does not start another Task")
    m.browseList.rowItemFocused = [10, 2]
    onGridFocus()
    check(not m.channelsPending, "Native scrolling remains free while the preceding Task stops")
    m.getStreams.state = "stop"
    onChannelsStopped()
    check(m.channelsPending and m.channelsCursor = "page3", "Task completion catches up if scrolling entered the next preload window")
    m.getStreams.state = "run"
    m.getStreams.searchResults = streamPage(48, 24)
    m.getStreams.pagination = "page3"
    onSearchResultChange()
    m.getStreams.state = "stop"
    m.browseList.rowItemFocused = [17, 0]
    onChannelsStopped()
    check(m.getStreams.pagination = "" and not m.channelsPending, "A repeated cursor ends preloading instead of looping")
    m.getStreams.pagination = "retry"
    onGridFocus()
    m.getStreams.errorMessage = "offline"
    onSearchResultChange()
    onChannelsStopped()
    check(m.browseList.hasFocus() and not m.channelsPending, "A failed preload preserves grid focus and does not retry automatically")
    m.getStreams.errorMessage = ""
    m.getStreams.pagination = "next"
    m.top.visible = false
    onGridFocus()
    check(not m.channelsPending, "Hidden grids do not start background pages")

    setup()
    m.currentlySelectedButton = 0
    m.browseCategoryList.numRows = 2
    m.getCategories.searchResults = []
    for index = 0 to 23
        m.getCategories.searchResults.Push({id: index.ToStr(),name: "Game",logo: "x",viewers: 0})
    end for
    m.getCategories.pagination = "games2"
    onCategoryResultChange()
    m.top.apiReady = true
    m.browseCategoryList.setFocus(true)
    m.browseCategoryList.rowItemFocused = [1, 0]
    onGridFocus()
    check(not m.categoriesPending, "Games uses its own visible row count")
    m.browseCategoryList.rowItemFocused = [2, 0]
    onGridFocus()
    check(m.categoriesPending and m.categoriesCursor = "games2", "Games preloads before reaching the last row")
    m.getCategories.state = "run"
    m.getCategories.searchResults = []
    m.getCategories.pagination = "games3"
    m.browseCategoryList.jumpToRowItem = invalid
    onCategoryResultChange()
    check(m.getCategories.pagination = "" and m.browseCategoryList.jumpToRowItem = invalid, "An empty page leaves Games and its selection intact and stops preloading")
end sub

sub testQuietPlaybackRequest()
    for each tab in [1, 2]
        setup()
        m.currentlySelectedButton = tab
        m.followingView.hasItems = true
        m.playbackStatus.text = "Previous error"
        item = {ShortDescriptionLine1: "channel", Title: "Title", Description: "Channel", Categories: [], ShortDescriptionLine2: "123"}
        playLiveItem(item)
        check(m.playbackPending and m.getLivePlayback.control = "RUN" and not m.busy.active, "Selecting a channel requests playback without a browse spinner")
        check(m.playbackStatus.text = "", "Retry clears the previous playback error immediately")
        showActiveSurface()
        showBusy()
        check(not m.busy.active, "Background browse callbacks cannot restore the pre-player spinner")
        m.getLivePlayback.state = "stop"
        m.getLivePlayback.errorMessage = "Stream offline"
        onPlaybackRequestStopped()
        check(not m.playbackPending and m.playbackStatus.text = "Stream offline Press OK to retry.", "Failed playback publishes an error through the timed message")
        cancelPlaybackRequest()
        check(m.playbackStatus.text = "", "Leaving or cancelling clears the timed playback error")
        playLiveItem(item)
        m.top.visible = false
        onPlaybackRequestStopped()
        check(m.playbackStatus.text = "", "A hidden browse view rejects late playback errors")
    end for
end sub
