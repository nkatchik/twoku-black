sub init()
    m.live = m.top.findNode("live")
    m.offline = m.top.findNode("offline")
    m.liveFocus = m.top.findNode("liveFocus")
end sub

sub showContent()
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
    if m.liveFocus = invalid then return
    opacity = 0.0
    if m.top.rowListHasFocus
        opacity = m.top.focusPercent * m.top.rowFocusPercent
        if m.top.itemHasFocus then opacity = 1.0
    end if
    m.liveFocus.opacity = opacity
    m.liveFocus.visible = opacity > 0 and m.live.visible
    m.live.itemHasFocus = m.top.rowListHasFocus and m.top.itemHasFocus and m.live.visible
    m.offline.itemHasFocus = m.top.rowListHasFocus and m.top.itemHasFocus and m.offline.visible
    m.offline.focusOpacity = opacity
end sub
