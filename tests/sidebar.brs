sub main()
    m.top = node()
    m.top.loggedIn = false
    m.top.loginRequested = false
    m.emptyLabel = node()
    m.emptyHint = node()
    m.emptyHintText = node()
    m.children = []
    updateEmptyState()
    check(m.emptyLabel.visible and m.emptyLabel.text = "Login", "Signed-out rail has a Login placeholder")
    check(not m.emptyHint.visible, "Empty hint stays collapsed without focus")
    m.top.focused = true
    updateEmptyState()
    check(m.emptyHint.visible, "Focused empty rail explains sign-in")
    check(onKeyEvent("up", true) and onKeyEvent("down", true), "Empty rail handles arrows without indexing missing children")
    check(not onKeyEvent("right", true), "Right bubbles back to Home")
    check(onKeyEvent("OK", true) and m.top.loginRequested, "OK opens sign-in from empty rail")
    m.top.loggedIn = true
    m.top.loginRequested = false
    updateEmptyState()
    check(m.emptyLabel.text = "None", "Signed-in empty rail has a distinct state")
    check(onKeyEvent("OK", true) and not m.top.loginRequested, "Empty signed-in rail does not select a missing channel")
    m.children.push(node())
    updateEmptyState()
    check(not m.emptyLabel.visible and not m.emptyHint.visible, "Channel content replaces the placeholder")
    print "PASS signed-out rail, empty arrows, login action, return to Home, populated rail"
end sub
