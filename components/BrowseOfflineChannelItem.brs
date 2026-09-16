sub init()
    m.itemThumbnail = m.top.findNode("itemThumbnail")
    m.itemStreamer = m.top.findNode("itemStreamer")
    m.focusRing = m.top.findNode("focusRing")
end sub

sub onItemHasFocus()
    m.focusRing.visible = m.top.itemHasFocus
    if m.top.itemHasFocus
        m.itemStreamer.color = "0xFFFFFFFF"
    else
        m.itemStreamer.color = "0xDEDEE3FF"
    end if
end sub

sub showContent()
    content = m.top.itemContent
    if content = invalid then return
    m.itemThumbnail.uri = content.HDPosterUrl
    m.itemStreamer.text = content.Title
end sub
