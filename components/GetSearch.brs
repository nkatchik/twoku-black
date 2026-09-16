sub init()
    m.top.functionName = "onSearchTextChange"
end sub

sub onSearchTextChange()
    m.top.searchResults = getSearchResults()
end sub

function getSearchResults() as Object
    search = GETJSON("https://api.twitch.tv/helix/search/channels?first=5&query=" + m.top.searchText.EncodeUriComponent())
    result = []
    if search = invalid or search.data = invalid then return result
    for each channel in search.data
        logo = channel.thumbnail_url
        if logo = invalid then logo = ""
        result.push({
            id: channel.id,
            login: channel.broadcaster_login,
            name: channel.display_name,
            logo: logo,
            is_live: channel.is_live,
            title: channel.title,
            game: channel.game_name
        })
    end for
    return result
end function
