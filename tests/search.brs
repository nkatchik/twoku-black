function testCreateObject(kind, name)
    return node()
end function

sub main()
    m.top = node()
    m.top.visible = true
    m.reloadPending = false
    m.searching = false
    m.playbackLoading = false
    m.busy = node()
    m.emptyLabel = node()
    m.playbackStatus = node()
    m.playbackRequestId = 0
    m.getLivePlayback = node()
    m.getSearch = node()
    m.getCategorySearch = node()
    m.keyboard = {text: "example"}
    m.liveLine = {visible: false}
    m.categoryLine = {visible: true}
    m.searchResultList = node()
    m.resultCategoryList = node()
    m.getCategorySearch.state = "run"
    reloadContent()
    check(m.reloadPending and m.busy.active, "Search refresh waits for its existing request")
    onSearchResultChange()
    check(m.resultCategoryList.content = invalid, "Superseded search cannot repopulate the result list")
    m.keyboard.text = "latest"
    m.getCategorySearch.state = "stop"
    onSearchStopped()
    check(m.getCategorySearch.control = "RUN" and m.getCategorySearch.searchText = "latest", "Search refresh uses the current query and game tab")
    check(not m.reloadPending and m.searching, "Fresh search owns the spinner")
    m.liveLine.visible = true
    m.categoryLine.visible = false
    reloadContent()
    check(m.getSearch.control = "RUN" and m.getSearch.searchText = "latest", "Channel search also reloads")
    m.keyboard.text = ""
    reloadContent()
    check(not m.searching and not m.busy.active, "Empty search reload stays usable without an endless spinner")
    print "PASS search reload, in-flight response rejection, latest query and selected tab"
end sub
