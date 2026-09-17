
function init()
    m.top.functionName = "onSearchTextChange"
end function

function onSearchTextChange()

    m.top.searchResults = getSearchResults()

end function

function getSearchResults() as Object
    search_results_url = "https://api.twitch.tv/helix/search/categories?first=5&query=" + m.top.searchText.EncodeUriComponent()

    ' url = CreateObject("roUrlTransfer")
    ' url.EnableEncodings(true)
    ' url.RetainBodyOnError(true)
    ' url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ' url.AddHeader("Accept", "application/vnd.twitchtv.v5+json")
    ' url.InitClientCertificates()
    ' url.SetUrl(search_results_url.EncodeUri())

    ' response_string = url.GetToString()
    ' search = ParseJson(response_string)
    search = GETJSON(search_results_url)

    result = []
    if search <> invalid and search.data <> invalid
        for each game in search.data
            item = {}
            item.id = game.id
            item.name = game.name
            item.logo = game.box_art_url
            result.push(item)
        end for
    end if

    return result
end function
