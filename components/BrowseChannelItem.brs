sub init()
    m.itemThumbnail = m.top.findNode("itemThumbnail")
    m.itemTitle = m.top.findNode("itemTitle")
    m.itemStreamer = m.top.findNode("itemStreamer")
    m.itemCategory = m.top.findNode("itemCategory")
    m.itemViewers = m.top.findNode("itemViewers")
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
    m.itemTitle.text = content.Title
    m.itemStreamer.text = content.Description
    m.itemCategory.text = itemCategoryText(content.Categories)
    m.itemViewers.text = content.ShortDescriptionLine2.Replace(" viewers", "").Trim()
end sub

function itemCategoryText(value) as String
    if type(value) = "roString" or type(value) = "String" then return value
    if type(value) = "roArray"
        if value.count() > 0 then return value[0]
    end if
    return ""
end function
