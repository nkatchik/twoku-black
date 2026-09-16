function init()
    m.top.functionName = "onStatusChange"
end function

function onStatusChange()

    m.top.appStatus = getAppStatus()

end function

function getAppStatus() as Object
    app_status_url = "https://worldreboot.github.io/status1"

    url = CreateObject("roUrlTransfer")
    url.EnableEncodings(true)
    url.RetainBodyOnError(true)
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()

    url.SetUrl(app_status_url)
    
    response = requestText(url)
    if response.error <> "" then return ""
    return response.body.Trim()
end function
