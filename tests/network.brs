function testCreateObject(kind, unused = invalid)
    if kind = "roMessagePort" then return {}
    if kind = "roRegistrySection"
        return {exists: function(key)
            return false
        end function}
    end if
    transfer = {
        headers: {}, cancelled: false,
        EnableEncodings: sub(value)
        end sub,
        RetainBodyOnError: sub(value)
        end sub,
        SetCertificatesFile: sub(value)
        end sub,
        InitClientCertificates: sub()
        end sub,
        AddHeader: sub(key, value)
            m.headers[key] = value
        end sub,
        SetMessagePort: sub(value)
        end sub,
        SetUrl: sub(value)
        end sub,
        AsyncGetToString: function()
            return getGlobalAA().started
        end function,
        AsyncPostFromString: function(payload)
            return getGlobalAA().started
        end function,
        AsyncCancel: sub()
            m.cancelled = true
        end sub
    }
    getGlobalAA().transfers.push(transfer)
    return transfer
end function

function testWait(timeout, port)
    check(timeout > 0 and timeout <= 10000, "HTTP wait must have a deadline")
    getGlobalAA().waits += 1
    return getGlobalAA().responses.shift()
end function

function testType(value)
    if type(value) = "roAssociativeArray"
        if value.DoesExist("GetResponseCode") then return "roUrlEvent"
    end if
    return type(value)
end function

function event(code, body)
    return {code: code, body: body,
        GetResponseCode: function()
            return m.code
        end function,
        GetString: function()
            return m.body
        end function,
        GetFailureReason: function()
            return "test failure"
        end function
    }
end function

sub saveLogin(access, refresh, login)
    check(false, "No failed refresh may save credentials")
end sub

sub main()
    g = getGlobalAA()
    g.transfers = []
    g.responses = []
    g.waits = 0
    g.started = true
    m.global = {userToken: "", appBearerToken: ""}
    url = createUrl()
    check(not url.headers.DoesExist("Authorization"), "No-token URL creation must return immediately")
    m.global.userToken = "saved"
    check(createUrl().headers.Authorization = "Bearer saved", "User credential takes precedence")
    check(createUrl().headers["Client-ID"] = twitchClientId(), "User token uses its issuing public client ID")
    m.global.appBearerToken = "Bearer app"
    g.started = false
    result = requestText(url)
    check(result.error <> "" and g.waits = 0, "Failed async start must not wait")
    g.started = true
    result = requestText(url)
    check(result.error <> "" and url.cancelled, "Timeout cancels transfer")
    g.responses = [event(200, "ok")]
    check(requestText(url).body = "ok", "Successful response preserved")
    g.responses = [event(503, "down")]
    check(requestText(url).code = 503, "HTTP failure preserved")
    g.responses = [event(200, "<html>unavailable</html>")]
    check(getApiJson("https://example.invalid") = invalid, "HTML response must not be parsed as API data")
    check(m.requestError <> "", "Malformed JSON has a visible error")
    g.responses = [event(401, "{}"), event(200, "{""data"":[]}")]
    result = getApiJson("https://example.invalid")
    check(result.data.count() = 0, "Expired user token falls back to app token")
    check(m.global.userToken = "", "Rejected saved token is cleared in memory")
    check(g.transfers.peek().headers.Authorization = "Bearer app", "Retry uses app credential")
    check(g.transfers.peek().headers["Client-ID"] = "w9msa6phhl3u8s2jyjcmshrfjczj2y", "Anonymous token keeps its original client ID")
    check(m.global.sessionRefreshRequested, "Rejected user token requests the retained refresh task")
    m.global.userToken = "expired"
    g.responses = [event(401, "{}") ]
    result = getApiJson("https://example.invalid/follows", true)
    check(result = invalid and g.responses.count() = 0, "Protected API never retries with an app token")
    g.responses = [event(401, "{}"), event(401, "{}")]
    before = g.waits
    check(getApiJson("https://example.invalid") = invalid, "Repeated 401 terminates")
    check(g.waits - before = 2, "At most two API requests")
    m.global.userToken = "user-secret"
    g.responses = [event(200, "{}")]
    metadata = GETJSON("https://api.betterttv.net/3/cached/emotes/global")
    check(not g.transfers.peek().headers.DoesExist("Authorization"), "External emote requests cannot receive a Twitch user token")
    check(not g.transfers.peek().headers.DoesExist("Client-ID"), "External providers receive no Twitch authentication headers")
    print "PASS failed start, timeout, HTTP errors, malformed JSON, token fallback, bounded retries"
end sub
