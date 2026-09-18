sub init()
    m.heldDown = false
    m.repeatTimer = m.top.findNode("rowRepeatTimer")
    m.repeatTimer.observeField("fire", "onRowRepeat")
    m.top.observeField("focusedChild", "onGridFocusChanged")
    m.top.observeField("visible", "onGridFocusChanged")
    m.top.observeField("content", "resetRowHold")
    m.top.observeField("rowItemFocused", "onRowFocused")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press
        if key <> "down" or not m.heldDown then return false
        stopRowHold()
        return true
    end if
    if key <> "down"
        resetRowHold()
        return false
    end if
    ' IR repeats must not restart the initial delay or add a second step.
    if m.heldDown then return true
    if m.top.content = invalid or m.top.rowItemFocused.Count() <> 2 then return false
    if m.top.content.getChildCount() = 0 then return false
    ' Keep the last target across quick taps: native focus can still be animating.
    if m.top.navigationRow < 0
        m.top.navigationRow = m.top.rowItemFocused[0]
        m.navigationColumn = m.top.rowItemFocused[1]
    end if
    m.heldDown = true
    moveDownRow()
    m.repeatTimer.duration = 0.4
    m.repeatTimer.control = "start"
    return true
end function

sub onRowRepeat()
    if not m.heldDown then return
    if not m.top.hasFocus() or not m.top.visible
        resetRowHold()
        return
    end if
    moveDownRow()
    m.repeatTimer.duration = 0.12
    m.repeatTimer.control = "start"
end sub

sub moveDownRow()
    if m.top.content = invalid then return
    row = m.top.navigationRow + 1
    if row >= m.top.content.getChildCount() then return
    ' Native held scrolling caches its last row at key-down. Step with native
    ' animation instead, checking the current content length on every repeat.
    ' At a loading boundary the timer waits here and resumes when rows arrive.
    m.top.navigationRow = row
    m.top.animateToItem = row
end sub

sub onGridFocusChanged()
    if not m.top.hasFocus() or not m.top.visible then resetRowHold()
end sub

sub onRowFocused()
    position = m.top.rowItemFocused
    if m.top.navigationRow < 0 or position.Count() <> 2 or m.top.scrollingStatus then return
    if position[0] <> m.top.navigationRow or m.top.content = invalid then return
    row = m.top.content.getChild(position[0])
    if row = invalid then return
    column = m.navigationColumn
    if column >= row.getChildCount() then column = row.getChildCount() - 1
    ' Newly created native rows default to column zero. Correct only the column
    ' after the requested row settles; never replay a row during its animation.
    if column >= 0 and position[1] <> column then m.top.jumpToRowItem = [position[0], column]
end sub

sub stopRowHold()
    m.heldDown = false
    m.repeatTimer.control = "stop"
end sub

sub resetRowHold()
    stopRowHold()
    m.top.navigationRow = -1
end sub
