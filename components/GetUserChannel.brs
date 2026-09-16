sub init()
    m.top.functionName = "onSearchTextChange"
end sub

sub onSearchTextChange()
    m.top.searchResults = getSearchResults()
end sub

function getSearchResults() as Object
    login = m.top.loginRequested
    response = getApiJson("https://api.twitch.tv/helix/users?login=" + login.EncodeUriComponent())
    if response = invalid or response.data = invalid then return {}
    if response.data.count() = 0 then return {}
    user = response.data[0]
    return {
        id: user.id,
        display_name: user.display_name,
        description: user.description,
        profile_image_url: user.profile_image_url
    }
end function
