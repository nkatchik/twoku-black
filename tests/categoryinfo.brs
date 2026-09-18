function createHttpUrl()
    return {headers: {}, AddHeader: sub(key, value)
        m.headers[key] = value
    end sub, SetUrl: sub(value)
        m.url = value
    end sub}
end function

function requestText(transfer, payload, timeoutMs, logFailure)
    m.calls += 1
    m.request = {headers: transfer.headers, url: transfer.url, payload: ParseJson(payload), timeoutMs: timeoutMs}
    if m.cancelDuringRequest then m.top.cancelRequested = true
    if m.changeDuringRequest then m.top.requestId += 1
    return m.response
end function

sub main()
    m.top = {categoryId: "21779", requestId: 1, cancelRequested: false, info: invalid}
    m.calls = 0
    m.cancelDuringRequest = false
    m.changeDuringRequest = false
    m.response = {error: "", body: FormatJson({data: {game: {id: "21779", description: "  A real game description.  "}}})}
    getCategoryInfo()
    check(m.top.info.id = "21779" and m.top.info.description = "A real game description.", "Selected game receives Twitch's description")
    check(m.calls = 1 and m.request.timeoutMs = 10000 and m.request.headers.Authorization = invalid, "Metadata uses one bounded anonymous request")
    check(m.request.payload.variables.id = "21779" and Instr(1, m.request.payload.query, "$id") > 0, "Game identity is passed as a GraphQL variable")
    for each description in [invalid, "", 123]
        m.top.info = invalid
        m.response.body = FormatJson({data: {game: {id: "21779", description: description}}})
        getCategoryInfo()
        check(m.top.info.description = "", "Missing game descriptions remain empty")
    end for
    for each body in ["bad json", "null", "[]", "{}", FormatJson({data: {game: invalid}}), FormatJson({data: {game: {id: "other", description: "Wrong"}}})]
        m.top.info = invalid
        m.response.body = body
        getCategoryInfo()
        check(m.top.info = invalid, "Malformed or mismatched responses cannot publish a description")
    end for
    m.response = {error: "Unavailable", body: ""}
    getCategoryInfo()
    check(m.top.info = invalid, "Network failure leaves the optional description unavailable")
    m.response = {error: "", body: FormatJson({data: {game: {id: "21779", description: "Game"}}})}
    m.cancelDuringRequest = true
    getCategoryInfo()
    check(m.top.info = invalid, "Cancelled requests cannot publish late metadata")
    m.cancelDuringRequest = false
    m.top.cancelRequested = false
    m.changeDuringRequest = true
    getCategoryInfo()
    check(m.top.info = invalid, "Superseded requests cannot overwrite the current game")
    m.top.categoryId = ""
    calls = m.calls
    getCategoryInfo()
    check(m.calls = calls, "Missing game identity sends no request")
    print "PASS game descriptions, bounded anonymous metadata, absent fields, cancellation and stale response guards"
end sub
