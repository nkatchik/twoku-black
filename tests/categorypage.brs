function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    return result
end function

sub main()
    items = []
    for index = 0 to 8
        item = node()
        item.Title = index.ToStr()
        items.push(item)
    end for
    content = categoryGrid(items)
    check(content.getChildCount() = 3, "Nine streams occupy three four-column rows")
    check(content.getChild(0).getChildCount() = 4 and content.getChild(1).getChildCount() = 4, "Complete rows contain exactly four items")
    check(content.getChild(2).getChildCount() = 1 and content.getChild(2).getChild(0).Title = "8", "Final partial row is appended exactly once")
    check(categoryGrid([]).getChildCount() = 0, "Empty response does not create an empty selectable row")
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
    m.browseList.content = content
    focusContent()
    check(m.browseList.hasFocus(), "Loaded category focuses stream cards")
    m.playbackRequestId = 7
    m.getStuff = {requestId: 7, cancelRequested: false, streamUrl: "late-url", streamerRequested: "channel"}
    m.playbackStatus = node()
    cancelPlaybackRequest()
    onStreamUrlChange()
    check(m.getStuff.cancelRequested and m.playbackRequestId = 8 and m.top.streamUrl = invalid, "Cancelled stream lookup cannot publish late playback")
    print "PASS category grid packing, empty focus, SG metadata, cancelled playback"
end sub
