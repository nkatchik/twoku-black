function testCreateObject(kind, arg1 = invalid, arg2 = invalid)
    if kind = "roRegex" then return CreateObject(kind, arg1, arg2)
    return {
        EnableEncodings: sub(value)
        end sub,
        RetainBodyOnError: sub(value)
        end sub,
        SetCertificatesFile: sub(value)
        end sub,
        InitClientCertificates: sub()
        end sub,
        SetUrl: sub(value)
        end sub
    }
end function

function requestText(url)
    return m.response
end function

sub main()
    m.top = {}
    m.response = {error: "offline", body: ""}
    check(getStreamLink() = "" and m.top.errorMessage = "offline", "Token failure reaches UI")
    m.response = {error: "", body: "<html>404</html>"}
    check(getStreamLink() = "", "HTML cannot become an Authorization header")
    m.response.body = "Bearer "
    check(getStreamLink() = "", "Empty credential rejected")
    m.response.body = "Bearer abc123" + chr(10)
    check(getStreamLink() = "Bearer abc123", "Trailing newline trimmed")
    print "PASS token outage, invalid body, empty credential, valid credential"
end sub
