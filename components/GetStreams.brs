function init()
    m.top.functionName = "onSearchTextChange"
end function

function onSearchTextChange()
    m.top.errorMessage = ""
    m.top.searchResults = getSearchResults()
end function

function getSearchResults() as Object
    link = "https://api.twitch.tv/helix/streams?first=24"
    if m.top.gameRequested <> ""
        link += "&game_id=" + m.top.gameRequested.EncodeUriComponent()
    end if
    search = getApiJson(link + m.top.pagination)
    result = []
    if search = invalid
        m.top.errorMessage = m.requestError
        return result
    end if
    if type(search.data) <> "roArray"
        m.top.errorMessage = "Twitch returned an invalid channel list. Try again."
        return result
    end if
    for each stream in search.data
        if type(stream) = "roAssociativeArray"
            if stream.user_login <> invalid and stream.thumbnail_url <> invalid
                result.push({
                    id: stream.user_id,
                    display_name: stream.user_name,
                    game_id: stream.game_id,
                    game: stream.game_name,
                    name: stream.user_login,
                    title: stream.title,
                    viewers: stream.viewer_count,
                    thumbnail: stream.thumbnail_url.Replace("{width}", "320").Replace("{height}", "180")
                })
            end if
        end if
    end for
    m.top.pagination = ""
    if type(search.pagination) = "roAssociativeArray"
        if GetInterface(search.pagination.cursor, "ifString") <> invalid
            m.top.pagination = "&after=" + search.pagination.cursor.EncodeUriComponent()
        end if
    end if
    return result
end function
