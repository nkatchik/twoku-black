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
    bitmap = CreateObject("roBitmap", {width: side, height: side, AlphaEnable: false})
    if bitmap = invalid then return ""
    qr = QrCode()
    segments = qr.QrSegment.makeSegments(uri)
    qr.encodeSegments(segments, qr.Ecc[1], 1, 10, -1, false)
    pixel = Int(side / (qr.size + 8))
    offset = Int((side - qr.size * pixel) / 2)
    bitmap.DrawRect(0, 0, side, side, &hFFFFFFFF)
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
