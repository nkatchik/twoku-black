function init()
    m.top.functionName = "onSearchTextChange"
end function

function onSearchTextChange()
    m.top.errorMessage = ""
    m.top.searchResults = getSearchResults()
end function

function getSearchResults() as Object
    search = getApiJson("https://api.twitch.tv/helix/games/top?first=24" + m.top.pagination)
    result = []
    if search = invalid
        m.top.errorMessage = m.requestError
        return result
    end if
    if type(search.data) <> "roArray"
        m.top.errorMessage = "Twitch returned an invalid category list. Try again."
        return result
    end if
    for each category in search.data
        if type(category) = "roAssociativeArray"
            if category.id <> invalid and category.box_art_url <> invalid
                result.push({
                    id: category.id,
                    name: category.name,
                    logo: category.box_art_url.Replace("{width}", "136").Replace("{height}", "190"),
                    viewers: 0
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
