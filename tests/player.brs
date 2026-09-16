function testCreateObject(kind, name = invalid)
    return playerNode()
end function

function playerNode()
    return {
        width: 0, height: 0, translation: [0, 0], visible: false, children: [], state: "none", position: 0, duration: 0,
        setFocus: function(value)
            m.focused = value
        end function,
        appendChild: function(child)
            m.children.Push(child)
        end function,
        getChildCount: function()
            return m.children.Count()
        end function,
        removeChildIndex: function(index)
            m.children.Delete(index)
        end function
    }
end function

sub resetPlayer()
    m.top = playerNode()
    m.top.contentKind = "live"
    m.top.chatEnabled = true
    m.top.chatIsVisible = false
    m.top.playbackError = ""
    m.top.visible = true
    m.top.thumbnailInfo = invalid
    m.top.videoBookmarks = {}
    m.top.findNode = function(id)
        if not m.nodes.DoesExist(id) then m.nodes[id] = playerNode()
        return m.nodes[id]
    end function
    m.top.nodes = {}
    m.global = {preferredQuality: "Auto"}
    m.video = playerNode()
    m.video.state = "buffering"
    m.video.content = {}
    m.overlay = playerNode()
    m.qualityPanel = playerNode()
    m.qualityName = playerNode()
    m.controls = playerNode()
    m.progress = playerNode()
    m.progressTrack = playerNode()
    m.progressFill = playerNode()
    m.seekFocus = playerNode()
    m.statusBox = playerNode()
    m.statusText = playerNode()
    m.pauseIndicator = playerNode()
    m.overlayTimer = playerNode()
    m.watchdog = playerNode()
    m.seekTimer = playerNode()
    m.controlIndex = 0
    m.overlayFocus = "buttons"
    m.buttonNodes = []
    m.variants = [
        {name: "1080p60 (source)", url: "https://example/source", height: 1080, frameRate: 60},
        {name: "720p", url: "https://example/720", height: 720, frameRate: 30},
        {name: "480p", url: "https://example/480", height: 480, frameRate: 30},
        {name: "360p", url: "https://example/360", height: 360, frameRate: 30}
    ]
    m.preference = "Auto"
    m.qualityIndex = 0
    m.playingIndex = 1
    m.tried = {"1": true}
    m.pendingContent = invalid
    m.startRequested = false
    m.pendingSeek = invalid
    m.playbackActive = true
    m.switching = false
    m.resumePaused = false
    m.bufferTicks = 0
    m.stalledTicks = 0
    m.lastPosition = 0
    refreshControls()
end sub

sub main()
    resetPlayer()
    m.video.position = invalid
    m.video.duration = invalid
    onChatVisibilityChange()
    check(m.progressFill.width = 0 and convertToReadableTimeFormat(invalid) = "0:00", "native invalid position is safe before first decoded sample")
    stopPlayback()

    resetPlayer()
    m.statusBox.visible = true
    check(onKeyEvent("back", true), "Back consumed while buffering")
    check(m.top.back = true and m.video.control = "stop", "buffering Back exits explicitly and stops decoder")
    check(m.pendingContent = invalid and m.watchdog.control = "stop", "exit cancels pending playback and watchdog")

    resetPlayer()
    m.top.content = {url: "https://example/new", streamFormat: "hls", live: true}
    m.video.state = "stopping"
    onRequestedContent()
    m.top.control = "play"
    onRequestedControl()
    check(m.video.content.url = invalid and m.pendingContent.url = "https://example/new", "fast reopen does not replace content before stop")
    m.video.state = "stopped"
    onVideoStateChange()
    check(m.video.content.url = "https://example/new" and m.video.control = "play", "reopen starts after old decoder releases")

    resetPlayer()
    m.global.preferredQuality = "missing quality"
    m.top.playbackInfo = {variants: m.variants}
    onPlaybackInfo()
    check(m.preference = "Auto" and m.global.preferredQuality = "missing quality", "unavailable preference uses Auto without forgetting user choice")

    resetPlayer()
    m.top.chatEnabled = false
    refreshControls()
    check(m.controlActions.Count() = 2 and m.controlActions[1] = "quality", "disabled chat has no player control")
    m.top.chatIsVisible = false
    onChatVisibilityChange()
    check(m.video.width = 1280 and m.video.height = 720, "closed chat restores full video")
    m.top.chatIsVisible = true
    onChatVisibilityChange()
    check(m.video.width = 920 and m.video.height = 518 and m.video.translation[1] = 101, "chat uses Twellie aspect-preserving video region")

    resetPlayer()
    m.bufferTicks = 14
    checkPlaybackProgress()
    check(m.playingIndex = 2 and m.pendingContent.url = "https://example/480", "buffering deadline selects lower quality")
    check(m.video.control = "stop", "quality change waits for native stopped event")
    check(m.pendingContent.live = true, "quality switch preserves live content metadata")
    m.video.state = "stopped"
    onVideoStateChange()
    check(m.video.content.url = "https://example/480" and m.video.control = "play", "stopped event commits pending quality")
    check(m.preference = "Auto", "automatic recovery preserves preference")
    m.video.state = "playing"
    m.stalledTicks = 19
    m.lastPosition = 0
    checkPlaybackProgress()
    check(m.playingIndex = 3, "nonadvancing playing state also falls back")
    m.video.state = "stopped"
    onVideoStateChange()
    m.video.state = "error"
    onVideoStateChange()
    check(not m.playbackActive and m.top.playbackError <> "", "exhausted fallback displays finite error")

    resetPlayer()
    m.preference = "1080p60 (source)"
    m.playingIndex = 0
    recoverPlayback()
    check(m.playingIndex = 0 and m.top.playbackError <> "", "manual quality does not silently change")
    showQuality()
    m.qualityIndex = 3
    applyQuality()
    check(m.global.preferredQuality = "480p" and m.top.qualityPreference = "480p", "explicit quality emits persisted preference")
    check(m.playingIndex = 2, "quality picker applies selected variant")

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 120
    m.video.state = "paused"
    switchVariant(2)
    check(m.pendingContent.playStart = 120 and m.resumePaused, "quality change preserves VOD position and pause state")
    stopPlayback()
    m.video.state = "stopped"
    onVideoStateChange()
    check(m.pendingContent = invalid and m.video.control = "stop", "late native stop cannot restart exited player")

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 120
    seekBy(10)
    seekBy(10)
    check(m.pendingSeek = 140, "successive seeks accumulate before one commit")
    commitSeek()
    check(m.video.seek = 140 and m.pendingSeek = invalid, "seek commits once")
    m.video.duration = 0
    seekBy(10)
    check(m.pendingSeek = invalid, "zero-duration/live transport cannot divide or seek")
    check(convertToReadableTimeFormat(3661) = "1:01:01", "time formatting")

    resetPlayer()
    m.overlay.visible = true
    check(onKeyEvent("OK", true), "OK handled by player rather than chat input")
    check(m.top.channelRequested = true, "Channel control emits navigation event")
    showQuality()
    check(onKeyEvent("back", true) and not m.qualityPanel.visible, "Back closes quality picker first")
    print "PASS player remote ownership, stop handshake, watchdog, chat layout, quality and VOD seek"
end sub
