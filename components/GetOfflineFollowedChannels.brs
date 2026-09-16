sub init()
    m.top.functionName = "onSearchTextChange"
end sub

sub onSearchTextChange()
    m.top.errorMessage = ""
    m.top.offlineFollowedUsers = getSearchResults()
end sub

function getSearchResults() as Object
    if m.top.userId = "" then return []
    channels = getTwitchPages("https://api.twitch.tv/helix/channels/followed?first=100&user_id=" + m.top.userId.EncodeUriComponent())
    if channels = invalid
        m.top.errorMessage = m.requestError
        return invalid
    end if
    live = m.top.currentlyLiveStreamerIds
    if type(live) <> "roAssociativeArray" then live = {}
    ids = []
    seen = {}
    result = []
    for each channel in channels
        id = channel.broadcaster_id
        if nonEmptyString(id) and not live.DoesExist(id) and not seen.DoesExist(id)
            seen[id] = true
            ids.push(id)
            result.push({id: id, login: channel.broadcaster_login, display_name: channel.broadcaster_name, profile_image_url: ""})
        end if
    end for
    profiles = getUserProfiles(ids)
    for each channel in result
        if profiles.DoesExist(channel.id) then channel.profile_image_url = profiles[channel.id].profile_image_url
    end for
    return result
end function
