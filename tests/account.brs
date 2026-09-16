function testCreateObject(kind, name = invalid)
    if kind = "roRegistrySection"
        return {
            Exists: function(key)
                return GetGlobalAA().registry.DoesExist(key)
            end function,
            Read: function(key)
                return GetGlobalAA().registry[key]
            end function,
            Delete: sub(key)
                GetGlobalAA().registry.Delete(key)
            end sub,
            Flush: sub()
                GetGlobalAA().flushed = true
            end sub
        }
    end if
    return node()
end function

sub startAuthentication()
    GetGlobalAA().anonymousRestarted = true
end sub

function oauthPost(endpoint, payload)
    GetGlobalAA().revoke = {endpoint: endpoint, payload: payload}
    return {error: "offline"}
end function

function twitchClientId()
    return "public-client"
end function

sub main()
    g = GetGlobalAA()
    m.global = {sessionVersion: 4, userToken: "token", appBearerToken: "anonymous", sessionRefreshRequested: false}
    m.homeScene = node()
    m.homeScene.loggedInUserId = "123"
    m.homeScene.loggedInUserName = "Viewer"
    m.homeScene.loggedInUserProfileImage = "avatar"
    m.homeScene.buttonPressed = "login"
    m.homeScene.callFunc = sub(name)
        if name = "clearAccount" then GetGlobalAA().clearedAccount = true
        if name = "focusContent" then GetGlobalAA().homeFocused = true
    end sub
    m.loginPage = node()
    m.chat = node()
    m.login = "viewer"
    g.registry = {UserToken: "token", RefreshToken: "refresh", UserClientId: "public-client", LoggedInUser: "viewer", RecentStreamers: "preserved"}
    onHeaderButtonPress()
    check(m.loginPage.visible and m.loginPage.accountName = "Viewer", "Signed-in chip opens current account")
    check(m.global.sessionVersion = 4 and m.global.userToken = "token", "Account view preserves active authentication and refresh generation")
    m.loginPage.logoutRequested = true
    onLogoutRequested()
    check(m.global.sessionVersion = 5 and m.global.userToken = "" and m.login = "", "Logout invalidates refresh generation before clearing identity")
    check(not g.registry.DoesExist("UserToken") and not g.registry.DoesExist("RefreshToken") and g.flushed, "Logout clears and flushes persisted credentials")
    check(g.registry.RecentStreamers = "preserved", "Logout preserves unrelated local preferences")
    check(m.homeScene.loggedInUserId = "" and m.homeScene.followedStreams.Count() = 0 and m.chat.loggedInUsername = "", "Logout clears personalized UI and chat identity")
    check(g.clearedAccount and g.homeFocused and m.homeScene.visible and not m.loginPage.visible, "Logout returns immediately to Channels")
    check(m.logoutTask.control = "RUN" and m.logoutTask.accessToken = "token", "Remote token revocation runs separately")
    m.top = m.logoutTask
    revokeSession()
    check(m.top.accessToken = "" and g.revoke.endpoint = "revoke", "Revocation drops published token and cannot restore local session on failure")
    onLogoutRequested()
    check(m.global.sessionVersion = 5, "Repeated logout signal cannot mutate hidden account")
    m.homeScene.buttonPressed = "login"
    onHeaderButtonPress()
    check(m.loginPage.accountName = "" and m.global.sessionVersion = 6, "Signed-out chip opens a fresh login generation")
    print "PASS account navigation, logout, stale refresh invalidation, local clearing and asynchronous revoke"
end sub
