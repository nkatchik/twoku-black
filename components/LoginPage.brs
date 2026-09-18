sub init()
    m.top.focusable = true
    m.pendingView = m.top.findNode("pendingView")
    m.accountView = m.top.findNode("accountView")
    m.accountLabel = m.top.findNode("accountLabel")
    m.logoutButton = m.top.findNode("logoutButton")
    m.logoutLabel = m.top.findNode("logoutLabel")
    m.backButton = m.top.findNode("backButton")
    m.backLabel = m.top.findNode("backLabel")
    m.busy = m.top.findNode("busy")
    m.code = m.top.findNode("code")
    m.qr = m.top.findNode("qr")
    m.qrHelp = m.top.findNode("qrHelp")
    m.address = m.top.findNode("address")
    m.status = m.top.findNode("status")
    m.hint = m.top.findNode("hint")
    m.retryWhenStopped = false
    m.top.observeField("visible", "onVisible")
    m.getAuth = createObject("roSGNode", "GetAuth")
    m.getAuth.observeField("code", "onAuthUpdate")
    m.getAuth.observeField("qrUri", "onAuthUpdate")
    m.getAuth.observeField("verificationUri", "onAuthUpdate")
    m.getAuth.observeField("statusMessage", "onAuthUpdate")
    m.getAuth.observeField("errorMessage", "onAuthUpdate")
    m.getAuth.observeField("finished", "whenFinished")
    m.getAuth.observeField("state", "onAuthStopped")
end sub

sub whenFinished()
    if m.top.visible and m.top.accountName = "" and not m.getAuth.cancelRequested and m.getAuth.finished
        m.top.finished = true
    end if
end sub

sub onAuthUpdate()
    if not m.top.visible or m.top.accountName <> "" or m.getAuth.cancelRequested then return
    m.code.text = m.getAuth.code
    m.qr.uri = m.getAuth.qrUri
    m.qr.visible = m.getAuth.qrUri <> "" and m.getAuth.code <> "" and m.getAuth.errorMessage = ""
    m.qrHelp.visible = m.qr.visible
    ' The code can be entered at the short address; no query string to type.
    m.address.text = "www.twitch.tv/activate"
    m.status.text = m.getAuth.errorMessage
    m.busy.active = m.getAuth.code = "" and m.getAuth.errorMessage = ""
    if m.getAuth.errorMessage <> ""
        m.hint.text = "Press OK to try again. Press Back to return."
    else
        m.hint.text = "Press Back to cancel."
    end if
end sub

sub startLogin()
    if m.top.accountName <> "" then return
    m.pendingView.visible = true
    m.accountView.visible = false
    m.busy.active = true
    m.top.finished = false
    clearLoginQr()
    m.code.text = ""
    m.address.text = "www.twitch.tv/activate"
    m.status.text = ""
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
    if m.getAuth.state <> "stop" or not m.top.visible or m.top.accountName <> "" then return
    if m.retryWhenStopped
        startLogin()
    else if not m.getAuth.finished and m.getAuth.errorMessage = ""
        m.busy.active = false
        clearLoginQr()
        m.code.text = ""
        m.status.text = "Sign-in stopped before it completed. Please try again."
        m.hint.text = "Press OK to try again. Press Back to return."
    end if
end sub

sub onVisible()
    m.busy.enabled = m.top.visible
    if m.top.visible
        m.top.logoutRequested = false
        m.top.backRequested = false
        if m.top.accountName <> ""
            showAccount()
        else
            startLogin()
        end if
    else
        m.busy.active = false
        m.retryWhenStopped = false
        m.getAuth.cancelRequested = true
        clearLoginQr()
        m.code.text = ""
    end if
end sub

sub showAccount()
    m.retryWhenStopped = false
    m.getAuth.cancelRequested = true
    m.top.finished = false
    clearLoginQr()
    m.code.text = ""
    m.busy.active = false
    m.pendingView.visible = false
    m.accountView.visible = true
    m.accountLabel.text = "Logged in as " + m.top.accountName
    m.accountIndex = 1
    updateAccountFocus()
end sub

sub updateAccountFocus()
    ' The existing 260-by-64 button is the selected size on this page.
    applyButtonFocus(m.logoutButton, m.logoutButton, m.logoutLabel, m.accountIndex = 0, 1.0)
    applyButtonFocus(m.backButton, m.backButton, m.backLabel, m.accountIndex = 1, 1.0)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if m.top.accountName <> ""
        if press
            if key = "up"
                m.accountIndex = 0
                updateAccountFocus()
            else if key = "down"
                m.accountIndex = 1
                updateAccountFocus()
            else if key = "OK"
                if m.accountIndex = 0
                    m.top.logoutRequested = true
                else
                    m.top.backRequested = true
                end if
            end if
        end if
        return key <> "back" and key <> "home"
    end if
    if press and key = "OK" and m.getAuth.state <> "run"
        startLogin()
        return true
    end if
    return false
end function

sub clearLoginQr()
    m.qr.uri = ""
    m.qr.visible = false
    m.qrHelp.visible = false
end sub
