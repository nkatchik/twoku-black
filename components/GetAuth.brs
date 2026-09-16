sub init()
    m.top.functionName = "authenticate"
end sub

sub authenticate()
    m.top.finished = false
    m.top.errorMessage = ""
    m.top.code = ""
    m.top.verificationUri = ""
    m.top.statusMessage = "Getting a sign-in code..."
    if m.top.cancelRequested then return

    parameters = "client_id=" + twitchClientId() + "&scopes=" + twitchScopes().EncodeUriComponent()
    response = oauthPost("device", parameters)
    if m.top.cancelRequested then return
    grant = ParseJson(response.body)
    if response.error <> "" or not validDeviceGrant(grant)
        failLogin("Could not get a Twitch sign-in code. Check your connection and try again.")
        return
    end if

    m.top.verificationUri = grant.verification_uri
    m.top.code = grant.user_code
    m.top.statusMessage = "Approve access in your browser. This screen will update automatically."
    clock = CreateObject("roTimespan")
    clock.Mark()
    expiresMs = grant.expires_in * 1000
    intervalMs = 5000
    if GetInterface(grant.interval, "ifInt") <> invalid
        if grant.interval > 0 then intervalMs = grant.interval * 1000
    end if
    parameters += "&device_code=" + grant.device_code.EncodeUriComponent()
    parameters += "&grant_type=urn:ietf:params:oauth:grant-type:device_code"

    while clock.TotalMilliseconds() < expiresMs
        remaining = expiresMs - clock.TotalMilliseconds()
        delay = intervalMs
        if delay > remaining then delay = remaining
        if not waitForLoginPoll(delay) then return
        if clock.TotalMilliseconds() >= expiresMs then exit while
        response = oauthPost("token", parameters)
        if m.top.cancelRequested then return
        token = ParseJson(response.body)
        if response.code = 200
            if not validTokenPair(token)
                failLogin("Twitch returned an invalid sign-in response. Try again.")
                return
            end if
            identity = validateUserToken(token.access_token)
            if m.top.cancelRequested then return
            if identity = invalid
                failLogin("Could not verify your Twitch account and followed-channel access. Try again.")
                return
            end if
            saveLogin(token.access_token, token.refresh_token, identity.login)
            m.top.statusMessage = "Signed in as " + identity.login
            m.top.finished = true
            return
        end if
        reason = oauthError(token)
        if reason = "authorization_pending"
            ' Wait for the next permitted poll; this is an expected response.
        else if reason = "slow_down" or response.code = 429
            intervalMs += 5000
        else if reason = "access_denied"
            failLogin("Sign-in was declined. You can try again.")
            return
        else if reason = "expired_token" or reason = "invalid device code"
            exit while
        else
            failLogin("Could not complete Twitch sign-in. Check your connection and try again.")
            return
        end if
    end while
    failLogin("This sign-in code has expired. Request a new code to try again.")
end sub

function validDeviceGrant(grant) as Boolean
    if type(grant) <> "roAssociativeArray" then return false
    if not nonEmptyString(grant.device_code) or not nonEmptyString(grant.user_code) then return false
    if not nonEmptyString(grant.verification_uri) then return false
    if GetInterface(grant.expires_in, "ifInt") = invalid then return false
    if grant.expires_in <= 0 or grant.expires_in > 3600 then return false
    if not CreateObject("roRegex", "^[A-Za-z0-9-]{4,32}$", "").IsMatch(grant.user_code) then return false
    uri = grant.verification_uri
    return uri = "https://www.twitch.tv/activate" or Left(uri, 31) = "https://www.twitch.tv/activate?"
end function

function waitForLoginPoll(delayMs as Integer) as Boolean
    clock = CreateObject("roTimespan")
    clock.Mark()
    port = CreateObject("roMessagePort")
    while clock.TotalMilliseconds() < delayMs
        if m.top.cancelRequested then return false
        remaining = delayMs - clock.TotalMilliseconds()
        waitMs = 250
        if remaining < waitMs then waitMs = remaining
        if waitMs > 0 then wait(waitMs, port)
    end while
    return not m.top.cancelRequested
end function

sub failLogin(message as String)
    if m.top.cancelRequested then return
    m.top.code = ""
    m.top.errorMessage = message
    m.top.statusMessage = message
end sub
