function getApiJson(link)
    return m.response
end function

sub main()
    m.top = {pagination: "", errorMessage: ""}
    m.response = invalid
    m.requestError = "offline"
    check(getSearchResults().count() = 0 and m.top.errorMessage = "offline", "Offline categories return error")
    m.response = {data: []}
    check(getSearchResults().count() = 0 and m.top.pagination = "", "No cursor is valid")
    m.response = {data: [{id: "1", name: "Game", box_art_url: "https://example.invalid/{width}x{height}.jpg"}]}
    result = getSearchResults()
    check(result.count() = 1 and result[0].logo = "https://example.invalid/285x380.jpg", "Covers match the rendered Games card instead of stretching a half-size image")
    print "PASS category errors, empty results, missing cursor, thumbnails"
end sub
