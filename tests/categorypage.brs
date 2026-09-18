function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    return result
end function

sub testReloadCategory()
    m.top = node()
    m.top.visible = true
    m.top.currentCategory = "game"
    m.busy = node()
    m.emptyLabel = node()
    m.playbackStatus = node()
    m.getLivePlayback = node()
    m.getClipPlayback = node()
    m.getStreams = node()
    m.getClips = node()
    m.getClips.state = "run"
    m.liveLine = {visible: false}
    m.clipLine = {visible: true}
    m.browseList = node()
    m.browseClipsList = node()
    m.browseClipsList.content = node()
    m.browseButtons = node()
    reloadContent()
    check(m.reloadPending and m.busy.active, "Category reload queues behind an in-flight request")
    insertClips()
    check(m.browseClipsList.content <> invalid, "Stale clips are ignored during refresh")
    m.getClips.state = "stop"
    onClipsStopped()
    check(m.getClips.control = "RUN" and m.getClips.pagination = "" and m.clipLine.visible, "Clip reload fetches page one without switching to live")
    check(m.seenClips.Count() = 0 and m.browseClipsList.content = invalid, "Clip pagination deduplication resets on refresh")
    m.liveLine.visible = true
    m.clipLine.visible = false
    reloadContent()
    check(m.getStreams.control = "RUN" and m.getStreams.gameRequested = "game" and m.getStreams.pagination = "", "Game live grid reload retains its game")
    m.getStreams.state = "run"
    reloadContent()
    m.top.visible = false
    tryReloadContent()
    check(not m.reloadPending, "Leaving the category cancels a queued reload")
end sub

sub main()
    items = []
    for index = 0 to 8
        item = node()
        item.Title = index.ToStr()
        items.push(item)
    end for
    grid = node()
    appendGridItems(grid, items)
    content = grid.content
    check(content.getChildCount() = 3, "Nine streams occupy three four-column rows")
    check(content.getChild(0).getChildCount() = 4 and content.getChild(1).getChildCount() = 4, "Complete rows contain exactly four items")
    check(content.getChild(2).getChildCount() = 1 and content.getChild(2).getChild(0).Title = "8", "Final partial row is appended exactly once")
    empty = node()
    appendGridItems(empty, [])
    check(empty.content.getChildCount() = 0, "Empty response does not create an empty selectable row")
    first = node()
    appendGridItems(empty, [first])
    check(empty.jumpToRowItem[0] = 0 and empty.jumpToRowItem[1] = 0, "First cards arriving into an empty content root initialize the first cursor")
    check(itemCategoryText(["Science"]) = "Science" and itemCategoryText([]) = "", "SG Categories arrays are normalized safely")
    m.top = node()
    m.top.visible = true
    m.browseList = node()
    m.browseClipsList = node()
    m.browseButtons = node()
    m.liveLine = {visible: true}
    m.clipLine = {visible: false}
    focusContent()
    check(m.browseButtons.hasFocus(), "Empty category focuses usable tabs")
    m.top.currentCategory = "game"
    m.streamsCategory = "game"
    m.streamRows = []
    m.seenStreams = {}
    m.newCategory = true
    m.getStreams = {searchResults: [{name: "a", title: "A", display_name: "A", game: "G", thumbnail: "x", viewers: 1}], errorMessage: "", pagination: "", state: "stop"}
    m.emptyLabel = node()
    m.browseList.rowItemFocused = []
    onSearchResultChange()
    check(m.browseList.hasFocus() and m.browseList.jumpToRowItem[0] = 0 and m.browseList.jumpToRowItem[1] = 0, "First game response transfers focus to the first live cell")
    m.browseList.jumpToRowItem = invalid
    m.browseList.rowItemFocused = [1, 2]
    onSearchResultChange()
    check(m.browseList.jumpToRowItem = invalid, "Game pagination does not cancel native scrolling with a focus jump")
    m.browseButtons.setFocus(true)
    m.pendingGridFocus = ""
    onSearchResultChange()
    check(m.browseButtons.hasFocus(), "Game response respects cancelled focus intent")
    m.pendingGridFocus = "live"
    m.top.visible = false
    onSearchResultChange()
    check(m.browseButtons.hasFocus(), "Hidden game result cannot acquire focus")
    m.top.visible = true
    m.browseList.content = content
    focusContent()
    check(m.browseList.hasFocus(), "Loaded category focuses stream cards")
    m.playbackRequestId = 7
    m.getLivePlayback = {requestId: 7, cancelRequested: false, streamUrl: "late-url", streamerRequested: "channel"}
    m.playbackStatus = node()
    cancelPlaybackRequest()
    onStreamUrlChange()
    check(m.getLivePlayback.cancelRequested and m.playbackRequestId = 8 and m.top.streamUrl = invalid, "Cancelled stream lookup cannot publish late playback")
    testClipPreload()
    testReloadCategory()
    testQuietCategoryPlayback()
    print "PASS category grid packing, empty focus, SG metadata, cancelled playback"
end sub

sub testClipPreload()
    m.top.visible = true
    m.top.currentCategory = "game"
    m.clipsCategory = "game"
    m.clipsCursor = ""
    m.seenClips = {}
    m.clipLine.visible = true
    m.liveLine.visible = false
    m.browseClipsList = node()
    m.browseClipsList.numRows = 2
    m.getClips = node()
    m.getClips.pagination = "clips2"
    m.getClips.searchResults = []
    for index = 0 to 23
        m.getClips.searchResults.Push({id:index.ToStr(),thumbnail_url:index.ToStr(),title:"Clip",broadcaster_name:"C",viewer_count:1})
    end for
    insertClips()
    m.browseClipsList.setFocus(true)
    m.browseClipsList.rowItemFocused = [2, 1]
    onGridFocus()
    check(m.clipsLoading and m.getClips.control = "RUN", "Clips preloads before the visible window reaches its last row")
    original = m.browseClipsList.content
    m.getClips.state = "run"
    m.browseClipsList.rowItemFocused = [4, 1]
    m.browseClipsList.jumpToRowItem = invalid
    m.getClips.searchResults = [{id:"new",thumbnail_url:"new",title:"New clip",broadcaster_name:"C",viewer_count:1}]
    m.getClips.pagination = "clips3"
    insertClips()
    check(m.browseClipsList.content.testId = original.testId and original.getChildCount() = 7, "Clip pagination retains existing content nodes")
    check(m.browseClipsList.rowItemFocused[0] = 4 and m.browseClipsList.jumpToRowItem = invalid, "Clip responses cannot restart focus animation")
    m.getClips.errorMessage = "offline"
    m.getClips.state = "stop"
    onClipsStopped()
    check(not m.clipsLoading, "Clip preload errors cannot enter an automatic retry loop")
    m.top.currentCategory = "other"
    m.getClips.searchResults = [{id:"late",thumbnail_url:"late",title:"Late clip",broadcaster_name:"C",viewer_count:1}]
    insertClips()
    check(original.getChild(6).getChildCount() = 1, "A previous game's clip response cannot append to the new game")
end sub

sub testQuietCategoryPlayback()
    m.top.visible = true
    m.playbackRequestId = 0
    m.getLivePlayback = node()
    m.getClipPlayback = node()
    m.playbackStatus = node()
    m.busy = node()
    m.streamsLoading = false
    m.clipsLoading = false
    for each clip in [false, true]
        m.liveLine.visible = not clip
        m.clipLine.visible = clip
        m.browseList.visible = not clip
        m.browseClipsList.visible = clip
        m.browseList.content = node()
        m.browseClipsList.content = node()
        row = node()
        row.appendChild({Title: "Title", Description: "Channel", Categories: [], ShortDescriptionLine1: "channel-or-clip", ShortDescriptionLine2: "1K"})
        m.browseList.content.appendChild(row)
        m.browseClipsList.content.appendChild(row)
        m.browseList.rowItemSelected = [0,0]
        m.browseClipsList.rowItemSelected = [0,0]
        m.playbackStatus.text = "Previous error"
        if clip
            onBrowseClipsItemSelect()
            task = m.getClipPlayback
        else
            onBrowseItemSelect()
            task = m.getLivePlayback
        end if
        check(m.playbackLoading and not m.busy.active and task.control = "RUN", "Game stream and clip requests leave the grid visible without a spinner")
        check(m.playbackStatus.text = "", "A fresh game playback request clears its old error")
        task.state = "stop"
        task.errorMessage = "Unavailable"
        if clip
            onClipPlaybackStopped()
        else
            onPlaybackStopped()
        end if
        check(m.playbackStatus.text = "Unavailable" and not m.playbackLoading and not m.busy.active, "Game playback failures reach the timed error label")
    end for
end sub
