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
    m.followBar = {loggedIn: false,focused: false}
    m.channelPage = node()
    m.channelPage.callFunc = function(name)
        if name = "focusContent" then m.setFocus(true)
    end function
    m.getStreams = node()
    m.getCategories = node()
    m.getOfflineFollowed = node()
    m.getStuff = node()
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
    m.loggedUserGroup = node()
    m.profileImage = node()
    m.profileImage.uri = ""
    m.profileCover = node()
    m.accountBackground = node()
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
    m.append = false
    m.appendCategory = false
    m.channelsPending = false
    m.categoriesPending = false
end sub

sub main()
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
    layoutHeader()
    check(m.liveLine.width = m.liveButton.localBoundingRect().width, "Channels underline matches rendered glyph extent")
    check(m.categoryLine.width = m.categoryButton.localBoundingRect().width, "Games underline uses its own rendered extent")
    check(m.categoryButton.translation[0] = m.liveButton.translation[0] + m.liveButton.localBoundingRect().width + 24, "Tab spacing follows rendered width")
    m.liveButton.measuredWidth = 61.125
    layoutHeader()
    check(m.liveLine.width = 61.125 and m.categoryButton.translation[0] = 95 + 61.125 + 24, "Font metrics changes update underline and neighboring position together")
    check(m.loggedUserGroup.translation[0] + m.accountBackground.width = 1237, "Account chip remains flush with the right page edge")
    check(m.accountBackground.width = m.loggedUserName.localBoundingRect().width + 8, "Short Login chip has only measured text and balanced padding")
    m.profileImage.uri = "avatar"
    m.loggedUserName.measuredWidth = 400
    layoutAccount()
    check(m.loggedUserName.width = 180 and m.accountBackground.width = 226, "Long account names truncate within a compact chip")
    check((4 + m.loggedUserName.translation[0] + m.loggedUserName.width) / 2 = m.accountBackground.width / 2, "Avatar and name content midpoint equals chip midpoint")
    check(m.profileImage.visible and m.profileCover.visible and m.loggedUserName.translation[0] = 42, "Avatar and name share one vertically centered chip")

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
    m.getCategories.state = "stop"
    m.getCategories.searchResults = [{id: "1",name: "Game",logo: "x",viewers: 0}]
    onCategoryResultChange()
    check(hasRows(m.browseCategoryList) and not m.busy.active, "Category completion stops the spinner")
    m.top.startupError = "offline"
    onStartupError()
    check(m.loadStatus.visible and not m.busy.active and m.appLaunchComplete, "Authentication failure has a finite error state")

    setup()
    m.currentlySelectedButton = 2
    onFollowingSelect()
    focusActiveGrid()
    check(m.followingView.visible and m.browseButtons.hasFocus() and m.loadStatus.visible, "Signed-out Following stays navigable at the header")
    m.followBar.loggedIn = true
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
    print "PASS measured header, compact account, feed packing, spinner lifecycle, unified Following return, logout"
end sub

sub testFeedPacking()
    setup()
    m.getStreams.searchResults = []
    for index = 0 to 16
        m.getStreams.searchResults.Push({title: index.ToStr(),display_name: "A",game: "G",thumbnail: "x",name: index.ToStr(),viewers: 1})
    end for
    onSearchResultChange()
    m.browseList.rowItemFocused = [4,0]
    m.append = true
    m.getStreams.searchResults = [{title:"next",display_name:"B",game:"G",thumbnail:"x",name:"next",viewers:1}]
    onSearchResultChange()
    check(m.browseList.content.getChildCount() = 5 and m.browseList.content.getChild(4).getChildCount() = 2, "A short Channels page fills the previous partial row")
    check(m.browseList.content.getChild(4).getChild(1).Title = "next" and m.browseList.jumpToRowItem[0] = 4, "Pagination preserves card order and focused row/column")
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
