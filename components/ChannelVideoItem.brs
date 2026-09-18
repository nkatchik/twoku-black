sub init()
    m.itemThumbnail = m.top.findNode("itemThumbnail")
    m.thumbnailFallback = m.top.findNode("thumbnailFallback")
    m.fallbackAvatar = m.top.findNode("fallbackAvatar")
    m.itemThumbnail.observeField("loadStatus", "onThumbnailState")
    m.itemTitle = m.top.findNode("itemTitle")
    m.itemStreamer = m.top.findNode("itemStreamer")
    m.itemDuration = m.top.findNode("itemDuration")
    m.durationBadge = m.top.findNode("durationBadge")
    m.itemPosted = m.top.findNode("itemPosted")
end sub

sub onItemHasFocus()
    if m.top.itemHasFocus
        m.itemTitle.repeatCount = -1
    else
        m.itemTitle.repeatCount = 0
    end if
end sub

sub showContent()
    content = m.top.itemContent
    if content = invalid then return
    m.itemThumbnail.uri = content.HDPosterUrl
    onThumbnailState()
    m.itemTitle.text = content.Title
    m.itemStreamer.text = content.Description
    m.itemDuration.text = itemCategoryText(content.Categories)
    width = Int(m.itemDuration.localBoundingRect().width + 0.5) + 10
    m.durationBadge.width = width
    m.durationBadge.translation = [280 - width,132]
    m.durationBadge.visible = m.itemDuration.text <> ""
    ' Compensate for the system font's descent to center the visible digits.
    m.itemDuration.translation = [width / 2,13]
    m.itemPosted.text = content.ReleaseDate
end sub

sub onThumbnailState()
    if m.top.itemContent = invalid then return
    ready = m.itemThumbnail.uri <> "" and m.itemThumbnail.loadStatus = "ready"
    m.itemThumbnail.visible = ready
    m.thumbnailFallback.visible = not ready
    if not ready then m.fallbackAvatar.uri = m.top.itemContent.channelAvatar
end sub

function itemCategoryText(value) as String
    if type(value) = "roString" or type(value) = "String" then return value
    if type(value) = "roArray"
        if value.count() > 0 then return value[0]
    end if
    return ""
end function
