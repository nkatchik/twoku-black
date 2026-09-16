sub main()
    root = {focusState: [-1,0,false]}
    row = {parent:root,getParent:function():return m.parent:end function}
    item = {parent:row,getParent:function():return m.parent:end function}
    m.top = {itemContent:item,rowIndex:2,itemHasFocus:false,rowListHasFocus:true,focusPercent:0.5,rowFocusPercent:1.0}
    m.live = {visible:true}
    m.offline = {visible:false}
    onItemFocus()
    check(root.focusState[0] = 2 and root.focusState[1] = 1, "Horizontal interpolation never changes cursor opacity")
    m.top.rowFocusPercent = 0.5
    onItemFocus()
    check(root.focusState[1] = 0.5, "Vertical movement signals the shared cursor to wait for settlement")
    m.top.rowFocusPercent = 1
    m.top.itemHasFocus = true
    m.live.visible = false
    m.offline.visible = true
    onItemFocus()
    check(root.focusState[1] = 1 and m.offline.itemHasFocus, "Settled offline row restores solid shared focus")
    m.top.rowListHasFocus = false
    onItemFocus()
    check(not root.focusState[2] and not m.offline.itemHasFocus, "Header focus hides the shared cursor")
    print "PASS Following shared cursor signals without fading individual items"
end sub
