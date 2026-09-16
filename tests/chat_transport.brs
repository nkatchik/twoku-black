function testCreateObject(kind, argument = invalid, flags = invalid)
    g = getGlobalAA()
    if kind = "roRegex" then return CreateObject(kind, argument, flags)
    if kind = "roMessagePort" then return {}
    if kind = "roSocketAddress"
        return {SetAddress: sub(value)
            m.address = value
        end sub}
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
            closed: false, assignedPort: false, reads: [],
            SetMessagePort: sub(port)
                m.assignedPort = true
            end sub,
            SetSendToAddress: sub(address)
            end sub,
            Connect: function()
                check(m.assignedPort, "Port is attached before connect so network operations are asynchronous")
                return true
            end function,
            IsConnected: function()
                return getGlobalAA().connected
            end function,
            eOK: function()
                return true
            end function,
            IsWritable: function()
                return true
            end function,
            SendStr: function(value)
                g = getGlobalAA()
                length = Len(value)
                if length > 17 then length = 17
                g.sent += Left(value, length)
                return length
            end function,
            GetCountRcvBuf: function()
                if not getGlobalAA().connected then return 0
                return Len(getGlobalAA().input)
            end function,
            ReceiveStr: function(count)
                check(count > 0 and count <= 8192, "Reads use available bytes with bounded chunks")
                g = getGlobalAA()
                m.reads.Push(count)
                chunk = Left(g.input, count)
                g.input = Mid(g.input, count + 1)
                return chunk
            end function,
            IsReadable: function()
                return getGlobalAA().peerClosed
            end function,
            Close: sub()
                m.closed = true
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
    if not g.top.readyForNextComment
        check(not g.top.connecting, "JOIN handshake clears the spinner before chat delivery")
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
    return {buffer: "", droppingLine: false, queue: [], reconnect: false}
end function

sub main()
    resetTransport()
    g = getGlobalAA()
    state = emptyState()
    line = chatLine("hello")
    consumeChatChunk(state, Left(line, 20), "alpha")
    check(state.queue.Count() = 0 and Len(state.buffer) = 20, "Partial lines do not block or produce incomplete messages")
    consumeChatChunk(state, Mid(line, 21), "alpha")
    check(state.queue.Count() = 1 and state.queue[0].nick = "Viewer" and state.queue[0].text = "hello", "Split IRC line preserves its message and display name")
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
    g.cancelAt = 200
    readChat()
    check(not m.top.connecting, "Cancellation clears the transport connecting state")
    check(g.now = 200 and g.sockets[0].closed, "Cancelling a pending connection never waits for its 10-second timeout")
    resetTransport()
    g.connected = false
    g.cancelAt = 16000
    readChat()
    check(g.sockets.Count() = 2 and g.now = 16000, "Failed connect has a deadline and five-second reconnection backoff")
    resetTransport()
    g.peerClosed = true
    readChat()
    check(g.sockets.Count() = 1 and g.sockets[0].closed, "Peer close backs off rather than recreating sockets in a busy loop")
    print "PASS partial frames, bounded queues, async sockets, yielding, cancellation, reconnect backoff"
end sub
