sub main()
    m.top = {screenShown: false}
    m.getToken = node()
    m.homeScene = node()
    m.homeScene.callFunc = sub(name)
        check(name = "focusContent", "Home receives explicit focus request")
        m.focusRequested = true
    end sub
    m.homeScene.focusRequested = false
    m.homeScene.visible = true
    onScreenShown()
    check(not m.homeScene.focusRequested, "No focus handoff before the screen is shown")
    m.top.screenShown = true
    onScreenShown()
    check(m.homeScene.focusRequested, "Shown screen explicitly focuses Home content")
    m.homeScene.visible = false
    m.homeScene.focusRequested = false
    focusHome()
    check(not m.homeScene.focusRequested, "Hidden Home cannot steal focus")
    m.loginPage = node()
    m.getUser = node()
    m.global = {appBearerToken: "", userToken: "", sessionVersion: 1}
    m.login = ""
    startAuthentication()
    check(m.getToken.control = "RUN" and not m.homeScene.apiReady, "Auth starts while browse remains gated")
    m.getToken.appBearerToken = ""
    m.getToken.errorMessage = "offline"
    onTokenStateChanged()
    check(m.homeScene.startupError = "offline" and not m.homeScene.apiReady, "Failure exposes retry state")
    m.getToken.appBearerToken = "Bearer test"
    onTokenStateChanged()
    check(m.global.appBearerToken = "Bearer test" and m.homeScene.apiReady, "Token published before API ready")
    check(m.getUser.control = "", "Anonymous launch never looks up empty username")
    m.login = "viewer"
    refreshFollows()
    check(m.getUser.control = "RUN" and m.getUser.loginRequested = "viewer", "Saved login restores after auth")
    m.getUser.searchResults = invalid
    onUserLogin()
    m.getUser.control = ""
    m.loginPage.visible = true
    refreshFollows()
    check(m.getUser.control = "", "Background restore pauses while the login page owns authentication")
    m.loginPage.visible = false
    m.homeScene.apiReady = false
    refreshFollows()
    check(m.getUser.control = "RUN", "Saved login can restore independently of anonymous token service")
    m.chat = node()
    m.getUser.searchResults = {id: "123", login: "viewer", display_name: "Viewer", profile_image_url: "avatar", followed_users: []}
    m.getUser.currentlyLiveStreamerIds = {}
    m.global.userToken = "validated-token"
    onUserLogin()
    check(m.homeScene.loggedInUserName = "Viewer" and m.homeScene.loggedInUserId = "123", "Validated identity reaches Home")
    check(m.homeScene.apiReady, "User authentication unlocks browsing")
    check(getGlobalAA().savedLogin = "viewer", "Registry stores canonical login, not display name")
    m.global.sessionVersion = 2
    m.getUser.searchResults.display_name = "Stale result"
    onUserLogin()
    check(m.homeScene.loggedInUserName = "Viewer", "Superseded task cannot change displayed account")
    m.getUser.state = "stop"
    m.getUser.control = ""
    onUserStopped()
    check(m.getUser.control = "RUN" and m.getUser.sessionVersion = 2, "New account refresh starts when the old task stops")
    m.getToken.appBearerToken = ""
    onTokenStateChanged()
    check(m.homeScene.apiReady and m.homeScene.startupError = "", "Anonymous token failure cannot undo user authentication")
    print "PASS authentication success, failure, retry state, anonymous startup, saved login, invalid user result"
end sub

sub setRegistrySection(section, key, value)
    getGlobalAA().savedLogin = value
end sub
