sub init()
    m.live = m.top.findNode("live")
    m.offline = m.top.findNode("offline")
end sub

sub showContent()
    syncRowFocusSpeed(m.top)
    item = m.top.itemContent
    if item = invalid then return
    m.live.visible = item.followKind = "live"
    m.offline.visible = not m.live.visible
    if m.live.visible
        m.live.itemContent = item
    else
        m.offline.itemContent = item
    end if
    onItemFocus()
end sub

sub onItemFocus()
    if m.live = invalid then return
    m.live.itemHasFocus = m.top.rowListHasFocus and m.top.itemHasFocus and m.live.visible
    m.offline.itemHasFocus = m.top.rowListHasFocus and m.top.itemHasFocus and m.offline.visible
    item = m.top.itemContent
    if item = invalid or m.top.rowFocusPercent <= 0 or m.top.focusPercent <= 0 then return
    row = item.getParent()
    if row = invalid then return
    content = row.getParent()
    if content = invalid then return
    state = content.focusState
    ' Forward row changes and motion boundaries, not competing per-item fades.
    ' Keep observing focusPercent so initial native field ordering cannot leave
    ' a newly focused row unpublished while its first item is still at zero.
    if state[0] = m.top.rowIndex and state[1] = m.top.rowFocusPercent and state[2] = m.top.rowListHasFocus and state[5] = m.top.itemHasFocus
        if not m.top.itemHasFocus or state[3] = m.top.index then return
    end if
    content.focusState = [m.top.rowIndex,m.top.rowFocusPercent,m.top.rowListHasFocus,m.top.index,m.top.focusPercent,m.top.itemHasFocus]
end sub
