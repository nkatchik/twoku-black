function testCreateObject(kind, name = invalid)
    return {}
end function

function createHttpUrl()
    return {headers: {}, AddHeader: sub(key, value)
        m.headers[key] = value
    end sub, SetUrl: sub(value)
        m.url = value
    end sub}
end function

function requestText(transfer, payload, timeoutMs, logFailure)
    g = GetGlobalAA()
    g.calls += 1
    g.request = {headers: transfer.headers, url: transfer.url, payload: payload, timeoutMs: timeoutMs}
    return g.response
end function

function getApiJson(url)
    g = GetGlobalAA()
    if Instr(1, url, "/streams?") > 0
        g.streamCalls += 1
        return g.streamResponse
    end if
    g.helixCalls += 1
    return {data: [{id: "123", display_name: "Fallback", description: "", profile_image_url: "avatar"}]}
end function

function nonEmptyString(value) as Boolean
    if GetInterface(value, "ifString") = invalid then return false
    return value <> ""
end function

sub main()
    g = GetGlobalAA()
    g.calls = 0
    g.helixCalls = 0
    g.streamCalls = 0
    g.streamResponse = {data: []}
    m.top = {loginRequested: "sample", includeFollowers: true}
    g.response = {code: 200, error: "", body: FormatJson({data: {user: {id: "123", displayName: "Sample", description: "Description", profileImageURL: "avatar", followers: {totalCount: 1234567}}}})}
    profile = getSearchResults()
    check(profile.followers = 1234567 and profile.display_name = "Sample", "Channel page receives actual public follower count and profile")
    check(g.calls = 1 and g.helixCalls = 0, "Profile and followers share one channel-page request")
    check(g.request.headers["Authorization"] = invalid and g.request.timeoutMs = 10000, "Public query is anonymous and bounded")
    payload = channelInfoPayload("name" + Chr(34))
    check(payload.variables.login = "name" + Chr(34) and Instr(1, payload.query, "$login") > 0, "Channel name uses a GraphQL variable")
    g.response.body = FormatJson({data: {user: {id: "123", followers: {totalCount: 0}}}})
    profile = getSearchResults()
    check(profile.followers = 0, "A returned zero remains a real count")
    g.response.body = FormatJson({data: {user: {id: "123", followers: invalid}}})
    profile = getSearchResults()
    check(profile.followers = invalid, "Missing follower data is never invented as zero")
    g.response = {code: 503, error: "Unavailable", body: ""}
    profile = getSearchResults()
    check(profile.display_name = "Fallback" and profile.followers = invalid, "Public outage falls back to profile with unknown count")
    g.streamResponse = {data: [{type: "live", title: "Current stream", user_login: "sample"}]}
    profile = getSearchResults()
    check(profile.live_stream.title = "Current stream", "Profile receives current live stream metadata")
    g.streamResponse = invalid
    profile = getSearchResults()
    check(profile.id = "123" and profile.live_stream = invalid, "Failed live lookup preserves the profile without inventing a live card")
    g.calls = 0
    g.helixCalls = 0
    g.streamCalls = 0
    m.top.includeFollowers = false
    profile = getSearchResults()
    check(g.calls = 0 and g.helixCalls = 1 and g.streamCalls = 0, "Player avatar path adds no follower request or latency")
    print "PASS channel follower totals, anonymous bounded query, unknown count and lightweight player profile"
end sub
