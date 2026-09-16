sub init()
    m.spinner = m.top.findNode("spinner")
    m.top.focusable = false
    updateSpinnerSize()
    updateActivity()
end sub

sub updateSpinnerSize()
    if m.spinner = invalid then return
    size = m.top.size
    if size < 16 then size = 16
    if size > 192 then size = 192
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.spinner.poster.width = size
    m.spinner.poster.height = size
    m.spinner.poster.loadDisplayMode = "scaleToFit"
end sub

sub updateActivity()
    if m.spinner = invalid then return
    running = m.top.active and m.top.enabled
    m.top.visible = running
    if running
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
    end if
end sub
