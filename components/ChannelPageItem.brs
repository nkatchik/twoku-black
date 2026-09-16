sub init()
    m.live = m.top.findNode("live")
    m.recording = m.top.findNode("recording")
    m.liveBadge = m.top.findNode("liveBadge")
end sub

sub showContent()
    item = m.top.itemContent
    if item = invalid then return
    m.live.visible = item.playbackKind = "live"
    m.recording.visible = not m.live.visible
    m.liveBadge.visible = m.live.visible
    if m.live.visible
        m.live.itemContent = item
    else
        m.recording.itemContent = item
    end if
    onItemFocus()
end sub

sub onItemFocus()
    m.live.itemHasFocus = m.top.itemHasFocus and m.live.visible
    m.recording.itemHasFocus = m.top.itemHasFocus and m.recording.visible
end sub
