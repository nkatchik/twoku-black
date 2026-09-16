function testCreateObject(kind, argument = invalid, flags = invalid)
    g = getGlobalAA()
    if kind = "roRegex" then return CreateObject(kind, argument, flags)
    if kind = "roMessagePort" then return {}
    if kind = "roSocketAddress"
        return {
            SetAddress: function(value)
                m.address = value
                return getGlobalAA().addressValid
            end function,
            GetAddress: function()
                return "192.0.2.1:6667"
            end function,
            IsAddressValid: function()
                return getGlobalAA().addressValid
            end function}
    end if
    if kind = "roTimespan"
        return {at: g.now,
            Mark: sub()
                m.at = getGlobalAA().now
            end sub,
            TotalMilliseconds: function()
                return getGlobalAA().now - m.at
            end function}
    end if
    if kind = "roStreamSocket"
        socket = {
            closed: false, assignedPort: false, reads: [], born: g.now,
            sent: "", input: g.input, sendCalls: 0, connectCalls: 0, failed: false, closedAt: invalid,
            SetMessagePort: sub(port)
                m.assignedPort = true
            end sub,
            SetSendToAddress: function(address)
                return getGlobalAA().addressValid
            end function,
            Connect: function()
                check(m.assignedPort, "Port is attached before connect so network operations are asynchronous")
                m.connectCalls += 1
                return getGlobalAA().connectStarted
            end function,
            IsConnected: function()
                return getGlobalAA().connected
            end function,
            eOK: function()
                g = getGlobalAA()
                return not m.failed and not (g.hardConnectError and g.now - m.born >= g.writableAfter)
            end function,
            Status: function()
                if not m.eOK() then return 111
                if not getGlobalAA().connected then return 115
                return 0
            end function,
            IsWritable: function()
                g = getGlobalAA()
                if g.writeBlockAfterFirst and m.sendCalls > 0 then return false
                return g.now - m.born >= g.writableAfter
            end function,
            SendStr: function(value)
                g = getGlobalAA()
                m.sendCalls += 1
                if g.sendFailure
                    m.failed = true
                    return -1
                end if
                if g.sendZero or (g.stallAfterFirst and m.sendCalls > 1) then return 0
                length = Len(value)
                if length > g.sendLimit then length = g.sendLimit
                g.sent += Left(value, length)
                m.sent += Left(value, length)
                if g.firstSentAt = invalid then g.firstSentAt = g.now
                return length
            end function,
            GetCountRcvBuf: function()
                g = getGlobalAA()
                if Instr(1, m.sent, "JOIN #alpha" + Chr(13) + Chr(10)) = 0 then return 0
                if g.now - m.born < g.inputAfter then return 0
                return Len(m.input)
            end function,
            ReceiveStr: function(count)
                check(count > 0 and count <= 8192, "Reads use available bytes with bounded chunks")
                g = getGlobalAA()
                m.reads.Push(count)
                if count > g.readLimit then count = g.readLimit
                chunk = Left(m.input, count)
                m.input = Mid(m.input, count + 1)
                return chunk
            end function,
            IsReadable: function()
                return getGlobalAA().peerClosed
            end function,
            Close: sub()
                m.closed = true
                m.closedAt = getGlobalAA().now
            end sub
        }
        g.sockets.Push(socket)
        return socket
    end if
    check(false, "Unexpected object: " + kind)
end function

function testWait(delay, port)
    g = getGlobalAA()
    check(delay = 50, "Every network loop yields for 50 ms without socket event floods")
    g.now += delay
    if g.sockets.Count() > 0
        socket = g.sockets[g.sockets.Count() - 1]
        if not socket.closed
            if not g.top.connecting and g.readyAt = invalid then g.readyAt = g.now
            if g.expectPending then check(g.top.connecting, "An unacknowledged open connection keeps the spinner active")
            if g.now - socket.born < g.inputAfter then check(g.top.connecting, "A complete outgoing handshake alone cannot clear the spinner")
        end if
    end if
    if not g.top.readyForNextComment
        check(not g.top.connecting, "Channel confirmation clears the spinner before chat delivery")
        g.deliveries.Push({at: g.now, message: g.top.nextComment})
        g.top.readyForNextComment = true
    end if
    if g.now >= g.cancelAt then g.top.cancelRequested = true
    return invalid
end function

sub resetTransport()
    g = getGlobalAA()
    m.top = {channel: "alpha", cancelRequested: false, readyForNextComment: true, connecting: false}
    g.top = m.top
    g.now = 0
    g.cancelAt = 1000
    g.connected = true
    g.addressValid = true
    g.connectStarted = true
    g.writableAfter = 0
    g.hardConnectError = false
    g.sendFailure = false
    g.sendZero = false
    g.stallAfterFirst = false
    g.writeBlockAfterFirst = false
    g.sendLimit = 17
    g.readLimit = 8192
    g.inputAfter = 0
    g.expectPending = false
    g.readyAt = invalid
    g.firstSentAt = invalid
    g.peerClosed = false
    g.input = ""
    g.sent = ""
    g.sockets = []
    g.deliveries = []
end sub

function chatLine(text)
    return "@color=#123ABC;display-name=Viewer :viewer!viewer@host PRIVMSG #alpha :" + text + Chr(13) + Chr(10)
end function

function emptyState()
    return {buffer: "", droppingLine: false, queue: [], reconnect: false, joined: false}
end function

sub checkHandshakeTimeout(description as String)
    g = getGlobalAA()
    g.cancelAt = 15100
    g.expectPending = true
    readChat()
    check(g.sockets.Count() = 2, description + " retries after the five-second backoff")
    check(g.sockets[0].closedAt >= 10000 and g.sockets[0].closedAt <= 10050, description + " closes at the ten-second deadline")
    check(g.sockets[1].born - g.sockets[0].closedAt = 5000, description + " never reconnects in a busy loop")
    check(g.readyAt = invalid and not m.top.connecting, description + " never reports an acknowledged channel")
end sub

sub main()
    resetTransport()
    g = getGlobalAA()
    state = emptyState()
    line = chatLine("hello")
    consumeChatChunk(state, Left(line, 20), "alpha")
    check(state.queue.Count() = 0 and Len(state.buffer) = 20, "Partial lines do not block or produce incomplete messages")
    consumeChatChunk(state, Mid(line, 21), "alpha")
    check(state.queue.Count() = 1 and state.queue[0].nick = "Viewer" and state.queue[0].text = "hello", "Split IRC line preserves its message and display name")
    check(state.joined, "A first matching channel message confirms a quiet connection's channel")
    check(state.queue[0].color = "0x123ABCFF", "Valid name color is retained")
    replies = consumeChatChunk(state, "PING :server" + Chr(13) + Chr(10), "alpha")
    check(replies = "PONG :server" + Chr(13) + Chr(10), "PING receives a bounded protocol reply")
    check(parseChatMessage(":viewer!host PRIVMSG #other :no", "alpha") = invalid, "Wrong channel is ignored")
    check(parseChatMessage("@invalid", "alpha") = invalid, "Malformed tag line is ignored")
    fallback = parseChatMessage("@color=garbage :viewer!host PRIVMSG #alpha :message", "alpha")
    check(fallback.nick = "viewer" and fallback.color = "0xc8c8d0FF", "Missing display name and invalid color use safe defaults")
    for i = 1 to 100
        consumeChatChunk(state, chatLine(i.ToStr()), "alpha")
    end for
    check(state.queue.Count() = 40 and state.queue[0].text = "61", "Flooded queue keeps at most 40 recent messages")
    state = emptyState()
    consumeChatChunk(state, String(5000, "x"), "alpha")
    check(state.buffer = "" and state.droppingLine, "Oversized partial lines cannot grow the buffer")
    consumeChatChunk(state, "ignored" + Chr(10) + chatLine("after"), "alpha")
    check(state.queue.Count() = 1 and state.queue[0].text = "after", "Parser recovers at the next complete line after an oversized frame")
    consumeChatChunk(state, chatLine(" RECONNECT"), "alpha")
    check(not state.reconnect, "A viewer message cannot masquerade as a server reconnect command")
    consumeChatChunk(state, ":tmi.twitch.tv RECONNECT" + Chr(10), "alpha")
    check(state.reconnect, "Server reconnect instruction ends the current connection")
    state = emptyState()
    consumeChatChunk(state, ":tmi.twitch.tv CAP * ACK :twitch.tv/tags twitch.tv/commands" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":tmi.twitch.tv 001 justinfan12345 :Welcome, GLHF!" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":tmi.twitch.tv ROOMSTATE #other" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":tmi.twitch.tv ROOMSTATE #alpha_extra" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":tmi.twitch.tv 366 justinfan12345 #other :End of /NAMES list" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":viewer!viewer@host ROOMSTATE #alpha" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":viewer!viewer@host JOIN #alpha" + Chr(13) + Chr(10), "alpha")
    consumeChatChunk(state, ":viewer!viewer@host PRIVMSG #other :ROOMSTATE #alpha" + Chr(13) + Chr(10), "alpha")
    check(not state.joined, "Welcome, unrelated channels, and viewer messages cannot impersonate server channel confirmation")
    consumeChatChunk(state, "@room-id=123 :tmi.twitch.tv ROOMSTATE #alpha" + Chr(13), "alpha")
    check(not state.joined, "An incomplete channel acknowledgement waits for its line ending")
    consumeChatChunk(state, Chr(10), "alpha")
    check(state.joined and state.queue.Count() = 0, "Tagged ROOMSTATE confirms an empty channel across partial reads")
    state = emptyState()
    consumeChatChunk(state, ":tmi.twitch.tv 366 justinfan12345 #alpha :End of /NAMES list" + Chr(13) + Chr(10), "alpha")
    check(state.joined, "Matching end-of-names confirms a channel without waiting for a viewer to speak")
    resetTransport()
    g.input = chatLine("one") + chatLine("two") + chatLine("three") + chatLine("four") + "incomplete"
    readChat()
    check(g.sockets.Count() = 1 and g.sockets[0].closed, "Cancellation closes the connection without replacement sockets")
    check(g.now = 1000 and g.deliveries.Count() = 3, "Delivery is rate limited to four messages a second and cancelled promptly")
    check(g.deliveries[1].at - g.deliveries[0].at >= 250, "Message floods cannot monopolize the render thread")
    check(Instr(1, g.sent, "CAP REQ") = 1 and Instr(1, g.sent, "JOIN #alpha") > 0, "Partial socket writes retain the entire anonymous handshake")
    check(Instr(1, g.sent, "PASS") = 0 and Instr(1, g.sent, "PRIVMSG") = 0, "Read-only chat never sends an account token or user message")
    resetTransport()
    g.connected = false
    g.writableAfter = 100
    g.input = ":tmi.twitch.tv ROOMSTATE #alpha" + Chr(13) + Chr(10)
    readChat()
    check(g.sockets.Count() = 1 and g.firstSentAt = 100, "Writable readiness starts IRC while native IsConnected stays false with EINPROGRESS")
    check(g.readyAt <> invalid and g.readyAt <= 400, "The stale native connected flag cannot delay an acknowledged chat by ten seconds")
    resetTransport()
    g.input = ":tmi.twitch.tv ROOMSTATE #alpha" + Chr(13) + Chr(10)
    g.inputAfter = 650
    readChat()
    check(g.readyAt <> invalid and g.readyAt >= 650 and g.deliveries.Count() = 0, "An empty channel stops spinning only after its delayed acknowledgement")
    resetTransport()
    g.readLimit = 8
    g.input = "@room-id=123 :tmi.twitch.tv ROOMSTATE #alpha" + Chr(13) + Chr(10)
    readChat()
    check(g.readyAt <> invalid and g.sockets[0].reads.Count() > 1, "Partial socket reads preserve channel confirmation")
    resetTransport()
    g.connected = false
    g.writableAfter = 20000
    g.cancelAt = 200
    readChat()
    check(not m.top.connecting, "Cancellation clears the transport connecting state")
    check(g.now = 200 and g.sockets[0].closed, "Cancelling a pending connection never waits for its 10-second timeout")
    resetTransport()
    g.connected = false
    g.writableAfter = 20000
    g.cancelAt = 16000
    readChat()
    check(g.sockets.Count() = 2 and g.now = 16000, "Failed connect has a deadline and five-second reconnection backoff")
    check(g.sockets[0].closedAt = 10000 and g.sockets[1].born = 15000, "Pending readiness uses the connection deadline and retry backoff")
    resetTransport()
    g.hardConnectError = true
    g.writableAfter = 100
    readChat()
    check(g.sockets[0].closedAt = 100 and g.sent = "" and g.readyAt = invalid, "Writable connection refusal cannot be mistaken for connection success")
    resetTransport()
    g.sendFailure = true
    readChat()
    check(g.sockets[0].closedAt <= 50 and g.sent = "" and g.readyAt = invalid, "A failed first send closes without reporting a joined channel")
    resetTransport()
    g.addressValid = false
    readChat()
    check(g.sockets[0].connectCalls = 0 and g.sent = "" and g.sockets[0].closed, "Failed DNS resolution never starts a socket connection")
    resetTransport()
    g.connectStarted = false
    readChat()
    check(g.sent = "" and g.sockets[0].closedAt = 0, "Rejected asynchronous connect is closed immediately")
    resetTransport()
    g.sendZero = true
    checkHandshakeTimeout("Zero-byte sends")
    check(g.sent = "", "Zero-byte sends do not consume the pending handshake")
    resetTransport()
    g.stallAfterFirst = true
    checkHandshakeTimeout("A partial send followed by zero progress")
    check(g.sockets[0].sent = Left("CAP REQ :twitch.tv/tags twitch.tv/commands", 17), "Stalled partial sends never repeat or skip already sent bytes")
    resetTransport()
    g.writeBlockAfterFirst = true
    checkHandshakeTimeout("A socket that stops being writable")
    resetTransport()
    checkHandshakeTimeout("A silent server after the full outgoing handshake")
    check(Instr(1, g.sockets[0].sent, "JOIN #alpha" + Chr(13) + Chr(10)) > 0, "Silent-server timeout happens after the complete JOIN was sent")
    resetTransport()
    g.input = ":tmi.twitch.tv CAP * ACK :twitch.tv/tags" + Chr(13) + Chr(10)
    g.input += ":tmi.twitch.tv 001 justinfan12345 :Welcome, GLHF!" + Chr(13) + Chr(10)
    checkHandshakeTimeout("A server that never confirms the channel")
    resetTransport()
    g.cancelAt = 400
    g.expectPending = true
    readChat()
    check(g.now = 400 and g.sockets.Count() = 1 and g.sockets[0].closedAt = 400, "Cancellation during acknowledgement wait closes promptly without a replacement socket")
    resetTransport()
    g.peerClosed = true
    readChat()
    check(g.sockets.Count() = 1 and g.sockets[0].closed, "Peer close backs off rather than recreating sockets in a busy loop")
    print "PASS partial frames, bounded queues, async connect readiness, channel acknowledgements, handshake deadlines and cancellation"
end sub
