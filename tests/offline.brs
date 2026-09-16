sub main()
    g = getGlobalAA()
    a = {broadcaster_id: "a", broadcaster_login: "alpha", broadcaster_name: "Alpha"}
    b = {broadcaster_id: "b", broadcaster_login: "beta", broadcaster_name: "Beta"}
    resetFollowing([{data: [a, b], pagination: {cursor: "next"}}, {data: [b], pagination: {}}, {data: [{id: "b", profile_image_url: "beta.jpg"}]}])
    m.top.currentlyLiveStreamerIds = {a: true}
    result = getSearchResults()
    check(result.count() = 1 and result[0].login = "beta" and result[0].profile_image_url = "beta.jpg", "Offline follows exclude live channels and duplicates")
    check(Instr(1, g.links[0], "/channels/followed?first=100&user_id=123") > 0, "Followed channels endpoint uses account ID")
    resetFollowing([{data: [], pagination: {}}])
    result = getSearchResults()
    check(result.count() = 0 and g.links.count() = 1, "Empty follows does not fetch an unfiltered users list")
    resetFollowing([invalid])
    result = getSearchResults()
    check(result = invalid and m.top.errorMessage <> "", "Offline follows reports transport failure")
    resetFollowing([])
    m.top.userId = ""
    result = getSearchResults()
    check(result.count() = 0 and g.links.count() = 0, "Signed-out state makes no followed-channel request")
    print "PASS modern offline follows, authenticated ID, pagination, live exclusion, duplicates, empty/error results"
end sub
