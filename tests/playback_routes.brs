function testCreateObject(kind, name)
    return node()
end function

sub setRegistrySection(section, key, value)
    m.saved[key] = value
end sub

sub focusHome()
    m.homeScene.callFunc("focusContent")
end sub

sub requestPlayerInfo()
end sub

function routeNode()
    result = node()
    result.calls = []
    result.callFunc = function(name)
        m.calls.Push(name)
        if name = "focusContent" then m.setFocus(true)
    end function
    return result
end function

sub setupRoutes()
    m.reloadKeyDown = false
    m.loginPage = routeNode()
    m.top = node()
    m.saved = {}
    m.global = {chatOption: false, preferredQuality: "Auto"}
    m.homeScene = routeNode()
    m.keyboardGroup = routeNode()
    m.categoryScene = routeNode()
    m.chat = routeNode()
    m.videoPlayer = routeNode()
    m.videoPlayer.chatIsVisible = false
    m.videoPlayer.channelUsername = "Streamer"
    m.videoPlayer.channelAvatar = "avatar"
    m.videoPlayer.viewerText = "12 viewers"
    m.playerChannel = "streamer"
    m.routingChannel = false
    m.playbackKind = "live"
    m.currentScene = "home"
end sub

sub refreshFollows()
    m.followRefreshes += 1
end sub

sub testReloadRoutes()
    for each target in ["homeScene", "categoryScene", "keyboardGroup", "videoPlayer"]
        setupRoutes()
        m[target].visible = true
        m.chat.visible = target = "videoPlayer"
        check(onKeyEvent("replay", true), "Reload press is consumed")
        check(m[target].calls.Count() = 1 and m[target].calls[0] = "reloadContent", "Reload routes to the visible surface")
        onKeyEvent("replay", true)
        check(m[target].calls.Count() = 1, "Held reload key does not flood requests")
        onKeyEvent("replay", false)
        onKeyEvent("replay", true)
        check(m[target].calls.Count() = 2, "A new reload press works after release")
        if target = "videoPlayer" then check(m.chat.calls.Count() = 2, "Visible chat refreshes along with the player")
    end for
    setupRoutes()
    m.videoPlayer.visible = true
    reloadVisibleContent()
    check(m.chat.calls.Count() = 0 and not m.chat.visible, "Reload does not enable disabled chat")
    m.getUser = node()
    m.getUser.state = "run"
    m.followRefreshes = 0
    reloadFollowing()
    check(m.followingReloadPending and m.followRefreshes = 0, "Following refresh queues behind account work")
    m.getUser.state = "stop"
    onUserStopped()
    check(not m.followingReloadPending and m.followRefreshes = 1, "Following refresh starts once the old account task stops")
end sub

sub main()
    setupRoutes()
    m.homeScene.visible = true
    beginPlayback("https://video/live", {variants: []}, "hls")
    check(m.videoPlayer.visible and m.videoPlayer.hasFocus(), "Player wrapper owns input before playback")
    check(not m.homeScene.visible and not m.chat.visible, "Disabled chat remains hidden when stream opens")
    check(m.videoPlayer.content.live and m.videoPlayer.content.url = "https://video/live", "Live content reaches decoder")
    m.videoPlayer.toggleChat = true
    onToggleChat()
    check(m.chat.visible and m.videoPlayer.chatIsVisible and m.global.chatOption, "Chat button opens rail and synchronizes player")
    check(m.chat.channel = "streamer" and m.saved.ChatOption = "true", "Rail receives current channel and preference persists")
    m.videoPlayer.toggleChat = true
    onToggleChat()
    check(not m.chat.visible and m.saved.ChatOption = "false", "Chat button hides rail and persists disabled state")
    m.videoPlayer.state = "buffering"
    m.videoPlayer.back = true
    onVideoPlayerBack()
    check(not m.videoPlayer.visible and not m.chat.visible, "Back hides video and chat while buffering")
    check(m.homeScene.visible and m.homeScene.hasFocus(), "Back restores browsing without waiting for decoder state")
    check(m.videoPlayer.calls.Peek() = "stopPlayback", "Back cancels player timers and queued switches")
    setupRoutes()
    m.global.chatOption = true
    m.playbackKind = "vod"
    m.currentScene = "category"
    beginPlayback("https://video/vod", invalid, "hls")
    check(not m.chat.visible and not m.videoPlayer.chatEnabled, "VOD never opens live chat")
    m.videoPlayer.toggleChat = true
    onToggleChat()
    check(m.global.chatOption and not m.chat.visible, "VOD controls do not erase saved live-chat preference")
    closePlayback()
    check(m.categoryScene.visible and m.categoryScene.hasFocus(), "Category route regains focus")
    setupRoutes()
    m.currentScene = "search"
    m.videoPlayer.visible = true
    closePlayback()
    check(m.keyboardGroup.visible and m.keyboardGroup.hasFocus(), "Search route regains focus")
    m.videoPlayer.qualityPreference = "480p"
    onQualityPreference()
    check(m.global.preferredQuality = "480p" and m.saved.PreferredQuality = "480p", "Manual quality persists by name across streams")
    setupRoutes()
    m.categoryScene.visible = true
    m.categoryScene.streamerSelectedName = "selected"
    m.categoryScene.streamerSelectedThumbnail = "preview"
    m.homeScene.streamerSelectedName = "previous"
    m.routingChannel = true
    onStreamerSelected()
    check(m.homeScene.streamerSelectedName = "previous", "Recursive Home notification cannot forward a channel again")
    m.routingChannel = false
    onStreamerSelected()
    check(not m.categoryScene.visible and m.homeScene.visible and m.homeScene.streamerSelectedName = "selected", "Channel forwarding hides its origin and opens the requested Home page")
    check(not m.routingChannel, "Channel forwarding releases the recursion guard")
    testReloadRoutes()
    print "PASS playback input ownership, Back during buffering, chat preference, VOD isolation, return routes, quality persistence"
end sub
