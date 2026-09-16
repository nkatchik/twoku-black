sub init()
    m.top.functionName = "onSearchTextChange"
end sub

sub onSearchTextChange()
    m.top.searchResults = getSearchResults()
end sub

function getStartDate() as String
    date = CreateObject("roDateTime")
    date.FromSeconds(date.AsSeconds() - 604800)
    return date.ToISOString()
end function

function getSearchResults() as Object
    m.top.errorMessage = ""
    url = "https://api.twitch.tv/helix/clips?first=24&started_at=" + getStartDate().EncodeUriComponent()
    if m.top.gameRequested <> "" then url += "&game_id=" + m.top.gameRequested.EncodeUriComponent()
    url += m.top.pagination
    search = getApiJson(url)
    if type(search) <> "roAssociativeArray"
        m.top.errorMessage = "Could not load clips. Select Clips to retry."
        return []
    end if
    if type(search.data) <> "roArray"
        m.top.errorMessage = "Twitch returned an invalid clip list."
        return []
    end if
    result = []
    for each clip in search.data
        if nonEmptyString(clip.id)
            result.Push({id: clip.id, broadcaster_name: clip.broadcaster_name, creator_name: clip.creator_name, title: clip.title, viewer_count: clip.view_count, thumbnail_url: clip.thumbnail_url})
        end if
    end for
    m.top.pagination = ""
    if type(search.pagination) = "roAssociativeArray"
        if nonEmptyString(search.pagination.cursor) then m.top.pagination = "&after=" + search.pagination.cursor.EncodeUriComponent()
    end if
    return result
end function
