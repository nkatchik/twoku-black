function testCreateObject(kind)
    if kind = "roMessagePort" then return {}
    return {
        setMessagePort: sub(port)
        end sub,
        CreateScene: function(name)
            getGlobalAA().scene = {screenShown: false}
            return getGlobalAA().scene
        end function,
        show: sub()
            check(not getGlobalAA().scene.screenShown, "Focus handoff must follow screen.show")
            getGlobalAA().shown = true
        end sub
    }
end function

function testWait(timeout, port)
    check(getGlobalAA().shown and getGlobalAA().scene.screenShown, "Main loop starts after post-show focus request")
    return {isScreenClosed: function()
        return true
    end function}
end function

function testType(value)
    return "roSGScreenEvent"
end function

sub main()
    RunUserInterface()
    print "PASS screen presentation precedes focus handoff and main event loop"
end sub
