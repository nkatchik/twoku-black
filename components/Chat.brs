sub init()
    m.chatPanel = m.top.findNode("chatPanel")
    m.name = m.top.findNode("channelName")
    m.avatar = m.top.findNode("channelAvatar")
    m.viewers = m.top.findNode("viewers")
    m.status = m.top.findNode("status")
    m.chat = CreateObject("roSGNode", "ChatTest")
    m.chat.observeField("nextComment", "onNewComment")
    m.chat.observeField("statusMessage", "onChatStatus")
    m.chat.observeField("state", "onChatStopped")
    m.top.observeField("visible", "onInvisible")
    m.restartAfterStop = false
    m.currentChannel = ""
    m.rows = []
    m.messageFont = CreateObject("roSGNode", "Font")
    m.messageFont.uri = "pkg:/fonts/Inter-Regular.ttf"
    m.messageFont.size = 16
    m.nameFont = CreateObject("roSGNode", "Font")
    m.nameFont.uri = "pkg:/fonts/Inter-SemiBold.ttf"
    m.nameFont.size = 15
    updateChatHeader()
end sub

sub updateChatHeader()
    if m.name = invalid then return
    m.name.text = m.top.channelUsername
    if m.name.text = "" then m.name.text = m.top.channel
    m.avatar.uri = m.top.channelAvatar
    m.viewers.text = m.top.viewerText
end sub

sub onInvisible()
    syncChatConnection()
end sub

sub onEnterChannel()
    if m.chat = invalid then return
    if m.currentChannel <> m.top.channel
        m.chatPanel.removeChildrenIndex(m.chatPanel.getChildCount(), 0)
        m.rows = []
        m.currentChannel = m.top.channel
        m.status.text = "Connecting to chat..."
        m.status.visible = true
    end if
    updateChatHeader()
    syncChatConnection()
end sub

sub syncChatConnection()
    wanted = m.top.visible and m.top.channel <> ""
    if m.chat.state = "run"
        if not wanted or m.chat.channel <> m.top.channel or m.chat.cancelRequested
            m.chat.cancelRequested = true
            m.restartAfterStop = wanted
        end if
        return
    end if
    m.restartAfterStop = false
    if not wanted then return
    m.chat.channel = m.top.channel
    m.chat.cancelRequested = false
    m.chat.readyForNextComment = true
    m.chat.control = "RUN"
end sub

sub onChatStopped()
    if m.chat.state <> "stop" then return
    if m.restartAfterStop
        syncChatConnection()
    else if m.top.visible
        m.status.text = "Chat unavailable"
        m.status.visible = m.rows.Count() = 0
    end if
end sub

sub onChatStatus()
    if not m.top.visible or m.chat.channel <> m.top.channel then return
    m.status.text = m.chat.statusMessage
    m.status.visible = m.rows.Count() = 0
end sub

sub onNewComment()
    comment = m.chat.nextComment
    if m.top.visible and comment <> invalid
        if comment.channel = LCase(m.top.channel) and not m.chat.cancelRequested
            appendChatComment(comment)
        end if
    end if
    m.chat.readyForNextComment = true
end sub

sub appendChatComment(comment)
    ' One name label and one wrapped message replace the old per-word/emote
    ' node tree. This matches Twellie's read-only rail and bounds render work.
    row = CreateObject("roSGNode", "Rectangle")
    row.width = 336
    row.color = "0x1f1f24FF"
    nick = CreateObject("roSGNode", "Label")
    nick.text = comment.nick
    nick.color = comment.color
    nick.font = m.nameFont
    nick.width = 316
    nick.height = 18
    nick.translation = [10, 9]
    row.appendChild(nick)
    message = CreateObject("roSGNode", "Label")
    message.text = comment.text
    message.color = "0xe6e8eeFF"
    message.font = m.messageFont
    message.width = 316
    message.wrap = true
    message.maxLines = 4
    message.translation = [10, 29]
    row.appendChild(message)
    messageHeight = message.boundingRect().height
    if messageHeight < 20 then messageHeight = 20
    if messageHeight > 80 then messageHeight = 80
    row.height = messageHeight + 39
    m.chatPanel.appendChild(row)
    m.rows.Push(row)
    total = 0
    for each entry in m.rows
        total += entry.height + 8
    end for
    while m.rows.Count() > 1 and (total > 592 or m.rows.Count() > 40)
        old = m.rows.Shift()
        total -= old.height + 8
        m.chatPanel.removeChild(old)
    end while
    offset = 0
    for each entry in m.rows
        entry.translation = [0, offset]
        offset += entry.height + 8
    end for
    m.status.visible = false
end sub

' Retained interface compatibility: the chat rail never takes remote focus.
sub onSetKeyboardFocus()
    if m.top.setKeyboardFocus
        m.top.setKeyboardFocus = false
        m.top.doneFocus = true
    end if
end sub

sub onVideoChange()
    if m.chat <> invalid and not m.top.control then m.chat.cancelRequested = true
end sub
