function init()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.getPlayerInfo = createObject("roSGNode", "GetUserChannel")
    m.getPlayerInfo.observeField("searchResults", "onPlayerInfo")
    m.getPlayerInfo.observeField("state", "onPlayerInfoStopped")
    m.keyboardGroup = m.top.findNode("keyboardGroup")
    m.homeScene = m.top.findNode("homeScene")
    m.categoryScene = m.top.findNode("categoryScene")
    m.loginPage = m.top.findNode("loginPage")

    m.keyboardGroup.observeField("streamUrl", "onStreamChange")
    m.keyboardGroup.observeField("streamerSelectedName", "onStreamerSelected")

    m.homeScene.observeField("streamUrl", "onStreamChange")
    m.homeScene.observeField("streamerSelectedName", "onStreamerSelected")
    m.homeScene.observeField("categorySelected", "onCategoryItemSelect")
    m.homeScene.observeField("buttonPressed", "onHeaderButtonPress")
    m.homeScene.observeField("videoUrl", "onStreamChangeFromChannelPage")

    m.keyboardGroup.observeField("categorySelected", "onCategoryItemSelectFromSearch")

    m.categoryScene.observeField("streamUrl", "onStreamChange")
    m.categoryScene.observeField("streamerSelectedThumbnail", "onStreamerSelected")
    m.categoryScene.observeField("clipUrl", "onClipChange")

    m.loginPage.observeField("finished", "onLoginFinish")
    m.loginPage.observeField("logoutRequested", "onLogoutRequested")

    m.videoPlayer.observeField("back", "onVideoPlayerBack")
    m.videoPlayer.observeField("toggleChat", "onToggleChat")
    m.videoPlayer.observeField("channelRequested", "onPlayerChannelRequested")
    m.videoPlayer.observeField("qualityPreference", "onQualityPreference")

    m.top.backgroundColor = "0x08080AFF"
    m.top.backgroundUri = ""

    m.currentScene = "home"
    m.lastScene = ""

    m.getToken = createObject("roSGNode", "GetToken")
    m.getToken.observeField("state", "onTokenStateChanged")
    m.homeScene.observeField("retryAuthentication", "startAuthentication")
    m.homeScene.observeField("reloadFollowingRequested", "reloadFollowing")
    m.global.addFields({appBearerToken: "", userToken: "", sessionVersion: 0})
    m.global.addField("sessionRefreshRequested", "boolean", true)
    m.global.observeField("sessionRefreshRequested", "onSessionRefreshRequested")

    m.login = ""
    m.getUser = createObject("roSGNode", "GetUser")
    m.getUser.observeField("searchResults", "onUserLogin")
    m.getUser.observeField("state", "onUserStopped")

    m.followingRefreshTimer = m.top.findNode("followingRefreshTimer")
    m.followingRefreshTimer.control = "start"
    m.followingRefreshTimer.ObserveField("fire", "refreshFollows")

    if checkRegistrySection("LoggedInUserData", "Reset") = invalid
        sec = createObject("roRegistrySection", "LoggedInUserData")
        sec.Write("UserToken", "")
        sec.Write("RefreshToken", "")
        sec.Write("LoggedInUser", "")
        setRegistrySection("LoggedInUserData", "Reset", "true")
    end if
    
    loggedInUser = checkRegistrySection("LoggedInUserData", "LoggedInUser")
    if loggedInUser <> invalid and loggedInUser <> ""
        m.login = loggedInUser
    end if

    quality = checkRegistrySection("VideoSettings", "PreferredQuality")
    if quality = invalid or quality = "" then quality = "Auto"
    m.global.addFields({preferredQuality: quality})

    ' Chat preference is applied when a live stream actually starts.
    chatOption = checkRegistrySection("VideoSettings", "ChatOption")
    if chatOption <> invalid and chatOption = "true"
        m.global.addFields({chatOption: true})
    else
        m.global.addFields({chatOption: false})
    end if

    videoBookmarks = checkRegistrySection("VideoSettings", "VideoBookmarks")
    if videoBookmarks <> invalid
        m.videoPlayer.videoBookmarks = ParseJSON(videoBookmarks)
    else
        m.videoPlayer.videoBookmarks = {}
    end if

    m.chat = m.top.findNode("chat")


    m.playbackKind = ""
    m.playerChannel = ""
    m.routingChannel = false

    startAuthentication()
    refreshFollows()
end function

sub onScreenShown()
    if m.top.screenShown then focusHome()
end sub

sub focusHome()
    if m.homeScene.visible
        m.homeScene.callFunc("focusContent")
    end if
end sub

sub onLoginFinish()
    if m.loginPage.finished = true
        loggedInUser = checkRegistrySection("LoggedInUserData", "LoggedInUser")
        if loggedInUser <> invalid and loggedInUser <> ""
            m.login = loggedInUser
        end if
        m.loginPage.visible = false
        m.homeScene.startupError = ""
        m.homeScene.apiReady = true
        refreshFollows()
        m.homeScene.visible = false
        m.homeScene.visible = true
        focusHome()
        m.loginPage.finished = false
    end if
end sub

sub startAuthentication()
    if m.getToken.state = "run" then return
    m.homeScene.apiReady = false
    m.homeScene.startupError = ""
    m.getToken.control = "RUN"
end sub

sub onTokenStateChanged()
    if m.getToken.state <> "stop" then return
    token = m.getToken.appBearerToken
    if token = ""
        if m.global.userToken <> ""
            m.homeScene.startupError = ""
            m.homeScene.apiReady = true
            return
        end if
        message = m.getToken.errorMessage
        if message = "" then message = "Could not connect to Twitch. Try again."
        print "Startup authentication failed: "; message
        m.homeScene.startupError = message
        return
    end if
    m.global.appBearerToken = token
    m.homeScene.apiReady = true
    refreshFollows()
end sub


sub onStreamChangeFromChannelPage()
    if not m.homeScene.visible or m.homeScene.videoUrl = "" then return
    m.currentScene = "home"
    m.playbackKind = "vod"
    m.playerChannel = m.homeScene.streamerSelectedName
    m.videoPlayer.videoTitle = m.homeScene.videoTitle
    m.videoPlayer.channelUsername = m.homeScene.channelUsername
    m.videoPlayer.channelAvatar = m.homeScene.channelAvatar
    m.videoPlayer.gameName = ""
    m.videoPlayer.viewerText = ""
    m.videoPlayer.thumbnailInfo = m.homeScene.thumbnailInfo
    beginPlayback(m.homeScene.videoUrl, m.homeScene.videoPlaybackInfo, "hls")
end sub

sub onStreamerSelected()
    if m.routingChannel then return
    m.routingChannel = true
    channel = ""
    thumbnail = ""
    if m.categoryScene.visible
        channel = m.categoryScene.streamerSelectedName
        thumbnail = m.categoryScene.streamerSelectedThumbnail
        m.lastScene = "category"
    else if m.keyboardGroup.visible
        channel = m.keyboardGroup.streamerSelectedName
        m.lastScene = "search"
    else
        m.lastScene = "home"
    end if
    ' Home's alwaysNotify observer may fire synchronously when forwarded below.
    ' Hide the origin first and keep the guard until its channel page is ready.
    m.keyboardGroup.visible = false
    m.categoryScene.visible = false
    m.homeScene.visible = true
    if channel <> ""
        m.homeScene.streamerSelectedThumbnail = thumbnail
        m.homeScene.streamerSelectedName = channel
    end if
    m.currentScene = "channel"
    m.routingChannel = false
end sub

function checkRegistrySection(section as object, key as object)
    sec = createObject("roRegistrySection", section)
    if sec.Exists(key)
        return sec.Read(key)
    end if
    return invalid
end function

function setRegistrySection(section as object, key as object, value as object)
    sec = createObject("roRegistrySection", section)
    sec.Write(key, value)
    sec.Flush()
end function

function onHeaderButtonPress()
    if m.homeScene.buttonPressed = "search"
        m.homeScene.visible = false
        m.keyboardGroup.visible = true
        m.keyboardGroup.callFunc("focusContent")
    else if m.homeScene.buttonPressed = "login"
        m.homeScene.visible = false
        m.loginPage.accountName = ""
        if m.homeScene.loggedInUserId <> "" and m.homeScene.loggedInUserName <> ""
            ' Viewing the current account does not invalidate its running refresh.
            m.loginPage.accountName = m.homeScene.loggedInUserName
        else
            m.global.sessionVersion += 1
        end if
        m.loginPage.visible = true
        m.loginPage.setFocus(true)
    end if
end function

sub onLogoutRequested()
    if not m.loginPage.visible or not m.loginPage.logoutRequested or m.loginPage.accountName = "" then return
    m.loginPage.logoutRequested = false
    m.global.sessionVersion += 1
    m.global.userToken = ""
    m.global.sessionRefreshRequested = false
    m.login = ""
    section = CreateObject("roRegistrySection", "LoggedInUserData")
    token = ""
    if section.Exists("UserToken") then token = section.Read("UserToken")
    for each key in ["UserToken", "RefreshToken", "UserClientId", "LoggedInUser"]
        section.Delete(key)
    end for
    section.Flush()
    m.homeScene.loggedInSessionVersion = m.global.sessionVersion
    m.homeScene.loggedInUserId = ""
    m.homeScene.loggedInUserName = ""
    m.homeScene.loggedInUserProfileImage = ""
    m.homeScene.followingError = ""
    m.homeScene.followedStreams = []
    m.homeScene.currentlyLiveStreamerIds = {}
    m.loginPage.visible = false
    m.loginPage.accountName = ""
    m.homeScene.callFunc("clearAccount")
    if m.global.appBearerToken = "" then startAuthentication()
    m.homeScene.visible = true
    focusHome()
    ' The old credentials cannot be restored by an in-flight GetUser callback.
    if token <> ""
        m.logoutTask = CreateObject("roSGNode", "Logout")
        m.logoutTask.accessToken = token
        m.logoutTask.control = "RUN"
    end if
end sub

sub onUserLogin()
    if m.followingReloadPending = true then return
    if m.getUser.sessionVersion <> m.global.sessionVersion then return
    m.homeScene.followingError = m.getUser.errorMessage
    if type(m.getUser.searchResults) <> "roAssociativeArray" then return
    if m.getUser.searchResults.display_name = invalid then return
    if m.global.userToken <> ""
        m.homeScene.startupError = ""
        m.homeScene.apiReady = true
    end if
    changedUser = m.homeScene.loggedInUserId <> m.getUser.searchResults.id
    m.homeScene.loggedInSessionVersion = m.global.sessionVersion
    m.homeScene.loggedInUserId = m.getUser.searchResults.id
    m.homeScene.loggedInUserName = m.getUser.searchResults.display_name
    m.homeScene.loggedInUserProfileImage = m.getUser.searchResults.profile_image_url
    if m.getUser.errorMessage = ""
        m.homeScene.followedStreams = m.getUser.searchResults.followed_users
        m.homeScene.currentlyLiveStreamerIds = m.getUser.currentlyLiveStreamerIds
    else if changedUser
        m.homeScene.followedStreams = []
        m.homeScene.currentlyLiveStreamerIds = {}
    end if
    setRegistrySection("LoggedInUserData", "LoggedInUser", m.getUser.searchResults.login)
end sub

function onCategoryItemSelectFromSearch()
    m.categoryScene.currentCategoryName = m.keyboardGroup.categorySelectedName
    m.categoryScene.currentCategoryImage = m.keyboardGroup.categorySelectedImage
    m.categoryScene.currentCategory = m.keyboardGroup.categorySelected
    m.homeScene.visible = false
    m.keyboardGroup.visible = false
    m.categoryScene.visible = true
    m.lastScene = "search"
end function

function onCategoryItemSelect()
    m.categoryScene.currentCategoryName = m.homeScene.categorySelectedName
    m.categoryScene.currentCategoryImage = m.homeScene.categorySelectedImage
    m.categoryScene.currentCategory = m.homeScene.categorySelected
    m.homeScene.visible = false
    m.keyboardGroup.visible = false
    m.categoryScene.visible = true
    m.lastScene = "home"
end function

sub onClipChange()
    if not m.categoryScene.visible or m.categoryScene.clipUrl = "" then return
    m.categoryScene.fromClip = true
    m.currentScene = "category"
    m.playbackKind = "clip"
    m.playerChannel = m.categoryScene.streamerRequested
    m.videoPlayer.videoTitle = m.categoryScene.liveTitle
    m.videoPlayer.channelUsername = m.categoryScene.liveName
    m.videoPlayer.channelAvatar = m.categoryScene.playbackInfo.avatar
    m.videoPlayer.gameName = m.categoryScene.liveGame
    m.videoPlayer.viewerText = m.categoryScene.liveViewers
    beginPlayback(m.categoryScene.clipUrl, m.categoryScene.playbackInfo, "mp4")
end sub

sub onStreamChange()
    if m.keyboardGroup.visible
        m.currentScene = "search"
        source = m.keyboardGroup
    else if m.homeScene.visible
        m.currentScene = "home"
        source = m.homeScene
    else if m.categoryScene.visible
        m.currentScene = "category"
        source = m.categoryScene
    else
        return
    end if
    if source.streamUrl = "" then return
    m.playerChannel = source.streamerRequested
    m.playbackKind = "live"
    m.videoPlayer.videoTitle = source.liveTitle
    m.videoPlayer.channelUsername = source.liveName
    if m.videoPlayer.channelUsername = "" then m.videoPlayer.channelUsername = m.playerChannel
    m.videoPlayer.gameName = source.liveGame
    m.videoPlayer.viewerText = source.liveViewers
    m.videoPlayer.channelAvatar = ""
    m.videoPlayer.thumbnailInfo = invalid
    beginPlayback(source.streamUrl, source.playbackInfo, "hls")
end sub

sub refreshFollows()
    if m.loginPage.visible then return
    if m.login <> "" and m.getUser.state <> "run"
        m.getUser.sessionVersion = m.global.sessionVersion
        m.getUser.loginRequested = m.login
        m.getUser.control = "RUN"
    end if
end sub

sub onSessionRefreshRequested()
    if not m.global.sessionRefreshRequested then return
    m.global.sessionRefreshRequested = false
    refreshFollows()
end sub

sub onUserStopped()
    if m.followingReloadPending = true
        reloadFollowing()
        return
    end if
    if m.getUser.state = "stop" and m.getUser.sessionVersion <> m.global.sessionVersion
        refreshFollows()
    end if
end sub

sub onVideoPlayerBack()
    if not m.videoPlayer.back then return
    closePlayback()
end sub

sub onToggleChat()
    if not m.videoPlayer.toggleChat then return
    m.videoPlayer.toggleChat = false
    if m.playbackKind <> "live" then return
    m.global.chatOption = not m.global.chatOption
    preference = "false"
    if m.global.chatOption then preference = "true"
    setRegistrySection("VideoSettings", "ChatOption", preference)
    onToggleStreamLayout()
end sub

sub onToggleStreamLayout()
    showChat = m.videoPlayer.visible and m.playbackKind = "live" and m.global.chatOption
    m.videoPlayer.chatIsVisible = showChat
    if showChat
        m.chat.channel = m.playerChannel
        m.chat.channelUsername = m.videoPlayer.channelUsername
        m.chat.channelAvatar = m.videoPlayer.channelAvatar
        m.chat.viewerText = m.videoPlayer.viewerText
    end if
    m.chat.visible = showChat
end sub

function onKeyEvent(key, press) as Boolean
    if key = "replay"
        if not press
            m.reloadKeyDown = false
        else if m.reloadKeyDown <> true
            m.reloadKeyDown = true
            reloadVisibleContent()
        end if
        return true
    end if
    if not press then return false
    if m.videoPlayer.visible
        if key = "back"
            closePlayback()
            return true
        end if
        return false
    end if
    if m.loginPage.visible and key = "back"
        m.loginPage.visible = false
        m.homeScene.visible = true
        focusHome()
        return true
    end if
    if (m.keyboardGroup.visible or m.categoryScene.visible) and key = "back"
        m.keyboardGroup.callFunc("cancelPlaybackRequest")
        m.categoryScene.callFunc("cancelPlaybackRequest")
        m.keyboardGroup.visible = false
        m.categoryScene.visible = false
        if m.lastScene = "search"
            m.lastScene = "home"
            m.keyboardGroup.visible = true
            m.keyboardGroup.callFunc("focusContent")
        else
            m.homeScene.visible = true
            focusHome()
        end if
        return true
    end if
    return false
end function

sub reloadVisibleContent()
    if m.videoPlayer.visible
        m.videoPlayer.callFunc("reloadContent")
        if m.chat.visible then m.chat.callFunc("reloadContent")
        requestPlayerInfo()
    else if m.loginPage.visible
        return
    else if m.keyboardGroup.visible
        m.keyboardGroup.callFunc("reloadContent")
    else if m.categoryScene.visible
        m.categoryScene.callFunc("reloadContent")
    else if m.homeScene.visible
        m.homeScene.callFunc("reloadContent")
    end if
end sub

sub reloadFollowing()
    m.followingReloadPending = true
    if m.getUser.state = "run" then return
    m.followingReloadPending = false
    refreshFollows()
end sub


sub beginPlayback(url as String, info as Dynamic, streamFormat as String)
    m.chat.visible = false
    m.homeScene.visible = false
    m.categoryScene.visible = false
    m.keyboardGroup.visible = false
    m.videoPlayer.contentKind = m.playbackKind
    m.videoPlayer.chatEnabled = m.playbackKind = "live"
    m.videoPlayer.playbackInfo = info
    content = createObject("roSGNode", "ContentNode")
    content.streamFormat = streamFormat
    content.url = url
    content.live = m.playbackKind = "live"
    m.videoPlayer.visible = true
    m.videoPlayer.content = content
    onToggleStreamLayout()
    m.videoPlayer.callFunc("focusContent")
    m.videoPlayer.control = "play"
    requestPlayerInfo()
end sub

sub closePlayback()
    ' Restore UI immediately; cancellation/decoder shutdown do not gate navigation.
    m.chat.visible = false
    m.videoPlayer.visible = false
    m.videoPlayer.callFunc("stopPlayback")
    m.videoPlayer.back = false
    m.videoPlayer.chatIsVisible = false
    if m.currentScene = "category"
        m.categoryScene.visible = true
        m.categoryScene.callFunc("focusContent")
    else if m.currentScene = "search"
        m.keyboardGroup.visible = true
        m.keyboardGroup.callFunc("focusContent")
    else
        m.homeScene.visible = true
        focusHome()
    end if
end sub

sub onPlayerChannelRequested()
    if not m.videoPlayer.channelRequested then return
    m.videoPlayer.channelRequested = false
    channel = m.playerChannel
    closePlayback()
    if channel = "" then return
    m.categoryScene.visible = false
    m.keyboardGroup.visible = false
    m.homeScene.visible = true
    m.homeScene.streamerSelectedThumbnail = ""
    m.homeScene.streamerSelectedName = channel
end sub

sub onQualityPreference()
    preference = m.videoPlayer.qualityPreference
    if preference = "" then return
    m.global.preferredQuality = preference
    setRegistrySection("VideoSettings", "PreferredQuality", preference)
end sub

sub requestPlayerInfo()
    if not m.videoPlayer.visible or m.playerChannel = "" then return
    if m.videoPlayer.channelAvatar <> "" or m.getPlayerInfo.state = "run" then return
    m.getPlayerInfo.loginRequested = m.playerChannel
    m.getPlayerInfo.control = "RUN"
end sub

sub onPlayerInfo()
    if not m.videoPlayer.visible or m.getPlayerInfo.loginRequested <> m.playerChannel then return
    info = m.getPlayerInfo.searchResults
    if type(info) <> "roAssociativeArray" then return
    if GetInterface(info.profile_image_url, "ifString") <> invalid
        m.videoPlayer.channelAvatar = info.profile_image_url
        m.chat.channelAvatar = info.profile_image_url
    end if
end sub

sub onPlayerInfoStopped()
    if m.getPlayerInfo.state = "stop" and m.getPlayerInfo.loginRequested <> m.playerChannel then requestPlayerInfo()
end sub
