sub main()
    g = getGlobalAA()
    profile = {data: [{id: "123", display_name: "Viewer", profile_image_url: "viewer.jpg"}]}
    resetFollowing([profile, {data: [stream("a", 10)], pagination: {cursor: "next+page"}}, {data: [stream("a", 10), stream("b", 20)], pagination: {}}, {data: [{id: "a", profile_image_url: "a.jpg"}, {id: "b", profile_image_url: "b.jpg"}]}])
    result = getSearchResults()
    check(result.id = "123" and result.login = "viewer" and result.display_name = "Viewer", "Identity comes from the authenticated account")
    check(result.followed_users.count() = 2 and result.followed_users[0].login = "streamerb", "Paginated live streams deduplicate and sort by viewers")
    check(result.followed_users[0].profile_image_url = "b.jpg" and result.followed_users[0].game_id = "A game", "Sidebar gets profile image and game name")
    check(result.followed_users[0].thumbnail = "https://example.invalid/320x180.jpg", "Modern thumbnail placeholders are resolved")
    check(m.top.currentlyLiveStreamerIds.DoesExist("a") and m.top.currentlyLiveStreamerIds.DoesExist("b"), "Live IDs are published for offline filtering")
    check(Instr(1, g.links[1], "/streams/followed?first=100&user_id=123") > 0, "Followed streams endpoint uses validated user ID")
    check(Instr(1, g.links[2], "after=next%2Bpage") > 0, "Pagination cursor is encoded")
    resetFollowing([profile, {data: [], pagination: {}}])
    result = getSearchResults()
    check(result.followed_users.count() = 0 and m.top.currentlyLiveStreamerIds.count() = 0 and g.links.count() = 2, "No follows needs no profile batch and clears live IDs")
    resetFollowing([profile, invalid])
    result = getSearchResults()
    check(result.login = "viewer" and m.top.errorMessage = "Network unavailable", "Follow failure keeps identity and exposes an error")
    resetFollowing([{data: [], pagination: {cursor: "same"}}, {data: [], pagination: {cursor: "same"}}])
    check(getTwitchPages("https://example.invalid?first=100") = invalid and g.links.count() = 2, "Repeated cursor stops instead of looping")
    resetFollowing([])
    g.identity = invalid
    check(getSearchResults() = invalid and g.links.count() = 0, "Invalid identity cannot request another user's follows")
    resetFollowing([{data: []}, {data: []}])
    ids = []
    for index = 1 to 101
        ids.push(index.ToStr())
    end for
    profiles = getUserProfiles(ids)
    check(g.links.count() = 2 and Instr(1, g.links[1], "id=101") > 0, "Profile requests split at Helix's 100-user limit")
    resetFollowing([])
    m.global.sessionVersion = 2
    check(getTwitchPages("https://example.invalid") = invalid and g.links.count() = 0, "Superseded account stops pagination")
    print "PASS authenticated follows, pagination, duplicate streams, ordering, avatars, empty/error results, batch limits"
end sub
