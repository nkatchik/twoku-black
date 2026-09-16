function testCreateObject(kind, name)
    return node()
end function

sub setup()
    m.top = node()
    m.top.visible = true
    m.top.setFocus(true)
    m.top.apiReady = false
    m.top.retryAuthentication = false
    m.loadStatus = node()
    m.browseButtons = node()
    m.browseList = node()
    m.browseList.visible = true
    m.browseCategoryList = node()
    m.browseFollowingList = node()
    m.browseOfflineFollowingList = node()
    m.offlineChannelList = node()
    m.offlineChannelsLabel = node()
    m.followBar = node()
    m.recentsBar = node()
    m.channelPage = node()
    m.getStreams = node()
    m.getCategories = node()
    m.currentlySelectedButton = 1
    m.currentlyFocusedButton = 1
    m.actualBrowseButtons = [node(), node(), node(), node(), node(), node()]
    m.browseMain = node()
    m.top.appendChild(m.browseMain)
    for each child in [m.browseButtons, m.browseList, m.browseCategoryList, m.browseFollowingList, m.browseOfflineFollowingList]
        m.browseMain.appendChild(child)
    end for
    for each child in [m.followBar, m.recentsBar, m.channelPage, m.offlineChannelList]
        m.top.appendChild(child)
    end for
    m.categoryButton = m.actualBrowseButtons[0]
    m.liveButton = m.actualBrowseButtons[1]
    m.followingButton = m.actualBrowseButtons[2]
    m.searchLabel = m.actualBrowseButtons[3]
    m.optionsButton = m.actualBrowseButtons[4]
    m.loggedUserName = m.actualBrowseButtons[5]
    m.categoryLine = node()
    m.liveLine = node()
    m.followingLine = node()
    m.appLaunchComplete = false
    m.append = false
    m.appendCategory = false
end sub

sub main()
    setup()
    focusContent()
    check(m.browseButtons.hasFocus(), "Parent focus routes to usable header on empty home")
    check(onKeyEvent("down", true), "Down on empty grid is handled")
    check(not m.browseList.hasFocus(), "Empty grid cannot take focus from header")
    check(not m.top.hasFocus() and m.top.isInFocusChain(), "Only the leaf owns focus; Home remains its ancestor")
    check(onKeyEvent("right", true) and m.currentlyFocusedButton = 2, "Right moves to Following")
    check(onKeyEvent("right", true) and m.currentlyFocusedButton = 3, "Right moves to Search")
    check(onKeyEvent("right", true) and m.currentlyFocusedButton = 4, "Right moves to Options")
    check(onKeyEvent("right", true) and m.currentlyFocusedButton = 5, "Right moves to Login")
    check(onKeyEvent("OK", true) and m.top.buttonPressed = "login", "Login is reachable before content loads")
    onHomeLoad()
    check(m.getStreams.control = "", "No content task before authentication")
    check(m.top.retryAuthentication, "Live selection requests authentication retry")
    m.top.apiReady = true
    onApiReady()
    check(m.getStreams.control = "RUN", "Authentication starts content task")
    m.getStreams.searchResults = [{title: "A", display_name: "A", game: "G", thumbnail: "x", name: "a", viewers: 1}]
    onSearchResultChange()
    check(m.browseList.content.getChildCount() = 1, "Single result renders a partial row")
    check(m.browseList.content.children[0].getChildCount() = 1, "Partial row contains no duplicated item")
    check(not m.loadStatus.visible and m.appLaunchComplete, "Success clears loading and completes launch")
    check(onKeyEvent("down", true), "Down enters populated grid")
    check(m.browseList.hasFocus() and not m.browseButtons.hasFocus(), "Header gives up focus to grid")
    check(onKeyEvent("up", true), "Up at grid boundary returns to header")
    check(m.browseButtons.hasFocus() and not m.browseList.hasFocus(), "Grid gives up focus to header")
    m.top.setFocus(true)
    focusContent()
    check(m.browseList.hasFocus(), "Returning to populated Home explicitly targets grid")
    m.getStreams.errorMessage = "offline"
    m.append = true
    onSearchResultChange()
    check(m.browseList.content.getChildCount() = 1 and m.browseList.content.children[0].children[0].title = "A", "Failed pagination preserves existing content")
    check(m.loadStatus.visible and not m.append, "Failure exposes retry and resets append")
    m.getStreams.errorMessage = ""
    m.getStreams.searchResults = []
    onSearchResultChange()
    check(not hasRows(m.browseList) and m.loadStatus.visible, "Empty success has visible status")
    m.getStreams.control = ""
    m.getStreams.pagination = ""
    getMoreChannels()
    check(m.getStreams.control = "", "Exhausted pagination makes no request")
    m.getStreams.pagination = "&after=next"
    m.getStreams.state = "run"
    getMoreChannels()
    check(m.getStreams.control = "", "Repeated down cannot start concurrent request")

    setup()
    m.currentlySelectedButton = 0
    m.top.apiReady = true
    onApiReady()
    check(m.getCategories.control = "RUN", "Category chosen during auth loads when ready")
    m.getCategories.searchResults = [{id: "1", name: "Game", logo: "x", viewers: 0}]
    onCategoryResultChange()
    check(m.browseCategoryList.content.getChildCount() = 1, "Category partial row renders without stream results")
    check(not m.loadStatus.visible, "Category success clears loading")
    m.top.startupError = "offline"
    onStartupError()
    check(m.loadStatus.visible and m.appLaunchComplete, "Auth failure shows error and completes launch")
    print "PASS parent focus, empty-grid input, auth gating, retry, partial rows, error recovery, pagination"
end sub
