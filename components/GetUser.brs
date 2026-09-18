sub init()
    m.top.functionName = "onSearchTextChange"
end sub

sub onSearchTextChange()
    m.top.errorMessage = ""
    m.top.searchResults = getSearchResults()
end sub

function getSearchResults() as Object
    identity = restoreUserSession()
    if identity = invalid
        m.top.errorMessage = "Could not restore your Twitch session. Open Log In to sign in again."
        return invalid
    end if
    result = {id: identity.user_id, login: identity.login, display_name: identity.login, profile_image_url: "", followed_users: []}
    profile = getApiJson("https://api.twitch.tv/helix/users?id=" + identity.user_id.EncodeUriComponent(), true)
    if profile <> invalid
        if type(profile.data) = "roArray" and profile.data.count() > 0
            result.display_name = profile.data[0].display_name
            result.profile_image_url = profile.data[0].profile_image_url
        end if
    end if
    streams = getTwitchPages("https://api.twitch.tv/helix/streams/followed?first=100&user_id=" + identity.user_id.EncodeUriComponent())
    if streams = invalid
        m.top.errorMessage = m.requestError
        return result
    end if
    ids = []
    seen = {}
    for each stream in streams
        if nonEmptyString(stream.user_id) and not seen.DoesExist(stream.user_id)
            seen[stream.user_id] = true
            ids.push(stream.user_id)
            item = {
                user_name: stream.user_name, login: stream.user_login,
                viewer_count: stream.viewer_count, game_id: stream.game_name,
                title: stream.title, user_id: stream.user_id, profile_image_url: "",
                thumbnail: stream.thumbnail_url.Replace("{width}", "320").Replace("{height}", "180"),
                live_duration: convertToTimeFormat(stream.started_at)
            }
            result.followed_users.push(item)
        end if
    end for
    profiles = getUserProfiles(ids)
    for each stream in result.followed_users
        if profiles.DoesExist(stream.user_id) then stream.profile_image_url = profiles[stream.user_id].profile_image_url
    end for
    result.followed_users.SortBy("viewer_count", "r")
    m.top.currentlyLiveStreamerIds = seen
    return result
end function

function convertToTimeFormat(timestamp as String) as String
    secondsSincePublished = createObject("roDateTime")
    secondsSincePublished.FromISO8601String(timestamp)
    currentTime = createObject("roDateTime").AsSeconds()
    elapsedTime = currentTime - secondsSincePublished.AsSeconds()
    hours = Int(elapsedTime / 60 / 60)
    mins = elapsedTime / 60 MOD 60
    secs = elapsedTime MOD 60
    if mins < 10
        mins = mins.ToStr()
        mins = "0" + mins
    else
        mins = mins.ToStr()
    end if
    if secs < 10
        secs = secs.ToStr()
        secs = "0" + secs
    else
        secs = secs.ToStr()
    end if
    return hours.ToStr() + ":" + mins + ":" + secs
end function
