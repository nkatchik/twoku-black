sub main()
    m.top = {itemHasFocus:false,rowListHasFocus:true,focusPercent:0.5,rowFocusPercent:1.0}
    m.live = {visible:true}
    m.offline = {visible:false}
    m.liveFocus = {}
    onItemFocus()
    check(m.liveFocus.visible and m.liveFocus.opacity = 0.5, "Horizontal animation retains a visible frame while itemHasFocus is false")
    m.top.focusPercent = 1.0
    m.top.rowFocusPercent = 0.5
    onItemFocus()
    check(m.liveFocus.visible and m.liveFocus.opacity = 0.5, "Vertical animation fades the frame with its row")
    m.live.visible = false
    m.offline.visible = true
    onItemFocus()
    check(not m.liveFocus.visible and m.offline.focusOpacity = 0.5, "Offline circles receive the same animated focus opacity")
    m.top.itemHasFocus = true
    onItemFocus()
    check(m.offline.focusOpacity = 1 and m.offline.itemHasFocus, "Settled focus is fully opaque")
    m.top.rowListHasFocus = false
    onItemFocus()
    check(m.offline.focusOpacity = 0 and not m.offline.itemHasFocus and not m.liveFocus.visible, "Returning focus to the header hides animated feedback")
    print "PASS Following focus feedback during horizontal and vertical animation"
end sub
