sub check(condition, message)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub

function node()
    g = getGlobalAA()
    if g.nextNodeId = invalid then g.nextNodeId = 0
    g.nextNodeId += 1
    return {
        testId: g.nextNodeId, parent: invalid,
        visible: false, focused: false, content: invalid, rowItemFocused: [0, 0], numRows: 3,
        children: [], state: "stop", control: "", errorMessage: "", pagination: "",
        setFocus: function(value)
            g = getGlobalAA()
            if value
                g.focusNode = m
            else if m.hasFocus()
                g.focusNode = invalid
            end if
            return true
        end function,
        hasFocus: function()
            current = getGlobalAA().focusNode
            if current = invalid then return false
            return current.testId = m.testId
        end function,
        isInFocusChain: function()
            current = getGlobalAA().focusNode
            while current <> invalid
                if current.testId = m.testId then return true
                current = current.parent
            end while
            return false
        end function,
        appendChild: function(child)
            child.parent = m
            m.children.push(child)
        end function,
        appendChildren: function(children)
            for each child in children
                m.appendChild(child)
            end for
            return true
        end function,
        getChild: function(index)
            return m.children[index]
        end function,
        getChildCount: function()
            return m.children.count()
        end function,
        signalBeacon: function(name)
            m.beacon = name
        end function
    }
end function
