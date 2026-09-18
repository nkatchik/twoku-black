sub speedUpFocus(node as Object)
    kind = node.subtype()
    ' Apply once at startup. This native field is firmware-dependent; preserve
    ' the different list/grid defaults and leave older firmware unchanged.
    if (kind = "RowList" or kind = "PagedRowList" or kind = "MarkupList") and node.hasField("scrollSpeed")
        node.scrollSpeed *= 1.5
    end if
    for each child in node.getChildren(-1, 0)
        speedUpFocus(child)
    end for
end sub

sub syncRowFocusSpeed(item as Object)
    ' RowList's speed only controls vertical scrolling. Its private horizontal
    ' MarkupGrid is accessible through an attached item's parent chain, but is
    ' absent from RowList.getChildren(). Apply the row owner's speed each time
    ' an item is populated so new/recycled rows match without compounding it.
    grid = invalid
    ancestor = item.getParent()
    while ancestor <> invalid
        kind = ancestor.subtype()
        if kind = "MarkupGrid" then grid = ancestor
        if kind = "RowList" or kind = "PagedRowList"
            if grid <> invalid and ancestor.hasField("scrollSpeed")
                if grid.hasField("scrollSpeed") then grid.scrollSpeed = ancestor.scrollSpeed
            end if
            return
        end if
        ancestor = ancestor.getParent()
    end while
end sub
