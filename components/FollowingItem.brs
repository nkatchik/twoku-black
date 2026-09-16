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
    m.liveFocus.visible = m.top.itemHasFocus and m.live.visible
    m.live.itemHasFocus = m.top.itemHasFocus and m.live.visible
    m.offline.itemHasFocus = m.top.itemHasFocus and m.offline.visible
end sub
