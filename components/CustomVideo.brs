sub init()
    m.reloadPending = false
    m.reloadTask = invalid
    m.liveStatusTask = invalid
    m.liveCheckId = 0
    m.liveCheckPending = false
    m.liveCheckClock = invalid
    m.liveCheckLogin = ""
    m.top.focusable = true
    m.video = m.top.findNode("video")
    if m.video.hasField("asyncStopSemantics") then m.video.asyncStopSemantics = true
    m.decoderInUse = false
    m.decoderStopPending = false
    m.compatibility = m.top.findNode("compatibility")
    m.compatibility.observeField("result", "onCompatibilityResult")
    m.compatibility.observeField("state", "onCompatibilityState")
    m.playbackStartTimer = m.top.findNode("playbackStartTimer")
    m.playbackStartTimer.observeField("fire", "onDeferredPlaybackStart")
    m.compatRequestId = 0
    cancelCompatibility()
    m.overlay = m.top.findNode("overlay")
    m.qualityPanel = m.top.findNode("qualityPanel")
    m.qualityName = m.top.findNode("qualityName")
    m.controls = m.top.findNode("controls")
    m.progress = m.top.findNode("progress")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.seekFocus = m.top.findNode("seekFocus")
    m.statusBox = m.top.findNode("statusBox")
    m.statusText = m.top.findNode("statusText")
    m.busy = m.top.findNode("busy")
    m.busy.enabled = m.top.visible
    m.pauseIndicator = m.top.findNode("pauseIndicator")
    m.overlayTimer = m.top.findNode("overlayTimer")
    m.watchdog = m.top.findNode("watchdog")
    m.endedStatusTimer = m.top.findNode("endedStatusTimer")
    m.endedStatusTimer.observeField("fire", "onEndedStatusPoll")
    m.seekTimer = m.top.findNode("seekTimer")
    m.seekRepeatTimer = m.top.findNode("seekRepeatTimer")
    m.heldSeekKey = ""
    m.video.observeField("state", "onVideoStateChange")
    m.video.observeField("content", "onContentChange")
    m.top.observeField("content", "onRequestedContent")
    m.top.observeField("control", "onRequestedControl")
    m.video.observeField("position", "onVideoPositionChange")
    m.video.observeField("downloadedSegment", "onDownloadedSegment")
    m.top.observeField("visible", "onVisible")
    m.top.observeField("playbackInfo", "onPlaybackInfo")
    m.top.observeField("chatIsVisible", "onChatVisibilityChange")
    m.top.observeField("chatEnabled", "refreshControls")
    for each field in ["channelAvatar", "channelUsername", "videoTitle", "gameName", "viewerText", "contentKind", "liveStatus"]
        m.top.observeField(field, "onMetadataChange")
    end for
    m.overlayTimer.observeField("fire", "hideOverlay")
    m.watchdog.observeField("fire", "checkPlaybackProgress")
    m.seekTimer.observeField("fire", "commitSeek")
    m.seekRepeatTimer.observeField("fire", "onSeekRepeat")
    m.controlIndex = 0
    m.overlayFocus = "buttons"
    m.variants = []
    m.capabilities = invalid
    m.qualityIndex = 0
    m.playingIndex = -1
    m.preference = "Auto"
    m.manualRetries = 0
    m.tried = {}
    m.pendingContent = invalid
    m.startRequested = false
    m.pendingSeek = invalid
    m.seekInFlight = invalid
    m.seekWaitTicks = 0
    m.seekPaused = false
    m.resumePaused = false
    m.switching = false
    m.playbackActive = false
    m.bufferTicks = 0
    m.stalledTicks = 0
    m.lastPosition = -1
    resetPlaybackAttempt()
    m.buttonNodes = []
    onChatVisibilityChange()
    onMetadataChange()
end sub

sub focusContent()
    ' The Group owns remote input even while the native decoder is buffering/stopping.
    m.top.setFocus(true)
end sub

sub onVisible()
    m.busy.enabled = m.top.visible
    if m.top.visible
        m.top.streamEnded = false
        m.controlIndex = 0
        m.overlayFocus = "buttons"
        focusContent()
        showOverlay()
    else
        stopPlayback()
    end if
end sub

sub onMetadataChange()
    m.top.findNode("avatar").uri = m.top.channelAvatar
    m.top.findNode("channelLabel").text = m.top.channelUsername
    title = m.top.videoTitle
    if m.top.gameName <> "" then title = m.top.gameName + " · " + title
    m.top.findNode("titleLabel").text = title
    m.top.findNode("viewerLabel").text = m.top.viewerText
    kind = "LIVE"
    color = "0xE91916FF"
    if m.top.contentKind = "vod"
        kind = "VOD"
        color = "0x68D8E8FF"
    else if m.top.contentKind = "clip"
        kind = "CLIP"
        color = "0xFFCE6AFF"
    end if
    m.top.findNode("kindLabel").text = kind
    m.top.findNode("kindBackground").color = color
    showBadge = m.top.contentKind <> "live" or m.top.liveStatus = "live"
    m.top.findNode("kindLabel").visible = showBadge
    m.top.findNode("kindBackground").visible = showBadge
    m.top.findNode("viewerLabel").visible = showBadge
    refreshControls()
end sub

sub onChatVisibilityChange()
    surfaceWidth = 1280
    if m.top.chatIsVisible
        surfaceWidth = 920
        m.video.width = 920
        m.video.height = 518
        m.video.translation = [0, 101]
    else
        m.video.width = 1280
        m.video.height = 720
        m.video.translation = [0, 0]
    end if
    m.top.findNode("scrim").width = surfaceWidth
    m.top.findNode("channelLabel").width = surfaceWidth - 204
    m.top.findNode("titleLabel").width = surfaceWidth - 204
    m.progressTrack.width = surfaceWidth - 84
    m.seekFocus.width = surfaceWidth - 68
    m.top.findNode("durationLabel").translation = [surfaceWidth - 174, 0]
    m.statusBox.translation = [(surfaceWidth - 480) / 2, 268]
    m.busy.translation = [(surfaceWidth - 64) / 2, 328]
    m.pauseIndicator.translation = [(surfaceWidth - 132) / 2, 268]
    refreshControls()
    onVideoPositionChange()
end sub

sub onPlaybackInfo()
    m.liveCheckClock = invalid
    m.liveCheckLogin = ""
    m.endedStatusTimer.control = "stop"
    cancelLiveStatusCheck()
    m.top.streamEnded = false
    cancelPlaybackReload()
    cancelCompatibility()
    m.variants = []
    m.capabilities = invalid
    info = m.top.playbackInfo
    m.top.liveStatus = "unknown"
    applyPlaybackLiveStatus(info)
    if type(info) = "roAssociativeArray"
        if type(info.variants) = "roArray" then m.variants = info.variants
        if type(info.capabilities) = "roAssociativeArray" then m.capabilities = info.capabilities
    end if
    m.preference = "Auto"
    if GetInterface(m.global.preferredQuality, "ifString") <> invalid then m.preference = m.global.preferredQuality
    m.qualityIndex = 0
    if m.preference <> "Auto"
        for index = 0 to m.variants.Count() - 1
            if m.variants[index].name = m.preference then m.qualityIndex = index + 1
        end for
    end if
    if m.qualityIndex = 0 then m.preference = "Auto"
    m.playingIndex = playbackPreferenceIndex(m.variants, m.preference, m.capabilities)
    if type(info) = "roAssociativeArray" and info.initialIndex <> invalid
        index = info.initialIndex
        if index >= 0 and index < m.variants.Count()
            m.playingIndex = index
        end if
    end if
    m.manualRetries = 0
    m.tried = {}
    if m.playingIndex >= 0 then m.tried[m.playingIndex.ToStr()] = true
    m.qualityPanel.visible = false
    m.pendingContent = invalid
    m.switching = false
    m.resumePaused = false
    m.top.playbackError = ""
    m.top.playbackDiagnostics = {}
    renderQuality()
    refreshControls()
end sub

sub onRequestedContent()
    cancelCompatibility()
    m.pendingContent = m.top.content
    m.startRequested = false
    if not m.top.visible
        m.pendingContent = invalid
        return
    end if
    if m.pendingContent = invalid then return
    if m.variants.Count() > 0 and m.playingIndex < 0
        showPlaybackError("No stream quality is available.")
        return
    end if
    m.playbackActive = true
    m.switching = true
    m.bufferTicks = 0
    requestDecoderStop()
end sub

sub onRequestedControl()
    command = m.top.control
    if m.top.streamEnded and command <> "stop" then return
    if command = "stop"
        stopPlayback()
    else if command = "play"
        if not m.top.visible then return
        if m.pendingContent = invalid and not m.playbackActive then return
        m.startRequested = true
        if m.pendingContent <> invalid
            state = m.video.state
            if playerDecoderIdle(state)
                startPendingContent()
            else
                m.playbackActive = true
                showPlayerBusy()
                m.watchdog.control = "start"
                requestDecoderStop()
            end if
        else
            if not m.decoderStopPending and m.video.state <> "stopping" then m.video.control = "play"
        end if
    else
        if not m.decoderStopPending and m.video.state <> "stopping" then m.video.control = command
    end if
end sub

sub startPendingContent()
    if m.pendingContent = invalid or not m.startRequested or not m.top.visible then return
    if m.deferredRequestId <> invalid then return
    if not playerDecoderIdle(m.video.state) then return
    nextContent = m.pendingContent
    if m.compatibility <> invalid and nextContent.streamFormat = "hls" and not m.compatPrepared
        showPlayerBusy()
        m.watchdog.control = "start"
        if m.compatPreparing then return
        ' Reuse the Task only after its sockets and pending transfers have closed.
        state = m.compatibility.state
        if state <> "stop" and state <> "init" then return
        m.compatRequestId += 1
        m.compatPreparing = true
        m.compatibility.sourceUrl = nextContent.url
        variant = {}
        if m.playingIndex >= 0 and m.playingIndex < m.variants.Count() then variant = m.variants[m.playingIndex]
        m.compatibility.variant = variant
        m.compatibility.requestId = m.compatRequestId
        m.compatibility.cancelRequested = false
        m.compatibility.control = "RUN"
        return
    end if
    if m.compatMode <> "direct"
        nextContent = nextContent.clone(false)
        nextContent.url = m.compatUrl
    end if
    m.playbackStartTimer.control = "stop"
    m.deferredRequestId = invalid
    m.pendingContent = invalid
    resetPlaybackAttempt()
    if m.top.contentKind <> "live" then m.completedPosition = playerSeconds(nextContent.playStart)
    m.playbackActive = true
    if m.compatMode = "split" then recordPlaybackDiagnostic("compatibility-native-start")
    ' Claim the decoder before play: native state can still describe the old load
    ' until buffering arrives, including during a very fast Back/reopen.
    m.decoderInUse = true
    print "Playback decoder start request="; m.compatRequestId
    m.video.content = nextContent
    m.video.control = "play"
    if m.compatMode = "split" then recordPlaybackDiagnostic("compatibility-play-requested")
end sub

sub cancelCompatibility()
    if m.compatRequestId = invalid then m.compatRequestId = 0
    m.compatRequestId += 1
    m.deferredRequestId = invalid
    if m.playbackStartTimer <> invalid then m.playbackStartTimer.control = "stop"
    m.compatPreparing = false
    m.compatPrepared = false
    m.compatTicks = 0
    m.compatMode = "direct"
    m.compatUrl = ""
    if m.compatibility <> invalid then m.compatibility.cancelRequested = true
end sub

sub onCompatibilityResult()
    if m.compatibility = invalid or not m.top.visible or not m.playbackActive then return
    result = m.compatibility.result
    if type(result) <> "roAssociativeArray" then return
    if result.requestId <> m.compatRequestId then return
    if not m.compatPreparing
        if m.compatMode <> "direct" and result.error <> invalid and result.error <> ""
            recoverPlayback("compatibility-failed")
        end if
        return
    end if
    m.compatPreparing = false
    m.compatPrepared = true
    m.compatMode = "direct"
    ' A failed or unsupported preparation always leaves the original URL playable.
    if (result.mode = "split" or result.mode = "manifest") and result.url <> invalid and result.url <> "" and result.error = ""
        m.compatMode = result.mode
        m.compatUrl = result.url
        recordPlaybackDiagnostic("compatibility-" + m.compatMode)
    end if
    deferPendingPlayback()
end sub

sub onCompatibilityState()
    if m.compatibility = invalid or not m.top.visible or not m.playbackActive then return
    if m.compatibility.state <> "stop" then return
    if m.compatMode <> "direct" and not m.compatibility.cancelRequested
        recoverPlayback("compatibility-stopped")
    else if m.pendingContent <> invalid
        deferPendingPlayback()
    end if
end sub

sub deferPendingPlayback()
    if m.pendingContent = invalid or not m.startRequested or not m.top.visible then return
    ' Task field observers run inside its synchronous rendezvous. Return before
    ' Video can request the localhost URL that the publishing Task must serve.
    m.deferredRequestId = m.compatRequestId
    m.playbackStartTimer.control = "start"
end sub

sub onDeferredPlaybackStart()
    m.playbackStartTimer.control = "stop"
    if m.deferredRequestId = invalid or m.deferredRequestId <> m.compatRequestId then return
    m.deferredRequestId = invalid
    startPendingContent()
end sub

sub onContentChange()
    if m.video.content = invalid or not m.top.visible or not m.playbackActive then return
    stopSeekHold()
    m.pendingSeek = invalid
    m.seekInFlight = invalid
    m.seekPaused = m.resumePaused
    m.seekTimer.control = "stop"
    m.top.playbackError = ""
    showPlayerBusy()
    m.watchdog.control = "start"
    focusContent()
    showOverlay()
end sub

sub onVideoStateChange()
    state = m.video.state
    ' Shutdown completion must be consumed even after Back hides this component.
    if m.decoderStopPending and state = "stopped"
        m.decoderStopPending = false
        m.decoderInUse = false
        if m.pendingContent <> invalid then deferPendingPlayback()
        m.video.content = invalid
        print "Playback decoder stopped"
        return
    end if
    if not m.playbackActive or not m.top.visible then return
    if m.decoderStopPending then return
    if m.pendingContent <> invalid
        if playerDecoderIdle(state) then startPendingContent()
        return
    end if
    if state = "finished" or state = "error"
        ' A previous decoder's terminal state can remain briefly after play.
        ' The watchdog handles an attempt that never enters buffering/playing.
        if not m.attemptStarted then return
        handlePlaybackTerminal(state)
    else if state = "playing"
        cancelLiveStatusCheck()
        if m.top.contentKind = "live" then applyLiveStatus("live")
        m.attemptStarted = true
        m.attemptPlayed = true
        m.terminalTicks = 0
        rememberPlaybackPosition()
        m.bufferTicks = 0
        m.statusBox.visible = false
        m.busy.active = false
        if m.resumePaused or (m.seekPaused and m.seekInFlight = invalid)
            m.resumePaused = false
            m.video.control = "none"
            m.video.control = "pause"
        end if
        m.switching = false
        m.pauseIndicator.visible = false
    else if state = "paused"
        m.pauseIndicator.visible = true
        m.statusBox.visible = false
        m.busy.active = false
    else if state = "buffering"
        m.attemptStarted = true
        m.terminalTicks = 0
        showPlayerBusy()
        m.pauseIndicator.visible = false
    end if
end sub

sub checkPlaybackProgress()
    if not m.top.visible then return
    if m.liveCheckPending = true
        m.liveCheckTicks += 1
        if m.liveCheckTicks >= 6
            reason = m.liveCheckReason
            cancelLiveStatusCheck()
            finishLiveStatusCheck("unknown", reason)
        end if
        return
    end if
    if not m.playbackActive then return
    if m.seekInFlight <> invalid
        m.seekWaitTicks += 1
        if m.seekWaitTicks >= 8
            m.seekInFlight = invalid
            commitSeek()
            onVideoPositionChange()
        end if
    end if
    state = m.video.state
    if m.pendingContent <> invalid and playerDecoderIdle(state)
        m.compatTicks += 1
        if m.compatTicks >= 15 and m.compatibility <> invalid and not m.compatPrepared
            ' Even failed Task cleanup cannot hold the UI or block a direct attempt.
            cancelCompatibility()
            m.compatPrepared = true
            recordPlaybackDiagnostic("compatibility-timeout")
        end if
        startPendingContent()
        return
    end if
    if m.pendingContent <> invalid or state = "buffering" or state = "none" or state = "stopping" or state = "stopped"
        m.bufferTicks += 1
        if m.bufferTicks >= 15
            if m.pendingContent <> invalid
                showPlaybackError("The video decoder did not stop. Press Back and reopen the stream.")
            else
                recoverPlayback("buffering-timeout")
            end if
        end if
    else if state = "playing"
        m.attemptStarted = true
        m.attemptPlayed = true
        rememberPlaybackPosition()
        m.bufferTicks = 0
        if Abs(playerSeconds(m.video.position) - m.lastPosition) < 0.1
            m.stalledTicks += 1
            if m.stalledTicks >= 20 then recoverPlayback("progress-timeout")
        else
            m.stalledTicks = 0
            m.lastPosition = playerSeconds(m.video.position)
        end if
    else if state = "paused"
        m.stalledTicks = 0
    else if state = "finished" or state = "error"
        m.terminalTicks += 1
        if m.attemptStarted or m.terminalTicks >= 2 then handlePlaybackTerminal(state)
    end if
end sub

sub resetPlaybackAttempt()
    m.attemptStarted = false
    m.attemptPlayed = false
    m.terminalTicks = 0
    m.bufferTicks = 0
    m.stalledTicks = 0
    m.lastPosition = -1
    m.completedPosition = 0
    m.completedDuration = 0
    m.downloadSamples = []
    m.lastDownloadSequence = invalid
    m.lastDownloadStart = invalid
end sub

function playerDecoderIdle(state as String) as Boolean
    return not m.decoderStopPending and not m.decoderInUse and (state = "none" or state = "stopped")
end function

sub requestDecoderStop()
    ' Back, visibility and scene cleanup can all close the same stream. Never
    ' issue another stop while the first still owns the native media player.
    if m.decoderStopPending then return
    state = m.video.state
    if playerDecoderIdle(state)
        if m.video.content <> invalid then m.video.content = invalid
        return
    end if
    m.decoderStopPending = true
    if state = "stopping" then return
    print "Playback decoder stop state="; state
    m.video.control = "stop"
end sub

sub rememberPlaybackPosition()
    if m.seekInFlight <> invalid or m.pendingSeek <> invalid then return
    position = playerSeconds(m.video.position)
    duration = playerSeconds(m.video.duration)
    if m.video.state = "playing" or m.video.state = "paused"
        m.completedPosition = position
    else if position > m.completedPosition
        m.completedPosition = position
    end if
    if duration > 0 then m.completedDuration = duration
end sub

sub handlePlaybackTerminal(state as String)
    if state = "finished" and m.top.contentKind <> "live" and m.attemptPlayed
        rememberPlaybackPosition()
        if m.completedDuration <= 0 or m.completedPosition >= m.completedDuration - 2
            stopPlayback()
            m.top.back = true
            return
        end if
    end if
    reason = "native-error"
    if state = "finished" then reason = "unexpected-finish"
    recoverPlayback(reason)
end sub

sub recoverPlayback(reason = "playback-failed", statusChecked = false)
    if not m.playbackActive then return
    if not statusChecked
        if beginLiveStatusCheck(reason) then return
    end if
    recordPlaybackDiagnostic(reason)
    nextIndex = -1
    if m.preference <> "Auto"
        if m.manualRetries < 2 and m.playingIndex >= 0 and m.playingIndex < m.variants.Count()
            m.manualRetries += 1
            nextIndex = m.playingIndex
        else
            ' Three failed manual attempts enter Auto for this playback only.
            ' Keep the saved preference, and do not revisit the exhausted quality.
            m.preference = "Auto"
            m.qualityIndex = 0
            renderQuality()
            nextIndex = playbackAutoIndex(m.variants, m.capabilities, m.tried)
        end if
    else
        nextIndex = playbackFallbackIndex(m.variants, m.playingIndex, m.tried, m.capabilities)
    end if
    if nextIndex >= 0
        showPlayerBusy()
        switchVariant(nextIndex)
    else
        message = "Playback failed. Choose a quality or press Back."
        if reason = "unexpected-finish"
            message = "Playback stopped early. Choose a quality or press Back."
            if m.top.contentKind = "live" then message = "Live stream stopped. Choose a quality or press Back."
        else if m.top.playbackDiagnostics.category = "http"
            message = "Stream download failed. Choose a quality or press Back."
        end if
        showPlaybackError(message)
    end if
end sub

function beginLiveStatusCheck(reason as String) as Boolean
    if m.top.contentKind <> "live" or not m.top.visible then return false
    if m.liveCheckPending = true then return true
    info = m.top.playbackInfo
    if type(info) <> "roAssociativeArray" then return false
    if GetInterface(info.login, "ifString") = invalid then return false
    if info.login = "" then return false
    ' Do not overlap a cancelled request that is still leaving its HTTP wait.
    if m.liveStatusTask <> invalid
        if m.liveStatusTask.state = "run" then return false
    end if
    ' A run of failing variants must not issue one status request per quality.
    if reason <> "ended-poll" and reason <> "reload-failed" and m.liveCheckClock <> invalid
        if m.liveCheckLogin = info.login and m.liveCheckClock.TotalMilliseconds() < 15000 then return false
    end if
    m.liveCheckClock = CreateObject("roTimespan")
    m.liveCheckClock.Mark()
    m.liveCheckLogin = info.login
    cancelLiveStatusCheck()
    m.liveStatusTask = CreateObject("roSGNode", "GetLiveStatus")
    m.liveStatusTask.login = LCase(info.login)
    m.liveStatusTask.requestId = m.liveCheckId
    m.liveStatusTask.cancelRequested = false
    m.liveStatusTask.observeField("state", "onLiveStatusStopped")
    m.liveCheckReason = reason
    m.liveCheckTicks = 0
    m.liveCheckPending = true
    if reason <> "ended-poll" then showPlayerBusy()
    m.watchdog.control = "start"
    m.liveStatusTask.control = "RUN"
    return true
end function

sub cancelLiveStatusCheck()
    if m.liveCheckId = invalid then m.liveCheckId = 0
    m.liveCheckId += 1
    m.liveCheckPending = false
    if m.liveStatusTask <> invalid then m.liveStatusTask.cancelRequested = true
end sub

sub onLiveStatusStopped()
    if m.liveCheckPending <> true or not m.top.visible then return
    if m.liveStatusTask.state <> "stop" then return
    if m.liveStatusTask.requestId <> m.liveCheckId or m.liveStatusTask.cancelRequested then return
    reason = m.liveCheckReason
    status = m.liveStatusTask.liveStatus
    m.liveCheckPending = false
    viewers = invalid
    if type(m.liveStatusTask.liveStream) = "roAssociativeArray" then viewers = m.liveStatusTask.liveStream.viewer_count
    finishLiveStatusCheck(status, reason, viewers)
end sub

sub applyLiveStatus(status, viewers = invalid)
    if status <> "live" and status <> "offline" then return
    m.top.liveStatus = status
    if status = "offline"
        if m.top.viewerText <> "" then m.top.viewerText = ""
    else if viewers <> invalid
        count = playerSeconds(viewers)
        label = Int(count).ToStr().Trim()
        if count >= 1000000
            label = (Int(count / 100000) / 10).ToStr().Trim() + "M"
        else if count >= 1000
            label = (Int(count / 100) / 10).ToStr().Trim() + "K"
        end if
        if m.top.viewerText <> label then m.top.viewerText = label
    end if
end sub

sub applyPlaybackLiveStatus(info)
    if m.top.contentKind <> "live" or type(info) <> "roAssociativeArray" then return
    applyLiveStatus(info.liveStatus, info.viewerCount)
end sub

sub onEndedStatusPoll()
    if not m.top.visible or not m.top.streamEnded or m.reloadPending then return
    beginLiveStatusCheck("ended-poll")
end sub

sub finishLiveStatusCheck(status as String, reason as String, viewers = invalid)
    applyLiveStatus(status, viewers)
    if reason = "ended-poll"
        m.watchdog.control = "stop"
        renderEndedStatus()
    else if status = "offline"
        showStreamEnded()
    else if reason = "reload-failed"
        if status = "unknown" and m.top.streamEnded
            showEndedScreen()
        else
            showPlaybackError(m.reloadError)
        end if
    else
        recoverPlayback(reason, true)
    end if
end sub

sub showStreamEnded()
    applyLiveStatus("offline")
    showEndedScreen()
end sub

sub showEndedScreen()
    stopPlayback()
    m.top.playbackError = ""
    ' Notify the scene once; polling and failed Refresh must not reset chat.
    m.top.streamEnded = true
    renderEndedStatus()
    if m.top.visible then m.endedStatusTimer.control = "start"
end sub

sub renderEndedStatus()
    if m.top.liveStatus = "live"
        m.statusText.text = "Stream is live"
        m.top.findNode("statusHint").text = "Refresh to watch"
    else
        m.statusText.text = "Stream ended"
        m.top.findNode("statusHint").text = "Refresh to try again"
    end if
    m.statusBox.visible = true
end sub

sub recordPlaybackDiagnostic(reason as String, measuredBps = 0)
    ' Never copy error strings or entire native AAs: they can contain signed URLs.
    diagnostic = {reason: reason, qualityIndex: m.playingIndex, measuredBps: measuredBps, delivery: m.compatMode}
    if reason = "native-error"
        diagnostic.errorCode = playerSeconds(m.video.errorCode)
        info = m.video.errorInfo
        if type(info) = "roAssociativeArray"
            for each category in ["http", "drm", "mediaerror", "mediaplayer"]
                if info.category = category then diagnostic.category = category
            end for
            diagnostic.detailCode = playerSeconds(info.errcode)
        end if
    end if
    m.top.playbackDiagnostics = diagnostic
    print "Playback "; FormatJson(diagnostic)
end sub

sub onDownloadedSegment()
    ' Loopback throughput measures local delivery, not the upstream connection.
    if m.compatMode = "split" then return
    if m.liveCheckPending = true then return
    if not m.playbackActive or not m.top.visible or m.pendingContent <> invalid then return
    if m.video.state <> "playing" and m.video.state <> "buffering" then return
    if m.playingIndex < 0 or m.playingIndex >= m.variants.Count() then return
    sample = m.video.downloadedSegment
    if type(sample) <> "roAssociativeArray" then return
    if sample.Status <> 0 or (sample.SegType <> 0 and sample.SegType <> 2) then return
    if sample.SegSequence = m.lastDownloadSequence and sample.SegStart = m.lastDownloadStart then return
    height = playerSeconds(sample.Height)
    if height > 0 and height <> m.variants[m.playingIndex].height then return
    bytes = playerSeconds(sample.SegSize)
    downloadMs = playerSeconds(sample.DownloadDuration)
    durationMs = playerSeconds(sample.SegDuration)
    if GetInterface(sample.SegDuration, "ifString") <> invalid then durationMs = Val(sample.SegDuration)
    if bytes <= 0 or downloadMs <= 0 or durationMs <= 0 then return
    m.lastDownloadSequence = sample.SegSequence
    m.lastDownloadStart = sample.SegStart
    m.downloadSamples.Push({bytes: bytes, downloadMs: downloadMs, durationMs: durationMs})
    if m.downloadSamples.Count() > 3 then m.downloadSamples.Shift()
    if m.downloadSamples.Count() < 3 or m.preference <> "Auto" then return
    totalBytes = 0.0
    totalDownload = 0.0
    totalDuration = 0.0
    for each recent in m.downloadSamples
        totalBytes += recent.bytes
        totalDownload += recent.downloadMs
        totalDuration += recent.durationMs
    end for
    ' Three complete video segments taking longer to download than to play
    ' provide throughput evidence. Buffering alone is not a codec diagnosis.
    if totalDownload <= totalDuration then return
    measuredBps = totalBytes * 8000.0 / totalDownload
    nextIndex = playbackBandwidthIndex(m.variants, m.playingIndex, measuredBps, m.tried, m.capabilities)
    if nextIndex >= 0
        recordPlaybackDiagnostic("download-throughput", measuredBps)
        switchVariant(nextIndex)
    end if
end sub

sub showPlaybackError(message as String)
    m.endedStatusTimer.control = "stop"
    cancelLiveStatusCheck()
    m.top.streamEnded = false
    cancelCompatibility()
    m.busy.active = false
    m.pendingContent = invalid
    m.startRequested = false
    m.playbackActive = false
    m.switching = false
    m.watchdog.control = "stop"
    requestDecoderStop()
    m.top.playbackError = message
    m.statusText.text = message
    m.top.findNode("statusHint").text = "Options: quality · Back: return"
    m.statusBox.visible = true
    m.pauseIndicator.visible = false
    showOverlay()
end sub

sub switchVariant(index as Integer)
    if index < 0 or index >= m.variants.Count() then return
    cancelLiveStatusCheck()
    stopSeekHold()
    selected = m.variants[index]
    showPlayerBusy()
    nextContent = CreateObject("roSGNode", "ContentNode")
    nextContent.url = selected.url
    nextContent.streamFormat = "hls"
    if selected.streamFormat <> invalid then nextContent.streamFormat = selected.streamFormat
    nextContent.live = m.top.contentKind = "live"
    if m.top.contentKind <> "live"
        if m.pendingSeek <> invalid
            nextContent.playStart = m.pendingSeek
        else if m.seekInFlight <> invalid
            nextContent.playStart = m.seekInFlight
        else
            nextContent.playStart = playerSeconds(m.video.position)
            if nextContent.playStart <= 0 then nextContent.playStart = playerSeconds(m.completedPosition)
        end if
    end if
    m.startRequested = true
    m.resumePaused = m.video.state = "paused"
    m.seekTimer.control = "stop"
    m.pendingSeek = invalid
    m.seekInFlight = invalid
    m.playingIndex = index
    m.tried[index.ToStr()] = true
    m.bufferTicks = 0
    m.stalledTicks = 0
    m.switching = true
    m.playbackActive = true
    m.top.playbackError = ""
    m.watchdog.control = "start"
    ' A second load cannot start until Roku releases the underlying media player.
    cancelCompatibility()
    m.pendingContent = nextContent
    requestDecoderStop()
    if playerDecoderIdle(m.video.state) then startPendingContent()
    renderQuality()
end sub

sub stopPlayback()
    m.endedStatusTimer.control = "stop"
    cancelLiveStatusCheck()
    cancelPlaybackReload()
    stopSeekHold()
    cancelCompatibility()
    m.startRequested = false
    m.playbackActive = false
    m.pendingContent = invalid
    m.pendingSeek = invalid
    m.seekInFlight = invalid
    m.switching = false
    m.resumePaused = false
    m.watchdog.control = "stop"
    m.overlayTimer.control = "stop"
    m.seekTimer.control = "stop"
    m.qualityPanel.visible = false
    m.statusBox.visible = false
    m.busy.active = false
    m.pauseIndicator.visible = false
    m.overlay.visible = false
    ' Keep the bookmark in memory. Back never waits for a registry flush.
    if m.top.contentKind = "vod" and type(m.top.thumbnailInfo) = "roAssociativeArray"
        id = m.top.thumbnailInfo.video_id
        if id <> invalid and playerSeconds(m.video.position) > 0
            bookmarks = m.top.videoBookmarks
            if type(bookmarks) <> "roAssociativeArray" then bookmarks = {}
            bookmarks[id.ToStr()] = Int(playerSeconds(m.video.position)).ToStr()
            m.top.videoBookmarks = bookmarks
        end if
    end if
    requestDecoderStop()
end sub

sub showOverlay()
    m.overlay.visible = true
    m.overlayTimer.control = "stop"
    if not m.qualityPanel.visible then m.overlayTimer.control = "start"
    refreshControls()
end sub

sub hideOverlay()
    if m.qualityPanel.visible or m.top.playbackError <> ""
        m.overlayTimer.control = "stop"
        return
    end if
    m.overlay.visible = false
    m.overlayTimer.control = "stop"
end sub

function canSeek() as Boolean
    if not m.playbackActive or not m.top.visible or m.pendingContent <> invalid or m.decoderStopPending or m.video.state = "stopping" then return false
    return m.top.contentKind <> "live" and playerSeconds(m.video.duration) > 0
end function

sub refreshControls()
    if m.buttonNodes = invalid then return
    ' A previous recording can leave focus on seek when the next live stream
    ' has no seek bar. Keep the logical focus on a control that is visible.
    seekable = canSeek()
    if m.overlayFocus = "seek" and not seekable then m.overlayFocus = "buttons"
    while m.controls.getChildCount() > 0
        m.controls.removeChildIndex(0)
    end while
    m.buttonNodes = []
    m.controlActions = ["channel"]
    labels = ["Channel"]
    if m.top.contentKind = "live" and m.top.chatEnabled
        m.controlActions.Push("chat")
        labels.Push("Chat")
    end if
    m.controlActions.Push("quality")
    labels.Push("Quality")
    if m.controlIndex >= labels.Count() then m.controlIndex = labels.Count() - 1
    if m.controlIndex < 0 then m.controlIndex = 0
    x = 0
    for index = 0 to labels.Count() - 1
        button = CreateObject("roSGNode", "Rectangle")
        button.translation = [x, 0]
        button.width = 132
        button.height = 40
        label = CreateObject("roSGNode", "SimpleLabel")
        ' Offset the system font's extra descent to center the visible text.
        label.translation = [66, 22]
        label.horizOrigin = "center"
        label.vertOrigin = "center"
        label.text = labels[index]
        label.fontUri = "font:BoldSystemFontFile"
        label.fontSize = 17
        applyButtonFocus(button, button, label, index = m.controlIndex and m.overlayFocus = "buttons")
        button.appendChild(label)
        m.controls.appendChild(button)
        m.buttonNodes.Push(button)
        x += 148
    end for
    m.progress.visible = seekable
    m.seekFocus.visible = m.overlayFocus = "seek" and seekable
end sub

sub renderQuality()
    label = "Auto"
    if m.qualityIndex > 0 and m.qualityIndex <= m.variants.Count() then label = m.variants[m.qualityIndex - 1].name
    m.qualityName.text = label
    m.top.findNode("qualityHint").text = "OK to apply · Back to close"
end sub

sub showQuality()
    for index = 0 to m.controlActions.Count() - 1
        if m.controlActions[index] = "quality" then m.qualityPanel.translation = [42 + index * 148,454]
    end for
    m.qualityIndex = 0
    if m.preference <> "Auto"
        for index = 0 to m.variants.Count() - 1
            if m.variants[index].name = m.preference then m.qualityIndex = index + 1
        end for
    end if
    m.qualityPanel.visible = true
    renderQuality()
    showOverlay()
end sub

sub applyQuality()
    index = playbackAutoIndex(m.variants, m.capabilities)
    preference = "Auto"
    if m.qualityIndex > 0 and m.qualityIndex <= m.variants.Count()
        index = m.qualityIndex - 1
        preference = m.variants[index].name
    end if
    if index < 0
        m.qualityPanel.visible = false
        showPlaybackError("No stream quality is available.")
        return
    end if
    m.preference = preference
    m.global.preferredQuality = m.preference
    m.top.qualityPreference = m.preference
    m.manualRetries = 0
    m.tried = {}
    m.qualityPanel.visible = false
    if index >= 0 then switchVariant(index)
    showOverlay()
end sub

sub startSeekHold(key as String)
    if not canSeek() or key = m.heldSeekKey then return
    stopSeekHold()
    m.heldSeekKey = key
    m.seekHoldClock = CreateObject("roTimespan")
    m.seekHoldClock.Mark()
    seekBy(10 * seekDirection(key))
    m.seekRepeatTimer.duration = 0.5
    m.seekRepeatTimer.control = "start"
end sub

function seekDirection(key as String) as Integer
    if key = "left" or key = "rewind" then return -1
    return 1
end function

function seekHoldStep(elapsedMs as Integer) as Integer
    if elapsedMs >= 5000 then return 120
    if elapsedMs >= 3000 then return 60
    if elapsedMs >= 1500 then return 30
    return 10
end function

sub onSeekRepeat()
    if m.heldSeekKey = "" then return
    if not canSeek() or m.qualityPanel.visible
        stopSeekHold()
        return
    end if
    ' Repeat between down/up edges without relying on extra key-down events.
    ' Advance the preview while held and submit one native seek on release.
    m.seekRepeatTimer.control = "stop"
    ' Use elapsed time so delayed timer events and IR repeats cannot reset the ramp.
    seconds = seekHoldStep(m.seekHoldClock.TotalMilliseconds())
    seekBy(seconds * seekDirection(m.heldSeekKey))
    m.seekRepeatTimer.duration = 0.15
    m.seekRepeatTimer.control = "start"
end sub

sub stopSeekHold()
    m.heldSeekKey = ""
    m.seekHoldClock = invalid
    if m.seekRepeatTimer <> invalid then m.seekRepeatTimer.control = "stop"
end sub

sub scheduleSeekCommit()
    if m.pendingSeek = invalid then return
    m.seekTimer.control = "stop"
    m.seekTimer.duration = 0.12
    m.seekTimer.control = "start"
end sub

sub seekBy(seconds as Integer)
    if not canSeek() then return
    if m.video.state = "paused" then m.seekPaused = true
    position = playerSeconds(m.video.position)
    if m.seekInFlight <> invalid then position = m.seekInFlight
    if m.pendingSeek <> invalid then position = m.pendingSeek
    position += seconds
    if position < 0 then position = 0
    if position > playerSeconds(m.video.duration) then position = playerSeconds(m.video.duration)
    m.pendingSeek = position
    m.overlayFocus = "seek"
    showOverlay()
    m.seekTimer.control = "stop"
    if m.heldSeekKey = ""
        m.seekTimer.duration = 0.65
        m.seekTimer.control = "start"
    end if
    onVideoPositionChange()
end sub

sub commitSeek()
    m.seekTimer.control = "stop"
    if m.heldSeekKey <> "" then return
    if m.pendingSeek = invalid then return
    if not canSeek()
        m.pendingSeek = invalid
        m.seekInFlight = invalid
        m.seekTimer.control = "stop"
        return
    end if
    ' Only one native seek at a time. Further input keeps accumulating separately.
    if m.seekInFlight <> invalid then return
    m.completedPosition = m.pendingSeek
    m.seekInFlight = m.pendingSeek
    m.seekOrigin = playerSeconds(m.video.position)
    m.seekWaitTicks = 0
    m.pendingSeek = invalid
    ' Some TVs stay in buffering with autoplayAfterSeek=false. Let the decoder
    ' reach the target, then restore pause through the position observer.
    m.video.autoplayAfterSeek = true
    print "Playback seek target="; m.seekInFlight; " paused="; m.seekPaused
    m.video.seek = m.seekInFlight
    m.stalledTicks = 0
end sub

sub togglePlayback()
    if not canSeek() then return
    commitSeek()
    if m.seekPaused or m.video.state = "paused"
        m.seekPaused = false
        m.resumePaused = false
        m.video.control = "resume"
    else if m.video.state = "playing"
        m.seekPaused = true
        m.video.control = "none"
        m.video.control = "pause"
    end if
end sub

sub onVideoPositionChange()
    if m.video = invalid then return
    position = playerSeconds(m.video.position)
    if m.seekInFlight <> invalid
        distance = Abs(position - m.seekInFlight)
        ' Roku can land on a nearby keyframe. Ignore updates from the old position.
        landed = distance <= 2
        if Abs(position - m.seekOrigin) > 2 and distance < Abs(m.seekOrigin - m.seekInFlight) and distance <= 8 then landed = true
        if m.video.state <> "playing" and m.video.state <> "paused" then landed = false
        if landed
            m.seekInFlight = invalid
            if m.seekPaused and m.video.state = "playing"
                ' Seek leaves the last control value intact; re-arm pause.
                m.video.control = "none"
                m.video.control = "pause"
            end if
            if m.pendingSeek <> invalid then m.seekTimer.control = "start"
        end if
    end if
    if m.playbackActive and (m.video.state = "playing" or m.video.state = "paused") then rememberPlaybackPosition()
    m.progress.visible = canSeek()
    m.seekFocus.visible = m.overlayFocus = "seek" and canSeek()
    if m.seekInFlight <> invalid then position = m.seekInFlight
    if m.pendingSeek <> invalid then position = m.pendingSeek
    m.top.findNode("positionLabel").text = convertToReadableTimeFormat(position)
    m.top.findNode("durationLabel").text = convertToReadableTimeFormat(playerSeconds(m.video.duration))
    width = 0
    if playerSeconds(m.video.duration) > 0 then width = m.progressTrack.width * position / playerSeconds(m.video.duration)
    if width > m.progressTrack.width then width = m.progressTrack.width
    if width < 0 then width = 0
    m.progressFill.width = width
end sub

function convertToReadableTimeFormat(value) as String
    seconds = Int(playerSeconds(value))
    if seconds < 0 then seconds = 0
    minutes = Int(seconds / 60)
    rest = (seconds MOD 60).ToStr()
    if Len(rest) = 1 then rest = "0" + rest
    if minutes < 60 then return minutes.ToStr() + ":" + rest
    hours = Int(minutes / 60)
    minuteText = (minutes MOD 60).ToStr()
    if Len(minuteText) = 1 then minuteText = "0" + minuteText
    return hours.ToStr() + ":" + minuteText + ":" + rest
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' MainScene routes the circular-arrow button even with controls/quality open.
    if key = "replay" then return false
    if not press
        if key = m.heldSeekKey
            stopSeekHold()
            scheduleSeekCommit()
        else if m.heldSeekKey = "" and (key = "left" or key = "right" or key = "rewind" or key = "fastforward")
            scheduleSeekCommit()
        end if
        return key <> "home"
    end if
    if m.heldSeekKey <> "" and key <> m.heldSeekKey
        stopSeekHold()
        scheduleSeekCommit()
    end if
    if key = "back"
        if m.qualityPanel.visible
            m.qualityPanel.visible = false
            showOverlay()
        else if m.busy.active or m.statusBox.visible or m.top.playbackError <> ""
            stopPlayback()
            m.top.back = true
        else if m.overlay.visible
            hideOverlay()
        else if m.top.chatIsVisible
            m.top.toggleChat = true
        else
            stopPlayback()
            m.top.back = true
        end if
        return true
    end if
    if m.reloadPending = true then return true
    if m.top.streamEnded then return key <> "home"
    if m.qualityPanel.visible
        if key = "up" and m.qualityIndex > 0
            m.qualityIndex -= 1
        else if key = "down" and m.qualityIndex < m.variants.Count()
            m.qualityIndex += 1
        else if key = "OK"
            applyQuality()
        else if key = "left" or key = "right"
            m.qualityPanel.visible = false
            showOverlay()
        end if
        renderQuality()
        return true
    end if
    if key = "options"
        showQuality()
        return true
    end if
    if key = "play"
        togglePlayback()
        return true
    end if
    if key = "rewind" or key = "fastforward"
        startSeekHold(key)
        return true
    end if
    if not m.overlay.visible
        if canSeek() and (key = "left" or key = "right")
            startSeekHold(key)
        else
            m.overlayFocus = "buttons"
            if canSeek() then m.overlayFocus = "seek"
            showOverlay()
            if key = "OK" then togglePlayback()
        end if
        return true
    end if
    if key = "down" and m.overlayFocus = "buttons"
        hideOverlay()
        return true
    else if (key = "up" or key = "down") and canSeek()
        m.overlayFocus = "buttons"
        if key = "up" then m.overlayFocus = "seek"
    else if m.overlayFocus = "seek"
        if key = "left"
            startSeekHold(key)
        else if key = "right"
            startSeekHold(key)
        else if key = "OK"
            commitSeek()
            togglePlayback()
        end if
    else if key = "left"
        if m.controlIndex > 0 then m.controlIndex -= 1
    else if key = "right"
        if m.controlIndex < m.controlActions.Count() - 1 then m.controlIndex += 1
    else if key = "OK"
        action = m.controlActions[m.controlIndex]
        if action = "chat"
            m.top.toggleChat = true
        else if action = "quality"
            showQuality()
        else if action = "channel"
            m.top.channelRequested = true
        end if
    else if key = "home"
        return false
    end if
    showOverlay()
    return true
end function

sub reloadContent()
    if not m.top.visible or m.reloadPending = true then return
    position = playerSeconds(m.video.position)
    if position <= 0 then position = playerSeconds(m.completedPosition)
    if m.pendingSeek <> invalid then position = m.pendingSeek
    if m.seekInFlight <> invalid and m.pendingSeek = invalid then position = m.seekInFlight
    paused = m.video.state = "paused" or m.resumePaused or m.seekPaused
    stopPlayback()
    m.reloadPosition = position
    m.reloadPaused = paused
    m.reloadPending = true
    m.reloadStarted = false
    m.top.playbackError = ""
    showPlayerBusy()
    showOverlay()
    startPlaybackReload()
end sub

sub cancelPlaybackReload()
    m.reloadPending = false
    if m.reloadTask <> invalid then m.reloadTask.cancelRequested = true
end sub

sub startPlaybackReload()
    if m.reloadPending <> true or not m.top.visible then return
    if m.reloadTask <> invalid
        if m.reloadTask.state = "run" then return
    end if
    info = m.top.playbackInfo
    if type(info) <> "roAssociativeArray"
        m.reloadPending = false
        showPlaybackError("Could not reload this video. Press Back and open it again.")
        return
    end if
    kind = "GetLivePlayback"
    field = "streamerRequested"
    identity = info.login
    if m.top.contentKind = "vod"
        kind = "GetVodPlayback"
        field = "videoId"
        identity = info.videoId
    else if m.top.contentKind = "clip"
        kind = "GetClipPlayback"
        field = "clipId"
        identity = info.clipId
    end if
    if GetInterface(identity, "ifString") = invalid or identity = ""
        m.reloadPending = false
        showPlaybackError("Could not reload this video. Press Back and open it again.")
        return
    end if
    m.reloadTask = CreateObject("roSGNode", kind)
    m.reloadTask[field] = identity
    m.reloadTask.observeField("state", "onPlaybackReloadStopped")
    m.reloadTask.cancelRequested = false
    m.reloadStarted = true
    m.reloadTask.control = "RUN"
end sub

sub onPlaybackReloadStopped()
    if m.reloadPending <> true or not m.top.visible then return
    if m.reloadTask.state <> "stop" then return
    if not m.reloadStarted
        startPlaybackReload()
        return
    end if
    m.reloadPending = false
    info = m.reloadTask.playbackInfo
    if type(info) <> "roAssociativeArray" or m.reloadTask.streamUrl = ""
        message = m.reloadTask.errorMessage
        if message = "" then message = "Could not reload this video. Press the reload button to retry."
        m.reloadError = message
        applyPlaybackLiveStatus(info)
        if m.top.contentKind = "live" and type(info) = "roAssociativeArray"
            if info.liveStatus = "offline"
                showStreamEnded()
                return
            else if info.liveStatus = "live"
                showPlaybackError(message)
                return
            end if
        end if
        if beginLiveStatusCheck("reload-failed") then return
        if m.top.streamEnded
            showEndedScreen()
            return
        end if
        showPlaybackError(message)
        return
    end if
    m.top.playbackInfo = info
    ' Reuse the normal content/stop handoff; never start a second native decoder.
    content = CreateObject("roSGNode", "ContentNode")
    content.url = m.reloadTask.streamUrl
    content.streamFormat = "hls"
    if m.top.contentKind = "clip" then content.streamFormat = "mp4"
    content.live = m.top.contentKind = "live"
    if not content.live then content.playStart = m.reloadPosition
    m.top.content = content
    m.resumePaused = m.reloadPaused
    m.top.control = "play"
end sub

function playerSeconds(value)
    kind = LCase(type(value))
    if kind = "integer" or kind = "roint" or kind = "float" or kind = "rofloat" or kind = "double" or kind = "rodouble" or kind = "longinteger" or kind = "rolonginteger"
        return value
    end if
    return 0
end function

sub showPlayerBusy()
    m.statusText.text = ""
    m.statusBox.visible = false
    m.busy.active = true
end sub
