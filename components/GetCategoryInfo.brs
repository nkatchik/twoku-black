sub init()
    m.top.functionName = "getCategoryInfo"
end sub

function categoryInfoPayload(id as String) as Object
    query = "query GameInfo($id: ID!) { game(id: $id) { id description } }"
    return {operationName: "GameInfo", query: query, variables: {id: id}}
end function

sub getCategoryInfo()
    id = m.top.categoryId
    requestId = m.top.requestId
    if id = "" or m.top.cancelRequested then return
    transfer = createHttpUrl()
    transfer.AddHeader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.SetUrl("https://gql.twitch.tv/gql")
    response = requestText(transfer, FormatJson(categoryInfoPayload(id)), 10000, false)
    if m.top.cancelRequested or m.top.categoryId <> id or m.top.requestId <> requestId then return
    if response.error <> "" then return
    data = ParseJson(response.body)
    if type(data) <> "roAssociativeArray" then return
    if type(data.data) <> "roAssociativeArray" then return
    game = data.data.game
    if type(game) <> "roAssociativeArray" then return
    if game.id <> id then return
    description = ""
    if nonEmptyString(game.description) then description = game.description.Trim()
    m.top.info = {id: id, description: description}
end sub
