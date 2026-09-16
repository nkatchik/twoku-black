function testCreateObject(kind, name = invalid)
    return {}
end function

function createHttpUrl()
    return {
        headers: {}, uri: "",
        AddHeader: sub(name, value)
            m.headers[name] = value
        end sub,
        SetUrl: sub(uri)
            m.uri = uri
        end sub
    }
end function

function nonEmptyString(value) as Boolean
    if GetInterface(value, "ifString") = invalid then return false
    return value <> ""
end function

function requestText(transfer, payload = invalid, timeoutMs = 10000, logFailure = true)
    g = GetGlobalAA()
    g.requests.Push({uri: transfer.uri, headers: transfer.headers, payload: payload, timeout: timeoutMs})
    if g.cancelAfterRequest then m.top.cancelRequested = true
    if g.responses.Count() = 0 then return {code: 500, body: "", error: "Unexpected request"}
    return g.responses.Shift()
end function

sub resetRequests()
    m.top = {cancelRequested: false}
    m.global = {preferredQuality: "Auto", userToken: "private-user-token"}
    g = GetGlobalAA()
    g.requests = []
    g.responses = []
    g.cancelAfterRequest = false
end sub

sub main()
    resetRequests()
    g = GetGlobalAA()
    q = Chr(34)
    query = playbackTokenPayload("name" + q + "break", "", false)
    check(query.variables.login = "name" + q + "break", "channel passed as GraphQL variable")
    check(Instr(1, query.query, "streamPlaybackAccessToken") > 0 and Instr(1, query.query, "name") = 0, "raw query avoids hash drift and unsafe interpolation")
    query = playbackTokenPayload("", "12345", true)
    check(query.variables.vodID = "12345" and Instr(1, query.query, "$vodID: ID!") > 0, "VOD query uses ID variable")
    g.responses = [
        {code: 200, body: FormatJson({data: {streamPlaybackAccessToken: {value: "{token with & symbols}", signature: "sig+value"}}}), error: ""},
        {code: 200, body: "#EXTM3U" + Chr(10) + "#EXT-X-STREAM-INF:RESOLUTION=852x480,FRAME-RATE=30" + Chr(10) + "https://cdn.example/480.m3u8", error: ""}
    ]
    result = requestPlayback("demo", "", false)
    check(result.error = "" and result.url = "https://cdn.example/480.m3u8", "live resolver returns playable variant and metadata")
    check(g.requests.Count() = 2, "resolver uses only token and master requests")
    check(g.requests[0].headers["Authorization"] = invalid and g.requests[1].headers["Authorization"] = invalid, "playback requests never leak OAuth credentials")
    check(g.requests[0].timeout = 10000 and g.requests[1].timeout = 10000, "both requests have deadlines")
    check(Left(g.requests[1].uri, 8) = "https://" and Instr(1, g.requests[1].uri, "sig=sig%2Bvalue") > 0, "master uses HTTPS and component-encoded signature")
    check(Instr(1, g.requests[1].uri, "supported_codecs=avc1") > 0, "master asks for AVC")

    resetRequests()
    g.responses = [{code: 500, body: "<html>failure</html>", error: "HTTP 500"}]
    result = requestPlayback("demo", "", false)
    check(result.url = "" and result.error <> "" and g.requests.Count() = 1, "HTTP failure never starts master request")
    resetRequests()
    g.responses = [{code: 200, body: "{bad json}", error: ""}]
    result = requestPlayback("demo", "", false)
    check(result.url = "" and result.error <> "", "invalid token response rejected")
    resetRequests()
    g.cancelAfterRequest = true
    g.responses = [{code: 200, body: "{}", error: ""}]
    result = requestPlayback("demo", "", false)
    check(g.requests.Count() = 1 and result.url = "", "canceled playback cannot publish or continue resolution")
    print "PASS bounded anonymous playback requests, raw query variables, failures and cancellation"
end sub
