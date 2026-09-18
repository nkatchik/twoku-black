function testCreateObject(kind, name = invalid)
    if LCase(kind) = "rotimespan"
        return {
            started: 0,
            Mark: sub()
                m.started = getGlobalAA().seekClockMs
            end sub,
            TotalMilliseconds: function()
                return getGlobalAA().seekClockMs - m.started
            end function
        }
    end if
    result = playerNode()
    result.componentName = name
    return result
end function

sub setSeekTime(milliseconds)
    getGlobalAA().seekClockMs = milliseconds
end sub

function playerNode()
    return {
        observeField: sub(field, callback)
        end sub,
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
    m.reloadPending = false
    m.reloadTask = invalid
    m.liveStatusTask = invalid
    m.liveCheckId = 0
    m.liveCheckPending = false
    m.liveCheckClock = invalid
    m.liveCheckLogin = ""
    setSeekTime(0)
    m.compatibility = invalid
    m.compatRequestId = 0
    m.playbackStartTimer = playerNode()
    cancelCompatibility()
    m.top = playerNode()
    m.top.contentKind = "live"
    m.top.chatEnabled = true
    m.top.chatIsVisible = false
    m.top.playbackError = ""
    m.top.streamEnded = false
    m.top.liveStatus = "unknown"
    m.top.videoTitle = "Title"
    m.top.gameName = ""
    m.top.playbackDiagnostics = {}
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
    m.decoderInUse = true
    m.decoderStopPending = false
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
    m.busy = playerNode()
    m.busy.active = false
    m.pauseIndicator = playerNode()
    m.overlayTimer = playerNode()
    m.watchdog = playerNode()
    m.endedStatusTimer = playerNode()
    m.seekTimer = playerNode()
    m.seekRepeatTimer = playerNode()
    m.heldSeekKey = ""
    m.controlIndex = 0
    m.overlayFocus = "buttons"
    m.buttonNodes = []
    m.variants = [
        {name: "1080p60 (source)", url: "https://example/source", width: 1920, height: 1080, frameRate: 60, bandwidth: 6000000},
        {name: "720p", url: "https://example/720", width: 1280, height: 720, frameRate: 30, bandwidth: 3000000},
        {name: "480p", url: "https://example/480", width: 852, height: 480, frameRate: 30, bandwidth: 1500000},
        {name: "360p", url: "https://example/360", width: 640, height: 360, frameRate: 30, bandwidth: 800000}
    ]
    m.capabilities = {maxWidth: 1920, maxHeight: 1080, maxFrameRate: 60, supported: {}}
    for each variant in m.variants
        m.capabilities.supported[variant.url] = true
    end for
    m.preference = "Auto"
    m.manualRetries = 0
    m.qualityIndex = 0
    m.playingIndex = 1
    m.tried = {"1": true}
    m.pendingContent = invalid
    m.startRequested = false
    m.pendingSeek = invalid
    m.seekInFlight = invalid
    m.seekWaitTicks = 0
    m.seekPaused = false
    m.playbackActive = true
    m.switching = false
    m.resumePaused = false
    m.bufferTicks = 0
    m.stalledTicks = 0
    m.lastPosition = 0
    resetPlaybackAttempt()
    m.lastPosition = 0
    refreshControls()
end sub

sub testReloadPlayer()
    for each kind in ["live", "vod", "clip"]
        resetPlayer()
        m.top.contentKind = kind
        m.top.playbackInfo = {login: "channel", videoId: "123", clipId: "clip-slug"}
        m.global.preferredQuality = "720p"
        m.video.state = "paused"
        m.video.position = 125
        m.qualityPanel.visible = true
        check(not onKeyEvent("replay", true) and not onKeyEvent("replay", false), "Player lets both reload edges reach the scene even inside quality controls")
        reloadContent()
        task = m.reloadTask
        expected = "GetLivePlayback"
        if kind = "vod" then expected = "GetVodPlayback"
        if kind = "clip" then expected = "GetClipPlayback"
        check(task.componentName = expected and task.control = "RUN", "Reload requests a fresh URL for the current media kind")
        check(m.busy.active and m.decoderStopPending and not m.qualityPanel.visible, "Reload stops the old decoder and presents a spinner")
        task.state = "run"
        reloadContent()
        check(m.reloadTask.state = "run" and not task.cancelRequested, "Repeated reload does not create overlapping token tasks")
        task.state = "stop"
        task.streamUrl = "https://fresh-url"
        task.playbackInfo = {variants: m.variants, initialIndex: 1}
        onPlaybackReloadStopped()
        check(not m.reloadPending and m.top.content.url = "https://fresh-url" and m.top.control = "play", "Fresh playback replaces the old signed URL")
        check(m.global.preferredQuality = "720p", "Reload preserves the saved manual quality")
        if kind = "live"
            check(m.top.content.live and m.top.content.playStart = invalid, "Live reload returns to the live edge")
        else
            check(m.top.content.playStart = 125 and m.resumePaused, "Recorded media reload preserves position and paused state")
        end if
        if kind = "clip" then check(m.top.content.streamFormat = "mp4", "Clip reload retains its playback format")
        onRequestedContent()
        onRequestedControl()
        check(m.pendingContent <> invalid and m.video.control = "stop", "Reload never overlaps native decoder ownership")
        finishDecoderStop()
        check(m.video.content.url = "https://fresh-url", "Fresh playback starts only after decoder stop acknowledgement")
    end for
    resetPlayer()
    m.top.playbackInfo = {login: "channel"}
    reloadContent()
    m.reloadTask.state = "run"
    stopPlayback()
    m.top.visible = false
    m.reloadTask.state = "stop"
    m.reloadTask.streamUrl = "late-url"
    onPlaybackReloadStopped()
    check(m.reloadTask.cancelRequested and not m.reloadPending and m.pendingContent = invalid, "Back cancels reload and rejects its late result")
    resetPlayer()
    m.top.playbackInfo = {login: "old-channel"}
    reloadContent()
    m.reloadTask.state = "run"
    stopPlayback()
    m.top.playbackInfo = {login: "new-channel"}
    reloadContent()
    check(m.reloadPending and not m.reloadStarted and m.reloadTask.cancelRequested, "A new reload waits for the cancelled token task to finish")
    m.reloadTask.state = "stop"
    onPlaybackReloadStopped()
    check(m.reloadStarted and m.reloadTask.streamerRequested = "new-channel", "Queued reload uses the latest video identity")
    resetPlayer()
    m.top.playbackInfo = {login: "channel"}
    reloadContent()
    m.reloadTask.state = "stop"
    m.reloadTask.streamUrl = ""
    m.reloadTask.errorMessage = "Offline"
    m.reloadTask.playbackInfo = {error: "Offline"}
    onPlaybackReloadStopped()
    check(m.liveCheckPending and m.busy.active, "Failed live reload verifies whether the stream ended")
    m.liveStatusTask.state = "stop"
    m.liveStatusTask.liveStatus = "live"
    onLiveStatusStopped()
    check(m.top.playbackError = "Offline" and not m.busy.active, "Live lookup failure leaves a retryable player error")
    reloadContent()
    check(m.reloadPending and m.reloadTask.control = "RUN", "Reload retries after a failed lookup")
end sub

sub testControlFocus()
    for each kind in ["vod", "clip"]
        resetPlayer()
        m.top.contentKind = kind
        m.video.state = "playing"
        m.video.duration = 600
        showOverlay()
        onKeyEvent("up", true)
        check(m.overlayFocus = "seek" and m.seekFocus.visible, "Recorded playback can focus the seek bar")
        refreshControls()
        check(m.overlayFocus = "seek", "Refreshing a seekable recording preserves its seek focus")

        ' Exercise the reused player, with metadata arriving before visibility.
        m.top.visible = false
        onVisible()
        m.video.state = "stopped"
        onVideoStateChange()
        m.top.contentKind = "live"
        refreshControls()
        m.controlIndex = 1
        m.top.visible = true
        onVisible()
        check(m.top.focused and m.overlay.visible and m.overlayFocus = "buttons" and m.controlIndex = 0, "Entering live playback resets focus to Channel before buffering")
        check(m.buttonNodes[0].color = "0xF4F4F7FF" and not m.seekFocus.visible, "Live entry has a visible button highlight instead of hidden seek focus")
        onKeyEvent("right", true)
        check(m.controlActions[m.controlIndex] = "chat" and m.buttonNodes[1].color = "0xF4F4F7FF", "First Right on live entry immediately moves focus")

        m.playbackActive = true
        m.video.state = "buffering"
        m.video.content = {}
        onContentChange()
        check(m.controlActions[m.controlIndex] = "chat", "Delayed decoder content does not reset a user's button selection")
        onKeyEvent("left", true)
        check(m.controlIndex = 0, "Buttons remain responsive after the decoder content callback")
    end for

    resetPlayer()
    m.overlayFocus = "seek"
    m.controlIndex = 2
    showOverlay()
    check(m.overlayFocus = "buttons" and m.buttonNodes[2].color = "0xF4F4F7FF", "Refreshing live controls repairs hidden seek focus without losing a valid button selection")
end sub

sub main()
    testManualRetries()
    testLiveEnd()
    testStatusPolling()
    testControlFocus()
    resetPlayer()
    m.video.position = invalid
    m.video.duration = invalid
    onChatVisibilityChange()
    check(m.progressFill.width = 0 and convertToReadableTimeFormat(invalid) = "0:00", "native invalid position is safe before first decoded sample")
    stopPlayback()

    resetPlayer()
    m.busy.active = true
    check(onKeyEvent("back", true), "Back consumed while buffering")
    check(m.top.back = true and m.video.control = "stop", "buffering Back exits explicitly and stops decoder")
    check(m.pendingContent = invalid and m.watchdog.control = "stop" and not m.busy.active, "exit cancels pending playback, spinner, and watchdog")

    resetPlayer()
    m.top.content = {url: "https://example/new", streamFormat: "hls", live: true}
    m.video.state = "stopping"
    onRequestedContent()
    m.top.control = "play"
    onRequestedControl()
    check(m.video.content.url = invalid and m.pendingContent.url = "https://example/new", "fast reopen does not replace content before stop")
    m.video.state = "stopped"
    onVideoStateChange()
    check(m.video.content = invalid and m.pendingContent <> invalid, "stop callback releases old content before a deferred restart")
    onDeferredPlaybackStart()
    check(m.video.content.url = "https://example/new" and m.video.control = "play", "reopen starts after old decoder releases")

    resetPlayer()
    m.global.preferredQuality = "missing quality"
    m.top.playbackInfo = {variants: m.variants}
    onPlaybackInfo()
    check(m.preference = "Auto" and m.global.preferredQuality = "missing quality", "unavailable preference uses Auto without forgetting user choice")

    resetPlayer()
    m.global.preferredQuality = "1080p60 (source)"
    m.capabilities.maxWidth = 1280
    m.capabilities.maxHeight = 720
    m.capabilities.maxFrameRate = 30
    m.capabilities.supported = {}
    m.top.playbackInfo = {variants: m.variants, capabilities: m.capabilities, initialIndex: 0}
    onPlaybackInfo()
    check(m.preference = "1080p60 (source)" and m.playingIndex = 0 and m.qualityIndex = 1, "saved manual source and resolver selection survive advisory capability rejection")
    check(m.tried.DoesExist("0"), "manual startup tracks the resolver's selected source")
    m.top.playbackInfo = {variants: m.variants, capabilities: m.capabilities}
    onPlaybackInfo()
    check(m.playingIndex = 0, "saved manual source remains selectable without a resolver index")

    resetPlayer()
    m.capabilities.maxWidth = 1280
    m.capabilities.maxHeight = 720
    m.capabilities.maxFrameRate = 30
    m.capabilities.supported = {}
    showQuality()
    m.qualityIndex = 1
    applyQuality()
    check(m.playingIndex = 0 and not m.qualityPanel.visible and m.playbackActive, "manual source selection bypasses advisory decoder and output limits")
    check(m.preference = "1080p60 (source)" and m.global.preferredQuality = m.preference and m.top.qualityPreference = m.preference, "explicit quality remains the saved manual preference")
    check(m.pendingContent.url = "https://example/source" and m.top.playbackError = "", "manual selection queues the requested source without a false capability error")
    check(Instr(1, m.top.findNode("qualityHint").text, "OK to apply") > 0, "quality picker keeps manual application available")

    resetPlayer()
    m.capabilities.supported = {}
    m.capabilities.maxFrameRate = 30
    m.top.playbackInfo = {variants: m.variants, capabilities: m.capabilities, initialIndex: 2}
    onPlaybackInfo()
    check(m.playingIndex = 2 and m.tried.DoesExist("2"), "Auto tracks the exact variant selected by the resolver despite unconfirmed decoder support")

    resetPlayer()
    m.capabilities.supported = {}
    m.capabilities.maxWidth = 1280
    m.capabilities.maxHeight = 720
    m.capabilities.maxFrameRate = 30
    switchVariant(0)
    check(m.preference = "Auto" and m.playingIndex = 0 and m.pendingContent.url = "https://example/source", "Auto can attempt a rendition despite negative capability hints")
    check(m.top.playbackError = "" and m.playbackActive, "capability hints never block a playback attempt")

    resetPlayer()
    m.capabilities.supported = {}
    showQuality()
    applyQuality()
    check(m.preference = "Auto" and m.playingIndex = 0 and m.top.playbackError = "", "Auto picker remains available when no rendition has confirmed decoder support")

    resetPlayer()
    m.variants = []
    showQuality()
    applyQuality()
    check(m.top.playbackError = "No stream quality is available." and not m.playbackActive, "empty quality list reports unavailable content rather than unsupported hardware")
    m.top.control = "play"
    onRequestedControl()
    check(m.video.control <> "play", "a later play command cannot revive a rejected content request")

    resetPlayer()
    m.video.state = "finished"
    onVideoStateChange()
    check(m.top.back <> true and m.playingIndex = 1, "stale startup finished cannot immediately exit or consume fallback")
    checkPlaybackProgress()
    check(m.playingIndex = 1, "first terminal tick gives new playback time to leave the previous state")
    m.video.state = "buffering"
    onVideoStateChange()
    m.video.state = "playing"
    onVideoStateChange()
    check(m.attemptPlayed and m.top.back <> true, "new attempt can start after a stale finished event")
    m.video.state = "finished"
    onVideoStateChange()
    check(m.playingIndex = 2 and m.pendingContent.url = "https://example/480", "live finished queues a retry inside the player")
    check(m.top.back <> true and m.playbackActive, "live completion never navigates automatically")
    for attempt = 1 to 6
        finishDecoderStop()
        m.video.state = "finished"
        checkPlaybackProgress()
    end for
    check(m.top.back <> true and not m.playbackActive and m.statusBox.visible, "repeated instant live finishes end in a finite visible error")
    check(onKeyEvent("options", true) and m.qualityPanel.visible, "quality controls remain usable after instant playback failures")

    resetPlayer()
    m.preference = "720p"
    m.video.state = "error"
    m.video.errorCode = -5
    m.video.errorInfo = {category: "mediaerror", errcode: 17, dbgmsg: "https://secret/?token=secret"}
    onVideoStateChange()
    checkPlaybackProgress()
    checkPlaybackProgress()
    check(m.top.back <> true and m.top.playbackError = "" and m.manualRetries = 1 and m.pendingContent.url = "https://example/720", "instant native error retries the selected quality inside the player")
    check(m.top.playbackDiagnostics.errorCode = -5 and m.top.playbackDiagnostics.category = "mediaerror", "native diagnostics retain useful numeric/category evidence")
    check(Instr(1, FormatJson(m.top.playbackDiagnostics), "secret") = 0, "native diagnostic output never includes error text or signed URLs")
    showQuality()
    m.qualityIndex = 3
    applyQuality()
    check(m.pendingContent.url = "https://example/480" and m.video.control = "stop", "terminal error cannot reuse the decoder before stop completes")
    finishDecoderStop()
    check(m.pendingContent = invalid and m.video.content.url = "https://example/480" and m.video.control = "play", "terminal error retries after the native stopped event")
    onVideoStateChange()
    check(m.playbackActive and m.top.playbackError = "", "old error state has a startup grace after retry")

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 120
    m.video.state = "playing"
    onVideoStateChange()
    m.video.state = "finished"
    onVideoStateChange()
    check(m.top.back <> true and m.playbackActive, "premature recorded completion recovers rather than returning to the grid")

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 599
    m.video.state = "playing"
    onVideoStateChange()
    m.video.position = invalid
    m.video.duration = invalid
    m.video.state = "finished"
    onVideoStateChange()
    check(m.top.back = true and not m.playbackActive, "natural VOD completion still exits when native terminal fields reset")

    resetPlayer()
    m.top.contentKind = "clip"
    m.video.duration = 12
    m.video.position = 12
    m.video.state = "playing"
    onVideoStateChange()
    m.video.state = "finished"
    onVideoStateChange()
    check(m.top.back = true, "natural clip completion still exits")

    resetPlayer()
    m.video.state = "playing"
    m.video.downloadedSegment = {Status: 0, SegSequence: 1, SegStart: 0, SegType: 0, SegSize: 750000, DownloadDuration: 3000, SegDuration: "2000", Height: 720}
    onDownloadedSegment()
    onDownloadedSegment()
    check(m.downloadSamples.Count() = 1 and m.playingIndex = 1, "one slow segment and duplicate notifications do not reduce quality")
    m.video.downloadedSegment.SegSequence = 2
    m.video.downloadedSegment.Status = -1
    onDownloadedSegment()
    m.video.downloadedSegment.Status = 0
    m.video.downloadedSegment.SegType = 1
    onDownloadedSegment()
    check(m.downloadSamples.Count() = 1, "failed and audio-only downloads are not video throughput samples")
    m.video.downloadedSegment.SegType = 2
    onDownloadedSegment()
    m.video.downloadedSegment.SegSequence = 3
    onDownloadedSegment()
    check(m.playingIndex = 2 and m.pendingContent.url = "https://example/480", "sustained measured throughput selects the highest fitting bitrate")
    check(m.top.playbackDiagnostics.reason = "download-throughput" and m.top.playbackDiagnostics.measuredBps = 2000000, "bandwidth decisions report measured bits per second")
    check(m.capabilities.supported["https://example/source"] and m.global.preferredQuality = "Auto", "network recovery does not mutate hardware support or user preference")

    resetPlayer()
    m.video.state = "playing"
    for sequence = 1 to 3
        downloadMs = 1000
        if sequence = 1 then downloadMs = 3000
        m.video.downloadedSegment = {Status: 0, SegSequence: sequence, SegStart: sequence * 2, SegType: 0, SegSize: 750000, DownloadDuration: downloadMs, SegDuration: 2000, Height: 720}
        onDownloadedSegment()
    end for
    check(m.playingIndex = 1, "a temporary slow segment does not downgrade when following downloads catch up")
    m.preference = "720p"
    for sequence = 4 to 6
        m.video.downloadedSegment = {Status: 0, SegSequence: sequence, SegStart: sequence * 2, SegType: 0, SegSize: 750000, DownloadDuration: 3000, SegDuration: 2000, Height: 720}
        onDownloadedSegment()
    end for
    check(m.playingIndex = 1, "manual quality is preserved during slow downloads")
    stopPlayback()
    onContentChange()
    m.video.state = "finished"
    onVideoStateChange()
    onDownloadedSegment()
    check(not m.playbackActive and m.top.back <> true and not m.busy.active, "late native callbacks cannot revive or navigate an exited player")
    m.top.visible = false
    m.top.content = {url: "https://example/late"}
    onRequestedContent()
    m.top.control = "play"
    onRequestedControl()
    check(m.pendingContent = invalid and m.video.control = "stop", "hidden content and control notifications cannot restart playback")

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
    onDeferredPlaybackStart()
    check(m.video.content.url = "https://example/480" and m.video.control = "play", "stopped event commits pending quality")
    check(m.preference = "Auto", "automatic recovery preserves preference")
    m.video.state = "playing"
    m.stalledTicks = 19
    m.lastPosition = 0
    checkPlaybackProgress()
    check(m.playingIndex = 3, "nonadvancing playing state also falls back")
    m.video.state = "stopped"
    onVideoStateChange()
    onDeferredPlaybackStart()
    m.video.state = "error"
    onVideoStateChange()
    checkPlaybackProgress()
    checkPlaybackProgress()
    check(not m.playbackActive and m.top.playbackError <> "", "exhausted fallback displays finite error")

    resetPlayer()
    m.preference = "1080p60 (source)"
    m.playingIndex = 0
    recoverPlayback()
    check(m.playingIndex = 0 and m.top.playbackError = "" and m.manualRetries = 1, "manual quality retries before changing")
    showQuality()
    m.qualityIndex = 3
    applyQuality()
    check(m.global.preferredQuality = "480p" and m.top.qualityPreference = "480p", "explicit quality emits persisted preference")
    check(m.playingIndex = 2 and m.manualRetries = 0, "quality picker applies selected variant with a fresh retry budget")

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 120
    m.video.state = "paused"
    switchVariant(2)
    check(m.pendingContent.playStart = 120 and m.resumePaused, "quality change preserves VOD position and pause state")
    check(not canSeek(), "pending quality content disables seeking while old duration remains")
    seekBy(10)
    commitSeek()
    check(m.video.seek = invalid and m.pendingSeek = invalid, "fast-forward during a pending quality switch never writes native seek")
    stopPlayback()
    m.video.state = "stopped"
    onVideoStateChange()
    check(m.pendingContent = invalid and m.video.control = "stop", "late native stop cannot restart exited player")

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 120
    seekBy(10)
    m.video.state = "stopping"
    check(not canSeek(), "native stopping disables seeking even without pending content")
    commitSeek()
    check(m.video.seek = invalid and m.pendingSeek = invalid and m.seekTimer.control = "stop", "delayed seek timer cannot issue seek after async stop begins")

    for each terminalState in ["error", "finished"]
        resetPlayer()
        m.top.contentKind = "vod"
        m.video.duration = 600
        m.video.position = 120
        m.video.state = "playing"
        onVideoStateChange()
        m.video.position = invalid
        m.video.state = terminalState
        onVideoStateChange()
        check(m.pendingContent.playStart = 120, "terminal recorded fallback queues the last valid position before shutdown")
        finishDecoderStop()
        check(m.video.content.playStart = 120 and m.completedPosition = 120, "terminal recorded fallback retains the last valid position")
        checkPlaybackProgress()
        checkPlaybackProgress()
        check(m.video.content.playStart = 120, "a second startup failure retains the pending resume position")
    end for

    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 120
    onVideoPositionChange()
    check(m.progress.visible, "VOD progress appears when native duration becomes available")
    seekBy(10)
    seekBy(10)
    check(m.pendingSeek = 140, "successive seeks accumulate before one commit")
    commitSeek()
    check(m.video.seek = 140 and m.pendingSeek = invalid, "seek commits once")
    check(m.seekInFlight = 140, "Committed target remains the source of truth until decoder acknowledgment")
    m.video.position = 121
    onVideoPositionChange()
    check(m.top.findNode("positionLabel").text = "2:20", "Old native progress does not move the seek preview backwards")
    onKeyEvent("right", true)
    check(m.pendingSeek = 150 and m.seekRepeatTimer.duration = 0.5, "A new hold after an early commit continues from the requested target")
    onKeyEvent("right", true)
    check(m.pendingSeek = 150, "Duplicate key-down edges do not double-count timer repeats")
    onSeekRepeat()
    check(m.pendingSeek = 160, "Held input accumulates without repeated key-down events")
    commitSeek()
    check(m.video.seek = 140 and m.pendingSeek = 160, "Repeated input cannot overlap a native seek")
    onKeyEvent("right", false)
    check(m.seekTimer.duration = 0.12, "Release promptly commits the accumulated seek")
    m.video.state = "paused"
    m.video.position = 140
    m.seekPaused = true
    onVideoPositionChange()
    check(m.seekInFlight = invalid and m.pendingSeek = 160, "Position acknowledgment preserves the queued hold target")
    commitSeek()
    check(m.seekPaused and m.video.autoplayAfterSeek, "Paused seek completes native buffering before restoring pause")
    check(m.video.seek = 160 and m.pendingSeek = invalid, "Accumulated seek submits after the previous seek completes")
    m.video.state = "playing"
    onVideoStateChange()
    m.video.position = 160
    onVideoPositionChange()
    check(m.video.control = "pause" and m.seekPaused, "Pause is restored after the target position arrives, not an early playing event")
    m.video.control = "resume"
    onVideoStateChange()
    check(m.video.control = "pause", "A late native playing event after seek acknowledgment cannot consume the paused intent")
    m.video.state = "paused"
    onKeyEvent("left", true)
    onSeekRepeat()
    check(m.pendingSeek = 140, "Held backward seek uses the same accumulating path")
    onKeyEvent("left", false)
    m.video.duration = 0
    commitSeek()
    seekBy(10)
    check(m.pendingSeek = invalid, "zero-duration/live transport cannot divide or seek")
    check(convertToReadableTimeFormat(3661) = "1:01:01", "time formatting")

    resetPlayer()
    m.overlay.visible = true
    check(onKeyEvent("OK", true), "OK handled by player rather than chat input")
    check(m.top.channelRequested = true, "Channel control emits navigation event")
    showQuality()
    check(onKeyEvent("back", true) and not m.qualityPanel.visible, "Back closes quality picker first")
    resetPlayer()
    onContentChange()
    check(m.busy.active and not m.statusBox.visible and m.statusText.text = "", "Initial buffering shows only a spinner")
    m.video.state = "playing"
    onVideoStateChange()
    check(not m.busy.active, "First playback stops the spinner")
    m.video.state = "buffering"
    onVideoStateChange()
    check(m.busy.active and not m.statusBox.visible, "Rebuffering shows a spinner without a text box")
    showPlaybackError("Decoder failed")
    check(not m.busy.active and m.statusBox.visible and m.statusText.text = "Decoder failed", "Errors replace the spinner with actionable text")
    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 600
    m.video.position = 100
    m.video.state = "playing"
    onKeyEvent("right", true)
    for count = 1 to 4
        onSeekRepeat()
        commitSeek()
    end for
    check(m.pendingSeek = 150 and m.video.seek = invalid, "A two-edge hold advances the preview without overlapping native seeks")
    onKeyEvent("right", false)
    check(m.heldSeekKey = "" and m.seekRepeatTimer.control = "stop", "Release stops synthetic repeats")
    commitSeek()
    check(m.video.seek = 150 and m.seekInFlight = 150, "Release commits the final held target once")
    onSeekRepeat()
    check(m.pendingSeek = invalid, "A queued timer fire after release cannot add another seek step")
    m.video.position = 150
    onVideoPositionChange()
    onKeyEvent("right", true)
    onSeekRepeat()
    onKeyEvent("left", true)
    onKeyEvent("right", false)
    check(m.heldSeekKey = "left", "Late release from the old direction cannot stop the new hold")
    onSeekRepeat()
    check(m.pendingSeek = 150, "A direction reversal accumulates from the preview rather than stale native time")
    onKeyEvent("back", true)
    onSeekRepeat()
    check(m.heldSeekKey = "" and m.seekRepeatTimer.control = "stop", "Back cancels held seeking before navigating away")

    testSeekAcceleration()
    testCompatibilityRouting()
    testDecoderLifecycle()
    testReloadPlayer()
    print "PASS player completion guards, compatibility cancellation and fallback, bandwidth, quality, remote input and VOD seek"
end sub

sub testSeekAcceleration()
    resetPlayer()
    m.top.contentKind = "vod"
    m.video.duration = 36000
    m.video.position = 100
    m.video.state = "playing"
    onKeyEvent("right", true)
    check(m.pendingSeek = 110, "An initial press remains a precise ten-second step")
    times = [500, 1499, 1500, 2999, 3000, 4999, 5000, 8000]
    steps = [10, 10, 30, 30, 60, 60, 120, 120]
    for index = 0 to times.Count() - 1
        before = m.pendingSeek
        setSeekTime(times[index])
        onKeyEvent("right", true)
        check(m.pendingSeek = before, "IR repeat events do not add steps or restart acceleration")
        onSeekRepeat()
        check(m.pendingSeek = before + steps[index], "Elapsed hold time selects the accelerated step even when callbacks are delayed")
        commitSeek()
        check(m.video.seek = invalid, "Acceleration updates only the preview while the key is held")
    end for
    before = m.pendingSeek
    onKeyEvent("left", true)
    check(m.pendingSeek = before - 10, "Reversing an accelerated hold starts with a precise ten-second step")
    onKeyEvent("right", false)
    setSeekTime(8500)
    onSeekRepeat()
    check(m.pendingSeek = before - 20 and m.heldSeekKey = "left", "Reversal resets the ramp and ignores the old direction's late release")
    setSeekTime(11000)
    onSeekRepeat()
    check(m.pendingSeek = before - 80, "Rewind uses the same acceleration curve")
    target = m.pendingSeek
    onKeyEvent("left", false)
    commitSeek()
    check(m.video.seek = target and m.seekInFlight = target and m.seekHoldClock = invalid, "Release submits the final target once and clears hold timing")
    onSeekRepeat()
    check(m.pendingSeek = invalid, "A late timer event after release cannot advance the target")
    onKeyEvent("fastforward", true)
    setSeekTime(11500)
    onSeekRepeat()
    check(m.pendingSeek = target + 20, "A new hold and the fast-forward key start at the slow rate")
    stopSeekHold()
    m.seekInFlight = invalid
    m.pendingSeek = invalid
    m.video.position = 35990
    onKeyEvent("right", true)
    setSeekTime(20000)
    onSeekRepeat()
    check(m.pendingSeek = 36000, "Accelerated forward seeking clamps at the recording's duration")
    stopSeekHold()
    m.pendingSeek = invalid
    m.video.position = 5
    onKeyEvent("rewind", true)
    setSeekTime(26000)
    onSeekRepeat()
    check(m.pendingSeek = 0, "Accelerated rewind clamps at the beginning")
end sub

sub finishDecoderStop()
    if not m.decoderStopPending then return
    m.video.state = "stopped"
    onVideoStateChange()
    onDeferredPlaybackStart()
end sub


sub prepareCompatibilityPlayer()
    resetPlayer()
    m.compatibility = {state: "init", cancelRequested: true, result: invalid}
    m.video.state = "stopped"
    m.decoderInUse = false
    content = playerNode()
    content.url = "https://example/new.m3u8"
    content.streamFormat = "hls"
    content.live = true
    content.playStart = 120
    content.clone = function(deep)
        copied = {}
        copied.Append(m)
        return copied
    end function
    m.top.content = content
    onRequestedContent()
    m.top.control = "play"
    onRequestedControl()
end sub

sub testCompatibilityRouting()
    prepareCompatibilityPlayer()
    check(m.compatPreparing and m.compatibility.control = "RUN" and m.video.control <> "play", "HLS preparation starts asynchronously before the decoder")
    check(m.compatibility.sourceUrl = m.pendingContent.url and m.busy.active, "preparation receives original leaf URL and shows a spinner")
    requestId = m.compatRequestId
    m.compatibility.state = "run"
    m.compatibility.result = {requestId: requestId - 1, mode: "split", url: "http://127.0.0.1/old", error: ""}
    onCompatibilityResult()
    check(m.pendingContent <> invalid and m.video.control <> "play", "stale preparation result cannot start a newer request")
    m.top.contentKind = "vod"
    m.compatibility.result = {requestId: requestId, mode: "split", url: "http://127.0.0.1/new", error: ""}
    onCompatibilityResult()
    check(m.video.control <> "play" and m.video.content = invalid and m.pendingContent <> invalid, "ready observer returns without starting native playback inside the Task rendezvous")
    check(m.playbackStartTimer.control = "start", "ready result schedules a separate render turn")
    checkPlaybackProgress()
    onVideoStateChange()
    onRequestedControl()
    check(m.video.control <> "play" and m.video.content = invalid, "watchdog and state/control callbacks cannot bypass the deferred startup boundary")
    onDeferredPlaybackStart()
    check(m.video.content.url = "http://127.0.0.1/new" and m.video.content.playStart = 120 and m.completedPosition = 120, "split route retains recorded resume position")
    check(m.top.content.url = "https://example/new.m3u8" and m.compatMode = "split", "split route leaves original source content untouched")
    m.video.state = "playing"
    m.video.downloadedSegment = {Status: 0, SegType: 2, SegSequence: 1, SegStart: 0, SegSize: 100, DownloadDuration: 5000, SegDuration: "2000", Height: 720}
    onDownloadedSegment()
    check(m.downloadSamples.Count() = 0, "local relay transfers never count as Internet throughput samples")
    m.busy.active = true
    check(onKeyEvent("back", true), "Back is handled while split playback is busy")
    check(m.compatibility.cancelRequested and m.video.control = "stop" and m.top.back, "Back cancels the relay and exits without waiting for Task cleanup")
    onCompatibilityResult()
    check(m.video.control = "stop", "late split result cannot restart an exited player")

    prepareCompatibilityPlayer()
    m.compatibility.state = "run"
    m.compatibility.result = {requestId: m.compatRequestId, mode: "manifest", url: "http://127.0.0.1/master.m3u8", error: ""}
    onCompatibilityResult()
    check(m.video.control <> "play", "Manifest-only startup also leaves the Task rendezvous before native playback")
    onDeferredPlaybackStart()
    check(m.compatMode = "manifest" and m.video.content.url = "http://127.0.0.1/master.m3u8", "Selected quality starts with full HLS metadata")
    m.video.state = "playing"
    m.video.downloadedSegment = {Status: 0, SegType: 0, SegSequence: 1, SegStart: 0, SegSize: 100, DownloadDuration: 5000, SegDuration: "2000", Height: 720}
    onDownloadedSegment()
    check(m.downloadSamples.Count() = 1, "Manifest-only delivery retains genuine CDN bandwidth measurements")
    stopPlayback()
    check(m.compatibility.cancelRequested and m.video.control = "stop", "Back releases both the manifest listener and decoder")

    prepareCompatibilityPlayer()
    m.compatibility.result = {requestId: m.compatRequestId, mode: "direct", url: m.pendingContent.url, error: "unsupported-layout"}
    onCompatibilityResult()
    check(m.video.control <> "play", "direct fallback also returns from the publishing Task before native startup")
    onDeferredPlaybackStart()
    check(m.video.content.url = m.top.content.url and m.video.control = "play" and m.compatMode = "direct", "unsupported preparation retains direct playback without rejecting quality")

    prepareCompatibilityPlayer()
    m.compatibility.state = "run"
    oldId = m.compatRequestId
    switchVariant(2)
    check(m.compatibility.cancelRequested and not m.compatPreparing and m.pendingContent.url = m.variants[2].url, "quality switch cancels old preparation and waits for its cleanup")
    m.compatibility.result = {requestId: oldId, mode: "split", url: "http://127.0.0.1/old", error: ""}
    onCompatibilityResult()
    check(m.video.control <> "play", "late old quality preparation cannot start playback")
    m.compatibility.state = "stop"
    onCompatibilityState()
    check(not m.compatPreparing and m.playbackStartTimer.control = "start", "Task stop observer defers the next preparation to a separate turn")
    onDeferredPlaybackStart()
    check(m.compatPreparing and not m.compatibility.cancelRequested and m.compatibility.sourceUrl = m.variants[2].url, "Task stop dispatches the latest quality exactly once")
    newId = m.compatRequestId
    onCompatibilityState()
    check(m.compatRequestId = newId, "repeated state notifications do not restart an in-flight request")

    prepareCompatibilityPlayer()
    m.compatibility.state = "run"
    oldId = m.compatRequestId
    for tick = 1 to 15
        checkPlaybackProgress()
    end for
    check(m.compatibility.cancelRequested and m.video.control = "play" and m.video.content.url = m.top.content.url, "preparation timeout cancels relay and attempts the original quality")
    check(m.compatRequestId <> oldId and m.compatMode = "direct", "timeout invalidates any delayed localhost result")

    prepareCompatibilityPlayer()
    m.compatibility.state = "stop"
    onCompatibilityState()
    check(m.compatPreparing and m.video.control <> "play", "Task stopping without a result does not repeatedly relaunch preparation")
    for tick = 1 to 15
        checkPlaybackProgress()
    end for
    check(m.video.content.url = m.top.content.url and m.video.control = "play", "missing Task result reaches bounded direct fallback")

    for each preference in ["Auto", "720p"]
        prepareCompatibilityPlayer()
        m.preference = preference
        m.compatibility.state = "run"
        m.compatibility.result = {requestId: m.compatRequestId, mode: "split", url: "http://127.0.0.1/new", error: ""}
        onCompatibilityResult()
        onDeferredPlaybackStart()
        m.video.state = "playing"
        m.compatibility.result = {requestId: m.compatRequestId, mode: "split", url: "", error: "relay failed"}
        onCompatibilityResult()
        check(m.compatibility.cancelRequested and m.video.control = "stop", "active relay failure stops both relay and native decoder")
        if preference = "Auto"
            check(m.playingIndex = 2 and m.pendingContent.url = m.variants[2].url, "active relay failure uses finite Auto recovery")
        else
            check(m.pendingContent.url = m.variants[1].url and m.manualRetries = 1 and m.top.playbackError = "", "manual relay failure retries the same quality through decoder shutdown")
        end if
    end for

    prepareCompatibilityPlayer()
    m.compatibility.state = "run"
    m.compatibility.result = {requestId: m.compatRequestId, mode: "split", url: "http://127.0.0.1/new", error: ""}
    onCompatibilityResult()
    check(m.playbackStartTimer.control = "start", "ready split start is pending")
    stopPlayback()
    check(m.playbackStartTimer.control = "stop" and m.deferredRequestId = invalid, "Back cancels the deferred start before any native URL is assigned")
    onDeferredPlaybackStart()
    check(m.video.control <> "play" and m.video.content = invalid, "late timer event cannot revive the exited stream")

    prepareCompatibilityPlayer()
    m.compatibility.state = "run"
    m.compatibility.result = {requestId: m.compatRequestId, mode: "split", url: "http://127.0.0.1/old", error: ""}
    onCompatibilityResult()
    switchVariant(2)
    onDeferredPlaybackStart()
    check(m.video.control <> "play" and m.pendingContent.url = m.variants[2].url, "quality change invalidates a ready-but-deferred old localhost URL")

    prepareCompatibilityPlayer()
    m.preference = "720p"
    m.compatibility.result = {requestId: m.compatRequestId, mode: "split", url: "http://127.0.0.1/dead", error: ""}
    onCompatibilityResult()
    m.compatibility.state = "stop"
    onCompatibilityState()
    onDeferredPlaybackStart()
    check(m.video.control <> "play" and m.pendingContent.url = m.variants[1].url and m.manualRetries = 1, "relay stopping before deferred play retries the original quality without loading the dead local URL")

    resetPlayer()
    m.compatibility = {state: "init", cancelRequested: true}
    m.video.state = "stopped"
    m.decoderInUse = false
    m.top.content = {url: "https://example/clip.mp4", streamFormat: "mp4"}
    onRequestedContent()
    m.top.control = "play"
    onRequestedControl()
    check(m.video.content.url = m.top.content.url and m.compatibility.control = invalid, "MP4 clips bypass HLS preparation")
end sub

sub testDecoderLifecycle()
    resetPlayer()
    m.video.state = "playing"
    stopPlayback()
    check(m.decoderStopPending and m.video.control = "stop", "first close requests asynchronous decoder shutdown")
    m.video.control = "observed-stop"
    stopPlayback()
    m.top.visible = false
    onVisible()
    stopPlayback()
    check(m.video.control = "observed-stop", "Back, visibility and scene cleanup issue only one native stop even before state changes")
    m.video.state = "stopped"
    onVideoStateChange()
    check(not m.decoderStopPending and not m.decoderInUse and m.video.content = invalid, "hidden player consumes shutdown completion and releases content")
    stopPlayback()
    check(m.video.control = "observed-stop", "closing an already released decoder does not send another stop")

    resetPlayer()
    m.video.state = "stopped"
    m.decoderInUse = false
    for cycle = 1 to 20
        m.top.visible = true
        m.top.content = {url: "https://example/cycle-" + cycle.ToStr(), streamFormat: "mp4"}
        onRequestedContent()
        m.top.control = "play"
        onRequestedControl()
        check(m.decoderInUse and m.video.control = "play", "repeated open claims the decoder before its first buffering event")
        ' The native state is deliberately still stopped from the previous load.
        stopPlayback()
        check(m.decoderStopPending and m.video.control = "stop", "Back before buffering still stops the newly requested native load")
        m.top.visible = false
        m.video.state = "stopping"
        onVideoStateChange()
        check(m.decoderStopPending, "stopping is not a release acknowledgement")
        m.video.state = "stopped"
        onVideoStateChange()
        check(not m.decoderInUse and m.video.content = invalid, "each hidden completion releases the previous load")
    end for

    for each terminal in ["error", "finished"]
        resetPlayer()
        m.video.state = terminal
        switchVariant(2)
        check(m.decoderStopPending and m.pendingContent <> invalid and m.video.control = "stop", "terminal state alone cannot authorize a new decoder")
        m.top.control = "play"
        onRequestedControl()
        startPendingContent()
        check(m.video.control = "stop", "queued play cannot bypass an outstanding stop")
        m.video.state = "stopped"
        onVideoStateChange()
        check(m.pendingContent <> invalid and m.video.content = invalid and m.playbackStartTimer.control = "start", "stopped callback queues playback outside native teardown")
        startPendingContent()
        check(m.video.control = "stop", "a second callback cannot bypass deferred native restart")
        stopPlayback()
        onDeferredPlaybackStart()
        check(m.video.control = "stop" and m.video.content = invalid, "Back between shutdown and restart cancels the queued load")
    end for
end sub

sub completeLiveCheck(status)
    m.liveStatusTask.state = "stop"
    m.liveStatusTask.liveStatus = status
    onLiveStatusStopped()
end sub

sub testLiveEnd()
    for each state in ["finished", "error"]
        resetPlayer()
        m.top.playbackInfo = {login: "Channel"}
        m.video.state = state
        m.attemptStarted = true
        m.attemptPlayed = true
        onVideoStateChange()
        check(m.liveCheckPending and m.liveStatusTask.login = "channel", "Live terminal states check channel status before switching quality")
        check(m.playingIndex = 1 and m.top.playbackError = "", "Status lookup does not prematurely report a variant failure")
        completeLiveCheck("offline")
        check(m.top.streamEnded and not m.playbackActive and m.video.control = "stop", "Confirmed offline stops native playback and enters ended state")
        check(m.statusText.text = "Stream ended" and m.statusBox.visible and m.top.playbackError = "", "Stream end has a short message separate from playback errors")
        check(not m.busy.active and not m.overlay.visible and m.watchdog.control = "stop", "Ending clears spinner, controls and recovery timers")
        for each key in ["play", "OK", "left", "right", "up", "down", "options", "fastforward", "rewind"]
            check(onKeyEvent(key, true), "Ended player consumes playback inputs")
            onKeyEvent(key, false)
        end for
        m.top.control = "play"
        onRequestedControl()
        m.top.control = "pause"
        onRequestedControl()
        check(m.video.control = "stop" and not m.overlay.visible and not m.qualityPanel.visible, "Keys and requested controls cannot restart or pause an ended stream")
        check(not onKeyEvent("replay", true), "Refresh still bubbles to the scene after stream end")
        onKeyEvent("back", true)
        check(m.top.back = true, "Back immediately exits an ended stream")
    end for

    for each status in ["live", "unknown"]
        resetPlayer()
        m.top.playbackInfo = {login: "channel"}
        recoverPlayback("decoder-error")
        completeLiveCheck(status)
        check(not m.top.streamEnded and m.playingIndex = 2, "Online or unknown status preserves automatic quality recovery")
    end for
    resetPlayer()
    m.top.playbackInfo = {login: "channel"}
    m.preference = "720p"
    recoverPlayback("decoder-error")
    completeLiveCheck("live")
    check(not m.top.streamEnded and m.top.playbackError = "" and m.manualRetries = 1 and m.playingIndex = 1, "Online status allows a manual retry without an early error")

    resetPlayer()
    m.top.playbackInfo = {login: "channel"}
    recoverPlayback("playback-stalled")
    task = m.liveStatusTask
    task.state = "run"
    for tick = 1 to 6
        checkPlaybackProgress()
    end for
    check(task.cancelRequested and not m.liveCheckPending and m.playingIndex = 2, "Status timeout falls back without blocking recovery")
    completeLiveCheck("offline")
    check(not m.top.streamEnded, "Late offline response after timeout is ignored")

    for each action in ["back", "refresh", "new-content", "resumed"]
        resetPlayer()
        m.top.playbackInfo = {login: "channel", variants: m.variants}
        recoverPlayback("playback-stalled")
        task = m.liveStatusTask
        task.state = "run"
        if action = "back"
            stopPlayback()
            m.top.visible = false
        else if action = "refresh"
            reloadContent()
        else if action = "new-content"
            onPlaybackInfo()
        else
            m.video.state = "playing"
            onVideoStateChange()
        end if
        completeLiveCheck("offline")
        check(task.cancelRequested and not m.top.streamEnded, "Navigation, Refresh, new playback or recovery cancels stale end detection")
    end for

    resetPlayer()
    m.top.playbackInfo = {login: "channel", variants: m.variants}
    showStreamEnded()
    for each status in ["offline", "unknown"]
        reloadContent()
        check(m.reloadPending and m.top.streamEnded, "Ended stream permits Refresh without clearing its ended marker")
        m.reloadTask.state = "stop"
        m.reloadTask.streamUrl = ""
        m.reloadTask.errorMessage = "Offline"
        onPlaybackReloadStopped()
        completeLiveCheck(status)
        check(m.top.streamEnded and m.statusText.text = "Stream ended", "Offline or unavailable Refresh keeps the graceful end screen")
    end for
    reloadContent()
    m.reloadTask.state = "stop"
    m.reloadTask.streamUrl = "https://fresh-url"
    m.reloadTask.playbackInfo = {login: "channel", variants: m.variants, initialIndex: 1}
    onPlaybackReloadStopped()
    onPlaybackInfo()
    onRequestedContent()
    onRequestedControl()
    check(not m.top.streamEnded and m.startRequested and m.pendingContent <> invalid, "Successful Refresh re-enables playback through the normal decoder handoff")

    resetPlayer()
    m.top.contentKind = "vod"
    m.top.playbackInfo = {login: "channel"}
    m.video.state = "finished"
    m.attemptStarted = true
    m.attemptPlayed = true
    m.video.position = 120
    m.video.duration = 120
    onVideoStateChange()
    check(not m.liveCheckPending and not m.top.streamEnded and m.top.back, "Completed recordings retain normal return behavior without live status requests")
end sub

sub testStatusPolling()
    resetPlayer()
    m.top.playbackInfo = {login: "channel"}
    onMetadataChange()
    check(not m.top.findNode("kindLabel").visible and not m.top.findNode("viewerLabel").visible, "Unknown status never fabricates LIVE or a viewer count")
    applyLiveStatus("live", 1234)
    onMetadataChange()
    check(m.top.findNode("kindBackground").visible and m.top.viewerText = "1.2K", "Confirmed live status displays the badge with fresh viewers")
    showStreamEnded()
    onMetadataChange()
    check(m.endedStatusTimer.control = "start" and not m.top.findNode("kindLabel").visible and m.top.viewerText = "", "Ended state starts polling and clears both live indicators")
    onEndedStatusPoll()
    task = m.liveStatusTask
    task.state = "run"
    requestId = task.requestId
    onEndedStatusPoll()
    check(m.liveStatusTask.requestId = requestId and m.liveCheckPending, "Repeated timer events coalesce into one status request")
    check(not m.busy.active and m.statusBox.visible and m.statusText.text = "Stream ended", "Background status checks do not replace the ended screen with a spinner")
    task.liveStream = {viewer_count: 321}
    completeLiveCheck("live")
    check(m.top.liveStatus = "live" and m.top.viewerText = "321" and m.statusText.text = "Stream is live", "Returning broadcast updates status and invites Refresh")
    check(m.top.streamEnded and not m.playbackActive and m.video.control = "stop" and m.endedStatusTimer.control = "start", "Online polling never restarts playback or stops watching broadcast status")
    check(onKeyEvent("play", true) and m.video.control = "stop", "Returning broadcast still ignores Play until Refresh")
    onEndedStatusPoll()
    completeLiveCheck("unknown")
    check(m.top.liveStatus = "live" and m.statusText.text = "Stream is live", "Unknown status preserves the last confirmed broadcast state")
    onEndedStatusPoll()
    completeLiveCheck("offline")
    check(m.top.liveStatus = "offline" and m.top.viewerText = "" and m.statusText.text = "Stream ended", "A broadcast going offline again clears stale live metadata")
    onEndedStatusPoll()
    m.liveStatusTask.state = "run"
    for tick = 1 to 6
        checkPlaybackProgress()
    end for
    check(m.statusText.text = "Stream ended" and m.endedStatusTimer.control = "start" and not m.liveCheckPending, "Timed-out background checks retain the screen and subsequent poll schedule")
    completeLiveCheck("live")
    check(m.top.liveStatus = "offline", "Late timed-out results cannot restore LIVE")
    stopPlayback()
    m.top.visible = false
    onEndedStatusPoll()
    check(m.endedStatusTimer.control = "stop" and not m.liveCheckPending, "Hidden ended player stops polling")

    resetPlayer()
    m.top.playbackInfo = {login: "channel"}
    check(beginLiveStatusCheck("native-error"), "First failure checks broadcast status")
    completeLiveCheck("live")
    check(not beginLiveStatusCheck("native-error"), "Failing quality ladder reuses its recent status check")
    setSeekTime(15000)
    check(beginLiveStatusCheck("native-error"), "Another status request is allowed after fifteen seconds")
    completeLiveCheck("live")
    m.top.playbackInfo = {login: "another"}
    check(beginLiveStatusCheck("native-error"), "A new channel never inherits the previous channel cooldown")

    for each status in ["live", "offline"]
        resetPlayer()
        m.top.playbackInfo = {login: "channel"}
        showStreamEnded()
        reloadContent()
        m.reloadTask.state = "stop"
        m.reloadTask.streamUrl = ""
        m.reloadTask.errorMessage = "Download failed"
        m.reloadTask.playbackInfo = {liveStatus: status, viewerCount: 900}
        onPlaybackReloadStopped()
        check(m.liveStatusTask = invalid and m.top.liveStatus = status, "Refresh reuses token-response status without a separate lookup")
        if status = "offline"
            check(m.top.streamEnded and m.endedStatusTimer.control = "start", "Offline token response resumes ended polling")
        else
            check(not m.top.streamEnded and m.top.playbackError = "Download failed", "Live token response distinguishes playback failure from stream end")
        end if
    end for
    resetPlayer()
    m.top.contentKind = "vod"
    onMetadataChange()
    check(m.top.findNode("kindLabel").visible and m.top.findNode("kindLabel").text = "VOD", "Recordings retain their badge independent of live status")
    check(not beginLiveStatusCheck("native-error"), "Recordings never issue live status requests")
end sub

sub testManualRetries()
    for each kind in ["live", "vod", "clip"]
        resetPlayer()
        m.top.contentKind = kind
        m.qualityIndex = 3
        applyQuality()
        finishDecoderStop()
        for failure = 1 to 3
            m.video.state = "playing"
            m.video.position = 120
            onVideoStateChange()
            if failure = 1
                m.video.state = "error"
                onVideoStateChange()
            else if failure = 2
                m.video.state = "buffering"
                m.bufferTicks = 14
                checkPlaybackProgress()
            else
                m.lastPosition = 120
                m.stalledTicks = 19
                checkPlaybackProgress()
            end if
            check(m.top.playbackError = "" and m.playbackActive, "Manual failures cannot show an error while retries or Auto candidates remain")
            if failure < 3
                check(m.preference = "480p" and m.playingIndex = 2 and m.manualRetries = failure, "First two failures retry the same explicit quality")
            else
                check(m.preference = "Auto" and m.playingIndex = 0 and m.qualityIndex = 0, "Third failure starts Auto at its best untried quality even above the manual choice")
                check(m.qualityName.text = "Auto" and m.global.preferredQuality = "480p" and m.top.qualityPreference = "480p", "Automatic recovery updates the menu without overwriting the saved preference")
            end if
            if kind <> "live" then check(m.pendingContent.playStart = 120, "Manual retries and Auto handoff retain recording position")
            check(m.video.control = "stop" and m.decoderStopPending, "Every retry waits for native decoder release")
            finishDecoderStop()
            check(m.video.control = "play" and m.pendingContent = invalid, "Retry starts only after decoder stop acknowledgement")
        end for
        ' Auto descends once per remaining quality, skipping the exhausted manual one.
        for each expected in [1,3,-1]
            m.video.state = "buffering"
            onVideoStateChange()
            m.video.state = "error"
            onVideoStateChange()
            if expected >= 0
                check(m.playingIndex = expected and m.top.playbackError = "", "Auto fallback skips the three-times-failed manual variant")
                finishDecoderStop()
            else
                check(not m.playbackActive and m.top.playbackError <> "" and m.pendingContent = invalid, "Failure message appears only after Auto also exhausts its candidates")
            end if
        end for
        m.top.playbackInfo = {variants: m.variants, capabilities: m.capabilities}
        onPlaybackInfo()
        check(m.preference = "480p" and m.manualRetries = 0, "Fresh playback metadata from Refresh or reopening restores saved quality and retries")
    end for

    resetPlayer()
    m.variants = [m.variants[1]]
    m.qualityIndex = 1
    applyQuality()
    finishDecoderStop()
    for failure = 1 to 3
        m.video.state = "buffering"
        onVideoStateChange()
        m.video.state = "error"
        onVideoStateChange()
        if failure < 3
            check(m.top.playbackError = "" and m.playingIndex = 0, "A single-variant stream still gets both manual retries")
            finishDecoderStop()
        else
            check(m.preference = "Auto" and m.top.playbackError <> "" and not m.playbackActive, "No fourth attempt when the only variant has failed three times")
        end if
    end for

    resetPlayer()
    m.preference = "720p"
    m.top.playbackInfo = {login: "channel"}
    recoverPlayback("native-error")
    completeLiveCheck("offline")
    check(m.top.streamEnded and m.manualRetries = 0 and m.pendingContent = invalid, "Confirmed stream end bypasses manual retries")

    resetPlayer()
    m.preference = "720p"
    recoverPlayback("native-error")
    onKeyEvent("back", true)
    finishDecoderStop()
    check(m.top.back and not m.playbackActive and m.pendingContent = invalid and m.video.control <> "play", "Back cancels a queued manual retry before it can restart")
end sub
