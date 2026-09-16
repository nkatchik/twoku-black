sub init()
    m.top.focusable = true
    m.video = m.top.findNode("video")
    if m.video.hasField("asyncStopSemantics") then m.video.asyncStopSemantics = true
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
    m.seekTimer = m.top.findNode("seekTimer")
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
    for each field in ["channelAvatar", "channelUsername", "videoTitle", "gameName", "viewerText", "contentKind"]
        m.top.observeField(field, "onMetadataChange")
    end for
    m.overlayTimer.observeField("fire", "hideOverlay")
    m.watchdog.observeField("fire", "checkPlaybackProgress")
    m.seekTimer.observeField("fire", "commitSeek")
    m.controlIndex = 0
    m.overlayFocus = "buttons"
    m.variants = []
    m.capabilities = invalid
    m.qualityIndex = 0
    m.playingIndex = -1
    m.preference = "Auto"
    m.tried = {}
    m.pendingContent = invalid
    m.startRequested = false
    m.pendingSeek = invalid
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
    m.top.findNode("channelLabel").width = surfaceWidth - 176
    m.top.findNode("titleLabel").width = surfaceWidth - 176
    m.progressTrack.width = surfaceWidth - 280
    m.seekFocus.width = surfaceWidth - 68
    m.top.findNode("durationLabel").translation = [surfaceWidth - 174, 0]
    m.statusBox.translation = [(surfaceWidth - 480) / 2, 268]
    m.busy.translation = [(surfaceWidth - 64) / 2, 328]
    m.pauseIndicator.translation = [(surfaceWidth - 132) / 2, 268]
    refreshControls()
    onVideoPositionChange()
end sub

sub onPlaybackInfo()
    m.variants = []
    m.capabilities = invalid
    info = m.top.playbackInfo
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
    state = m.video.state
    if not playerDecoderIdle(state) and state <> "stopping" then m.video.control = "stop"
    if state = "error" then m.video.control = "stop"
end sub

sub onRequestedControl()
    command = m.top.control
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
                if state <> "stopping" then m.video.control = "stop"
            end if
        else
            m.video.control = "play"
        end if
    else
        m.video.control = command
    end if
end sub

sub startPendingContent()
    if m.pendingContent = invalid or not m.startRequested or not m.top.visible then return
    if not playerDecoderIdle(m.video.state) then return
    nextContent = m.pendingContent
    m.pendingContent = invalid
    resetPlaybackAttempt()
    if m.top.contentKind <> "live" then m.completedPosition = playerSeconds(nextContent.playStart)
    m.playbackActive = true
    m.video.content = nextContent
    m.video.control = "play"
end sub

sub onContentChange()
    if m.video.content = invalid or not m.top.visible or not m.playbackActive then return
    m.pendingSeek = invalid
    m.seekTimer.control = "stop"
    m.top.playbackError = ""
    showPlayerBusy()
    m.watchdog.control = "start"
    focusContent()
    showOverlay()
end sub

sub onVideoStateChange()
    state = m.video.state
    if not m.playbackActive or not m.top.visible then return
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
        m.attemptStarted = true
        m.attemptPlayed = true
        m.terminalTicks = 0
        rememberPlaybackPosition()
        m.bufferTicks = 0
        m.statusBox.visible = false
        m.busy.active = false
        if m.resumePaused
            m.resumePaused = false
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
    if not m.top.visible or not m.playbackActive then return
    state = m.video.state
    if m.pendingContent <> invalid and playerDecoderIdle(state)
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
    return state = "none" or state = "stopped" or state = "finished" or state = "error"
end function

sub rememberPlaybackPosition()
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

sub recoverPlayback(reason = "playback-failed")
    if not m.playbackActive then return
    recordPlaybackDiagnostic(reason)
    nextIndex = -1
    if m.preference = "Auto" then nextIndex = playbackFallbackIndex(m.variants, m.playingIndex, m.tried, m.capabilities)
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

sub recordPlaybackDiagnostic(reason as String, measuredBps = 0)
    ' Never copy error strings or entire native AAs: they can contain signed URLs.
    diagnostic = {reason: reason, qualityIndex: m.playingIndex, measuredBps: measuredBps}
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
    m.busy.active = false
    m.pendingContent = invalid
    m.startRequested = false
    m.playbackActive = false
    m.switching = false
    m.watchdog.control = "stop"
    m.video.control = "stop"
    m.top.playbackError = message
    m.statusText.text = message
    m.statusBox.visible = true
    m.pauseIndicator.visible = false
    showOverlay()
end sub

sub switchVariant(index as Integer)
    if index < 0 or index >= m.variants.Count() then return
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
        else
            nextContent.playStart = playerSeconds(m.video.position)
            if nextContent.playStart <= 0 then nextContent.playStart = playerSeconds(m.completedPosition)
        end if
    end if
    m.startRequested = true
    m.resumePaused = m.video.state = "paused"
    m.seekTimer.control = "stop"
    m.pendingSeek = invalid
    m.playingIndex = index
    m.tried[index.ToStr()] = true
    m.bufferTicks = 0
    m.stalledTicks = 0
    m.switching = true
    m.playbackActive = true
    m.top.playbackError = ""
    m.watchdog.control = "start"
    ' A second load cannot start until Roku releases the underlying media player.
    state = m.video.state
    m.pendingContent = nextContent
    if state = "error" or (not playerDecoderIdle(state) and state <> "stopping") then m.video.control = "stop"
    if playerDecoderIdle(m.video.state) then startPendingContent()
    renderQuality()
end sub

sub stopPlayback()
    m.startRequested = false
    m.playbackActive = false
    m.pendingContent = invalid
    m.pendingSeek = invalid
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
    m.video.control = "stop"
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
    if not m.playbackActive or not m.top.visible or m.pendingContent <> invalid or m.video.state = "stopping" then return false
    return m.top.contentKind <> "live" and playerSeconds(m.video.duration) > 0
end function

sub refreshControls()
    if m.buttonNodes = invalid then return
    while m.controls.getChildCount() > 0
        m.controls.removeChildIndex(0)
    end while
    m.buttonNodes = []
    m.controlActions = ["channel"]
    labels = ["Channel"]
    if m.top.contentKind = "live" and m.top.chatEnabled
        m.controlActions.Push("chat")
        chatLabel = "Chat"
        if m.top.chatIsVisible then chatLabel = "Chat on"
        labels.Push(chatLabel)
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
        button.color = "0x323239FF"
        label = CreateObject("roSGNode", "Label")
        label.width = 132
        label.height = 40
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.text = labels[index]
        label.color = "0xEFF1F6FF"
        font = CreateObject("roSGNode", "Font")
        font.uri = "pkg:/fonts/Inter-SemiBold.ttf"
        font.size = 17
        label.font = font
        if index = m.controlIndex and m.overlayFocus = "buttons"
            button.color = "0xF4F4F7FF"
            label.color = "0x111318FF"
        end if
        button.appendChild(label)
        m.controls.appendChild(button)
        m.buttonNodes.Push(button)
        x += 148
    end for
    m.progress.visible = canSeek()
    m.seekFocus.visible = m.overlayFocus = "seek" and canSeek()
end sub

sub renderQuality()
    label = "Auto"
    if m.qualityIndex > 0 and m.qualityIndex <= m.variants.Count() then label = m.variants[m.qualityIndex - 1].name
    m.qualityName.text = label
    m.top.findNode("qualityHint").text = "OK to apply · Back to close"
end sub

sub showQuality()
    for index = 0 to m.controlActions.Count() - 1
        if m.controlActions[index] = "quality" then m.qualityPanel.translation = [42 + index * 148,438]
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
    m.tried = {}
    m.qualityPanel.visible = false
    if index >= 0 then switchVariant(index)
    showOverlay()
end sub

sub seekBy(seconds as Integer)
    if not canSeek() then return
    position = playerSeconds(m.video.position)
    if m.pendingSeek <> invalid then position = m.pendingSeek
    position += seconds
    if position < 0 then position = 0
    if position > playerSeconds(m.video.duration) then position = playerSeconds(m.video.duration)
    m.pendingSeek = position
    m.seekTimer.control = "stop"
    m.seekTimer.control = "start"
    onVideoPositionChange()
end sub

sub commitSeek()
    if m.pendingSeek = invalid then return
    if not canSeek()
        m.pendingSeek = invalid
        m.seekTimer.control = "stop"
        return
    end if
    m.completedPosition = m.pendingSeek
    m.video.seek = m.pendingSeek
    m.pendingSeek = invalid
    m.stalledTicks = 0
end sub

sub togglePlayback()
    if not canSeek() then return
    commitSeek()
    if m.video.state = "paused"
        m.video.control = "resume"
    else if m.video.state = "playing"
        m.video.control = "pause"
    end if
end sub

sub onVideoPositionChange()
    if m.video = invalid then return
    if m.playbackActive and (m.video.state = "playing" or m.video.state = "paused") then rememberPlaybackPosition()
    m.progress.visible = canSeek()
    m.seekFocus.visible = m.overlayFocus = "seek" and canSeek()
    position = playerSeconds(m.video.position)
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
    if not press then return key <> "home"
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
        delta = 10
        if key = "rewind" then delta = -10
        seekBy(delta)
        return true
    end if
    if not m.overlay.visible
        if canSeek() and (key = "left" or key = "right")
            delta = 10
            if key = "left" then delta = -10
            seekBy(delta)
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
            seekBy(-10)
        else if key = "right"
            seekBy(10)
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
