function getApiJson(url)
    getGlobalAA().requestUrl = url
    return getGlobalAA().response
end function
function getRelativeTimePublished(value)
    return "Yesterday"
end function
function convertDurationFormat(value)
    return "01:00"
end function
function numberToText(value)
    return "5 views"
end function
sub main()
    m.top = {userId: "123", pagination: "&after=cursor", errorMessage: ""}
    getGlobalAA().response = {data: [{id: "42", user_name: "Channel", duration: "1m", title: "Test", published_at: "date", view_count: 5, thumbnail_url: "https://image/%{width}x%{height}.jpg"}], pagination: {}}
    result = getSearchResults()
    check(result.count() = 1 and result[0].user_name = "Channel", "VOD cards retain the API channel name")
    check(result[0].thumbnail_url = "https://image/320x180.jpg", "API thumbnail placeholders produce a valid card URL")
    check(m.top.pagination = "", "Terminal VOD page clears the old cursor")
    getGlobalAA().response.pagination = {cursor: "a+b="}
    getSearchResults()
    check(m.top.pagination = "&after=a%2Bb%3D", "Next VOD cursor is encoded exactly once")
    getGlobalAA().response.data[0].thumbnail_url = "https://vod-secure.twitch.tv/_404/404_processing_%{width}x%{height}.png"
    result = getSearchResults()
    check(result[0].thumbnail_url = "", "Processing thumbnails use channel artwork instead of Twitch question marks")
    getGlobalAA().response = invalid
    check(getSearchResults().count() = 0 and m.top.errorMessage <> "", "Failed VOD query reports failure instead of a false empty library")
    print "PASS VOD metadata, thumbnails, terminal pagination, encoded cursors, failure state"
end sub
