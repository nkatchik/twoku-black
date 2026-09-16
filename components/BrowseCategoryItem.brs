sub init()
    m.itemThumbnail = m.top.findNode("itemThumbnail")
    m.itemTitle = m.top.findNode("itemTitle")
end sub

sub showContent()
    content = m.top.itemContent
    if content = invalid then return
    m.itemThumbnail.uri = content.HDPosterUrl
    m.itemTitle.text = content.Title
end sub
