sub RunUserInterface()

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("MainScene")

    screen.show()
    ' Assign focus after the scene and all its children are attached and shown.
    scene.screenShown = true

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then
                print "EXIT"
                return
            end if
        end if
    end while

end sub
