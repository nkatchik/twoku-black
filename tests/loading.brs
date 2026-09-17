function testCreateObject(kind, name)
    return node()
end function

sub resetLoadingViews()
    m.top = node()
    m.top.visible = true
    m.busy = {active: false, enabled: true}
    m.emptyLabel = node()
    m.playbackStatus = {text: ""}
    m.playbackLoading = false
    m.playbackRequestId = 7
    m.getLivePlayback = {state: "stop", requestId: 7, cancelRequested: false, errorMessage: ""}
    m.liveLine = {visible: true}
    m.clipLine = {visible: false}
    m.categoryLine = {visible: false}
    m.streamsLoading = false
    m.clipsLoading = false
    m.top.currentCategory = "game"
    m.streamsCategory = "game"
    m.clipsCategory = "game"
    m.getStreams = {state: "stop", pagination: "", offset: ""}
    m.getClips = {state: "stop", pagination: ""}
    m.browseList = node()
    m.browseClipsList = node()
    m.searching = false
    m.keyboard = {text: "alpha"}
    m.streamQuery = ""
    m.categoryQuery = ""
    m.getSearch = {state: "stop"}
    m.getCategorySearch = {state: "stop"}
    m.searchResultList = node()
    m.resultCategoryList = node()
end sub

sub main()
    m.top = {active: false, enabled: true, visible: true, size: 64}
    m.spinner = {control: "", poster: {}}
    updateSpinnerSize()
    updateActivity()
    check(m.spinner.poster.uri = "pkg:/images/spinner.png", "Spinner bitmap is assigned through the native Poster interface")
    check(m.spinner.poster.width = 64 and m.spinner.poster.height = 64, "Spinner size configures the native Poster")
    check(not m.top.visible and m.spinner.control = "stop", "An idle spinner is hidden and its native animation is stopped")
    m.top.active = true
    updateActivity()
    check(m.top.visible and m.spinner.control = "start", "Pending work starts the native spinner")
    m.top.enabled = false
    updateActivity()
    check(not m.top.visible and m.spinner.control = "stop" and m.top.active, "Hiding a view stops animation while retaining its pending request")
    m.top.enabled = true
    updateActivity()
    check(m.top.visible and m.spinner.control = "start", "A pending request resumes its spinner when the view returns")
    m.top.active = false
    updateActivity()
    check(not m.top.visible and m.spinner.control = "stop", "Request completion stops native animation")

    resetLoadingViews()
    startCategoryStreams()
    check(m.busy.active and m.getStreams.control = "RUN" and not m.emptyLabel.visible, "Category fetch shows a spinner without empty-state text")
    m.getStreams.state = "stop"
    onStreamsStopped()
    check(not m.busy.active, "A completed category request clears its spinner")
    m.clipLine.visible = true
    m.liveLine.visible = false
    onClipsLoad()
    check(m.busy.active and m.getClips.control = "RUN", "Clips fetch owns its own loading state")
    m.clipLine.visible = false
    m.liveLine.visible = true
    updateCategoryBusy()
    check(not m.busy.active, "An inactive category tab cannot keep the selected tab spinning")
    m.getClips.state = "stop"
    onClipsStopped()
    check(not m.clipsLoading, "Background completion clears the inactive tab state")
    m.browseClipsList.content = node()
    m.browseClipsList.content.appendChild(node())
    m.emptyLabel.visible = true
    m.emptyLabel.text = "No live channels in this category"
    onClipsLoad()
    check(not m.emptyLabel.visible, "Returning to cached clips clears an empty-state label from the Live tab")
    m.playbackLoading = true
    m.top.visible = false
    updateCategoryBusy()
    check(m.busy.active and not m.busy.enabled, "A hidden category cannot animate its pending request")
    m.top.visible = true
    m.getLivePlayback.errorMessage = "This channel is offline"
    onPlaybackStopped()
    check(not m.busy.active and m.playbackStatus.text = "This channel is offline", "A playback request error stops the spinner and retains its explanation")

    resetLoadingViews()
    onSearchTextChange()
    check(m.busy.active and m.streamQuery = "alpha" and m.getSearch.control = "RUN", "Typing a query starts a search spinner")
    m.getSearch.state = "run"
    m.keyboard.text = "beta"
    onSearchTextChange()
    check(m.busy.active and m.streamQuery = "alpha", "Editing an in-flight query retains pending state without restarting its task")
    m.getSearch.state = "stop"
    onSearchStopped()
    check(m.busy.active and m.streamQuery = "beta", "The next query keeps the spinner active when the old request stops")
    onSearchStopped()
    check(not m.busy.active, "The current search completing clears the spinner")
    m.getSearch.state = "run"
    m.liveLine.visible = false
    m.categoryLine.visible = true
    onSearchTextChange()
    check(m.busy.active and m.categoryQuery = "beta", "Switching tabs starts the selected search")
    onChannelSearchResultChange()
    check(m.busy.active and m.resultCategoryList.content = invalid, "An inactive tab result cannot consume the selected tab's unfinished result")
    onCategorySearchResultChange()
    check(not m.busy.active and m.emptyLabel.text = "No results found", "The active tab result ends its own spinner and shows its actual empty state")
    m.keyboard.text = ""
    onSearchTextChange()
    check(not m.busy.active and m.emptyLabel.text = "Enter a channel or game name", "Clearing search leaves an instruction instead of a spinner")
    m.playbackLoading = true
    m.top.visible = false
    updateSearchBusy()
    check(m.busy.active and not m.busy.enabled, "Hiding search disables animation for pending playback")
    print "PASS native spinner lifecycle, category tabs, errors, hidden views, and queued search"
end sub
