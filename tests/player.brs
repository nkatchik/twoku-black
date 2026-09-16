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
    m.compatibility = invalid
    m.compatRequestId = 0
    m.playbackStartTimer = playerNode()
    cancelCompatibility()
    m.top = playerNode()
    m.top.contentKind = "live"
    m.top.chatEnabled = true
    m.top.chatIsVisible = false
    m.top.playbackError = ""
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
    m.seekTimer = playerNode()
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
    resetPlaybackAttempt()
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
    check(m.playingIndex = 2 and m.video.content.url = "https://example/480", "live finished retries inside the player")
    check(m.top.back <> true and m.playbackActive, "live completion never navigates automatically")
    for attempt = 1 to 6
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
    check(m.top.back <> true and m.top.playbackError <> "", "instant native error stays in the player")
    check(m.top.playbackDiagnostics.errorCode = -5 and m.top.playbackDiagnostics.category = "mediaerror", "native diagnostics retain useful numeric/category evidence")
    check(Instr(1, FormatJson(m.top.playbackDiagnostics), "secret") = 0, "native diagnostic output never includes error text or signed URLs")
    showQuality()
    m.qualityIndex = 3
    applyQuality()
    check(m.pendingContent = invalid and m.video.content.url = "https://example/480" and m.video.control = "play", "terminal error can retry even when native stop emits no stopped event")
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
    checkPlaybackProgress()
    checkPlaybackProgress()
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
    testCompatibilityRouting()
    print "PASS player completion guards, compatibility cancellation and fallback, bandwidth, quality, remote input and VOD seek"
end sub


sub prepareCompatibilityPlayer()
    resetPlayer()
    m.compatibility = {state: "init", cancelRequested: true, result: invalid}
    m.video.state = "stopped"
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
    check(m.video.control <> "play" and m.video.content.url = invalid and m.pendingContent <> invalid, "ready observer returns without starting native playback inside the Task rendezvous")
    check(m.playbackStartTimer.control = "start", "ready result schedules a separate render turn")
    checkPlaybackProgress()
    onVideoStateChange()
    onRequestedControl()
    check(m.video.control <> "play" and m.video.content.url = invalid, "watchdog and state/control callbacks cannot bypass the deferred startup boundary")
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
            check(m.pendingContent = invalid and m.statusBox.visible and m.top.playbackError <> "", "manual relay failure retains quality controls and actionable error")
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
    check(m.video.control = "stop" and m.video.content.url = invalid, "late timer event cannot revive the exited stream")

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
    check(m.video.control = "stop" and m.statusBox.visible and m.pendingContent = invalid, "relay stopping before deferred play reports failure without loading a dead local URL")

    resetPlayer()
    m.compatibility = {state: "init", cancelRequested: true}
    m.video.state = "stopped"
    m.top.content = {url: "https://example/clip.mp4", streamFormat: "mp4"}
    onRequestedContent()
    m.top.control = "play"
    onRequestedControl()
    check(m.video.content.url = m.top.content.url and m.compatibility.control = invalid, "MP4 clips bypass HLS preparation")
end sub
