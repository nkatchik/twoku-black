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
    m.global = {preferredQuality: "Auto"}
    m.chatOpen = false
    m.playbackFromProfile = false
    m.homeScene = routeNode()
    m.homeScene.channelPageVisible = false
    m.keyboardGroup = routeNode()
    m.categoryScene = routeNode()
    m.chat = routeNode()
    m.videoPlayer = routeNode()
    m.videoPlayer.streamEnded = false
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
        if target = "videoPlayer" then check(m.chat.calls.Count() = 0 and m.chat.visible, "Player reload preserves visible chat without reconnecting")
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
    check(m.chat.visible and m.videoPlayer.chatIsVisible and m.chatOpen, "Chat button opens rail and synchronizes player")
    check(m.chat.channel = "streamer" and m.saved.ChatOption = invalid, "Rail receives current channel without persisting chat visibility")
    m.videoPlayer.toggleChat = true
    onToggleChat()
    check(not m.chat.visible and not m.chatOpen, "Chat button hides rail for the current session")
    m.videoPlayer.state = "buffering"
    m.videoPlayer.back = true
    onVideoPlayerBack()
    check(not m.videoPlayer.visible and not m.chat.visible, "Back hides video and chat while buffering")
    check(m.homeScene.visible and m.homeScene.hasFocus(), "Back restores browsing without waiting for decoder state")
    check(m.videoPlayer.calls.Peek() = "stopPlayback", "Back cancels player timers and queued switches")
    setupRoutes()
    m.chatOpen = true
    m.playbackKind = "vod"
    m.currentScene = "category"
    beginPlayback("https://video/vod", invalid, "hls")
    check(not m.chat.visible and not m.videoPlayer.chatEnabled, "VOD never opens live chat")
    m.videoPlayer.toggleChat = true
    onToggleChat()
    check(not m.chatOpen and not m.chat.visible, "Every playback session starts with chat closed, including VOD")
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
    testEndAndReturnRoutes()
    print "PASS playback input ownership, Back during buffering, session chat, ended-stream chat, profile-only refresh, VOD isolation, return routes, quality persistence"
end sub

sub testEndAndReturnRoutes()
    setupRoutes()
    m.homeScene.visible = true
    m.chatOpen = true
    m.chat.visible = true
    beginPlayback("https://video/live", {login: "streamer", variants: []}, "hls")
    check(not m.chatOpen and not m.chat.visible and not m.videoPlayer.chatIsVisible, "Opening another stream always resets chat to closed")
    m.videoPlayer.streamEnded = true
    onPlayerStreamEnded()
    check(m.chatOpen and m.chat.visible and m.videoPlayer.chatIsVisible, "Confirmed stream end opens its chat")
    check(m.chat.streamEnded, "End state reaches the chat header")
    check(m.chat.channel = "streamer" and m.videoPlayer.hasFocus(), "Ended chat uses the same channel while the player keeps remote input")
    reloadVisibleContent()
    check(m.chat.visible and m.chat.calls.Count() = 0, "Refreshing an ended stream leaves chat connected")
    m.videoPlayer.streamEnded = false
    onPlayerStreamEnded()
    check(not m.chat.streamEnded and m.chat.visible and m.chat.calls.Count() = 0, "Successful Refresh restores live header without resetting chat")
    closePlayback()
    check(m.homeScene.calls.Count() = 1 and m.homeScene.calls[0] = "focusContent", "Returning to ordinary home grids preserves content and cursor")
    onPlayerStreamEnded()
    check(not m.chat.visible, "Late end notifications cannot reopen chat outside the player")

    for each kind in ["live", "vod"]
        setupRoutes()
        m.playbackKind = kind
        m.homeScene.visible = true
        m.homeScene.channelPageVisible = true
        beginPlayback("https://video/playback", {variants: []}, "hls")
        check(m.playbackFromProfile, "Live and recorded playback capture their profile origin before hiding it")
        closePlayback()
        check(m.homeScene.calls.Count() = 2 and m.homeScene.calls[0] = "reloadContent" and m.homeScene.calls[1] = "focusContent", "Leaving profile playback refreshes the profile before restoring focus")
        check(not m.playbackFromProfile, "Closing consumes the origin marker")
    end for
    setupRoutes()
    m.homeScene.visible = true
    m.homeScene.channelPageVisible = true
    beginPlayback("https://video/playback", {variants: []}, "hls")
    closePlayback(false)
    check(m.homeScene.calls.Count() = 1, "Opening the player's Channel destination avoids refreshing a profile being replaced")
    setupRoutes()
    m.currentScene = "category"
    m.categoryScene.visible = true
    m.homeScene.channelPageVisible = true
    beginPlayback("https://video/playback", {variants: []}, "hls")
    closePlayback()
    check(m.homeScene.calls.Count() = 0 and m.categoryScene.calls.Count() = 1, "A hidden old profile never causes grid playback to refresh on exit")
end sub
