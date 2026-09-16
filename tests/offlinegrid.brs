function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    return result
end function

sub main()
    m.top = node()
    m.top.visible = true
    m.grid = node()
    m.top.appendChild(m.grid)
    m.top.offlineChannels = []
    onOfflineChannelsChange()
    check(not hasOfflineChannels(), "An empty following list creates no ghost channel")
    focusContent()
    check(m.top.hasFocus() and not m.grid.hasFocus(), "Empty offline list keeps a usable focus target")
    check(not onKeyEvent("up", true), "Up bubbles to Following tabs when empty")
    m.top.offlineChannels = [{display_name: "A", login: "a", profile_image_url: "avatar-a"}, {display_name: "B", login: "b", profile_image_url: "avatar-b"}]
    onOfflineChannelsChange()
    focusContent()
    check(m.grid.hasFocus() and m.top.isInFocusChain(), "Wrapper routes focus to its actual grid")
    check(m.grid.content.getChildCount() = 2, "Offline grid preserves every follow")
    m.grid.itemSelected = 1
    onChannelSelected()
    check(m.top.channelSelected = "b", "OK selects the focused channel login")
    m.grid.itemSelected = 5
    onChannelSelected()
    check(m.top.channelSelected = "b", "Stale invalid selection is ignored")
    print "PASS offline grid focus, empty navigation, full content, guarded selection"
end sub
