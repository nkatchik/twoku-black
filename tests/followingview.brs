function testCreateObject(kind, name)
    result = node()
    result.getChild = function(index)
        return m.children[index]
    end function
    result.addFields = function(fields)
        for each key in fields
            m[key] = fields[key]
        end for
    end function
    result.observeField = function(field, callback)
        return true
    end function
    return result
end function

sub main()
    live = []
    offline = []
    for index = 0 to 4
        live.Push({login: "live"+index.ToStr(),title: "Live",user_name: "Name",game_id: "Game",thumbnail: "thumb",viewer_count: 100})
    end for
    for index = 0 to 7
        offline.Push({login: "offline"+index.ToStr(),display_name: "Offline",profile_image_url: "avatar"})
    end for
    model = followingRows(live,offline)
    check(model.content.getChildCount() = 4, "Live and offline populate one ordered four-row data model")
    check(model.content.getChild(0).getChildCount() = 4 and model.content.getChild(1).getChildCount() = 1, "Live section keeps four columns and a partial row")
    check(model.content.getChild(2).getChildCount() = 6 and model.content.getChild(3).getChildCount() = 2, "Offline section keeps six columns and a partial row")
    check(model.labels[0] and not model.labels[1] and model.labels[2] and not model.labels[3], "Section headings occur once and scroll with their rows")
    check(model.heights[0] = model.heights[1]+36 and model.heights[2] = model.heights[3]+36, "Section heading space is part of the single scrolling row model")
    check(model.sizes[0][1] >= 227 and model.sizes[2][1] >= 140, "Native item sizes contain captions rather than clipping them outside poster bounds")
    offline.Push({login: "live0",display_name: "Old offline snapshot",profile_image_url: "avatar"})
    check(followingRows(live,offline).content.getChild(3).getChildCount() = 2, "Live identity wins over an overlapping stale offline snapshot")
    check(followingRows([],[]).content.getChildCount() = 0, "Empty follows creates no selectable placeholder rows")
    m.top = node()
    m.top.visible = true
    m.grid = node()
    m.top.appendChild(m.grid)
    m.focusLogin = "offline4"
    m.top.liveStreams = live
    m.top.offlineChannels = offline
    m.grid.setFocus(true)
    onContentChanged()
    check(m.grid.jumpToRowItem[0] = 2 and m.grid.jumpToRowItem[1] = 4, "Refresh retains focused offline identity across sections")
    check(m.grid.hasFocus(), "Refreshing data retains actual native grid focus")
    m.top.liveStreams = []
    onContentChanged()
    check(m.grid.jumpToRowItem[0] = 0 and m.grid.jumpToRowItem[1] = 4, "Selected identity follows its new row after live section disappears")
    m.top.liveStreams = live
    m.top.offlineChannels = []
    m.focusLogin = "live3"
    onContentChanged()
    m.top.offlineChannels = offline
    onContentChanged()
    check(m.grid.jumpToRowItem[0] = 0 and m.grid.jumpToRowItem[1] = 3, "Late offline arrival preserves the current live selection")
    m.grid.rowItemSelected = [2,1]
    onItemSelected()
    check(m.top.selectedItem.ShortDescriptionLine1 = "offline1", "Offline selection uses the same list event path")
    m.grid.rowItemFocused = [0,2]
    check(onKeyEvent("options",true), "Channel-details shortcut is handled on live cards")
    check(m.top.channelRequested.ShortDescriptionLine1 = "live2", "Details shortcut preserves focused live identity")
    m.focusCursor = node()
    m.liveFocus = node()
    m.offlineFocus = node()
    m.grid.setFocus(true)
    m.focusPosition = [0,0]
    m.grid.stride = 288 + 14
    m.grid.subBoundingRect = function(part)
        return {x:Right(part,1).ToInt()*m.stride,y:42}
    end function
    m.grid.content.focusState = [0,1,true,1,0.5,false]
    m.grid.currFocusColumn = 0.5
    onFocusColumnChanged()
    check(m.focusCursor.visible and Abs(m.focusCursor.translation[0] - (288 + 14) / 2) < 0.01 and m.liveFocus.visible, "Single solid live cursor follows native horizontal motion")
    m.grid.content.focusState = [0,1,true,0,0.5,false]
    updateFollowingFocus()
    check(Abs(m.focusCursor.translation[0] - (288 + 14) / 2) < 0.01, "Outgoing item updates cannot pull the cursor backwards")
    m.grid.content.focusState = [2,0.5,true,5,1,false]
    updateFollowingFocus()
    check(not m.focusCursor.visible, "Vertical animation hides the cursor without fading")
    m.grid.stride = 200.8
    m.grid.content.focusState = [2,1,true,5,0.996,false]
    updateFollowingFocus()
    check(m.focusCursor.visible and m.offlineFocus.visible and Abs(m.focusCursor.translation[0] - 1004) < 0.01, "Finished vertical scrolling shows the frame before delayed native item-focus notifications")
    m.grid.content.focusState = [2,1,true,5,1,true]
    updateFollowingFocus()
    check(m.focusCursor.visible and m.offlineFocus.visible and Abs(m.focusCursor.translation[0] - 1004) < 0.01, "Settled sixth avatar matches the actual focused index")
    m.grid.currFocusColumn = 5
    m.grid.stride = 288 + 14
    m.grid.content.focusState = [0,1,true,3,1,true]
    updateFollowingFocus()
    check(Abs(m.focusCursor.translation[0] - 906) < 0.01, "Moving to four-column live rows uses native selected column four")
    m.grid.stride = 200.8
    m.grid.content.focusState = [2,1,true,3,1,true]
    updateFollowingFocus()
    check(Abs(m.focusCursor.translation[0] - 602.4) < 0.01, "Returning to avatars cannot reuse stale column six")
    m.grid.currFocusColumn = 5
    onFocusColumnChanged()
    check(Abs(m.focusCursor.translation[0] - 602.4) < 0.01, "Late native column notifications cannot override a settled vertical destination")
    m.grid.content.focusState = [2,1,true,2,0.5,false]
    m.grid.currFocusColumn = 2.5
    onFocusColumnChanged()
    check(Abs(m.focusCursor.translation[0] - 502) < 0.01, "Left moves visually from column four toward column three")
    ' Direction changes during an unfinished move must not restart interpolation
    ' from the last settled item or trust an older incoming-item callback.
    m.grid.content.focusState = [2,1,true,4,0.3,false]
    updateFollowingFocus()
    check(Abs(m.focusCursor.translation[0] - 502) < 0.01, "An obsolete incoming item cannot move the shared cursor")
    for each column in [2.7,3.1,3.4,3.2,2.8,2.1]
        m.grid.currFocusColumn = column
        onFocusColumnChanged()
        check(Abs(m.focusCursor.translation[0] - column * 200.8) < 0.01, "Rapid reversals follow only native cursor motion")
        m.grid.content.focusState = [2,1,true,5,0.6,false]
        updateFollowingFocus()
        check(Abs(m.focusCursor.translation[0] - column * 200.8) < 0.01, "Interleaved item callbacks cannot fight native animation")
    end for
    m.grid.content.focusState = [2,1,true,2,1,true]
    updateFollowingFocus()
    check(m.focusPosition[1] = 2 and Abs(m.focusCursor.translation[0] - 401.6) < 0.01, "The final settled item restores exact logical and visual selection")
    m.grid.setFocus(false)
    updateFollowingFocus()
    check(not m.focusCursor.visible, "Returning to header hides shared focus")
    print "PASS single Following row model, partial sections, refresh identity, late arrival, unified selection"
end sub
