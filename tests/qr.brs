function testCreateObject(kind, arg = invalid, flags = invalid)
    if kind = "roRegex" then return CreateObject(kind, arg, flags)
    check(kind = "roBitmap", "QR generation uses no network or SceneGraph nodes")
    g = getGlobalAA()
    if g.failBitmap then return invalid
    g.draws = []
    return {
        DrawRect: sub(x, y, width, height, color)
            getGlobalAA().draws.push([x, y, width, height, color])
        end sub,
        Finish: sub()
        end sub,
        GetPng: function(x, y, width, height)
            check(width = 360 and height = 360, "QR image has its natural displayed dimensions")
            return {WriteFile: function(filename)
                return true
            end function}
        end function
    }
end function

sub main()
    g = getGlobalAA()
    g.failBitmap = false
    probe = QrCode()
    probe.version = 4
    probe.size = 33
    check(FormatJson(probe.getAlignmentPatternPositions()) = "[6,26]", "Alignment positions retain ascending order")
    urls = ["https://www.twitch.tv/activate?device-code=GSWYXLZX", "https://www.twitch.tv/activate?public=true&device-code=ABCD1234"]
    for each uri in urls
        filename = createLoginQr(uri, "tmp:/test-qr.png")
        check(filename = "tmp:/test-qr.png", "Activation QR is rendered locally")
        check(g.draws[0][2] = 360 and g.draws[0][4] = &hFFFFFFFF, "Opaque white background surrounds the code")
        for index = 1 to g.draws.count() - 1
            rect = g.draws[index]
            check(rect[0] >= rect[2] * 4 and rect[1] >= rect[3] * 4, "At least four white modules before the code")
            check(rect[0] + rect[2] * 5 <= 360 and rect[1] + rect[3] * 5 <= 360, "At least four white modules after the code")
        end for
        print "QR_FIXTURE " + FormatJson({url: uri, draws: g.draws})
    end for
    g.failBitmap = true
    check(createLoginQr(urls[0], "tmp:/test-qr.png") = "", "Bitmap allocation failure leaves manual login available")
    check(createLoginQr("", "tmp:/test-qr.png") = "", "Empty activation link produces no QR")
    check(createLoginQr(String(181, "x"), "tmp:/test-qr.png") = "", "Oversized input cannot consume unbounded TV resources")
    print "PASS local QR encoding, integer module sizes, quiet zone, PNG dimensions, allocation failure, input bounds"
end sub
