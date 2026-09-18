sub init()
    m.top.functionName = "checkLiveStatus"
end sub

sub checkLiveStatus()
    m.top.liveStatus = "unknown"
    m.top.liveStream = invalid
    login = m.top.login
    requestId = m.top.requestId
    if login = "" or m.top.cancelRequested then return
    response = getApiJson("https://api.twitch.tv/helix/streams?user_login=" + login.EncodeUriComponent())
    if m.top.cancelRequested or m.top.login <> login or m.top.requestId <> requestId then return
    ' Only a successful, empty live-stream list proves the channel is offline.
    ' Authentication, network and malformed-response failures remain unknown.
    if type(response) <> "roAssociativeArray" then return
    if type(response.data) <> "roArray" then return
    if response.data.Count() = 0
        m.top.liveStatus = "offline"
    else
        stream = response.data[0]
        if type(stream) <> "roAssociativeArray" then return
        if stream.user_login = login and stream.type = "live"
            m.top.liveStream = stream
            m.top.liveStatus = "live"
        end if
    end if
end sub
