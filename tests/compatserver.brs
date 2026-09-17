' Native socket/transfer/byte primitives are doubled; every server state change,
' manifest decision, fMP4 patch and range calculation uses production functions.
function testCreateObject(kind, ignored = invalid, flags = invalid)
    g = getGlobalAA()
    if kind = "roByteArray" then return []
    if kind = "roMessagePort"
        return {GetMessage: function()
            g = getGlobalAA()
            if not g.deliverEvents or g.events.Count() = 0 then return invalid
            return g.events.Shift()
        end function}
    end if
    if kind = "roRegex" then return CreateObject(kind, ignored, flags)
    if kind = "roTimespan"
        return {at: g.now, Mark: sub()
            m.at = getGlobalAA().now
        end sub, TotalMilliseconds: function()
            return getGlobalAA().now - m.at
        end function}
    end if
    if kind = "roDeviceInfo"
        return {GetRandomUUID: function()
            return "opaque-session"
        end function}
    end if
    if kind = "roSocketAddress"
        return {SetAddress: sub(value)
            m.value = value
        end sub, GetPort: function()
            return 34567
        end function, GetHostName: function()
            return "127.0.0.1"
        end function}
    end if
    if kind = "roStreamSocket"
        socket = testSocket()
        g.sockets.Push(socket)
        return socket
    end if
    if kind = "roFileSystem"
        return {Stat: function(filename)
            bytes = getGlobalAA().files[filename]
            if bytes = invalid then return {}
            if type(bytes) = "String" or type(bytes) = "roString" then return {size: Len(bytes)}
            return {size: bytes.Count()}
        end function, Delete: function(filename)
            getGlobalAA().files.Delete(filename)
            return true
        end function}
    end if
    if kind = "roUrlTransfer"
        transfer = {id: g.transfers.Count() + 1, assignedPort: false, cancelled: false, url: "",
            EnableEncodings: sub(value)
            end sub, RetainBodyOnError: sub(value)
            end sub, SetCertificatesFile: sub(value)
                check(value = "common:/certs/ca-bundle.crt", "Native TLS trust is retained")
            end sub, InitClientCertificates: sub()
            end sub, SetMessagePort: sub(port)
                m.assignedPort = true
            end sub, SetUrl: sub(url)
                check(compatUpstreamUrlAllowed(url), "Only validated Twitch CDN requests start")
                m.url = url
            end sub, GetIdentity: function()
                return m.id
            end function, AsyncCancel: sub()
                m.cancelled = true
            end sub, AsyncGetToString: function()
                return testQueueTransfer(m, "")
            end function, AsyncGetToFile: function(filename)
                return testQueueTransfer(m, filename)
            end function}
        g.transfers.Push(transfer)
        return transfer
    end if
    check(false, "Unexpected native primitive: " + kind)
    return invalid
end function

function testQueueTransfer(transfer, filename)
    g = getGlobalAA()
    check(transfer.assignedPort, "Upstream transfers are asynchronous")
    if not g.startOk then return false
    response = g.responses[transfer.url]
    if response = invalid then response = {body: "", code: 404, headers: []}
    if filename <> "" then g.files[filename] = response.body
    event = {eventType: "roUrlEvent", id: transfer.id, response: response,
        GetSourceIdentity: function()
            return m.id
        end function, GetResponseCode: function()
            return m.response.code
        end function, GetString: function()
            return m.response.body
        end function, GetResponseHeadersArray: function()
            return m.response.headers
        end function}
    g.events.Push(event)
    return true
end function

function testWait(delay, port)
    g = getGlobalAA()
    check(delay = 50, "Each transport poll yields with a bounded cancellation interval")
    g.now += delay
    if g.cancelAt > 0 and g.now >= g.cancelAt and not g.cancelDelivered
        g.savedTop.cancelRequested = true
        g.events.Push(testNodeEvent("cancelRequested",true))
        g.cancelDelivered = true
    end if
    if g.staleAt > 0 and g.now >= g.staleAt and not g.staleDelivered
        g.savedTop.requestId += 1
        g.events.Push(testNodeEvent("requestId",g.savedTop.requestId))
        g.staleDelivered = true
    end if
    if g.injectClient and g.sockets.Count() > 0
        socket = testSocket()
        socket.input = "GET /opaque-session/resource/4 HTTP/1.1" + Chr(13)+Chr(10) + "Host: 127.0.0.1:34567" + Chr(13)+Chr(10)+Chr(13)+Chr(10)
        g.sockets[0].accepted.Push(socket)
        g.injectClient = false
    end if
    if not g.deliverEvents or g.events.Count() = 0 then return invalid
    return g.events.Shift()
end function

function testNodeEvent(field, value)
    return {eventType:"roSGNodeEvent",field:field,value:value,
        GetField:function()
            return m.field
        end function,GetData:function()
            return m.value
        end function}
end function

function testType(value)
    if type(value) = "roAssociativeArray"
        if value.eventType <> invalid then return value.eventType
    end if
    return type(value)
end function

sub testBytesFromAsciiString(bytes, text)
    bytes.Clear()
    for index = 1 to Len(text)
        bytes.Push(Asc(Mid(text,index,1)))
    end for
end sub

function testReadBytes(bytes, filename)
    stored = getGlobalAA().files[filename]
    if stored = invalid then return false
    bytes.Append(stored)
    return true
end function

function testSocket()
    return {closed: false, assignedPort: false, output: [], input: "", accepted: [], maxSend: 17, zeroSend: false,
        SetMessagePort: sub(port)
            m.assignedPort = true
        end sub, NotifyReadable: sub(value)
            check(not value, "Polling sockets do not accumulate notifications")
        end sub, NotifyWritable: sub(value)
            check(not value, "Polling sockets do not accumulate notifications")
        end sub, NotifyException: sub(value)
            check(not value, "Polling sockets do not accumulate notifications")
        end sub, SetAddress: function(address)
            m.isListener = true
            check(m.assignedPort and address.value = "127.0.0.1:0", "Server binds loopback on an ephemeral port with nonblocking IO")
            return true
        end function, Listen: function(backlog)
            check(backlog = 6, "Listener backlog is bounded")
            return true
        end function, GetAddress: function()
            return testCreateObject("roSocketAddress")
        end function, GetSendToAddress: function()
            return testCreateObject("roSocketAddress")
        end function, IsReadable: function()
            return Len(m.input) > 0 or m.accepted.Count() > 0
        end function, Accept: function()
            return m.accepted.Shift()
        end function, eOK: function()
            return not m.closed
        end function, IsWritable: function()
            return true
        end function, GetCountRcvBuf: function()
            return Len(m.input)
        end function, ReceiveStr: function(count)
            chunk = Left(m.input,count)
            m.input = Mid(m.input,count+1)
            return chunk
        end function, Send: function(data, offset, count)
            check(count > 0, "No zero-byte writes can strand an empty HTTP response")
            if m.zeroSend then return 0
            if count > m.maxSend then count = m.maxSend
            for index = offset to offset + count - 1
                m.output.Push(data[index])
            end for
            return count
        end function, GetCountSendBuf: function()
            return 0
        end function, Close: sub()
            m.closed = true
            g = getGlobalAA()
            if m.isListener = true
                ' Simulate the render thread being unavailable throughout native
                ' playback startup. Any Task field access before closing the
                ' listener would dereference invalid and fail this test.
                g.owner.top = g.savedTop
                g.active = false
            end if
        end sub}
end function

sub testReset()
    g = getGlobalAA()
    g.now = 0
    g.cancelAt = 0
    g.staleAt = 0
    g.cancelDelivered = false
    g.staleDelivered = false
    g.active = false
    g.snapshots = 0
    g.readyCount = 0
    g.finalWrites = 0
    g.owner = m
    g.deliverEvents = true
    g.startOk = true
    g.injectClient = false
    g.transfers = []
    g.events = []
    g.sockets = []
    g.files = {}
    g.responses = {}
    g.responses.SetModeCaseSensitive()
    m.top = {sourceUrl: "https://video.ttvnw.net/path/index.m3u8", requestId: 9, cancelRequested: false, variant: {width: 1920,height: 1080,frameRate: 60,bandwidth: 8000000}, result: invalid}
    g.savedTop = m.top
    m.top.observers = {}
    m.top.ObserveField = function(field, port)
        check(not getGlobalAA().active,"Observers are installed before local playback starts")
        m.observers[field] = port
        return true
    end function
    m.top.GetFields = function()
        g = getGlobalAA()
        check(not g.active,"No render-owned input snapshot occurs while serving Video")
        check(m.observers.cancelRequested <> invalid and m.observers.requestId <> invalid,"Cancellation and request version are observed before startup input is copied")
        g.snapshots += 1
        return {sourceUrl:m.sourceUrl,requestId:m.requestId,cancelRequested:m.cancelRequested,variant:m.variant}
    end function
    m.top.UnobserveField = function(field)
        check(not getGlobalAA().active,"Field observers are removed only after listener cleanup")
        m.observers.Delete(field)
        return true
    end function
    m.top.SetField = function(field, value)
        g = getGlobalAA()
        check(not g.active,"No SceneGraph result or stats writes occur during active loopback serving")
        m[field] = value
        ready = false
        if field = "result" then ready = (value.mode = "split" or value.mode = "manifest") and value.url <> ""
        if ready
            g.active = true
            g.readyCount += 1
            g.owner.top = invalid
        else
            for each socket in g.sockets
                check(socket.closed,"Every local socket closes before terminal SceneGraph publication")
            end for
            check(g.files.Count() = 0,"All temporary files are removed before terminal SceneGraph publication")
            g.finalWrites += 1
        end if
        return true
    end function
    nl = Chr(10)
    g.leaf = "#EXTM3U" + nl + "#EXT-X-TARGETDURATION:2" + nl + "#EXT-X-MEDIA-SEQUENCE:100" + nl + "#EXT-X-MAP:URI=" + Chr(34) + "init.mp4" + Chr(34) + nl + "#EXTINF:2," + nl + "one.m4s" + nl
    g.responses[m.top.sourceUrl] = {body: g.leaf, code: 200, headers: []}
    g.responses["https://video.ttvnw.net/path/init.mp4"] = {body: testInitBytes(), code: 200, headers: []}
    g.responses["https://video.ttvnw.net/path/one.m4s"] = {body: testMediaBytes(), code: 200, headers: []}
end sub

function testU32(value)
    return [Int(value / 16777216#) mod 256,Int(value / 65536#) mod 256,Int(value / 256#) mod 256,value mod 256]
end function
function testJoin(parts)
    result = []
    for each part in parts
        result.Append(part)
    end for
    return result
end function
function testBox(kind, content)
    result = testU32(content.Count()+8)
    for index = 1 to 4
        result.Push(Asc(Mid(kind,index,1)))
    end for
    result.Append(content)
    return result
end function
function testInitBytes()
    tracks = []
    defaults = []
    for id = 1 to 2
        handler = "soun"
        if id = 2 then handler = "vide"
        header = []
        for index = 0 to 83
            header.Push(0)
        end for
        header[15] = id
        mediaHandler = [0,0,0,0,0,0,0,0]
        for index = 1 to 4
            mediaHandler.Push(Asc(Mid(handler,index,1)))
        end for
        mediaHandler.Append([0,0,0,0,0,0,0,0,0,0,0,0])
        tracks.Append(testBox("trak",testJoin([testBox("tkhd",header),testBox("mdia",testBox("hdlr",mediaHandler))])))
        defaults.Append(testBox("trex",testJoin([[0,0,0,0],testU32(id),[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]])))
    end for
    tracks.Append(testBox("mvex",defaults))
    return testJoin([testBox("ftyp",[105,115,111,109,0,0,0,1]),testBox("moov",tracks)])
end function
function testMediaBytes()
    tracks = []
    for id = 1 to 2
        tracks.Append(testBox("traf",testJoin([testBox("tfhd",testJoin([testU32(&h20000),testU32(id)])),testBox("trun",testJoin([[0,0,0,1,0,0,0,1],testU32(100+id*4)]))])))
    end for
    return testJoin([testBox("moof",tracks),testBox("mdat",[10,20,30,40,50,60,70,80])])
end function
function testClient(path, method = "GET", range = "")
    return {socket: testSocket(),phase: "waiting",header: "",touched: getGlobalAA().now,born: getGlobalAA().now,
        request: {valid: true,method: method,path: path,range: range},spans: [],spanIndex: 0,spanOffset: 0,cacheKey: "",closed: false}
end function
function testText(bytes)
    result = ""
    for each byte in bytes
        result += Chr(byte)
    end for
    return result
end function
sub testDrain(session, client)
    for attempt = 1 to 100
        compatSendClient(session, client)
        if client.phase = "draining" then exit for
    end for
    check(client.phase = "draining", "Partial writes eventually finish exactly one response")
end sub

sub main()
    testReset()
    g = getGlobalAA()
    session = compatServerSession(m.top.sourceUrl,m.top.requestId)
    check(compatPrepareServer(session,m.top.variant), "A verified muxed initialization starts a loopback session")
    check(g.transfers.Count() = 2 and session.cacheBytes > 0, "Preparation fetches one playlist and one initialization")
    check(session.baseUrl = "http://127.0.0.1:34567/opaque-session", "Native bound port and opaque session form the local URL")
    check(Instr(1,session.master,"https://") = 0, "Master exposes only local track playlists")
    audio = testClient(session.pathPrefix + "/audio.m3u8")
    video = testClient(session.pathPrefix + "/video.m3u8")
    compatServeRoute(session,audio)
    compatServeRoute(session,video)
    check(g.transfers.Count() = 2 and session.registry.counter = 4, "Paired leaves share a recent upstream timeline and stable opaque IDs")
    testDrain(session,audio)
    check(Instr(1,testText(audio.socket.output),"#EXT-X-MEDIA-SEQUENCE:100") > 0, "Local media leaf preserves its sequence")
    check(Instr(1,testText(audio.socket.output),"https://") = 0, "Signed CDN addresses never appear in a local response")
    audio = testClient(session.pathPrefix + "/resource/2")
    video = testClient(session.pathPrefix + "/resource/4")
    compatServeRoute(session,audio)
    compatServeRoute(session,video)
    check(session.jobs.Count() = 1, "Concurrent track views coalesce one upstream media fetch")
    compatTickTransfers(session)
    compatServerWait(session)
    compatServeRoute(session,audio)
    compatServeRoute(session,video)
    check(session.cache["https://video.ttvnw.net/path/one.m4s"].pins = 2, "Both responses pin the same original fragment")
    testDrain(session,audio)
    testDrain(session,video)
    check(Instr(1,testText(video.socket.output),"Content-Length: 112") > 0, "Patched track view retains the original media length")
    compatCloseClient(session,audio)
    compatCloseClient(session,video)
    check(session.cache["https://video.ttvnw.net/path/one.m4s"].pins = 0, "Completed client cleanup releases shared cache pins")
    invalidClient = testClient("/wrong-session/master.m3u8")
    compatServeRoute(session,invalidClient)
    testDrain(session,invalidClient)
    check(Instr(1,testText(invalidClient.socket.output),"404 Not Found") > 0, "Unknown opaque routes finish an empty404 without killing the session")
    check(session.error = "", "Local request errors do not terminate playback")
    head = testClient(session.pathPrefix + "/resource/4","HEAD","bytes=10-19")
    compatServeRoute(session,head)
    testDrain(session,head)
    text = testText(head.socket.output)
    check(Instr(1,text,"206 Partial Content") > 0 and Instr(1,text,"Content-Length: 10") > 0 and Instr(1,text,"Content-Range: bytes 10-19/112") > 0, "HEAD byte ranges advertise precise native view bounds")
    check(Right(text,4) = Chr(13)+Chr(10)+Chr(13)+Chr(10), "HEAD contains no body")
    badRange = testClient(session.pathPrefix + "/resource/4","GET","bytes=112-")
    compatServeRoute(session,badRange)
    testDrain(session,badRange)
    check(Instr(1,testText(badRange.socket.output),"416 Range Not Satisfiable") > 0, "Out-of-bounds requests finish with416")
    check(compatHttpRange("bytes=-5",112).start = 107 and compatHttpRange("bytes=110-999",112).length = 2, "Suffix and clamped ranges are valid")
    for each value in ["bytes=-0","bytes=9-2","bytes=0-1,3-4","bytes=x-4","bytes=9999999999-"]
        check(not compatHttpRange(value,112).valid,"Malformed or multipart byte ranges are rejected")
    end for
    crlf = Chr(13)+Chr(10)
    request = "GET /opaque-session/master.m3u8 HTTP/1.1" + crlf + "Host: 127.0.0.1:34567" + crlf + crlf
    check(compatHttpRequest(request,session.authority).valid,"Native origin-form request parses")
    check(not compatHttpRequest(request.Replace("127.0.0.1:34567","evil.test"),session.authority).valid,"Foreign Host is rejected")
    check(compatHttpRequest(request.Replace("GET ","POST "),session.authority).code = 405,"Unsupported HTTP methods are rejected")
    check(not compatHttpRequest(request.Replace("/opaque-session/master.m3u8","https://video.ttvnw.net/a"),session.authority).valid,"Absolute proxy URLs are rejected")
    check(not compatHttpRequest(request.Replace("Host:","Range: bytes=0-1"+crlf+"Range: bytes=1-2"+crlf+"Host:"),session.authority).valid,"Duplicate ranges are rejected")
    before = session.registry.counter
    g.now += 1001
    compatServeRoute(session,testClient(session.pathPrefix + "/audio.m3u8"))
    compatServeRoute(session,testClient(session.pathPrefix + "/video.m3u8"))
    check(session.jobs.Count() = 1,"Expired track playlists coalesce one refresh")
    compatTickTransfers(session)
    compatServerWait(session)
    check(compatUpdateViews(session) and session.registry.counter = before,"Unchanged refreshed playlists retain resource identities")
    for index = 1 to 150
        compatRegisterResource(session.registry,"https://video.ttvnw.net/old"+index.ToStr()+".m4s","segment","https://video.ttvnw.net/path/init.mp4","video")
    end for
    compatPruneRegistry(session.registry,{"1":true,"2":true,"3":true,"4":true})
    check(session.registry.resources.Count() <= 133 and session.registry.idmap.Count() = session.registry.resources.Count(),"Old resource and URL-key maps are pruned together")
    check(session.registry.resources["1"] <> invalid,"Current playlist resources survive pruning")
    check(compatNeedResource(session,"https://video.ttvnw.net/path/one.m4s?sig=A","media") = invalid,"Case-sensitive URL queued")
    check(compatNeedResource(session,"https://video.ttvnw.net/path/one.m4s?sig=a","media") = invalid and session.jobs.Count() = 2,"Case-only signed URL differences are never coalesced")
    compatTickTransfers(session)
    check(session.jobs[0].transfer <> invalid and session.jobs[1].transfer <> invalid,"Two independent upstream fetches may run")
    compatNeedResource(session,"https://video.ttvnw.net/third.m4s","media")
    compatTickTransfers(session)
    check(session.jobs[2].transfer = invalid,"A third transfer stays queued")
    transfers = [session.jobs[0].transfer,session.jobs[1].transfer]
    compatCleanupServer(session)
    check(transfers[0].cancelled and transfers[1].cancelled and session.listener.closed,"Cleanup cancels every active transfer and closes the listener")
    check(g.files.Count() = 0 and session.cacheBytes = 0 and compatServerStats(session).clients = 0,"Cleanup removes temporary media files and cached originals")
    testReset()
    g.cancelAt = 200
    serveCompatibility()
    check(m.top.result.mode = "split" and m.top.result.requestId = 9,"Successful split session publishes the initiating request ID")
    check(g.sockets[0].closed and m.top.stats.cacheBytes = 0,"Canceling an active session returns promptly and frees its listener/cache")
    check(g.snapshots = 1 and g.readyCount = 1 and g.finalWrites = 1 and m.top.observers.Count() = 0,"Active relay survives render-field isolation and unregisters its per-run message port")
    ' The same Task may run again; the previous noncopyable port is never reused.
    previousTransfers = g.transfers.Count()
    m.top.cancelRequested = false
    g.cancelDelivered = false
    g.cancelAt = g.now + 200
    serveCompatibility()
    check(g.transfers.Count() = previousTransfers + 2 and g.readyCount = 2 and m.top.observers.Count() = 0,"A restarted Task creates fresh event observers and fetches its own session")
    testReset()
    g.cancelAt = 50
    serveCompatibility()
    check(m.top.result = invalid,"Cancellation during preparation never publishes a stale playback URL")
    testReset()
    g.staleAt = 50
    serveCompatibility()
    check(m.top.result = invalid,"Changed request ID discards stale preparation")
    testReset()
    g.responses[m.top.sourceUrl].body = "#EXTM3U"+Chr(10)+"#EXT-X-TARGETDURATION:2"+Chr(10)+"#EXTINF:2,"+Chr(10)+"one.ts"+Chr(10)
    g.cancelAt = 200
    serveCompatibility()
    check(m.top.result.mode = "manifest" and m.top.result.requestId = 9, "Transport-stream playback preserves selected rendition metadata in a local master")
    check(g.transfers.Count() = 1 and g.readyCount = 1 and g.sockets[0].closed, "Manifest service downloads no media and closes on cancellation without render-field access")
    testReset()
    g.responses[m.top.sourceUrl].body = "#EXTM3U"+Chr(10)+"#EXT-X-TARGETDURATION:2"+Chr(10)+"#EXTINF:2,"+Chr(10)+"one.ts"+Chr(10)
    session = compatServerSession(m.top.sourceUrl, 9)
    check(compatPrepareServer(session, m.top.variant) and session.mode = "manifest", "Valid TS metadata prepares a master-only session")
    client = testClient(session.pathPrefix + "/master.m3u8")
    compatServeRoute(session, client)
    testDrain(session, client)
    check(Instr(1, testText(client.socket.output), "BANDWIDTH=8000000,RESOLUTION=1920x1080,FRAME-RATE=60") > 0, "Native master response carries the selected rendition's actual bitrate")
    check(Instr(1, testText(client.socket.output), m.top.sourceUrl) > 0, "Media playlist is fetched directly from Twitch by native HLS")
    client = testClient(session.pathPrefix + "/video.m3u8")
    compatServeRoute(session, client)
    testDrain(session, client)
    check(Instr(1, testText(client.socket.output), "404 Not Found") > 0 and g.transfers.Count() = 1, "Master-only routes cannot enter the split media proxy")
    compatCleanupServer(session)
    testReset()
    g.responses[m.top.sourceUrl].body = "#EXTM3U"+Chr(10)+"#EXT-X-TARGETDURATION:2"+Chr(10)+"#EXTINF:2,"+Chr(10)+"one.ts"+Chr(10)
    m.top.variant = {}
    serveCompatibility()
    check(m.top.result.mode = "direct" and m.top.result.url = m.top.sourceUrl and g.sockets.Count() = 0, "Missing rendition metadata retains direct playback")
    testReset()
    g.responses[m.top.sourceUrl].headers = [{Location:"https://other.example/a"}]
    serveCompatibility()
    check(m.top.result.mode = "direct" and g.sockets.Count() = 0,"Redirected preparation is left to native direct playback")
    testReset()
    g.startOk = false
    serveCompatibility()
    check(m.top.result.mode = "direct","Failed async start has a direct preparation fallback")
    testReset()
    g.deliverEvents = false
    serveCompatibility()
    check(g.now <= 10200 and g.transfers[0].cancelled and m.top.result.mode = "direct","A stalled upstream reaches its deadline and is canceled")
    testReset()
    g.injectClient = true
    g.cancelAt = 2000
    g.responses["https://video.ttvnw.net/path/one.m4s"].code = 500
    serveCompatibility()
    check(m.top.result.mode = "split" and m.top.result.url = "" and m.top.result.error <> "" and m.top.result.requestId = 9,"Fatal active upstream failure publishes a recoverable player result with the same request ID")
    check(g.sockets[0].closed and g.files.Count() = 0,"Active failure closes the listener and removes pending files")
    testReset()
    limited = {cache: {},cacheBytes: 800,maxBytes: 1000}
    for index = 1 to 8
        limited.cache[index.ToStr()] = {size:100,used:index,pins:0,kind:"media"}
    end for
    check(compatMakeCacheRoom(limited,400,"media"),"Byte-limited cache can make room without copying a fragment")
    check(limited.cacheBytes = 600 and limited.cache.Count() = 6 and not limited.cache.DoesExist("1") and not limited.cache.DoesExist("2"),"Byte cap evicts the least recently used unpinned originals with exact accounting")
    limited = {cache:{},cacheBytes:800,maxBytes:10000}
    for index = 1 to 8
        limited.cache[index.ToStr()] = {size:100,used:index,pins:0,kind:"media"}
    end for
    check(compatMakeCacheRoom(limited,100,"media") and limited.cache.Count() = 7 and limited.cacheBytes = 700,"Eight-media cap reserves one slot even with spare byte capacity")
    limited = {cache:{},cacheBytes:400,maxBytes:10000}
    for index = 1 to 4
        limited.cache[index.ToStr()] = {size:100,used:index,pins:0,kind:"init"}
    end for
    check(compatMakeCacheRoom(limited,100,"init") and limited.cache.Count() = 3 and limited.cacheBytes = 300,"Four-init cap reserves one slot even with spare byte capacity")
    limited = {cache:{one:{size:100,used:1,pins:1,kind:"media"},two:{size:100,used:2,pins:1,kind:"media"}},cacheBytes:200,maxBytes:200}
    check(not compatMakeCacheRoom(limited,100,"media") and limited.cacheBytes = 200 and limited.cache.Count() = 2,"Pinned original bodies cannot be evicted or removed from byte accounting")
    limited.cache.two.pins = 0
    check(compatMakeCacheRoom(limited,100,"media") and limited.cache.DoesExist("one") and not limited.cache.DoesExist("two") and limited.cacheBytes = 100,"A newer unpinned body is evicted before an older in-flight body")
    session = compatServerSession(m.top.sourceUrl,m.top.requestId)
    check(session.maxBytes = 12582912 and session.maxBody = 4194304 and session.maxInit = 524288,"Session initializes the documented RAM and input-file bounds")
    session.cache["https://video.ttvnw.net/a?sig=A"] = {marker:1}
    session.cache["https://video.ttvnw.net/a?sig=a"] = {marker:2}
    check(session.cache.Count() = 2,"Original-byte cache keeps case-sensitive signed URL keys")
    session.cache = {}
    check(compatOpenListener(session),"Loopback listener opens for bounded client tests")
    sockets = []
    for index = 1 to 7
        socket = testSocket()
        sockets.Push(socket)
        session.listener.accepted.Push(socket)
    end for
    compatAcceptClients(session)
    compatAcceptClients(session)
    check(session.clients.Count() = 6 and sockets[6].closed,"Only six concurrent HTTP clients are retained")
    for each client in session.clients
        compatCloseClient(session,client)
    end for
    session.clients = []
    socket = testSocket()
    socket.input = "GET /opaque-session/master.m3u8 HTTP/1.1" + crlf
    session.listener.accepted.Push(socket)
    compatAcceptClients(session)
    compatTickClients(session)
    check(session.clients[0].phase = "headers","Partial HTTP headers wait without reading missing bytes")
    socket.input = "Host: 127.0.0.1:34567"+crlf+crlf
    compatTickClients(session)
    check(session.clients[0].phase = "waiting","Subsequent HTTP header bytes complete one request")
    session.master = "#EXTM3U"+Chr(10)
    for attempt = 1 to 10
        compatTickClients(session)
    end for
    check(session.clients.Count() = 0 and socket.closed,"Partial-request response drains and closes the client")
    socket = testSocket()
    session.listener.accepted.Push(socket)
    compatAcceptClients(session)
    g.now = 10001
    session.clients[0].touched = g.now
    compatTickClients(session)
    check(socket.closed and session.clients.Count() = 0,"Slow header input has an absolute deadline independent of recent bytes")
    compatCleanupServer(session)
    session = compatServerSession(m.top.sourceUrl,m.top.requestId)
    compatHandleEvent(session,testNodeEvent("cancelRequested",true))
    compatHandleEvent(session,testNodeEvent("cancelRequested",false))
    check(session.cancelled,"Queued cancellation remains sticky even if a newer launch resets the field")
    session.cancelled = false
    compatHandleEvent(session,testNodeEvent("requestId",session.requestId+1))
    compatHandleEvent(session,testNodeEvent("requestId",session.requestId))
    check(session.cancelled,"A stale request stays canceled even if another event repeats its old version")
    session.cancelled = false
    for index = 1 to 3
        g.events.Push(testNodeEvent("cancelRequested",false))
    end for
    g.events.Push(testNodeEvent("cancelRequested",true))
    compatDrainEvents(session)
    check(session.cancelled and g.events.Count() = 0,"Already-queued cancellation is drained before the next socket tick")
    for each stat in [invalid, {}, {type:"directory"}, {size:invalid}, {size:"12"}, {size:-1}]
        check(compatStatSize(stat) = -1,"Native missing or nonnumeric file size is never compared as a number")
    end for
    check(compatStatSize({size:0}) = 0 and compatStatSize({size:112}) = 112,"Known file sizes retain zero and exact byte counts")
    testReset()
    session = compatServerSession(m.top.sourceUrl,m.top.requestId)
    compatNeedResource(session,"https://video.ttvnw.net/path/init.mp4","init")
    compatTickTransfers(session)
    job = session.jobs[0]
    body = g.files[job.filename]
    g.files.Delete(job.filename)
    compatTickTransfers(session)
    check(session.error = "" and session.jobs.Count() = 1,"Empty native Stat while async download creates its file keeps waiting without a debugger crash")
    g.files[job.filename] = body
    compatDrainEvents(session)
    check(session.error = "" and session.cacheBytes = body.Count(),"Delayed file creation completes and caches normally")
    compatCleanupServer(session)
    testReset()
    session = compatServerSession(m.top.sourceUrl,m.top.requestId)
    compatNeedResource(session,"https://video.ttvnw.net/path/init.mp4","init")
    compatTickTransfers(session)
    g.files.Delete(session.jobs[0].filename)
    compatDrainEvents(session)
    check(session.error = "file" and session.cacheBytes = 0,"Missing size after successful transfer reports a file error without entering the debugger")
    compatCleanupServer(session)
    print "PASS loopback lifecycle, coalesced CDN fetches, shared originals, sparse HTTP views, bounded queues, cancellation and direct fallback"
end sub
