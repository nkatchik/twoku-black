function getApiJson(url)
    m.calls += 1
    m.requestUrl = url
    if m.cancelDuringRequest then m.top.cancelRequested = true
    if m.changeDuringRequest then m.top.requestId += 1
    return m.response
end function

sub main()
    m.top = {login: "channel", requestId: 1, cancelRequested: false, liveStatus: "unknown"}
    m.calls = 0
    m.cancelDuringRequest = false
    m.changeDuringRequest = false
    for each response in [invalid, {}, {error: "Unauthorized"}, {data: invalid}, {data: {}}, {data: [invalid]}, {data: [{user_login: "other", type: "live"}]}]
        m.response = response
        checkLiveStatus()
        check(m.top.liveStatus = "unknown", "Network, authentication and malformed responses never prove a stream ended")
    end for
    m.response = {data: [{user_login: "channel", type: "live"}]}
    checkLiveStatus()
    check(m.top.liveStatus = "live", "Matching live stream is confirmed online")
    check(m.requestUrl = "https://api.twitch.tv/helix/streams?user_login=channel", "Status lookup is limited to the current channel")
    check(m.top.liveStream.user_login = "channel", "The same request supplies live-card metadata")
    m.response = {data: []}
    checkLiveStatus()
    check(m.top.liveStatus = "offline", "Successful empty stream list confirms offline")
    check(m.top.liveStream = invalid, "Offline clears the previous live metadata")
    m.cancelDuringRequest = true
    checkLiveStatus()
    check(m.top.liveStatus = "unknown", "Cancellation rejects an offline response arriving after Back or Refresh")
    m.cancelDuringRequest = false
    m.top.cancelRequested = false
    m.changeDuringRequest = true
    checkLiveStatus()
    check(m.top.liveStatus = "unknown", "A superseded request cannot end the new playback")
    m.changeDuringRequest = false
    m.top.login = ""
    calls = m.calls
    checkLiveStatus()
    check(m.calls = calls and m.top.liveStatus = "unknown", "Missing channel identity sends no request")
    print "PASS live status distinguishes confirmed offline from errors and rejects cancelled results"
end sub
