sub init()
    m.top.focusable = true
    m.grid = m.top.findNode("grid")
    m.focusCursor = m.top.findNode("focusCursor")
    m.liveFocus = m.top.findNode("liveFocus")
    m.offlineFocus = m.top.findNode("offlineFocus")
    m.grid.observeField("rowItemFocused", "onItemFocused")
    m.grid.observeField("rowItemSelected", "onItemSelected")
    m.grid.observeField("currFocusColumn", "onFocusColumnChanged")
    m.top.observeField("visible", "updateFollowingFocus")
    m.focusLogin = ""
    m.focusPosition = [0,0]
    m.cursorColumn = 0
end sub

function followingCount(items) as Integer
    if type(items) = "roArray" then return items.Count()
    return 0
end function

function followingViewerCount(count) as String
    if count = invalid then return ""
    if count >= 1000000 then return (Int(count / 100000) / 10).ToStr() + "M"
    if count >= 1000 then return (Int(count / 100) / 10).ToStr() + "K"
    return count.ToStr().Trim()
end function

function followingRows(liveStreams, offlineChannels) as Object
    content = CreateObject("roSGNode", "ContentNode")
    content.addFields({focusState: [-1,0,false,0,0,false]})
    heights = []
    sizes = []
    spacings = []
    labels = []
    seen = {}
    for section = 0 to 1
        columns = 4
        items = liveStreams
        title = "Live channels"
        if section = 1
            columns = 6
            items = offlineChannels
            title = "Offline channels"
        end if
        count = 0
        row = invalid
        for index = 0 to followingCount(items) - 1
            stream = items[index]
            login = stream.login
            if login <> invalid and login <> "" and not seen.DoesExist(login)
                seen[login] = true
                if count MOD columns = 0
                    row = CreateObject("roSGNode", "ContentNode")
                    row.Title = ""
                    first = count = 0
                    if first then row.Title = title
                    content.appendChild(row)
                    labels.Push(first)
                    if section = 0
                        height = 247
                        if first then height += 36
                        heights.Push(height)
                        sizes.Push([292,227])
                        spacings.Push([(1194 - 4 * 292) / 3,0])
                    else
                        height = 160
                        if first then height += 36
                        heights.Push(height)
                        sizes.Push([190,140])
                        spacings.Push([(1194 - 6 * 190) / 5,0])
                    end if
                end if
                item = CreateObject("roSGNode", "ContentNode")
                item.ShortDescriptionLine1 = login
                if section = 0
                    item.addFields({followKind: "live"})
                    item.Title = stream.title
                    item.Description = stream.user_name
                    item.Categories = stream.game_id
                    item.HDPosterUrl = stream.thumbnail
                    item.ShortDescriptionLine2 = followingViewerCount(stream.viewer_count)
                else
                    item.addFields({followKind: "offline"})
                    item.Title = stream.display_name
                    item.Description = stream.display_name
                    item.HDPosterUrl = stream.profile_image_url
                end if
                row.appendChild(item)
                count += 1
            end if
        end for
    end for
    return {content: content, heights: heights, sizes: sizes, spacings: spacings, labels: labels}
end function

sub onContentChanged()
    if m.grid = invalid then return
    focused = m.top.isInFocusChain()
    model = followingRows(m.top.liveStreams, m.top.offlineChannels)
    model.content.observeField("focusState", "updateFollowingFocus")
    position = [0,0]
    for rowIndex = 0 to model.content.getChildCount() - 1
        row = model.content.getChild(rowIndex)
        for col = 0 to row.getChildCount() - 1
            if row.getChild(col).ShortDescriptionLine1 = m.focusLogin then position = [rowIndex,col]
        end for
    end for
    m.grid.rowHeights = model.heights
    if model.sizes.Count() = 0 then model.sizes = [[292,227]]
    m.grid.rowItemSize = model.sizes
    m.grid.rowItemSpacing = model.spacings
    m.grid.showRowLabel = model.labels
    m.focusPosition = position
    m.cursorColumn = position[1]
    m.grid.content = model.content
    m.top.hasItems = model.content.getChildCount() > 0
    m.top.focusedItem = invalid
    if m.top.hasItems
        m.grid.jumpToRowItem = position
        m.top.focusedItem = model.content.getChild(position[0]).getChild(position[1])
        m.focusLogin = m.top.focusedItem.ShortDescriptionLine1
        if focused then m.grid.setFocus(true)
    else
        m.focusLogin = ""
    end if
    updateFollowingFocus()
end sub

sub focusContent()
    if m.top.visible and m.top.hasItems then m.grid.setFocus(true)
end sub

function itemAt(position) as Object
    if m.grid.content = invalid or position = invalid then return invalid
    if position.Count() < 2 then return invalid
    row = m.grid.content.getChild(position[0])
    if row = invalid then return invalid
    return row.getChild(position[1])
end function

sub onItemFocused()
    item = itemAt(m.grid.rowItemFocused)
    if item = invalid then return
    m.top.focusedItem = item
    m.focusLogin = item.ShortDescriptionLine1
    m.focusPosition = m.grid.rowItemFocused
    m.cursorColumn = m.focusPosition[1]
    updateFollowingFocus()
end sub

sub updateFollowingFocus()
    if m.grid.content <> invalid
        state = m.grid.content.focusState
        if state[1] = 1 and (state[5] or state[0] <> m.focusPosition[0])
            ' The row animation can finish before rowItemFocused/itemHasFocus
            ' arrives. Show its frame now instead of waiting for that second
            ' notification. Settled items still correct stale native columns.
            m.focusPosition = [state[0],state[3]]
            m.cursorColumn = state[3]
        end if
    end if
    renderFollowingCursor()
end sub

sub onFocusColumnChanged()
    ' Native motion stays continuous when another key interrupts a transition.
    ' Individual incoming/outgoing focusPercent callbacks cannot be combined
    ' into one interpolation after the destination changes midway through it.
    if m.grid.content = invalid then return
    ' A late column notification after a vertical move must not override the
    ' settled native item. Floating columns are needed only while it is moving.
    if not m.grid.content.focusState[5] then m.cursorColumn = m.grid.currFocusColumn
    renderFollowingCursor()
end sub

sub renderFollowingCursor()
    if m.focusCursor = invalid then return
    if not m.top.visible or not m.grid.hasFocus() or m.grid.content = invalid
        m.focusCursor.visible = false
        return
    end if
    state = m.grid.content.focusState
    ' Vertical movement snaps into place once the new row has settled.
    if state[0] < 0 or state[1] < 1 or not state[2]
        m.focusCursor.visible = false
        return
    end if
    if state[0] <> m.focusPosition[0]
        m.focusCursor.visible = false
        return
    end if
    row = m.grid.content.getChild(state[0])
    if row = invalid or row.getChildCount() = 0 then return
    column = m.cursorColumn
    if column < 0 then column = 0
    if column > row.getChildCount() - 1 then column = row.getChildCount() - 1
    index = Int(column)
    item = row.getChild(index)
    live = item.followKind = "live"
    stride = m.grid.rowItemSize[state[0]][0] + m.grid.rowItemSpacing[state[0]][0]
    rect = m.grid.subBoundingRect("item" + state[0].ToStr() + "_" + index.ToStr())
    m.focusCursor.translation = [rect.x + (column - index) * stride,rect.y]
    m.liveFocus.visible = live
    m.offlineFocus.visible = not live
    m.focusCursor.visible = true
end sub

sub onItemSelected()
    if not m.top.visible then return
    item = itemAt(m.grid.rowItemSelected)
    if item <> invalid then m.top.selectedItem = item
end sub

function onKeyEvent(key, press) as Boolean
    if not press or not m.top.visible then return false
    if key = "options"
        item = itemAt(m.grid.rowItemFocused)
        if item <> invalid then m.top.channelRequested = item
        return true
    end if
    ' The single RowList handles all live/offline boundary navigation and scrolling.
    return false
end function
