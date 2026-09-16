sub main()
    m.getToken = node()
    m.homeScene = node()
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
