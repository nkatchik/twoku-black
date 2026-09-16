sub init()
    m.top.functionName = "readChat"
end sub

' A socket without a message port is synchronous on Roku. Always attach one
' before connecting, and use a separate timed port so busy chats still yield.
sub readChat()
    channel = LCase(m.top.channel)
    validChannel = CreateObject("roRegex", "^[a-z0-9_]{1,25}$", "")
    if not validChannel.IsMatch(channel) then return
    tickPort = CreateObject("roMessagePort")
    socketPort = CreateObject("roMessagePort")
    while not m.top.cancelRequested
        print "Chat connecting"
        m.top.statusMessage = ""
        m.top.connecting = true
        socket = CreateObject("roStreamSocket")
        socket.SetMessagePort(socketPort)
        address = CreateObject("roSocketAddress")
        connectedAt = CreateObject("roTimespan")
        connectedAt.Mark()
        ready = false
        if address.SetAddress("irc.chat.twitch.tv:6667")
            socket.SetSendToAddress(address)
            if socket.Connect()
                ' Native IsConnected can remain false/EINPROGRESS even after
                ' TCP is writable. Poll readiness; a failed asynchronous connect
                ' is caught by eOK or the first send, never treated as a JOIN.
                while not socket.IsWritable() and socket.eOK() and connectedAt.TotalMilliseconds() < 10000
                    if not waitForChat(tickPort, 50) then exit while
                end while
                ready = socket.IsWritable() and socket.eOK()
            end if
        end if
        if not m.top.cancelRequested and ready
            nick = "justinfan" + (10000 + Rnd(89999)).ToStr()
            pendingSend = "CAP REQ :twitch.tv/tags twitch.tv/commands" + Chr(13) + Chr(10)
            pendingSend += "NICK " + nick + Chr(13) + Chr(10) + "JOIN #" + channel + Chr(13) + Chr(10)
            runChatConnection(socket, tickPort, channel, pendingSend)
        end if
        socket.Close()
        m.top.connecting = false
        if m.top.cancelRequested then return
        print "Chat disconnected; retrying"
        m.top.statusMessage = "Chat unavailable"
        if not waitForChat(tickPort, 5000) then return
    end while
end sub

function waitForChat(port, milliseconds as Integer) as Boolean
    remaining = milliseconds
    while remaining > 0
        if m.top.cancelRequested then return false
        delay = remaining
        if delay > 50 then delay = 50
        wait(delay, port)
        remaining -= delay
    end while
    return not m.top.cancelRequested
end function

sub runChatConnection(socket, tickPort, channel as String, pendingSend as String)
    state = {buffer: "", droppingLine: false, queue: [], reconnect: false, joined: false}
    deliveryClock = CreateObject("roTimespan")
    deliveryClock.Mark()
    handshakeClock = CreateObject("roTimespan")
    handshakeClock.Mark()
    m.top.statusMessage = ""
    joined = false
    delivered = false
    while not m.top.cancelRequested and socket.eOK() and not state.reconnect
        ' One deadline includes both sending and Twitch's channel acknowledgement.
        ' Partial writes or unrelated server traffic cannot extend it indefinitely.
        if not state.joined and handshakeClock.TotalMilliseconds() >= 10000 then exit while
        if pendingSend <> "" and socket.IsWritable()
            sent = socket.SendStr(pendingSend)
            if sent > 0 then pendingSend = Mid(pendingSend, sent + 1)
            if not socket.eOK() then exit while
        end if
        available = socket.GetCountRcvBuf()
        if available > 0
            if available > 8192 then available = 8192
            chunk = socket.ReceiveStr(available)
            pendingSend += consumeChatChunk(state, chunk, channel)
            if Len(pendingSend) > 2048 then exit while
        else if socket.IsReadable()
            ' Readable with no buffered bytes means the peer closed, not a
            ' reason to create sockets continuously inside the receive loop.
            exit while
        end if
        if state.joined and not joined
            joined = true
            m.top.connecting = false
            print "Chat joined"
        end if
        if state.queue.Count() > 0 and deliveryClock.TotalMilliseconds() >= 250
            if m.top.readyForNextComment
                m.top.readyForNextComment = false
                m.top.nextComment = state.queue.Shift()
                if not delivered then print "Chat delivering messages"
                delivered = true
                deliveryClock.Mark()
            end if
        end if
        if not waitForChat(tickPort, 50) then exit while
    end while
end sub

' Keep incomplete IRC lines for the next read. Both byte work per tick and the
' number of queued messages are bounded even when a channel floods the socket.
function consumeChatChunk(state, chunk as String, channel as String) as String
    replies = ""
    state.buffer += chunk
    lineEnd = Instr(1, state.buffer, Chr(10))
    while lineEnd > 0
        line = Left(state.buffer, lineEnd - 1)
        state.buffer = Mid(state.buffer, lineEnd + 1)
        if not state.droppingLine and Len(line) <= 4096
            if Right(line, 1) = Chr(13) then line = Left(line, Len(line) - 1)
            if Left(line, 5) = "PING "
                replies += "PONG " + Mid(line, 6) + Chr(13) + Chr(10)
            else if line = "RECONNECT" or line = ":tmi.twitch.tv RECONNECT"
                state.reconnect = true
            else
                message = parseChatMessage(line, channel)
                if message <> invalid
                    state.joined = true
                    state.queue.Push(message)
                    if state.queue.Count() > 40 then state.queue.Shift()
                else if chatChannelAcknowledged(line, channel)
                    state.joined = true
                end if
            end if
        end if
        state.droppingLine = false
        lineEnd = Instr(1, state.buffer, Chr(10))
    end while
    if Len(state.buffer) > 4096
        state.buffer = ""
        state.droppingLine = true
    end if
    return replies
end function

function chatChannelAcknowledged(line as String, channel as String) as Boolean
    if Left(line, 1) = "@"
        tagEnd = Instr(1, line, " ")
        if tagEnd = 0 then return false
        line = Mid(line, tagEnd + 1)
    end if
    ' Only the server can acknowledge membership. A viewer's message containing
    ' ROOMSTATE/366, or a response for another room, is not a successful join.
    parts = line.Split(" ")
    if parts.Count() < 3 then return false
    if parts[0] <> ":tmi.twitch.tv" then return false
    if parts[1] = "ROOMSTATE" then return parts[2] = "#" + channel
    if parts[1] = "366" and parts.Count() >= 4 then return parts[3] = "#" + channel
    return false
end function

function parseChatMessage(line as String, channel as String) as Object
    tags = {}
    if Left(line, 1) = "@"
        tagEnd = Instr(1, line, " ")
        if tagEnd = 0 then return invalid
        for each part in Mid(line, 2, tagEnd - 2).Split(";")
            equal = Instr(1, part, "=")
            if equal > 0 then tags[Left(part, equal - 1)] = Mid(part, equal + 1)
        end for
        line = Mid(line, tagEnd + 1)
    end if
    if Left(line, 1) <> ":" then return invalid
    prefixEnd = Instr(1, line, " ")
    if prefixEnd = 0 then return invalid
    prefix = Mid(line, 2, prefixEnd - 2)
    separator = Instr(1, prefix, "!")
    nick = prefix
    if separator > 0 then nick = Left(prefix, separator - 1)
    line = Mid(line, prefixEnd + 1)
    expected = "PRIVMSG #" + channel + " :"
    if Left(line, Len(expected)) <> expected then return invalid
    message = Mid(line, Len(expected) + 1)
    if tags["display-name"] <> invalid and tags["display-name"] <> "" then nick = tags["display-name"]
    if nick = "" or message = "" then return invalid
    color = "#c8c8d0"
    if tags.color <> invalid
        validColor = CreateObject("roRegex", "^#[0-9a-fA-F]{6}$", "")
        if validColor.IsMatch(tags.color) then color = tags.color
    end if
    return {channel: channel, nick: Left(nick, 50), text: Left(message, 400), color: "0x" + Mid(color, 2) + "FF"}
end function
