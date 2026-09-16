function init()
    m.top.functionName = "onStreamerChange"
end function

function onStreamerChange()
    m.top.errorMessage = ""
    m.top.appBearerToken = getStreamLink()

end function

function getStreamLink() as Object
    access_token_url = "https://worldreboot.github.io/code"

    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()

    url.SetUrl(access_token_url)
    
    response = requestText(url)
    if response.error <> ""
        m.top.errorMessage = response.error
        return ""
    end if
    token = response.body.Trim()
    if not CreateObject("roRegex", "^Bearer [A-Za-z0-9]+$", "").IsMatch(token)
        m.top.errorMessage = "The sign-in service returned an invalid response. Try again."
        return ""
    end if
    return token
end function
