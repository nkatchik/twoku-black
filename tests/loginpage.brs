sub resetPage()
    m.top = {visible: true, finished: false}
    m.getAuth = {state: "stop", control: "", finished: false, cancelRequested: false, errorMessage: "", qrUri: "", code: "", statusMessage: ""}
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
    print "PASS start, cancellation, late completion, reopen, successful completion, error display, retry"
end sub
