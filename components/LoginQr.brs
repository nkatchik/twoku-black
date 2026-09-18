function loginActivationUri(grant as Object) as String
    uri = grant.verification_uri
    ' Twitch normally includes the code. Preserve its full link and public flag.
    if Instr(1, uri, "device-code=") > 0 then return uri
    separator = "?"
    if Instr(1, uri, "?") > 0 then separator = "&"
    return uri + separator + "device-code=" + grant.user_code.EncodeUriComponent()
end function

function createLoginQr(uri as String, filename as String) as String
    ' Bound work and memory on older TVs; manual entry remains available.
    if uri = "" or Len(uri) > 180 then return ""
    side = 360
    ' Write RGBA values directly; the Poster blends the saved PNG's alpha.
    bitmap = CreateObject("roBitmap", {width: side, height: side, AlphaEnable: false})
    if bitmap = invalid then return ""
    qr = QrCode()
    segments = qr.QrSegment.makeSegments(uri)
    qr.encodeSegments(segments, qr.Ecc[1], 1, 10, -1, false)
    pixel = Int(side / (qr.size + 8))
    ' Preserve the QR's sharp module size while tightening the card to a
    ' three-module border. Round only the outer corners, away from the code.
    cardSide = (qr.size + 6) * pixel
    cardOffset = Int((side - cardSide) / 2)
    offset = cardOffset + 3 * pixel
    radius = 2 * pixel
    bitmap.DrawRect(0, 0, side, side, &hFFFFFF00)
    bitmap.DrawRect(cardOffset + radius, cardOffset, cardSide - 2 * radius, cardSide, &hFFFFFFFF)
    bitmap.DrawRect(cardOffset, cardOffset + radius, cardSide, cardSide - 2 * radius, &hFFFFFFFF)
    for row = 0 to radius - 1
        dy = radius - row - 0.5
        for col = 0 to radius - 1
            dx = radius - col - 0.5
            coverage = radius + 0.5 - Sqr(dx * dx + dy * dy)
            if coverage > 0
                if coverage > 1 then coverage = 1
                color = &hFFFFFF00 + Int(255 * coverage + 0.5)
                left = cardOffset + col
                right = cardOffset + cardSide - 1 - col
                top = cardOffset + row
                bottom = cardOffset + cardSide - 1 - row
                bitmap.DrawRect(left, top, 1, 1, color)
                bitmap.DrawRect(right, top, 1, 1, color)
                bitmap.DrawRect(left, bottom, 1, 1, color)
                bitmap.DrawRect(right, bottom, 1, 1, color)
            end if
        end for
    end for
    for y = 0 to qr.size - 1
        for x = 0 to qr.size - 1
            if qr.modules[y][x] = 1
                bitmap.DrawRect(offset + x * pixel, offset + y * pixel, pixel, pixel, &h000000FF)
            end if
        end for
    end for
    bitmap.Finish()
    png = bitmap.GetPng(0, 0, side, side)
    if png = invalid then return ""
    if not png.WriteFile(filename) then return ""
    return filename
end function
