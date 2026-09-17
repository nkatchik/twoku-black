' Shared by the four-column browse grids. Keep existing content nodes attached:
' replacing content or replaying rowItemFocused cancels native scroll animation.
sub appendGridItems(list, items, reset = false as Boolean)
    content = list.content
    if reset or content = invalid then content = CreateObject("roSGNode", "ContentNode")
    wasEmpty = content.getChildCount() = 0
    index = 0
    if content.getChildCount() > 0
        tail = content.getChild(content.getChildCount() - 1)
        fill = []
        while tail.getChildCount() + fill.Count() < 4 and index < items.Count()
            fill.Push(items[index])
            index += 1
        end while
        if fill.Count() > 0 then tail.appendChildren(fill)
    end if
    rows = []
    while index < items.Count()
        row = CreateObject("roSGNode", "ContentNode")
        while row.getChildCount() < 4 and index < items.Count()
            row.appendChild(items[index])
            index += 1
        end while
        rows.Push(row)
    end while
    if rows.Count() > 0 then content.appendChildren(rows)
    if reset or list.content = invalid
        list.content = content
    end if
    if wasEmpty and content.getChildCount() > 0 then list.jumpToRowItem = [0, 0]
end sub

function gridNeedsMore(list) as Boolean
    if not list.hasFocus() or list.content = invalid then return false
    position = list.rowItemFocused
    if position.Count() <> 2 or list.content.getChildCount() = 0 then return false
    ' Start fetching with two rows in reserve beyond the visible window.
    return position[0] + list.numRows + 2 >= list.content.getChildCount()
end function

sub finishGridPage(task, requestedCursor, addedCount as Integer)
    if task.errorMessage <> "" then return
    ' A repeated cursor or a page with no new cards must not spin in a fetch loop.
    if task.pagination = requestedCursor or addedCount = 0 then task.pagination = ""
end sub
