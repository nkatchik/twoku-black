sub init()
    m.top.focusable = true
    m.code = m.top.findNode("code")
    m.address = m.top.findNode("address")
    m.status = m.top.findNode("status")
    m.hint = m.top.findNode("hint")
    m.retryWhenStopped = false
    m.top.observeField("visible", "onVisible")
    m.getAuth = createObject("roSGNode", "GetAuth")
    m.getAuth.observeField("code", "onAuthUpdate")
    m.getAuth.observeField("verificationUri", "onAuthUpdate")
    m.getAuth.observeField("statusMessage", "onAuthUpdate")
    m.getAuth.observeField("errorMessage", "onAuthUpdate")
    m.getAuth.observeField("finished", "whenFinished")
    m.getAuth.observeField("state", "onAuthStopped")
end sub

sub whenFinished()
    if m.top.visible and not m.getAuth.cancelRequested and m.getAuth.finished
        m.top.finished = true
    end if
end sub

sub onAuthUpdate()
    if not m.top.visible or m.getAuth.cancelRequested then return
    m.code.text = m.getAuth.code
    ' The code can be entered at the short address; no query string to type.
    m.address.text = "www.twitch.tv/activate"
    m.status.text = m.getAuth.statusMessage
    if m.getAuth.errorMessage <> ""
        m.hint.text = "Press OK to try again. Press Back to return."
    else
        m.hint.text = "Press Back to cancel."
    end if
end sub

sub startLogin()
    m.top.finished = false
    m.code.text = ""
    m.address.text = "www.twitch.tv/activate"
    m.status.text = "Getting a sign-in code..."
    m.hint.text = "Press Back to cancel."
    if m.getAuth.state = "run"
        ' Keep the old attempt cancelled until it stops; never revive its code.
        m.getAuth.cancelRequested = true
        m.retryWhenStopped = true
        return
    end if
    m.retryWhenStopped = false
    m.getAuth.finished = false
    m.getAuth.cancelRequested = false
    m.getAuth.control = "RUN"
end sub

sub onAuthStopped()
    if m.getAuth.state <> "stop" or not m.top.visible then return
    if m.retryWhenStopped
        startLogin()
    else if not m.getAuth.finished and m.getAuth.errorMessage = ""
        m.status.text = "Sign-in stopped before it completed. Please try again."
        m.hint.text = "Press OK to try again. Press Back to return."
    end if
end sub

sub onVisible()
    if m.top.visible
        startLogin()
    else
        m.retryWhenStopped = false
        m.getAuth.cancelRequested = true
        m.code.text = ""
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "OK" and m.getAuth.state <> "run"
        startLogin()
        return true
    end if
    return false
end function
