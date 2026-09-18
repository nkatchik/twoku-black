sub resetPage()
    m.top = {visible: true, finished: false, accountName: "", logoutRequested: false}
    m.getAuth = {state: "stop", control: "", finished: false, cancelRequested: false, errorMessage: "", qrUri: "", code: "", statusMessage: ""}
    m.pendingView = node()
    m.accountView = node()
    m.accountLabel = node()
    m.logoutButton = node()
    m.logoutButton.width = 260
    m.logoutButton.height = 64
    m.logoutLabel = node()
    m.backButton = node()
    m.backButton.width = 260
    m.backButton.height = 64
    m.backLabel = node()
    m.busy = node()
    m.qr = node()
    m.qrHelp = node()
    m.code = node()
    m.address = node()
    m.status = node()
    m.hint = node()
    m.retryWhenStopped = false
end sub

sub main()
    resetPage()
    onVisible()
    check(m.getAuth.control = "RUN" and m.code.text = "", "Opening login starts code request")
    check(m.busy.active and m.busy.enabled and m.status.text = "", "Pending sign-in uses a visible spinner without temporary status copy")
    whenFinished()
    check(not m.top.finished, "Resetting the task's finished field does not signal success")
    m.getAuth.code = "ABCD1234"
    m.getAuth.qrUri = "tmp:/test-qr.png"
    onAuthUpdate()
    check(m.qr.visible and m.qr.uri = "tmp:/test-qr.png" and m.qrHelp.visible, "New activation image is shown beside the manual code")
    m.getAuth.state = "run"
    m.top.visible = false
    onVisible()
    check(not m.qr.visible and m.qr.uri = "" and not m.qrHelp.visible, "Leaving login immediately hides the old QR")
    check(m.getAuth.cancelRequested and m.code.text = "", "Hiding login cancels and clears code")
    m.getAuth.finished = true
    whenFinished()
    check(not m.top.finished, "Hidden completion cannot navigate home")
    m.top.visible = true
    onVisible()
    check(m.retryWhenStopped and m.getAuth.cancelRequested, "Reopening cannot revive a cancelled attempt")
    m.getAuth.state = "stop"
    onAuthStopped()
    check(not m.retryWhenStopped and not m.getAuth.cancelRequested and not m.getAuth.finished, "Old task stops before a fresh attempt starts")
    m.getAuth.finished = true
    whenFinished()
    check(m.top.finished, "Visible approved attempt signals success")
    resetPage()
    m.getAuth.code = "ABCD1234"
    m.getAuth.qrUri = "tmp:/expired.png"
    m.getAuth.errorMessage = "Sign-in expired"
    m.getAuth.statusMessage = m.getAuth.errorMessage
    onAuthUpdate()
    check(not m.qr.visible, "Expired QR cannot remain scannable")
    check(Instr(1, m.hint.text, "OK") > 0 and m.status.text = "Sign-in expired", "Failure exposes retry hint")
    check(onKeyEvent("OK", true) and m.getAuth.control = "RUN", "OK retries a stopped attempt")
    check(not onKeyEvent("back", true), "Back bubbles to the page owner")
    resetPage()
    m.getAuth.code = "ABCD1234"
    m.getAuth.qrUri = "tmp:/stopped.png"
    onAuthUpdate()
    onAuthStopped()
    check(not m.qr.visible and m.code.text = "", "Unexpected task stop also hides the activation code")
    resetPage()
    m.top.accountName = "ExampleViewer"
    onVisible()
    check(m.accountView.visible and not m.pendingView.visible, "Signed-in chip shows the account view")
    check(m.getAuth.control = "" and m.getAuth.cancelRequested, "Viewing account never starts device authorization")
    check(m.accountLabel.text = "Logged in as ExampleViewer" and not m.busy.active, "Account view identifies current user without a loading spinner")
    check(onKeyEvent("OK", true) and m.top.backRequested and not m.top.logoutRequested, "Account initially selects Back and returns without logging out")
    m.top.backRequested = false
    check(onKeyEvent("up", true) and m.accountIndex = 0, "Up selects Log Out")
    onKeyEvent("OK", false)
    check(not m.top.logoutRequested, "Releasing OK cannot activate Log Out")
    check(onKeyEvent("OK", true) and m.top.logoutRequested, "Selected Log Out emits logout request")
    m.top.logoutRequested = false
    check(onKeyEvent("down", true) and m.accountIndex = 1, "Down returns selection to Back")
    onKeyEvent("up", true)
    onVisible()
    check(m.accountIndex = 1 and not m.top.backRequested, "Reopening the account resets selection and stale Back requests")
    m.getAuth.finished = true
    whenFinished()
    check(not m.top.finished, "Old authorization cannot replace account view")
    check(not onKeyEvent("back", true), "Account Back returns through the page owner")
    print "PASS start, account mode, logout action, cancellation, late completion, reopen, successful completion, error display, retry"
end sub
