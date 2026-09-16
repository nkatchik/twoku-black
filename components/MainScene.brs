'api.twitch.tv/api/channels/${user}/access_token?client_id=jzkbprff40iqj646a697cyrvl0zt2m6
'usher.ttvnw.net/api/channel/hls/${user}.m3u8?allow_source=true&allow_spectre=true&type=any&token=${token}&sig=${sig}

function init()
    ' environment_variables = ReadAsciiFile("pkg:/env").Split(Chr(10))
    ' for each var in environment_variables
    '     var_info = var.Split("=")
    '     if var_info[0] = "CLIENT-ID"
    '         m.global.addFields({CLIENT_ID: Left(var_info[1], Len(var_info[1]) - 1)})
    '     else if var_info[0] = "AUTHORIZATION"
    '         m.global.addFields({AUTHORIZATION: var_info[1]})
    '     end if
    ' end for


    m.videoPlayer = m.top.findNode("videoPlayer")
    m.getPlayerInfo = createObject("roSGNode", "GetUserChannel")
    m.getPlayerInfo.observeField("searchResults", "onPlayerInfo")
    m.getPlayerInfo.observeField("state", "onPlayerInfoStopped")
    m.keyboardGroup = m.top.findNode("keyboardGroup")
    m.homeScene = m.top.findNode("homeScene")
    m.categoryScene = m.top.findNode("categoryScene")
    ' m.channelPage = m.top.findNode("channelPage")
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

    ' m.channelPage.observeField("videoUrl", "onStreamChangeFromChannelPage")
    ' m.channelPage.observeField("streamUrl", "onStreamChange")

    m.loginPage.observeField("finished", "onLoginFinish")

    m.videoPlayer.observeField("back", "onVideoPlayerBack")
    m.videoPlayer.observeField("toggleChat", "onToggleChat")
    m.videoPlayer.observeField("channelRequested", "onPlayerChannelRequested")
    m.videoPlayer.observeField("qualityPreference", "onQualityPreference")

    m.top.backgroundColor = "0x08080AFF"
    m.top.backgroundUri = ""

    m.currentScene = "home"
    m.lastScene = ""
    m.lastLastScene = ""

    m.stream = createObject("RoSGNode", "ContentNode")
    m.stream["streamFormat"] = "hls"

    m.getToken = createObject("roSGNode", "GetToken")
    m.getToken.observeField("state", "onTokenStateChanged")
    m.homeScene.observeField("retryAuthentication", "startAuthentication")
    m.global.addFields({appBearerToken: "", userToken: "", sessionVersion: 0})
    m.global.addField("sessionRefreshRequested", "boolean", true)
    m.global.observeField("sessionRefreshRequested", "onSessionRefreshRequested")

    m.login = ""
    m.getUser = createObject("roSGNode", "GetUser")
    m.getUser.observeField("searchResults", "onUserLogin")
    m.getUser.observeField("state", "onUserStopped")

    m.testtimer = m.top.findNode("testTimer")
    m.testtimer.control = "start"
    m.testtimer.ObserveField("fire", "refreshFollows")

    if checkRegistrySection("LoggedInUserData", "Reset") = invalid
        sec = createObject("roRegistrySection", "LoggedInUserData")
        sec.Write("UserToken", "")
        sec.Write("RefreshToken", "")
        sec.Write("LoggedInUser", "")
        ? "RESETTED"
        ' setReset("true")
        setRegistrySection("LoggedInUserData", "Reset", "true")
    end if
    
    ' registry = CreateObject("roRegistry")
    ' registry.Delete("LoggedInUserData")
    ' registry.Delete("VideoSettings")

    ' loggedInUser = checkIfLoggedIn()
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

    ' GetUser validates saved credentials before publishing a user token.

    ' videoBookmarks = checkVideoBookmarks()
    videoBookmarks = checkRegistrySection("VideoSettings", "VideoBookmarks")
    ? "MainScene >> videoBookmarks > " videoBookmarks
    if videoBookmarks <> invalid
        'm.videoPlayer.videoBookmarks = {}
        m.videoPlayer.videoBookmarks = ParseJSON(videoBookmarks)
        ? "MainScene >> ParseJSON > " m.videoPlayer.videoBookmarks
    else
        m.videoPlayer.videoBookmarks = {}
    end if

    recentStreamers = checkRegistrySection("LoggedInUserData", "RecentStreamers")
    m.homeScene.recentStreamers = []
    if recentStreamers <> invalid and recentStreamers <> ""
        parsedRecents = ParseJSON(recentStreamers)
        if type(parsedRecents) = "roAssociativeArray"
            if type(parsedRecents.recents) = "roArray"
                m.homeScene.recentStreamers = parsedRecents.recents
            end if
        end if
    end if

    ? "MainScene >> registry space > " createObject("roRegistry").GetSpaceAvailable()

    deviceInfo = CreateObject("roDeviceInfo")
    m.uiResolutionWidth = deviceInfo.GetUIResolution().width

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

sub onChatDoneFocus()
    if m.videoPlayer.visible then m.videoPlayer.callFunc("focusContent")
end sub

sub onLoginFinish()
    if m.loginPage.finished = true
        ' loggedInUser = checkIfLoggedIn()
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

sub updateRecents()
    recents = m.homeScene.recentStreamers
    for streamer = 0 to recents.count() - 1
        if recents[streamer].user_name = m.homeScene.channelUsername
            recents.delete(streamer)
            exit for
        end if
    end for
    streamer = {
        user_name: m.homeScene.channelUsername,
        profile_image_url: m.homeScene.channelAvatar,
        login: m.homeScene.streamerSelectedName
    }
    recents.push(streamer)
    m.homeScene.recentStreamers = recents
    sec = createObject("roRegistrySection", "LoggedInUserData")
    sec.Write("RecentStreamers", FormatJSON({recents: recents}))
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

' function setReset(word as String) as Void
'     sec = createObject("roRegistrySection", "LoggedInUserData")
'     sec.Write("Reset", word)
'     sec.Flush()
' end function

' function saveLogin() as Void
'     sec = createObject("roRegistrySection", "LoggedInUserData")
'     sec.Write("LoggedInUser", m.homeScene.loggedInUserName)
'     sec.Flush()
' end function

function onHeaderButtonPress()
    if m.homeScene.buttonPressed = "search"
        m.homeScene.visible = false
        m.keyboardGroup.visible = true
        m.keyboardGroup.callFunc("focusContent")
    else if m.homeScene.buttonPressed = "login"
        'm.top.dialog = createObject("RoSGNode", "LoginPrompt")
        'm.top.dialog.observeField("buttonSelected", "onLogin")
        m.homeScene.visible = false
        m.global.sessionVersion += 1
        m.loginPage.visible = true
        m.loginPage.setFocus(true)
    end if
end function

sub onUserLogin()
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
    m.chat.loggedInUsername = m.getUser.searchResults.login
    if m.getUser.errorMessage = ""
        m.homeScene.followedStreams = m.getUser.searchResults.followed_users
        m.homeScene.currentlyLiveStreamerIds = m.getUser.currentlyLiveStreamerIds
    else if changedUser
        m.homeScene.followedStreams = []
        m.homeScene.currentlyLiveStreamerIds = {}
    end if
    '? "currentlyLiveStreamerIds mainscene " m.getUser.currentlyLiveStreamerIds
    ' saveLogin()
    setRegistrySection("LoggedInUserData", "LoggedInUser", m.getUser.searchResults.login)
end sub

function onCategoryItemSelectFromSearch()
    m.categoryScene.currentCategoryName = m.keyboardGroup.categorySelectedName
    m.categoryScene.currentCategoryImage = m.keyboardGroup.categorySelectedImage
    m.categoryScene.currentCategory = m.keyboardGroup.categorySelected
    m.homeScene.visible = false
    m.keyboardGroup.visible = false
    m.categoryScene.visible = true
    m.lastLastScene = "home"
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
    if m.getUser.state = "stop" and m.getUser.sessionVersion <> m.global.sessionVersion
        refreshFollows()
    end if
end sub

function onLogin()
    m.login = m.top.dialog.text
    '? "login > "; m.login
    m.top.dialog.close = true
    m.getUser.loginRequested = m.login
    m.getUser.control = "RUN"
end function

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
