function testCreateObject(kind as String, ignored = invalid)
    if kind = "roByteArray" then return []
    return invalid
end function

function fmp4TestBytes(values = invalid)
    if values = invalid then return []
    result = []
    result.Append(values)
    return result
end function

function fmp4TestU32(value)
    return [Int(value / 16777216#) mod 256, Int(value / 65536#) mod 256, Int(value / 256#) mod 256, value mod 256]
end function

function fmp4TestBox(kind, content = invalid, extended = false)
    if content = invalid then content = []
    size = content.Count() + 8
    if extended
        result = [0,0,0,1]
    else
        result = fmp4TestU32(size)
    end if
    for i = 1 to 4
        result.Push(Asc(Mid(kind,i,1)))
    end for
    if extended
        result.Append([0,0,0,0])
        result.Append(fmp4TestU32(size + 8))
    end if
    result.Append(content)
    return result
end function

function fmp4TestJoin(parts)
    result = []
    for each part in parts
        result.Append(part)
    end for
    return result
end function

function fmp4TestTrack(id, handler, version = 0)
    header = []
    size = 84
    offset = 12
    if version = 1
        size = 96
        offset = 20
    end if
    for i = 0 to size - 1
        header.Push(0)
    end for
    header[0] = version
    identifier = fmp4TestU32(id)
    for i = 0 to 3
        header[offset+i] = identifier[i]
    end for
    mediaHandler = [0,0,0,0,0,0,0,0]
    for i = 1 to 4
        mediaHandler.Push(Asc(Mid(handler,i,1)))
    end for
    mediaHandler.Append([0,0,0,0,0,0,0,0,0,0,0,0])
    return fmp4TestBox("trak",fmp4TestJoin([fmp4TestBox("tkhd",header),fmp4TestBox("mdia",fmp4TestBox("hdlr",mediaHandler))]))
end function

function fmp4TestInit(audioId = 1, videoId = 2, extra = false)
    tracks = [fmp4TestTrack(audioId,"soun"),fmp4TestTrack(videoId,"vide",1)]
    ids = [audioId,videoId]
    if extra
        tracks.Push(fmp4TestTrack(3,"text"))
        ids.Push(3)
    end if
    defaults = []
    for each id in ids
        defaults.Append(fmp4TestBox("trex",fmp4TestJoin([[0,0,0,0],fmp4TestU32(id),[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]])))
    end for
    tracks.Push(fmp4TestBox("mvex",defaults))
    return fmp4TestJoin([fmp4TestBox("ftyp",[105,115,111,109,0,0,0,1]),fmp4TestBox("moov",fmp4TestJoin(tracks))])
end function

function fmp4TestTraf(id, offset, flags = &h20000)
    header = fmp4TestJoin([fmp4TestU32(flags),fmp4TestU32(id)])
    sampleRun = fmp4TestJoin([[0,0,0,1,0,0,0,1],fmp4TestU32(offset)])
    return fmp4TestBox("traf",fmp4TestJoin([fmp4TestBox("tfhd",header),fmp4TestBox("trun",sampleRun)]))
end function

function fmp4TestMedia(audioId = 1, videoId = 2, flags = &h20000)
    ' traf sizes are 44 bytes; the unchanged data begins after moof and mdat headers.
    return fmp4TestJoin([fmp4TestBox("moof",fmp4TestJoin([fmp4TestTraf(audioId,104,flags),fmp4TestTraf(videoId,108,flags)])),fmp4TestBox("mdat",[10,20,30,40,50,60,70,80])])
end function

sub fmp4CheckPatches(original, view, expected)
    check(view.valid, "Track view is valid: " + view.error)
    check(view.patches.Count() = expected, "Only other-track metadata is hidden")
    lastOffset = -1
    for each patch in view.patches
        check(patch.offset > lastOffset and patch.offset + 4 <= original.Count(), "Patches are ordered and in bounds")
        check(patch.bytes.Count() = 4 and patch.bytes[0] = 102 and patch.bytes[1] = 114 and patch.bytes[2] = 101 and patch.bytes[3] = 101, "Each patch only changes the box type to free")
        check(fmp4FourCC(original,patch.offset) <> "free", "Original media remains unchanged")
        lastOffset = patch.offset
    end for
end sub

sub main()
    initialization = fmp4TestInit()
    info = fmp4TrackInfo(initialization)
    check(info.valid and info.muxed and info.audioId = 1 and info.videoId = 2, "Version zero and version one track headers identify audio and video")
    fmp4CheckPatches(initialization,fmp4ViewPatches(initialization,info.videoId,info),2)
    fmp4CheckPatches(initialization,fmp4ViewPatches(initialization,info.audioId),2)
    singleDefaults = fmp4TestBox("trex",fmp4TestJoin([[0,0,0,0],fmp4TestU32(1),[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]]))
    single = fmp4TestBox("moov",fmp4TestJoin([fmp4TestTrack(1,"soun"),fmp4TestBox("mvex",singleDefaults)]))
    check(fmp4TrackInfo(single).valid and not fmp4TrackInfo(single).muxed, "A single-track init does not trigger muxed-media repair")
    fmp4CheckPatches(single,fmp4ViewPatches(single,1),0)
    check(not fmp4TrackInfo(fmp4TestBox("moov",fmp4TestTrack(1,"soun"))).valid, "Unfragmented tracks without mvex defaults are not rewritten")
    changed = fmp4TestBytes(initialization)
    changed[40] = 2
    check(not fmp4TrackInfo(changed).valid, "Unknown tkhd versions fail before reading their layout")
    changed = fmp4TestBytes(initialization)
    changed[32] = 0 : changed[33] = 0 : changed[34] = 0 : changed[35] = 4
    check(not fmp4TrackInfo(changed).valid, "Malformed nested box bounds cannot escape a track")
    media = fmp4TestMedia()
    fmp4CheckPatches(media,fmp4ViewPatches(media,info.videoId,info),1)
    check(fmp4ViewPatches(media,info.videoId,info).patches[0].offset = 12, "Video view hides the first audio traf")
    check(fmp4ViewPatches(media,info.audioId,info).patches[0].offset = 56, "Audio view hides the second video traf")
    combined = fmp4TestJoin([initialization,media,media])
    fmp4CheckPatches(combined,fmp4ViewPatches(combined,2,info),4)
    extras = fmp4TestInit(1,2,true)
    check(fmp4TrackInfo(extras).tracks.Count() = 3, "Other handler tracks remain identifiable")
    fmp4CheckPatches(extras,fmp4ViewPatches(extras,2),4)
    check(not fmp4ViewPatches(media,3,info).valid, "Unknown selected track cannot produce a broken view")
    check(not fmp4ViewPatches(media,2).valid, "A media segment requires initialization track metadata")
    check(not fmp4ViewPatches(fmp4TestMedia(4,2),2,info).valid, "Unknown fragment tracks fail safely")
    check(not fmp4ViewPatches(fmp4TestMedia(1,1),1,info).valid, "Duplicate fragment track identifiers fail safely")
    check(not fmp4ViewPatches(fmp4TestMedia(1,2,0),2,info).valid, "Implicit data bases cannot depend on a hidden track")
    check(not fmp4ViewPatches(fmp4TestInit(4,2),2,info).valid, "Changed initialization IDs require new track information")
    check(not fmp4TrackInfo(fmp4TestInit(1,1)).valid, "Duplicate initialization track identifiers fail safely")
    onlyAudio = fmp4TestJoin([fmp4TestBox("moof",fmp4TestTraf(1,60)),fmp4TestBox("mdat",[1,2,3,4])])
    fmp4CheckPatches(onlyAudio,fmp4ViewPatches(onlyAudio,2,info),1)
    check(fmp4ViewPatches(onlyAudio,2,info).patches[0].offset = 4, "A fragment without the requested track is hidden as a whole")

    check(not fmp4TrackInfo(invalid).valid and not fmp4TrackInfo("bad").valid, "Invalid buffers fail without array access")
    check(not fmp4TrackInfo([]).valid, "An empty buffer has no initialization")
    check(not fmp4TrackInfo([0,0,0]).valid, "A truncated box header fails safely")
    check(not fmp4TrackInfo([0,0,0,4,109,111,111,118]).valid, "A size smaller than its header fails safely")
    check(not fmp4TrackInfo([255,255,255,255,109,111,111,118]).valid, "Unsigned oversized lengths cannot wrap negative")
    check(not fmp4TrackInfo([0,0,0,1,109,111,111,118,0]).valid, "A truncated extended size fails safely")
    check(not fmp4TrackInfo([0,0,0,1,109,111,111,118,0,0,0,1,0,0,0,0]).valid, "A box larger than the addressable buffer is rejected")
    extended = fmp4TestJoin([fmp4TestBox("free",[1,2,3,4],true),initialization])
    check(fmp4TrackInfo(extended).valid, "Bounded extended-size boxes are accepted")
    zeroSize = fmp4TestBytes(initialization)
    zeroSize[16] = 0 : zeroSize[17] = 0 : zeroSize[18] = 0 : zeroSize[19] = 0
    check(fmp4TrackInfo(zeroSize).valid, "A zero-sized final box extends to its parent boundary")
    check(not fmp4Boxes(initialization,-1,initialization.Count(),{remaining:10}).valid, "Negative metadata offsets are rejected")
    check(not fmp4Boxes(initialization,0,initialization.Count()+1,{remaining:10}).valid, "Metadata boundaries cannot exceed the buffer")
    many = []
    for i = 0 to 4096
        many.Append(fmp4TestBox("free"))
    end for
    check(not fmp4Scan(many).valid, "Box count limits bound CPU work")
    broken = fmp4TestJoin([fmp4TestBox("moof",fmp4TestBox("traf",fmp4TestBox("free"))),fmp4TestBox("mdat",[1])])
    check(not fmp4ViewPatches(broken,2,info).valid, "Missing tfhd fails before any read")
    broken = fmp4TestMedia()
    ' First trun data offset lies at byte 48.
    broken[48] = 255 : broken[49] = 255 : broken[50] = 255 : broken[51] = 255
    check(not fmp4ViewPatches(broken,2,info).valid, "Negative signed sample offsets fail without buffer access")
    broken = fmp4TestMedia()
    broken[41] = 0 : broken[42] = 2 : broken[43] = 1
    broken[44] = 255 : broken[45] = 255 : broken[46] = 255 : broken[47] = 255
    check(not fmp4ViewPatches(broken,2,info).valid, "Huge sample counts cannot overflow sample-table bounds")
    partial = fmp4ViewPatches(fmp4TestJoin([initialization,broken]),2,info)
    check(not partial.valid and partial.patches.Count() = 0, "A later malformed fragment discards every earlier patch")
    print "PASS bounded fMP4 parsing, immutable track views, fragment offsets and malformed media"
end sub
