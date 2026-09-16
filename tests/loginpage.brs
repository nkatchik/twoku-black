sub resetPage()
    m.top = {visible: true, finished: false}
    m.getAuth = {state: "stop", control: "", finished: false, cancelRequested: false, errorMessage: "", code: "", statusMessage: ""}
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
    m.getAuth.state = "run"
    m.top.visible = false
    onVisible()
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
    m.getAuth.errorMessage = "Sign-in expired"
    m.getAuth.statusMessage = m.getAuth.errorMessage
    onAuthUpdate()
    check(Instr(1, m.hint.text, "OK") > 0 and m.status.text = "Sign-in expired", "Failure exposes retry hint")
    check(onKeyEvent("OK", true) and m.getAuth.control = "RUN", "OK retries a stopped attempt")
    check(not onKeyEvent("back", true), "Back bubbles to the page owner")
    print "PASS start, cancellation, late completion, reopen, successful completion, error display, retry"
end sub
