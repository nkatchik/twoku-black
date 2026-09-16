function testCreateObject(kind, arg = invalid, flags = invalid)
    if kind = "roRegex" then return CreateObject(kind, arg, flags)
    if kind = "roMessagePort" then return {}
    return {started: getGlobalAA().milliseconds,
        Mark: sub()
            m.started = getGlobalAA().milliseconds
        end sub,
        TotalMilliseconds: function()
            return getGlobalAA().milliseconds - m.started
        end function}
end function

function testWait(delay, port)
    g = getGlobalAA()
    check(delay > 0 and delay <= 250, "Cancellation is checked at least every 250 ms")
    g.milliseconds += delay
    if g.cancelAt > 0 and g.milliseconds >= g.cancelAt then g.top.cancelRequested = true
    return invalid
end function

function testType(value)
    return type(value)
end function

function oauthPost(endpoint, parameters)
    g = getGlobalAA()
    g.requests.push({endpoint: endpoint, parameters: parameters, at: g.milliseconds})
    response = g.responses.shift()
    check(response <> invalid, "No unexpected polling request")
    if response.DoesExist("cancel") then m.top.cancelRequested = true
    return response
end function

function validateUserToken(token)
    g = getGlobalAA()
    g.validations += 1
    if g.cancelValidation then m.top.cancelRequested = true
    return g.identity
end function

sub saveLogin(access, refresh, login)
    getGlobalAA().saved = {access: access, refresh: refresh, login: login}
end sub

function response(code, value)
    error = ""
    if code <> 200 then error = "HTTP error"
    return {code: code, body: FormatJson(value), error: error}
end function

function deviceGrant(expires = 60)
    return {device_code: "test-device", user_code: "ABCD1234", verification_uri: "https://www.twitch.tv/activate", expires_in: expires, interval: 5}
end function

sub resetAuth(responses)
    g = getGlobalAA()
    m.top = {finished: false, cancelRequested: false}
    g.top = m.top
    g.responses = responses
    g.requests = []
    g.milliseconds = 0
    g.cancelAt = 0
    g.cancelValidation = false
    g.identity = {login: "viewer"}
    g.saved = invalid
    g.validations = 0
end sub

sub main()
    g = getGlobalAA()
    pair = {access_token: "test-access", refresh_token: "test-refresh"}
    resetAuth([response(200, deviceGrant()), response(400, {message: "authorization_pending"}), response(400, {error: "slow_down"}), response(200, pair)])
    authenticate()
    check(m.top.finished and g.saved.login = "viewer", "Approval validates and persists identity before success")
    check(g.requests[1].at = 5000 and g.requests[2].at = 10000 and g.requests[3].at = 20000, "Pending interval and slow-down respected")
    check(Instr(1, g.requests[0].parameters, "scopes=user%3Aread%3Afollows") > 0, "Device grant requests followed-channel permission")
    check(Instr(1, g.requests[1].parameters, "device_code=test-device") > 0, "Poll carries device code")
    resetAuth([{code: 404, body: "<!DOCTYPE html><html>No such app</html>", error: "HTTP error"}])
    authenticate()
    check(not m.top.finished and m.top.code = "" and m.top.errorMessage <> "", "HTML cannot appear as a sign-in code")
    resetAuth([response(200, deviceGrant(10)), response(400, {message: "authorization_pending"})])
    authenticate()
    check(not m.top.finished and Instr(1, m.top.errorMessage, "expired") > 0, "Pending approval stops at expiration")
    resetAuth([response(200, deviceGrant())])
    g.cancelAt = 250
    authenticate()
    check(g.requests.count() = 1 and g.saved = invalid, "Back cancels before another poll")
    late = response(200, pair)
    late.cancel = true
    resetAuth([response(200, deviceGrant()), late])
    authenticate()
    check(g.validations = 0 and g.saved = invalid, "Cancelled in-flight response cannot authenticate")
    resetAuth([response(200, deviceGrant()), response(200, pair)])
    g.cancelValidation = true
    authenticate()
    check(g.saved = invalid and not m.top.finished, "Cancellation during validation prevents credential writes")
    resetAuth([response(200, deviceGrant()), response(200, pair)])
    g.identity = invalid
    authenticate()
    check(g.saved = invalid and m.top.errorMessage <> "", "Unverified identity never signals success")
    for each reason in ["access_denied", "invalid device code", "unexpected_error"]
        resetAuth([response(200, deviceGrant()), response(400, {message: reason})])
        authenticate()
        check(g.saved = invalid and m.top.errorMessage <> "", "Terminal errors stop polling")
    end for
    grant = deviceGrant()
    grant.user_code = "<html>"
    check(not validDeviceGrant(grant), "Code must be short plain text")
    grant = deviceGrant()
    grant.verification_uri = "https://www.twitch.tv.evil.invalid/activate"
    check(not validDeviceGrant(grant), "Activation address must be Twitch")
    print "PASS device approval, polling intervals, expiry, cancellation, malformed responses, identity failure"
end sub
