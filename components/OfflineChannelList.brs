sub init()
    m.top.focusable = true
    m.grid = m.top.findNode("grid")
    m.grid.observeField("itemSelected", "onChannelSelected")
end sub

function hasOfflineChannels() as Boolean
    if m.grid.content = invalid then return false
    return m.grid.content.getChildCount() > 0
end function

sub onOfflineChannelsChange()
    content = CreateObject("roSGNode", "ContentNode")
    if m.top.offlineChannels <> invalid
        for each channel in m.top.offlineChannels
            item = CreateObject("roSGNode", "ContentNode")
            item.Title = channel.display_name
            item.ShortDescriptionLine1 = channel.login
            item.HDPosterUrl = channel.profile_image_url
            content.appendChild(item)
        end for
    end if
    m.grid.content = content
    m.grid.jumpToItem = 0
    if m.top.focused then onGetFocus()
end sub

sub focusContent()
    if not m.top.visible then return
    if hasOfflineChannels()
        m.grid.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

sub onGetFocus()
    if m.top.focused then focusContent()
end sub

sub onChannelSelected()
    if not m.top.visible or not hasOfflineChannels() then return
    selected = m.grid.itemSelected
    if selected < 0 or selected >= m.grid.content.getChildCount() then return
    m.top.channelSelected = m.grid.content.getChild(selected).ShortDescriptionLine1
end sub

function onKeyEvent(key, press) as Boolean
    if not press or not m.top.visible then return false
    if not hasOfflineChannels()
        return key = "OK" or key = "down" or key = "right"
    end if
    return false
end function
