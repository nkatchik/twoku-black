function testCreateObject(kind, unused = invalid)
    if kind = "roRegistrySection"
        return {
            Exists: function(key)
                return getGlobalAA().registry.DoesExist(key)
            end function,
            Read: function(key)
                return getGlobalAA().registry[key]
            end function,
            Write: sub(key, value)
                getGlobalAA().registry[key] = value
            end sub,
            Flush: sub()
                getGlobalAA().flushes += 1
            end sub}
    end if
    return {headers: {},
        EnableEncodings: sub(value)
        end sub,
        RetainBodyOnError: sub(value)
        end sub,
        SetCertificatesFile: sub(value)
        end sub,
        InitClientCertificates: sub()
        end sub,
        SetUrl: sub(value)
            m.url = value
        end sub,
        AddHeader: sub(key, value)
            m.headers[key] = value
        end sub}
end function

function requestText(url, payload = invalid, timeout = 10000, logFailure = true)
    g = getGlobalAA()
    g.requests.push({url: url.url, headers: url.headers, payload: payload})
    response = g.responses.shift()
    check(response <> invalid, "Session makes only expected requests")
    if response.DoesExist("superseded") then m.global.sessionVersion += 1
    return response
end function

function response(code, value)
    error = ""
    if code <> 200 then error = "request failed"
    return {code: code, body: FormatJson(value), error: error}
end function

function identity()
    return {client_id: twitchClientId(), user_id: "123", login: "viewer", scopes: ["user:read:follows"]}
end function

sub resetSession(responses)
    g = getGlobalAA()
    g.registry = {UserToken: "old-access", RefreshToken: "old+refresh", LoggedInUser: "viewer"}
    g.responses = responses
    g.requests = []
    g.flushes = 0
    m.top = {sessionVersion: 1}
    m.global = {userToken: "", sessionVersion: 1,
        setField: sub(key, value)
            m[key] = value
        end sub}
end sub

sub main()
    g = getGlobalAA()
    resetSession([response(200, identity())])
    check(restoreUserSession().user_id = "123" and m.global.userToken = "old-access", "Saved session validates before use")
    check(g.requests[0].headers.Authorization = "OAuth old-access", "Validation uses the user token")
    pair = {access_token: "new-access", refresh_token: "new-refresh"}
    resetSession([response(401, {}), response(200, pair), response(200, identity())])
    check(restoreUserSession().login = "viewer", "Expired session refreshes through Twitch")
    check(g.registry.RefreshToken = "new-refresh" and g.registry.UserToken = "new-access" and g.flushes = 1, "Rotated token pair is persisted together")
    check(g.registry.UserClientId = twitchClientId(), "Saved token retains its issuing client")
    check(g.requests[1].url = "https://id.twitch.tv/oauth2/token", "Refresh never contacts Heroku")
    check(g.requests[1].headers["Content-Type"] = "application/x-www-form-urlencoded", "OAuth POST uses form encoding")
    check(Instr(1, g.requests[1].payload, "refresh_token=old%2Brefresh") > 0, "Refresh token is URL encoded")
    resetSession([response(0, {})])
    check(restoreUserSession() = invalid and g.requests.count() = 1 and g.flushes = 0, "Network failure does not consume refresh token")
    resetSession([response(401, {}), response(200, pair), response(0, {})])
    check(restoreUserSession() = invalid and g.registry.RefreshToken = "new-refresh", "Rotated refresh token survives a validation network failure")
    bad = identity()
    bad.client_id = "another-client"
    resetSession([response(200, bad)])
    check(restoreUserSession() = invalid and g.flushes = 0, "Token from another client is rejected")
    bad = identity()
    bad.scopes = ["chat:read"]
    resetSession([response(200, bad)])
    check(restoreUserSession() = invalid, "Missing followed-channel permission is rejected")
    stale = response(200, pair)
    stale.superseded = true
    resetSession([response(401, {}), stale])
    check(restoreUserSession() = invalid and g.flushes = 0, "Old refresh cannot overwrite a newly started login")
    resetSession([response(401, {}), response(200, {access_token: "incomplete"})])
    check(restoreUserSession() = invalid and g.flushes = 0, "Malformed refresh response cannot replace saved credentials")
    print "PASS identity and scopes, refresh rotation, persistence, client matching, network failure, superseded sessions"
end sub
