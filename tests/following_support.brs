function getApiJson(link, requireUser = false)
    g = getGlobalAA()
    check(requireUser, "Followed-channel requests require a user credential")
    check(Instr(1, link, "/users/follows") = 0, "Retired follows API is never requested")
    g.links.push(link)
    response = g.responses.shift()
    if response = invalid then m.requestError = "Network unavailable"
    return response
end function

function restoreUserSession()
    return getGlobalAA().identity
end function

function convertToTimeFormat(timestamp)
    return "1:00:00"
end function

sub resetFollowing(responses)
    g = getGlobalAA()
    m.top = {sessionVersion: 1, userId: "123", errorMessage: "", currentlyLiveStreamerIds: {}}
    m.global = {sessionVersion: 1}
    m.requestError = ""
    g.responses = responses
    g.links = []
    g.identity = {user_id: "123", login: "viewer"}
end sub

function stream(id, viewers)
    return {user_id: id, user_name: "Streamer " + id, user_login: "streamer" + id, viewer_count: viewers, game_name: "A game", title: "Live now", thumbnail_url: "https://example.invalid/{width}x{height}.jpg", started_at: "2026-09-16T00:00:00Z"}
end function
