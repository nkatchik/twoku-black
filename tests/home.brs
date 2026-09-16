function testCreateObject(kind, name)
    return node()
end function

sub setup()
    m.top = node()
    m.top.visible = true
    m.top.focused = true
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
    m.appLaunchComplete = false
    m.append = false
    m.appendCategory = false
end sub

sub main()
    setup()
    onHomeFocusChanged()
    check(m.browseButtons.focused, "Parent focus routes to usable header on empty home")
    check(onKeyEvent("down", true), "Down on empty grid is handled")
    check(not m.browseList.focused, "Empty grid cannot take focus from header")
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
