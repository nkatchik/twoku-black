sub init()
    m.itemThumbnail = m.top.findNode("itemThumbnail")
    m.itemStreamer = m.top.findNode("itemStreamer")
    m.focusRing = m.top.findNode("focusRing")
end sub

sub onItemHasFocus()
    opacity = m.top.focusOpacity
    if m.top.itemHasFocus then opacity = 1.0
    m.focusRing.opacity = opacity
    m.focusRing.visible = opacity > 0
    if opacity > 0
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
