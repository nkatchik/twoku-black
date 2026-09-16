function testCreateObject(kind, name = invalid)
    return {
        AsSeconds: function()
            return 1709251200
        end function,
        FromSeconds: sub(value)
            check(value = 1708646400, "Clip period subtracts exactly seven days across a month boundary")
        end sub,
        ToISOString: function()
            return "2024-02-23T00:00:00Z"
        end function
    }
end function

function getApiJson(url)
    m.requestedUrl = url
    return m.response
end function

sub main()
    m.top = {gameRequested: "game&id", pagination: "", errorMessage: ""}
    m.response = {data: [{id: "ClipSlug", title: "Clip", broadcaster_name: "Streamer", creator_name: "Viewer", view_count: 4, thumbnail_url: "preview"}], pagination: {cursor: "next&cursor"}}
    result = getSearchResults()
    check(result[0].id = "ClipSlug", "Feed preserves the slug used for actual clip playback")
    check(Instr(1, m.requestedUrl, "game_id=game%26id") > 0, "Clip category ID is safely encoded")
    check(m.top.pagination = "&after=next%26cursor", "Clip cursor is encoded")
    m.response = {data: [], pagination: {}}
    result = getSearchResults()
    check(result.Count() = 0 and m.top.pagination = "", "Last clip page clears stale cursor")
    m.response = invalid
    result = getSearchResults()
    check(result.Count() = 0 and m.top.errorMessage <> "", "Clip feed failure has visible retry state")
    print "PASS clip slugs, seven-day window, encoded category/cursor, terminal pagination, errors"
end sub
