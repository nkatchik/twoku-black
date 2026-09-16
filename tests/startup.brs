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
    m.getUser = node()
    m.global = {appBearerToken: ""}
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
    print "PASS authentication success, failure, retry state, anonymous startup, saved login, invalid user result"
end sub
