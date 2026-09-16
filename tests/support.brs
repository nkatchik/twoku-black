sub check(condition, message)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub

function node()
    return {
        visible: false, focused: false, content: invalid, rowItemFocused: [0, 0],
        children: [], state: "stop", control: "", errorMessage: "", pagination: "",
        setFocus: function(value)
            m.focused = value
        end function,
        hasFocus: function()
            return m.focused
        end function,
        isInFocusChain: function()
            return m.focused
        end function,
        appendChild: function(child)
            m.children.push(child)
        end function,
        getChildCount: function()
            return m.children.count()
        end function,
        signalBeacon: function(name)
            m.beacon = name
        end function
    }
end function
