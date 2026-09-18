sub main()
    root = motionNode("Scene")
    group = motionNode("Group")
    rows = motionNode("RowList", 3.0)
    search = motionNode("MarkupList", 5.0)
    title = motionNode("ScrollingLabel", 100.0)
    paged = motionNode("PagedRowList", 3.0)
    legacy = motionNode("RowList")
    group.children = [rows, paged, search, title, legacy]
    root.children = [group]
    speedUpFocus(root)
    check(rows.scrollSpeed = 4.5 and search.scrollSpeed = 7.5, "Nested grids and search lists get the same proportional increase")
    check(title.scrollSpeed = 100 and not legacy.hasField("scrollSpeed"), "Text scrolling and firmware without the native field are untouched")

    ' Native RowList does not expose this subtree through getChildren().
    row = motionNode("RowListItem")
    row.parent = rows
    horizontal = motionNode("MarkupGrid", 3.0)
    horizontal.parent = row
    wrapper = motionNode("FollowingItem")
    wrapper.parent = horizontal
    item = motionNode("BrowseChannelItem")
    item.parent = wrapper
    for index = 1 to 24
        syncRowFocusSpeed(item)
    end for
    check(horizontal.scrollSpeed = 4.5, "Populating/recycling many cards synchronizes a private row without compounding its speed")
    check(rows.scrollSpeed = 4.5, "Synchronizing horizontal motion does not multiply the owner again")

    row.parent = paged
    syncRowFocusSpeed(item)
    check(paged.scrollSpeed = 4.5 and horizontal.scrollSpeed = 4.5, "Paginated RowList subclasses retain both vertical and horizontal speeds")

    row.parent = legacy
    horizontal.scrollSpeed = 3.0
    syncRowFocusSpeed(item)
    check(horizontal.scrollSpeed = 3, "An older row owner leaves its private grid at the firmware default")
    row.parent = rows
    horizontal.Delete("scrollSpeed")
    syncRowFocusSpeed(item)
    check(not horizontal.hasField("scrollSpeed"), "Missing private speed support does not create a fake field")
    syncRowFocusSpeed(motionNode("BrowseCategoryItem"))
    print "PASS native focus speed, private horizontal rows, recycling, and older firmware"
end sub

function motionNode(kind, speed = invalid)
    result = {kind:kind, parent:invalid, children:[]}
    if speed <> invalid then result.scrollSpeed = speed
    result.subtype = function(): return m.kind: end function
    result.hasField = function(name): return m.DoesExist(name): end function
    result.getParent = function(): return m.parent: end function
    result.getChildren = function(count, start): return m.children: end function
    return result
end function
