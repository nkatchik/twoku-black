sub init()
    m.dismissTimer = m.top.findNode("dismissTimer")
    m.dismissTimer.observeField("fire", "clearMessage")
    m.top.observeField("text", "onMessageChanged")
    onMessageChanged()
end sub

sub onMessageChanged()
    m.dismissTimer.control = "stop"
    if m.top.text <> "" then m.dismissTimer.control = "start"
end sub

sub clearMessage()
    m.top.text = ""
end sub
