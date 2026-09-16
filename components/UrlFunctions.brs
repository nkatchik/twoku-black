function createHttpUrl()
    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    return url
end function

function createUrl()
    url = createHttpUrl()
    ' Callers start after authentication; never spin on a render-thread field.
    userToken = m.global.userToken
    if userToken <> invalid and userToken <> ""
        url.AddHeader("Client-ID", twitchClientId())
        url.AddHeader("Authorization", "Bearer " + userToken)
    else
        url.AddHeader("Client-ID", "w9msa6phhl3u8s2jyjcmshrfjczj2y")
        if nonEmptyString(m.global.appBearerToken) then url.AddHeader("Authorization", m.global.appBearerToken)
    end if
    return url
end function

' Task-thread HTTP helper. Every request has a deadline, including failed starts.
function requestText(url as Object, payload = invalid as Dynamic, timeoutMs = 10000 as Integer, logFailure = true as Boolean) as Object
    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)
    if payload = invalid
        started = url.AsyncGetToString()
    else
        started = url.AsyncPostFromString(payload)
    end if
    if not started
        return {code: 0, body: "", error: "Could not start the network request."}
    end if
    response = wait(timeoutMs, port)
    if type(response) <> "roUrlEvent"
        url.AsyncCancel()
        return {code: 0, body: "", error: "The connection timed out. Check your network and try again."}
    end if
    code = response.GetResponseCode()
    if code < 200 or code >= 300
        if logFailure then print "HTTP request failed: "; code; " "; response.GetFailureReason()
        return {code: code, body: response.GetString(), error: "The service is unavailable (HTTP " + code.ToStr() + "). Try again."}
    end if
    return {code: code, body: response.GetString(), error: ""}
end function

function getApiJson(link as String, requireUser = false as Boolean) as Object
    m.requestError = ""
    for attempt = 0 to 1
        userToken = m.global.userToken
        if requireUser and not nonEmptyString(userToken)
            m.requestError = "Sign in to load your followed channels."
            return invalid
        end if
        url = createUrl()
        url.SetUrl(link)
        response = requestText(url)
        if response.code = 401 and attempt = 0
            ' GetUser owns refresh-token rotation. Browse tasks may only fall back.
            if nonEmptyString(userToken) and m.global.userToken = userToken
                m.global.userToken = ""
                m.global.sessionRefreshRequested = true
            end if
            if requireUser
                m.requestError = "Your Twitch session needs refreshing. Please try again."
                return invalid
            end if
        else
            if response.error <> ""
                m.requestError = response.error
                return invalid
            end if
            data = ParseJson(response.body)
            if type(data) <> "roAssociativeArray"
                m.requestError = "The service returned an invalid response. Try again."
                return invalid
            end if
            return data
        end if
    end for
    return invalid
end function

function GETJSON(link as String) as Object
    prefix = "https://api.twitch.tv/helix/"
    if Left(link, Len(prefix)) = prefix then return getApiJson(link.EncodeUri())
    ' Emote and badge providers must never receive Twitch credentials.
    url = createHttpUrl()
    url.SetUrl(link.EncodeUri())
    response = requestText(url)
    if response.error <> "" then return invalid
    return ParseJson(response.body)
end function

function VALIDATE() as Object
    url = createUrl()
    url.SetUrl("https://id.twitch.tv/oauth2/validate")

    response_string = url.GetToString()

    return ParseJson(response_string)
end function

function POST(request_url as String, request_payload as String) as String
    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.AddHeader("Client-Id", "kimne78kx3ncx6brgo4mv6wki5h1ko")
    url.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36")
    url.AddHeader("Origin", "https://player.twitch.tv")
    url.AddHeader("Referer", "https://player.twitch.tv")
    url.SetUrl(request_url)

    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)

    url.AsyncPostFromString(request_payload)
    
    response = Wait(0, port)

    return response.GetString()
end function

function twitchClientId() as String
    ' Registered public client shared with nkatchik/smarttv-twitch (Twellie).
    ' Anonymous Helix and GraphQL each retain their own matching client ID.
    return "8dcy6t9zgupyzueekq81g808x0fd9c"
end function

function twitchScopes() as String
    return "user:read:follows chat:read chat:edit"
end function

function nonEmptyString(value) as Boolean
    if GetInterface(value, "ifString") = invalid then return false
    return value <> ""
end function

function oauthUrl(endpoint as String) as Object
    url = createHttpUrl()
    url.SetUrl("https://id.twitch.tv/oauth2/" + endpoint)
    return url
end function

function oauthPost(endpoint as String, parameters as String) as Object
    url = oauthUrl(endpoint)
    url.AddHeader("Content-Type", "application/x-www-form-urlencoded")
    ' Pending device approval is HTTP 400; do not log it as a connection failure.
    return requestText(url, parameters, 10000, false)
end function

function oauthError(value) as String
    if type(value) <> "roAssociativeArray" then return ""
    if nonEmptyString(value.message) then return LCase(value.message)
    if nonEmptyString(value.error) then return LCase(value.error)
    return ""
end function

function validTokenPair(value) as Boolean
    if type(value) <> "roAssociativeArray" then return false
    return nonEmptyString(value.access_token) and nonEmptyString(value.refresh_token)
end function

function validateUserToken(token as String) as Object
    m.validationCode = 0
    if token = "" then return invalid
    url = oauthUrl("validate")
    url.AddHeader("Authorization", "OAuth " + token)
    response = requestText(url, invalid, 10000, false)
    m.validationCode = response.code
    if response.error <> "" then return invalid
    identity = ParseJson(response.body)
    if type(identity) <> "roAssociativeArray" then return invalid
    if identity.client_id <> twitchClientId() then return invalid
    if not nonEmptyString(identity.login) or not nonEmptyString(identity.user_id) then return invalid
    if type(identity.scopes) <> "roArray" then return invalid
    hasFollows = false
    for each scope in identity.scopes
        if scope = "user:read:follows" then hasFollows = true
    end for
    if not hasFollows then return invalid
    return identity
end function

' Only the retained GetUser task calls this, so refresh tokens are never raced.
function restoreUserSession() as Object
    sec = CreateObject("roRegistrySection", "LoggedInUserData")
    if not sec.Exists("UserToken") then return invalid
    access = sec.Read("UserToken")
    identity = validateUserToken(access)
    if identity <> invalid
        if m.top.sessionVersion <> m.global.sessionVersion then return invalid
        m.global.userToken = access
        return identity
    end if
    ' Network failures must not rotate or discard an otherwise valid session.
    if m.validationCode <> 401 then return invalid
    refresh = getRefreshToken()
    if refresh = "" or m.top.sessionVersion <> m.global.sessionVersion then return invalid
    parameters = "client_id=" + twitchClientId() + "&grant_type=refresh_token&refresh_token=" + refresh.EncodeUriComponent()
    response = oauthPost("token", parameters)
    if response.error <> "" then return invalid
    token = ParseJson(response.body)
    if not validTokenPair(token) then return invalid
    if m.top.sessionVersion <> m.global.sessionVersion then return invalid
    ' Public-client refresh tokens rotate once. Persist the pair even if the
    ' subsequent validation request loses connectivity, so the next run recovers.
    saveLogin(token.access_token, token.refresh_token, sec.Read("LoggedInUser"))
    identity = validateUserToken(token.access_token)
    if m.top.sessionVersion <> m.global.sessionVersion then return invalid
    return identity
end function

function getRefreshToken()
    sec = createObject("roRegistrySection", "LoggedInUserData")
    if sec.Exists("RefreshToken")
        return sec.Read("RefreshToken")
    end if
    return ""
end function

function saveLogin(access_token, refresh_token, login) as Void
    sec = createObject("roRegistrySection", "LoggedInUserData")
    sec.Write("UserClientId", twitchClientId())
    sec.Write("UserToken", access_token)
    sec.Write("RefreshToken", refresh_token)
    sec.Write("LoggedInUser", login)
    m.global.setField("userToken", access_token)
    sec.Flush()
end function

function getPlaybackAccessToken(streamLogin as String, id as String, isVod as Boolean) as Object
    request = {
        "extensions": {
            "persistedQuery": {
                "sha256Hash": "0828119ded1c13477966434e15800ff57ddacf13ba1911c129dc2200705b0712",
                "version": 1
            }
        },
        "operationName": "PlaybackAccessToken",
        "variables": {
            "isLive": not isVod,
            "isVod": isVod,
            "login": streamLogin,
            "playerType": "channel_home_live",
            "vodID": id
        }
    }
    ? "format json: " FormatJson(request)
    response = POST("https://gql.twitch.tv/gql", FormatJson(request))
    return response
end function

' Follow endpoints require the signed-in user; never retry them anonymously.
function getTwitchPages(link as String) as Object
    result = []
    cursor = ""
    seen = {}
    for page = 1 to 100
        if m.top.sessionVersion <> m.global.sessionVersion then return invalid
        pageLink = link
        if cursor <> "" then pageLink += "&after=" + cursor.EncodeUriComponent()
        response = getApiJson(pageLink, true)
        if response = invalid then return invalid
        if type(response.data) <> "roArray"
            m.requestError = "Twitch returned an invalid followed-channel response. Try again."
            return invalid
        end if
        result.Append(response.data)
        cursor = ""
        if type(response.pagination) = "roAssociativeArray"
            if nonEmptyString(response.pagination.cursor) then cursor = response.pagination.cursor
        end if
        if cursor = "" then return result
        if seen.DoesExist(cursor) then exit for
        seen[cursor] = true
    end for
    m.requestError = "Twitch could not finish loading followed channels. Try again."
    return invalid
end function

function getUserProfiles(ids as Object) as Object
    profiles = {}
    for first = 0 to ids.count() - 1 step 100
        if m.top.sessionVersion <> m.global.sessionVersion then return profiles
        link = "https://api.twitch.tv/helix/users?"
        last = first + 99
        if last >= ids.count() then last = ids.count() - 1
        for index = first to last
            link += "&id=" + ids[index].EncodeUriComponent()
        end for
        response = getApiJson(link, true)
        if response <> invalid
            if type(response.data) = "roArray"
                for each profile in response.data
                    if nonEmptyString(profile.id) then profiles[profile.id] = profile
                end for
            end if
        end if
    end for
    return profiles
end function
