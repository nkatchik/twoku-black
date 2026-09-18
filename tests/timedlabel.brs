sub main()
    m.top = {text: ""}
    m.dismissTimer = {control: "start"}
    onMessageChanged()
    check(m.dismissTimer.control = "stop", "Empty messages do not leave a timer running")
    m.top.text = "Playback failed"
    onMessageChanged()
    check(m.dismissTimer.control = "start", "Each visible error begins its dismissal timer")
    clearMessage()
    check(m.top.text = "", "Expiry removes the actual error text, not just its visibility")
    onMessageChanged()
    check(m.dismissTimer.control = "stop", "Clearing an error cancels its timeout")
    m.top.text = "Playback failed"
    onMessageChanged()
    check(m.dismissTimer.control = "start", "The same error can be shown again after a retry")
    m.top.text = ""
    onMessageChanged()
    check(m.dismissTimer.control = "stop", "Retry and navigation cancel pending dismissal")
    print "PASS timed errors expire, cancel on clear and can recur after retry"
end sub
