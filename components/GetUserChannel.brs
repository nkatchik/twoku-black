sub init()
    m.top.functionName = "onSearchTextChange"
end sub

sub onSearchTextChange()
    login = m.top.loginRequested
    result = getSearchResults()
    if login = m.top.loginRequested then m.top.searchResults = result
end sub

function getSearchResults() as Object
    login = m.top.loginRequested
    ' Channel pages use the same public follower count as Twellie. The player's
    ' avatar lookup stays on its existing single-request path.
    profile = invalid
    if m.top.includeFollowers then profile = getPublicChannelInfo(login)
    if profile = invalid
        response = getApiJson("https://api.twitch.tv/helix/users?login=" + login.EncodeUriComponent())
        if response = invalid or response.data = invalid then return {}
        if response.data.count() = 0 then return {}
        user = response.data[0]
        profile = {id: user.id, display_name: user.display_name, description: user.description, profile_image_url: user.profile_image_url, followers: invalid}
    end if
    if m.top.includeFollowers then profile.live_stream = getChannelLiveStream(login)
    return profile
end function

function getChannelLiveStream(login as String) as Dynamic
    response = getApiJson("https://api.twitch.tv/helix/streams?user_login=" + login.EncodeUriComponent())
    if type(response) <> "roAssociativeArray" then return invalid
    if type(response.data) <> "roArray" then return invalid
    if response.data.Count() = 0 then return invalid
    stream = response.data[0]
    if stream.type <> "live" then return invalid
    return stream
end function

function channelInfoPayload(login as String) as Object
    query = "query ChannelInfo($login: String!) { user(login: $login) { id login displayName description profileImageURL(width: 300) followers { totalCount } } }"
    return {operationName: "ChannelInfo", query: query, variables: {login: login}}
end function

function getPublicChannelInfo(login as String) as Object
    transfer = createHttpUrl()
    transfer.AddHeader("Client-ID", "kimne78kx3ncx6brgo4mv6wki5h1ko")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.SetUrl("https://gql.twitch.tv/gql")
    response = requestText(transfer, FormatJson(channelInfoPayload(login)), 10000, false)
    if response.error <> "" then return invalid
    result = ParseJson(response.body)
    if type(result) <> "roAssociativeArray" then return invalid
    if type(result.data) <> "roAssociativeArray" then return invalid
    if type(result.data.user) <> "roAssociativeArray" then return invalid
    user = result.data.user
    if not nonEmptyString(user.id) then return invalid
    profile = {id: user.id, display_name: login, description: "", profile_image_url: "", followers: invalid}
    if nonEmptyString(user.displayName) then profile.display_name = user.displayName
    if nonEmptyString(user.description) then profile.description = user.description
    if nonEmptyString(user.profileImageURL) then profile.profile_image_url = user.profileImageURL
    if type(user.followers) = "roAssociativeArray"
        count = user.followers.totalCount
        kind = LCase(type(count))
        if kind = "integer" or kind = "roint" or kind = "longinteger" or kind = "rolonginteger" or kind = "float" or kind = "double"
            if count >= 0 then profile.followers = Int(count)
        end if
    end if
    return profile
end function
