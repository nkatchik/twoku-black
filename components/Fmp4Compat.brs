' Separate track views without copying compressed media. Replacing a atom's type
' with "free" preserves every atom size, absolute offset and mdat payload byte.
' Only bounded metadata is inspected; callers send original byte-array ranges
' interleaved with the four-byte patches returned by fmp4ViewPatches.
function fmp4TrackInfo(bytes) as Object
    result = {valid: false, audioId: 0, videoId: 0, muxed: false, tracks: [], error: ""}
    scan = fmp4Scan(bytes)
    if not scan.valid
        result.error = scan.error
        return result
    end if
    movie = invalid
    for each atom in scan.boxes
        if atom.kind = "moov"
            if movie <> invalid
                result.error = "Multiple initialization movies"
                return result
            end if
            movie = atom
        end if
    end for
    if movie = invalid
        result.error = "Missing initialization movie"
        return result
    end if
    children = fmp4Boxes(bytes, movie.data, movie.limit, scan.budget)
    if not children.valid
        result.error = children.error
        return result
    end if
    defaults = []
    for each atom in children.boxes
        if atom.kind = "trak"
            track = fmp4ReadTrack(bytes, atom, scan.budget)
            if not track.valid
                result.error = track.error
                return result
            end if
            if result.tracks.Count() >= 32 or fmp4HasTrack(result, track.id)
                result.error = "Too many tracks or duplicate track identifier"
                return result
            end if
            result.tracks.Push(track)
            if track.handler = "soun"
                if result.audioId <> 0
                    result.error = "Multiple audio tracks"
                    return result
                end if
                result.audioId = track.id
            else if track.handler = "vide"
                if result.videoId <> 0
                    result.error = "Multiple video tracks"
                    return result
                end if
                result.videoId = track.id
            end if
        else if atom.kind = "mvex"
            extensions = fmp4Boxes(bytes, atom.data, atom.limit, scan.budget)
            if not extensions.valid
                result.error = extensions.error
                return result
            end if
            for each extension in extensions.boxes
                if extension.kind = "trex"
                    if extension.limit - extension.data < 24 or bytes[extension.data] <> 0
                        result.error = "Malformed track defaults"
                        return result
                    end if
                    id = fmp4U32(bytes, extension.data + 4)
                    if defaults.Count() >= 32
                        result.error = "Too many track defaults"
                        return result
                    end if
                    for each existing in defaults
                        if existing = id
                            result.error = "Duplicate track defaults"
                            return result
                        end if
                    end for
                    defaults.Push(id)
                end if
            end for
        end if
    end for
    if result.tracks.Count() = 0 or defaults.Count() <> result.tracks.Count()
        result.error = "Missing fragmented track defaults"
        return result
    end if
    for each id in defaults
        if not fmp4HasTrack(result, id)
            result.error = "Track defaults reference an unknown track"
            return result
        end if
    end for
    if result.audioId = 0 and result.videoId = 0
        result.error = "No audio or video track"
        return result
    end if
    result.muxed = result.audioId <> 0 and result.videoId <> 0
    result.valid = true
    return result
end function

function fmp4ViewPatches(bytes, trackId, initInfo = invalid) as Object
    result = {valid: false, patches: [], error: ""}
    scan = fmp4Scan(bytes)
    if not scan.valid
        result.error = scan.error
        return result
    end if
    hasMovie = false
    for each atom in scan.boxes
        if atom.kind = "moov" then hasMovie = true
    end for
    if hasMovie
        currentInfo = fmp4TrackInfo(bytes)
        if not currentInfo.valid
            result.error = currentInfo.error
            return result
        end if
        if initInfo <> invalid
            if not fmp4SameTracks(initInfo, currentInfo)
                result.error = "Initialization tracks changed"
                return result
            end if
        end if
        initInfo = currentInfo
    end if
    if initInfo = invalid
        result.error = "Missing initialization track information"
        return result
    end if
    if not fmp4HasTrack(initInfo, trackId) or initInfo.valid <> true
        result.error = "Unknown requested track"
        return result
    end if
    foundMedia = false
    for each atom in scan.boxes
        if atom.kind = "moov"
            children = fmp4Boxes(bytes, atom.data, atom.limit, scan.budget)
            if not children.valid then return fmp4PatchError(children.error)
            for each child in children.boxes
                if child.kind = "trak"
                    track = fmp4ReadTrack(bytes, child, scan.budget)
                    if not track.valid then return fmp4PatchError(track.error)
                    if track.id <> trackId then fmp4HideBox(result, child)
                else if child.kind = "mvex"
                    extensions = fmp4Boxes(bytes, child.data, child.limit, scan.budget)
                    if not extensions.valid then return fmp4PatchError(extensions.error)
                    for each extension in extensions.boxes
                        if extension.kind = "trex"
                            if fmp4U32(bytes, extension.data + 4) <> trackId then fmp4HideBox(result, extension)
                        end if
                    end for
                end if
            end for
        else if atom.kind = "moof"
            foundMedia = true
            children = fmp4Boxes(bytes, atom.data, atom.limit, scan.budget)
            if not children.valid then return fmp4PatchError(children.error)
            fragments = []
            retained = false
            for each child in children.boxes
                if child.kind = "traf"
                    fragment = fmp4ReadFragment(bytes, child, scan.budget, atom.start)
                    if not fragment.valid then return fmp4PatchError(fragment.error)
                    if not fmp4HasTrack(initInfo, fragment.id) then return fmp4PatchError("Fragment references an unknown track")
                    for each previous in fragments
                        if previous.id = fragment.id then return fmp4PatchError("Duplicate track fragment")
                    end for
                    fragments.Push(fragment)
                    if fragment.id = trackId then retained = true
                end if
            end for
            if fragments.Count() = 0 then return fmp4PatchError("Missing track fragments")
            if not retained
                ' A fragment containing only the other track contributes no samples.
                fmp4HideBox(result, atom)
            else
                for each fragment in fragments
                    if fragment.id <> trackId then fmp4HideBox(result, fragment.atom)
                end for
            end if
        end if
    end for
    if not hasMovie and not foundMedia then return fmp4PatchError("Missing initialization or media fragment")
    result.valid = true
    return result
end function

function fmp4Scan(bytes) as Object
    if bytes = invalid then return {valid: false, error: "Missing media bytes"}
    kind = Type(bytes)
    if kind <> "roByteArray" and kind <> "roArray" then return {valid: false, error: "Invalid media bytes"}
    budget = {remaining: 4096}
    result = fmp4Boxes(bytes, 0, bytes.Count(), budget)
    result.budget = budget
    return result
end function

' Container depth is fixed by the callers (moov/trak/mdia and moof/traf),
' never recursively inferred from untrusted atom types. Count bounds CPU work.
function fmp4Boxes(bytes, first as Integer, limit as Integer, budget as Object) as Object
    result = {valid: false, boxes: [], error: "Malformed MP4 atom bounds"}
    if first < 0 or limit < first or limit > bytes.Count() then return result
    position = first
    while position < limit
        if budget.remaining <= 0
            result.error = "Too many MP4 boxes"
            return result
        end if
        budget.remaining -= 1
        if limit - position < 8 then return result
        size = fmp4U32(bytes, position)
        header = 8
        if size = 1
            if limit - position < 16 then return result
            ' Buffers are addressable with signed 32-bit offsets. Larger boxes
            ' cannot fit this buffer; reject before converting their size.
            if fmp4U32(bytes, position + 8) <> 0 then return result
            size = fmp4U32(bytes, position + 12)
            header = 16
        else if size = 0
            size = limit - position
        end if
        if size < header or size > limit - position then return result
        size = Int(size)
        result.boxes.Push({kind: fmp4FourCC(bytes, position + 4), start: position, data: position + header, limit: position + size})
        position += size
    end while
    result.valid = true
    result.error = ""
    return result
end function

function fmp4ReadTrack(bytes, atom as Object, budget as Object) as Object
    result = {valid: false, id: 0, handler: "", error: "Malformed initialization track"}
    children = fmp4Boxes(bytes, atom.data, atom.limit, budget)
    if not children.valid
        result.error = children.error
        return result
    end if
    for each child in children.boxes
        if child.kind = "tkhd"
            if result.id <> 0 or child.limit - child.data < 4 then return result
            version = bytes[child.data]
            if version <> 0 and version <> 1 then return result
            idOffset = child.data + 12
            required = 84
            if version = 1
                idOffset = child.data + 20
                required = 96
            end if
            if child.limit - child.data < required then return result
            result.id = fmp4U32(bytes, idOffset)
            if result.id = 0 then return result
        else if child.kind = "mdia"
            media = fmp4Boxes(bytes, child.data, child.limit, budget)
            if not media.valid
                result.error = media.error
                return result
            end if
            for each field in media.boxes
                if field.kind = "hdlr"
                    if result.handler <> "" or field.limit - field.data < 24 then return result
                    if bytes[field.data] <> 0 then return result
                    result.handler = fmp4FourCC(bytes, field.data + 8)
                end if
            end for
        end if
    end for
    if result.id = 0 or result.handler = "" then return result
    result.valid = true
    result.error = ""
    return result
end function

function fmp4ReadFragment(bytes, atom as Object, budget as Object, moofStart as Integer) as Object
    result = {valid: false, id: 0, atom: atom, error: "Malformed media track fragment"}
    children = fmp4Boxes(bytes, atom.data, atom.limit, budget)
    if not children.valid
        result.error = children.error
        return result
    end if
    header = invalid
    for each child in children.boxes
        if child.kind = "tfhd"
            if header <> invalid then return result
            header = child
        end if
    end for
    if header = invalid then return result
    if header.limit - header.data < 8 or bytes[header.data] <> 0 then return result
    flags = fmp4U32(bytes, header.data)
    ' An implicit base can depend on the previous, now hidden track. Require
    ' fragment-relative addressing so keeping atom sizes also keeps offsets.
    if (flags and &h020000) = 0 or (flags and 1) <> 0
        result.error = "Track fragment uses dependent data offsets"
        return result
    end if
    required = 8
    if (flags and 2) <> 0 then required += 4
    if (flags and 8) <> 0 then required += 4
    if (flags and 16) <> 0 then required += 4
    if (flags and 32) <> 0 then required += 4
    if header.limit - header.data < required then return result
    result.id = fmp4U32(bytes, header.data + 4)
    if result.id = 0 then return result
    runs = 0
    for each child in children.boxes
        if child.kind = "trun"
            if child.limit - child.data < 8 then return result
            if bytes[child.data] <> 0 and bytes[child.data] <> 1 then return result
            runFlags = fmp4U32(bytes, child.data) and &hffffff
            samples = fmp4U32(bytes, child.data + 4)
            required = 8
            if (runFlags and 1) <> 0
                required += 4
                if child.limit - child.data < required then return result
                dataOffset = fmp4U32(bytes, child.data + 8)
                if dataOffset > 2147483647# or dataOffset >= bytes.Count() - moofStart
                    result.error = "Media sample offset is outside its buffer"
                    return result
                end if
            else if runs = 0
                result.error = "First sample run has no fragment-relative offset"
                return result
            end if
            if (runFlags and 4) <> 0 then required += 4
            sampleFields = 0
            if (runFlags and &h100) <> 0 then sampleFields += 4
            if (runFlags and &h200) <> 0 then sampleFields += 4
            if (runFlags and &h400) <> 0 then sampleFields += 4
            if (runFlags and &h800) <> 0 then sampleFields += 4
            required += samples * (sampleFields + 0#)
            if required > child.limit - child.data then return result
            runs += 1
        end if
    end for
    if runs = 0 then return result
    result.valid = true
    result.error = ""
    return result
end function

function fmp4HasTrack(info, id) as Boolean
    if info = invalid or id = invalid then return false
    if info.tracks = invalid then return false
    for each track in info.tracks
        if track.id = id then return true
    end for
    return false
end function

function fmp4SameTracks(left, right) as Boolean
    if left = invalid or right = invalid then return false
    if left.valid <> true or right.valid <> true then return false
    if left.tracks = invalid or right.tracks = invalid then return false
    if left.tracks.Count() <> right.tracks.Count() then return false
    for each track in left.tracks
        matches = false
        for each other in right.tracks
            if track.id = other.id and track.handler = other.handler then matches = true
        end for
        if not matches then return false
    end for
    return true
end function

sub fmp4HideBox(result as Object, atom as Object)
    replacement = CreateObject("roByteArray")
    replacement.Push(102)
    replacement.Push(114)
    replacement.Push(101)
    replacement.Push(101)
    result.patches.Push({offset: atom.start + 4, bytes: replacement})
end sub

function fmp4PatchError(message as String) as Object
    return {valid: false, patches: [], error: message}
end function

function fmp4U32(bytes, offset as Integer) as Double
    ' Double represents every unsigned 32-bit value exactly. Float and signed
    ' shifts can silently round or turn a hostile size into a negative offset.
    return bytes[offset] * 16777216# + bytes[offset + 1] * 65536# + bytes[offset + 2] * 256# + bytes[offset + 3]
end function

function fmp4FourCC(bytes, offset as Integer) as String
    return Chr(bytes[offset]) + Chr(bytes[offset + 1]) + Chr(bytes[offset + 2]) + Chr(bytes[offset + 3])
end function
