function getApiJson(link)
    m.link = link
    return m.response
end function

sub main()
    m.top = {gameRequested: "", pagination: "", errorMessage: ""}
    m.response = invalid
    m.requestError = "offline"
    check(getSearchResults().count() = 0 and m.top.errorMessage = "offline", "Offline streams return error")
    m.response = {}
    check(getSearchResults().count() = 0, "Missing data is handled")
    m.response = {data: []}
    check(getSearchResults().count() = 0 and m.top.pagination = "", "Empty list without pagination is valid")
    m.top.gameRequested = "123"
    m.response = {data: [{user_id: "1", user_name: "Streamer", user_login: "streamer", game_id: "123", game_name: "Game", title: "Live", viewer_count: 5, thumbnail_url: "https://example.invalid/{width}x{height}.jpg"}], pagination: {cursor: "next"}}
    results = getSearchResults()
    check(results.count() = 1 and results[0].name = "streamer", "Stream login comes from stream response")
    check(results[0].game = "Game", "Game name needs no extra request")
    check(results[0].thumbnail = "https://example.invalid/320x180.jpg", "Thumbnail dimensions replaced")
    check(m.top.pagination = "&after=next", "Cursor preserved")
    check(instr(1, m.link, "game_id=123") > 0, "Category filter preserved")
    print "PASS stream errors, empty results, direct metadata, thumbnails, pagination"
end sub
