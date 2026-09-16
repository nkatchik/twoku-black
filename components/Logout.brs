sub init()
    m.top.functionName = "revokeSession"
end sub

sub revokeSession()
    token = m.top.accessToken
    m.top.accessToken = ""
    if token = "" then return
    ' Local sign-out is already complete; revocation never holds up navigation.
    oauthPost("revoke", "client_id=" + twitchClientId().EncodeUriComponent() + "&token=" + token.EncodeUriComponent())
end sub
