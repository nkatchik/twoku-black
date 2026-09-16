sub init()
    m.image = m.top.findNode("image")
    m.itemTitle = m.top.findNode("itemTitle")
    m.itemStatus = m.top.findNode("itemStatus")
    if CreateObject("roDeviceInfo").GetUIResolution().width = 1920
        m.top.findNode("itemIcon").maskSize = [96,96]
    end if
end sub

sub showContent()
    content = m.top.itemContent
    if content = invalid then return
    m.image.uri = content.url
    m.itemTitle.text = content.title
    m.itemStatus.text = "Offline"
    if content.isLive
        m.itemStatus.text = "Live · " + itemCategoryText(content.categories)
    end if
end sub

function itemCategoryText(value) as String
    if type(value) = "roString" or type(value) = "String" then return value
    if type(value) = "roArray"
        if value.count() > 0 then return value[0]
    end if
    return ""
end function
