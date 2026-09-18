sub main()
    setupGrid(6)
    m.top.rowItemFocused = [0, 2]
    check(onKeyEvent("down", true), "Down is handled before the native hold caches its endpoint")
    check(m.top.animateToItem = 1 and m.top.navigationRow = 1, "The first press requests exactly one row with native animation")
    check(m.repeatTimer.duration = 0.4 and m.repeatTimer.control = "start", "A tap has the normal initial hold delay")
    check(gridNeedsMore(m.top), "The requested row triggers preload before settled focus catches up")
    check(onKeyEvent("down", true) and m.top.navigationRow = 1, "IR repeats do not duplicate movement or reset acceleration")
    check(onKeyEvent("down", false) and m.repeatTimer.control = "stop", "Release stops the timer immediately")
    check(onKeyEvent("down", true) and m.top.navigationRow = 2, "A quick second tap advances from the target, not stale native focus")
    onRowRepeat()
    check(m.top.navigationRow = 3 and m.repeatTimer.duration = 0.12, "Holding repeats without more key-down events")
    onRowRepeat()
    onRowRepeat()
    onRowRepeat()
    check(m.top.navigationRow = 5 and m.heldDown, "Reaching the loaded boundary keeps the hold alive")
    appendGridItems(m.top, cards(24))
    onRowRepeat()
    check(m.top.navigationRow = 6 and m.top.animateToItem = 6, "The same hold crosses the old endpoint as soon as a page arrives")
    check(m.top.jumpToRowItem = invalid, "Appending does not replay a stale focus position")
    onKeyEvent("down", false)
    target = m.top.animateToItem
    appendGridItems(m.top, cards(24))
    onRowRepeat()
    check(m.top.animateToItem = target, "A late page or queued timer cannot move focus after release")

    setupGrid(6)
    onKeyEvent("down", true)
    m.top.setFocus(false)
    onGridFocusChanged()
    check(not m.heldDown and m.top.navigationRow = -1 and m.repeatTimer.control = "stop", "Losing focus cancels the hold and its pending target")
    onRowRepeat()
    check(m.top.animateToItem = 1, "A cancelled timer does not scroll a background grid")
    m.top.setFocus(true)
    onKeyEvent("down", true)
    m.top.visible = false
    onRowRepeat()
    check(not m.heldDown, "Hiding the grid stops repeats even before a focus callback")

    setupGrid(6)
    onKeyEvent("down", true)
    resetRowHold()
    check(not m.heldDown and m.top.navigationRow = -1, "Replacing content clears the previous hold")
    m.top.rowItemFocused = [0, 2]
    check(not onKeyEvent("up", true), "Up remains native, including returning to the page header")
    check(not onKeyEvent("right", true), "Horizontal movement remains native")
    onKeyEvent("down", true)
    check(not onKeyEvent("back", true) and not m.heldDown, "Back cancels repeats and bubbles to the page")
    check(not onKeyEvent("down", false), "A late release after cancellation cannot restart the hold")

    setupGrid(6)
    m.top.rowItemFocused = [0, 2]
    onKeyEvent("down", true)
    m.top.rowItemFocused = [1, 0]
    m.top.scrollingStatus = true
    onRowFocused()
    check(m.top.jumpToRowItem = invalid, "Column correction never cancels a moving row")
    m.top.scrollingStatus = false
    onRowFocused()
    check(m.top.jumpToRowItem[0] = 1 and m.top.jumpToRowItem[1] = 2, "New rows retain the selected column once vertical movement settles")
    m.top.content.getChild(2).children = cards(1)
    onRowRepeat()
    m.top.rowItemFocused = [2, 0]
    m.top.jumpToRowItem = invalid
    onRowFocused()
    check(m.top.jumpToRowItem = invalid and m.navigationColumn = 2, "A short row clamps the column without forgetting the preferred one")
    onRowRepeat()
    m.top.rowItemFocused = [3, 0]
    onRowFocused()
    check(m.top.jumpToRowItem[1] = 2, "A later full row restores the preferred column")
    resetRowHold()
    m.top.jumpToRowItem = invalid
    onRowFocused()
    check(m.top.jumpToRowItem = invalid, "Native navigation after cancellation is not corrected by a stale target")

    setupGrid(1)
    onKeyEvent("down", true)
    for index = 1 to 10
        onRowRepeat()
    end for
    check(m.top.navigationRow = 0 and m.top.animateToItem = invalid, "An exhausted feed stays within bounds without issuing more navigation")
    onKeyEvent("down", false)
    m.top.content = invalid
    check(not onKeyEvent("down", true) and not m.heldDown, "An empty grid cannot start a repeat timer")
    print "PASS held pagination boundaries, delayed pages, quick taps, IR repeats, release and focus cancellation"
end sub

sub setupGrid(rows)
    m.top = node()
    m.top.visible = true
    m.top.navigationRow = -1
    m.top.scrollingStatus = false
    m.top.content = node()
    m.top.content.children = cards(rows)
    for each row in m.top.content.children
        row.children = cards(4)
    end for
    m.top.jumpToRowItem = invalid
    m.top.animateToItem = invalid
    m.top.setFocus(true)
    m.heldDown = false
    m.repeatTimer = {duration:0, control:"stop"}
end sub

function cards(count)
    result = []
    for index = 1 to count
        result.Push(node())
    end for
    return result
end function

function testCreateObject(kind, name)
    return node()
end function
