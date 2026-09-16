'api.twitch.tv/kraken/search/channels?query=${search_text}&limit=5&client_id=jzkbprff40iqj646a697cyrvl0zt2m6

function init()
    'm.DURATION_REGEX = createObject("roRegex", "h|m|s", "")
    m.top.functionName = "onSearchTextChange"
end function

function onSearchTextChange()

    m.top.searchResults = getSearchResults()

end function

function getRelativeTimePublished(timePublished as String) as String
    secondsSincePublished = createObject("roDateTime")
    secondsSincePublished.FromISO8601String(timePublished)
    currentTime = createObject("roDateTime").AsSeconds()
    elapsedTime = currentTime - secondsSincePublished.AsSeconds()

    elapsedTime = Int(elapsedTime / 60)
    if elapsedTime < 60
        if elapsedTime = 1
            return "1 minute ago"
        else
            return elapsedTime.ToStr() + " minutes ago"
        end if
    end if

    elapsedTime = Int(elapsedTime / 60)
    if elapsedTime < 24
        if elapsedTime = 1
            return "1 hour ago"
        else
            return elapsedTime.ToStr() + " hours ago"
        end if
    end if

    elapsedTime = Int(elapsedTime / 24)
    if elapsedTime < 30
        if elapsedTime = 1
            return "1 day ago"
        else
            return elapsedTime.ToStr() + " days ago"
        end if
    end if

    elapsedTime = Int(elapsedTime / 30)
    if elapsedTime < 12
        if elapsedTime = 1
            return "Last month"
        else
            return elapsedTime.ToStr() + " months ago"
        end if
    end if

    elapsedTime = Int(elapsedTime / 12)
    if elapsedTime = 1
        return "1 year ago"
    else
        return elapsedTime.ToStr() + " years ago"
    end if
    
end function

function numberToText(number) as Object
    s = StrI(number)
    result = ""
    if number >=100000 and number < 1000000
        result = Left(s, 4) + "K"
    else if number >=10000 and number < 100000
        result = Left(s, 3) + "." + Mid(s, 4, 1) + "K"
    else if number >=1000 and number < 10000
        result = Left(s, 2) + "." + Mid(s, 3, 1) + "K"
    else if number < 1000
        result = s
    end if
    return result + " views"
end function

function convertDurationFormat(org_duration as String) as String
    new_duration = ""
    DURATION_REGEX = createObject("roRegex", "h|m|s", "")
    
    values = DURATION_REGEX.Split(org_duration)
    values_length = values.Count()


    for number = 0 to values_length - 1
        if values[number].Len() = 1 and not (number = 0 and values_length = 3)
            values[number] = "0" + values[number]
        end if
    end for

    if values_length = 3
        new_duration = values[0] + ":" + values[1] + ":" + values[2]
    else if values_length = 2
        new_duration = values[0] + ":" + values[1]
    else if values_length = 1
        new_duration = "0" + ":" + values[0]
    end if

    return new_duration
end function

function getSearchResults() as Object
    m.top.errorMessage = ""
    searchUrl = "https://api.twitch.tv/helix/videos?first=24&user_id=" + m.top.userId.EncodeUriComponent()
    if m.top.pagination <> "" then searchUrl += m.top.pagination
    search = getApiJson(searchUrl)
    m.top.pagination = ""
    if search = invalid or search.data = invalid
        m.top.errorMessage = "Couldn't load videos. Press OK to retry."
        return []
    end if
    result = []
    for each video in search.data
        thumbnail = video.thumbnail_url
        if thumbnail = invalid then thumbnail = ""
        thumbnail = thumbnail.Replace("%{width}", "320").Replace("%{height}", "180")
        thumbnail = thumbnail.Replace("{width}", "320").Replace("{height}", "180")
        result.push({
            id: video.id,
            user_name: video.user_name,
            duration: convertDurationFormat(video.duration),
            title: video.title,
            published_at: getRelativeTimePublished(video.published_at),
            viewer_count: numberToText(video.view_count),
            thumbnail_url: thumbnail
        })
    end for
    if search.pagination <> invalid and search.pagination.cursor <> invalid
        m.top.pagination = "&after=" + search.pagination.cursor.EncodeUriComponent()
    end if
    return result
end function
