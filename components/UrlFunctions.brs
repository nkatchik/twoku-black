function createUrl()
    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.AddHeader("Client-ID", "w9msa6phhl3u8s2jyjcmshrfjczj2y")
    ' Callers start after authentication; never spin on a render-thread field.
    userToken = m.global.userToken
    if userToken <> invalid and userToken <> ""
        url.AddHeader("Authorization", "Bearer " + userToken)
    else if m.global.appBearerToken <> invalid and m.global.appBearerToken <> ""
        url.AddHeader("Authorization", m.global.appBearerToken)
    end if
    return url
end function

' Task-thread HTTP helper. Every request has a deadline, including failed starts.
function requestText(url as Object, payload = invalid as Dynamic, timeoutMs = 10000 as Integer) as Object
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
        print "HTTP request failed: "; code; " "; response.GetFailureReason()
        return {code: code, body: response.GetString(), error: "The service is unavailable (HTTP " + code.ToStr() + "). Try again."}
    end if
    return {code: code, body: response.GetString(), error: ""}
end function

function getApiJson(link as String) as Object
    m.requestError = ""
    for attempt = 0 to 1
        url = createUrl()
        url.SetUrl(link)
        response = requestText(url)
        if response.code = 401 and attempt = 0
            ' A stale saved user token must not prevent anonymous browsing.
            if not refreshToken()
                m.global.userToken = ""
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
    url = createUrl()
    url.SetUrl(link.EncodeUri())

    response_string = url.GetToString()

    return ParseJson(response_string)
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

function refreshToken() as Boolean
    refresh = getRefreshToken()
    if refresh = "" then return false
    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://twoku-web.herokuapp.com/refresh")
    result = requestText(url, "code=" + refresh.EncodeUriComponent())
    if result.error <> "" then return false
    oauth_token = ParseJson(result.body)
    if type(oauth_token) <> "roAssociativeArray" then return false
    if GetInterface(oauth_token.access_token, "ifString") = invalid then return false
    if GetInterface(oauth_token.refresh_token, "ifString") = invalid then return false
    if oauth_token.access_token = "" or oauth_token.refresh_token = "" then return false

    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://id.twitch.tv/oauth2/validate")
    url.AddHeader("Authorization", "Bearer " + oauth_token.access_token)
    result = requestText(url)
    if result.error <> "" then return false
    response = ParseJson(result.body)
    if type(response) <> "roAssociativeArray" then return false
    if GetInterface(response.login, "ifString") = invalid then return false

    saveLogin(oauth_token.access_token, oauth_token.refresh_token, response.login)
    return true
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
