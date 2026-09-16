function testCreateObject(kind, subtype = invalid)
    result = node()
    result.boundingRect = function()
        return {height: 40}
    end function
    result.removeChild = function(child)
        for i = 0 to m.children.Count() - 1
            if m.children[i].testId = child.testId
                m.children.Delete(i)
                exit for
            end if
        end for
    end function
    result.removeChildrenIndex = function(count, offset)
        m.children = []
    end function
    return result
end function

sub resetChat()
    m.top = {visible: false, channel: "alpha", channelUsername: "Alpha", channelAvatar: "avatar.png", viewerText: "12 viewers", control: false}
    m.chat = {state: "stop", channel: "", control: "", cancelRequested: false, readyForNextComment: true}
    m.chatPanel = testCreateObject("roSGNode", "Group")
    m.name = node()
    m.avatar = node()
    m.viewers = node()
    m.status = node()
    m.rows = []
    m.restartAfterStop = false
    m.currentChannel = ""
end sub

sub main()
    resetChat()
    onEnterChannel()
    check(m.chat.control = "", "Selecting a channel cannot start hidden chat")
    check(m.name.text = "Alpha" and m.avatar.uri = "avatar.png" and m.viewers.text = "12 viewers", "Header uses stream metadata")
    m.top.visible = true
    onInvisible()
    check(m.chat.control = "RUN" and m.chat.channel = "alpha", "Showing chat starts one task for its channel")
    m.chat.state = "run"
    m.chat.control = ""
    onEnterChannel()
    check(m.chat.control = "" and not m.chat.cancelRequested, "Repeated channel callback cannot restart running task")
    m.chat.nextComment = {channel: "alpha", nick: "Viewer", text: "hello", color: "0xFFFFFFFF"}
    onNewComment()
    check(m.rows.Count() = 1 and m.chat.readyForNextComment, "Visible matching message renders and acknowledges")
    for i = 1 to 100
        onNewComment()
    end for
    check(m.rows.Count() = 6 and m.chatPanel.getChildCount() = 6, "Only rows fitting 592 pixels remain in the render tree")
    check(m.rows[5].translation[1] + m.rows[5].height <= 592, "Messages cannot extend below the rail")
    m.top.visible = false
    onInvisible()
    check(m.chat.cancelRequested and not m.restartAfterStop, "Hiding chat immediately requests cooperative stop")
    before = m.rows.Count()
    onNewComment()
    check(m.rows.Count() = before and m.chat.readyForNextComment, "Hidden late delivery is ignored but acknowledged")
    m.top.visible = true
    onInvisible()
    check(m.restartAfterStop and m.chat.cancelRequested and m.chat.control = "", "Fast reopen waits for old task to stop")
    m.chat.state = "stop"
    onChatStopped()
    check(m.chat.control = "RUN" and not m.chat.cancelRequested, "Reopen starts fresh after cancellation completes")
    m.chat.state = "run"
    m.top.channel = "beta"
    onEnterChannel()
    check(m.rows.Count() = 0 and m.chatPanel.getChildCount() = 0 and m.chat.cancelRequested, "Changing channel clears history and cancels old connection")
    onNewComment()
    check(m.rows.Count() = 0, "Old channel messages cannot enter the new channel")
    m.chat.state = "stop"
    onChatStopped()
    check(m.chat.channel = "beta" and not m.chat.cancelRequested, "Latest channel starts when old task stops")
    m.top.visible = false
    onInvisible()
    m.chat.state = "stop"
    m.chat.control = ""
    onChatStopped()
    check(m.chat.control = "", "Cancelled hidden chat does not restart")
    m.top.setKeyboardFocus = true
    onSetKeyboardFocus()
    check(not m.top.setKeyboardFocus and m.top.doneFocus, "Legacy keyboard request returns focus without exposing keyboard")
    print "PASS hidden startup, cancellation, reopen, channel races, bounded read-only rail"
end sub
