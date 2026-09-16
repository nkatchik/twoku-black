sub init()
    m.top.functionName = "serveCompatibility"
end sub

' Only this Task owns sockets, CDN requests and original fragment bytes. Nothing
' large crosses a SceneGraph field or is copied into a separate audio/video body.
sub serveCompatibility()
    ' Subscribe before copying inputs so an immediate Back/request change cannot
    ' disappear between the initial snapshot and the first transport wait.
    port = CreateObject("roMessagePort")
    m.top.ObserveField("cancelRequested", port)
    m.top.ObserveField("requestId", port)
    inputs = m.top.GetFields()
    session = compatServerSession(inputs.sourceUrl, inputs.requestId)
    session.port = port
    session.cancelled = inputs.cancelRequested
    ready = compatPrepareServer(session, inputs.variant)
    compatDrainEvents(session)
    result = invalid
    if not session.cancelled
        if ready
            compatTrace(session, "prepared-split")
            ' The render observer must return before starting Video. Once this
            ' rendezvous returns, the relay never touches a SceneGraph node until
            ' all local sockets and upstream transfers have been closed.
            m.top.SetField("result", {requestId: session.requestId, url: session.baseUrl + "/master.m3u8", mode: "split", error: ""})
            compatTrace(session, "serving")
            compatRunServer(session)
            if session.error <> "" and not session.cancelled
                result = {requestId: session.requestId, url: "", mode: "split", error: "The stream compatibility session could not continue."}
            end if
        else
            compatTrace(session, "direct")
            result = {requestId: session.requestId, url: session.sourceUrl, mode: "direct", error: ""}
        end if
    end if
    ' Cleanup must precede every terminal rendezvous: Video may be blocked on a
    ' localhost response while the render thread is unable to serve field access.
    compatCleanupServer(session)
    if session.cancelled
        compatTrace(session, "cancelled")
    else if session.error <> ""
        compatTrace(session, "terminal-error")
    end if
    m.top.UnobserveField("cancelRequested")
    m.top.UnobserveField("requestId")
    compatDrainEvents(session)
    if not session.cancelled and result <> invalid then m.top.SetField("result", result)
    m.top.SetField("stats", compatServerStats(session))
end sub

sub compatRunServer(session)
    while not session.cancelled and session.error = ""
        compatDrainEvents(session)
        if session.cancelled or session.error <> "" then exit while
        compatAcceptClients(session)
        compatTickClients(session)
        compatTickTransfers(session)
        compatServerWait(session)
    end while
end sub

function compatServerSession(sourceUrl as String, requestId as Integer) as Object
    clock = CreateObject("roTimespan")
    clock.Mark()
    token = CreateObject("roDeviceInfo").GetRandomUUID()
    cache = {}
    cache.SetModeCaseSensitive()
    return {sourceUrl: sourceUrl, requestId: requestId, token: token, clock: clock,
        port: CreateObject("roMessagePort"), socketPort: CreateObject("roMessagePort"), fs: CreateObject("roFileSystem"),
        listener: invalid, clients: [], jobs: [], cache: cache, cacheBytes: 0, cacheHits: 0,
        downloads: 0, servedBytes: 0.0, files: {}, serial: 0, error: "", baseUrl: "", pathPrefix: "/" + token,
        rawPlaylist: "", parsed: invalid, playlistExpires: 0, playlistVersion: 0,
        registry: invalid, master: "", views: {}, viewVersion: -1, cancelled: false, maxBytes: 12582912, maxBody: 4194304, maxInit: 524288}
end function

function compatServerCancelled(session) as Boolean
    return session.cancelled
end function

sub compatServerWait(session)
    event = wait(50, session.port)
    compatHandleEvent(session, event)
    compatDrainEvents(session)
end sub

sub compatDrainEvents(session)
    for attempt = 1 to 64
        event = session.port.GetMessage()
        if event = invalid then return
        compatHandleEvent(session, event)
    end for
end sub

sub compatHandleEvent(session, event)
    kind = type(event)
    if kind = "roSGNodeEvent"
        field = event.GetField()
        value = event.GetData()
        if field = "cancelRequested" and value = true then session.cancelled = true
        if field = "requestId" and value <> session.requestId then session.cancelled = true
    else if kind = "roUrlEvent" and not session.cancelled
        compatCompleteTransfer(session, event)
    end if
end sub

function compatAwaitResource(session, url as String, kind as String)
    while not compatServerCancelled(session) and session.error = ""
        compatDrainEvents(session)
        if session.cancelled or session.error <> "" then exit while
        resource = compatNeedResource(session, url, kind)
        if resource <> invalid then return resource
        compatTickTransfers(session)
        compatServerWait(session)
    end while
    return invalid
end function

function compatPrepareServer(session, variant) as Boolean
    leaf = compatAwaitResource(session, session.sourceUrl, "playlist")
    if leaf = invalid then return false
    parsed = compatParseMedia(leaf.text, session.sourceUrl)
    if not parsed.valid or not parsed.hasMap then return false
    initial = compatAwaitResource(session, parsed.firstInitUrl, "init")
    if initial = invalid then return false
    info = initial.initInfo
    if not info.valid or not info.muxed then return false
    if not fmp4ViewPatches(initial.bytes, info.audioId, info).valid or not fmp4ViewPatches(initial.bytes, info.videoId, info).valid then return false
    if not compatOpenListener(session) then return false
    session.registry = {idmap: {}, resources: {}, baseUrl: session.baseUrl, counter: 0}
    session.rawPlaylist = leaf.text
    session.parsed = parsed
    session.playlistExpires = session.clock.TotalMilliseconds() + compatRefreshDelay(parsed)
    session.master = compatMasterPlaylist(session.baseUrl + "/video.m3u8", session.baseUrl + "/audio.m3u8", variant)
    return compatUpdateViews(session)
end function

function compatOpenListener(session) as Boolean
    socket = CreateObject("roStreamSocket")
    socket.SetMessagePort(session.socketPort)
    socket.NotifyReadable(false)
    socket.NotifyWritable(false)
    socket.NotifyException(false)
    address = CreateObject("roSocketAddress")
    address.SetAddress("127.0.0.1:0")
    if not socket.SetAddress(address) or not socket.Listen(6)
        socket.Close()
        return false
    end if
    bound = socket.GetAddress()
    if bound = invalid
        socket.Close()
        return false
    end if
    port = bound.GetPort()
    if port <= 0
        socket.Close()
        return false
    end if
    session.listener = socket
    session.authority = "127.0.0.1:" + port.ToStr()
    session.baseUrl = "http://" + session.authority + session.pathPrefix
    return true
end function

function compatRefreshDelay(parsed) as Integer
    delay = 1000
    if parsed.targetDuration <> invalid then delay = Int(parsed.targetDuration * 500)
    if delay < 1000 then delay = 1000
    if delay > 6000 then delay = 6000
    return delay
end function

function compatNeedResource(session, url as String, kind as String)
    if kind = "playlist"
        if session.rawPlaylist <> "" and session.clock.TotalMilliseconds() < session.playlistExpires then return {text: session.rawPlaylist}
    else if session.cache.DoesExist(url)
        item = session.cache[url]
        item.used = session.clock.TotalMilliseconds()
        session.cacheHits += 1
        return item
    end if
    if not compatUpstreamUrlAllowed(url)
        session.error = "cdn"
        return invalid
    end if
    for each job in session.jobs
        if job.url = url then return invalid
    end for
    if session.jobs.Count() >= 12
        session.error = "queue"
        return invalid
    end if
    session.jobs.Push({url: url, kind: kind, transfer: invalid, started: 0, filename: ""})
    return invalid
end function

sub compatTickTransfers(session)
    now = session.clock.TotalMilliseconds()
    active = 0
    for each job in session.jobs
        if job.transfer <> invalid
            active += 1
            limit = session.maxBody
            if job.kind = "init" then limit = session.maxInit
            if now - job.started > 10000
                session.error = "timeout"
            else if job.filename <> ""
                stat = session.fs.Stat(job.filename)
                if stat <> invalid
                    if stat.size > limit then session.error = "size"
                end if
            end if
        end if
    end for
    if session.error <> "" or compatServerCancelled(session) then return
    for each job in session.jobs
        if active >= 2 then exit for
        if job.transfer = invalid
            transfer = createHttpUrl()
            transfer.SetMessagePort(session.port)
            transfer.SetUrl(job.url)
            job.transfer = transfer
            job.started = now
            started = false
            if job.kind = "playlist"
                started = transfer.AsyncGetToString()
            else
                session.serial += 1
                job.filename = "tmp:/twoku-compat-" + session.token + "-" + session.serial.ToStr() + ".bin"
                session.files[job.filename] = true
                started = transfer.AsyncGetToFile(job.filename)
            end if
            if not started
                session.error = "start"
                return
            end if
            active += 1
        end if
    end for
end sub

sub compatCompleteTransfer(session, event)
    found = -1
    for index = 0 to session.jobs.Count() - 1
        job = session.jobs[index]
        if job.transfer <> invalid
            if job.transfer.GetIdentity() = event.GetSourceIdentity()
                found = index
                exit for
            end if
        end if
    end for
    if found < 0 then return
    job = session.jobs[found]
    session.jobs.Delete(found)
    code = event.GetResponseCode()
    if not compatResponseIsDirect(event)
        session.error = "redirect"
    else if code <> 200
        session.error = "http"
    else if job.kind = "playlist"
        body = event.GetString()
        if Len(body) > 262144
            session.error = "playlist-size"
        else
            parsed = compatParseMedia(body, session.sourceUrl)
            if not parsed.valid
                session.error = "playlist"
            else
                session.rawPlaylist = body
                session.parsed = parsed
                session.playlistExpires = session.clock.TotalMilliseconds() + compatRefreshDelay(parsed)
                session.playlistVersion += 1
            end if
        end if
    else
        limit = session.maxBody
        if job.kind = "init" then limit = session.maxInit
        stat = session.fs.Stat(job.filename)
        if stat = invalid
            session.error = "file"
        else if stat.size <= 0 or stat.size > limit
            session.error = "size"
        else if compatMakeCacheRoom(session, stat.size, job.kind)
            bytes = CreateObject("roByteArray")
            if not bytes.ReadFile(job.filename)
                session.error = "read"
            else
                item = {url: job.url, bytes: bytes, size: bytes.Count(), kind: job.kind, used: session.clock.TotalMilliseconds(), pins: 0, initInfo: invalid}
                if job.kind = "init"
                    item.initInfo = fmp4TrackInfo(bytes)
                    if not item.initInfo.valid or not item.initInfo.muxed then session.error = "init"
                end if
                if session.error = ""
                    session.cache[job.url] = item
                    session.cacheBytes += item.size
                end if
            end if
        else
            session.error = "cache"
        end if
    end if
    session.downloads += 1
    if job.filename <> ""
        session.fs.Delete(job.filename)
        session.files.Delete(job.filename)
    end if
end sub

function compatMakeCacheRoom(session, size as Integer, kind as String) as Boolean
    while true
        count = 0
        for each key in session.cache
            if session.cache[key].kind = kind then count += 1
        end for
        limit = 8
        if kind = "init" then limit = 4
        if session.cacheBytes + size <= session.maxBytes and count < limit then return true
        oldest = ""
        oldestAt = invalid
        for each key in session.cache
            item = session.cache[key]
            eligible = item.pins = 0
            if count >= limit then eligible = eligible and item.kind = kind
            if eligible
                if oldestAt = invalid or item.used < oldestAt
                    oldest = key
                    oldestAt = item.used
                end if
            end if
        end for
        if oldest = "" then return false
        session.cacheBytes -= session.cache[oldest].size
        session.cache.Delete(oldest)
    end while
end function

sub compatAcceptClients(session)
    for attempt = 1 to 6
        if not session.listener.IsReadable() then return
        socket = session.listener.Accept()
        if socket = invalid then return
        socket.SetMessagePort(session.socketPort)
        socket.NotifyReadable(false)
        socket.NotifyWritable(false)
        socket.NotifyException(false)
        peer = socket.GetSendToAddress()
        local = false
        if peer <> invalid then local = peer.GetHostName() = "127.0.0.1"
        if session.clients.Count() >= 6 or not local
            socket.Close()
        else
            session.clients.Push({socket: socket, phase: "headers", header: "", touched: session.clock.TotalMilliseconds(), born: session.clock.TotalMilliseconds(),
                request: invalid, spans: [], spanIndex: 0, spanOffset: 0, cacheKey: "", closed: false})
        end if
    end for
end sub

sub compatTickClients(session)
    now = session.clock.TotalMilliseconds()
    for each client in session.clients
        if now - client.touched > 15000 or (client.phase = "headers" and now - client.born > 10000) or not client.socket.eOK()
            compatCloseClient(session, client)
        else if client.phase = "headers"
            count = client.socket.GetCountRcvBuf()
            if count > 0
                if count > 1024 then count = 1024
                client.header += client.socket.ReceiveStr(count)
                client.touched = now
                if Len(client.header) > 8192
                    compatReplyText(client, "", 431, "text/plain")
                else if Instr(1, client.header, Chr(13) + Chr(10) + Chr(13) + Chr(10)) > 0
                    client.request = compatHttpRequest(client.header, session.authority)
                    if not client.request.valid
                        compatReplyText(client, "", client.request.code, "text/plain")
                    else
                        client.phase = "waiting"
                    end if
                end if
            else if client.socket.IsReadable()
                compatCloseClient(session, client)
            end if
        else if client.phase = "waiting"
            compatServeRoute(session, client)
        else if client.phase = "sending"
            compatSendClient(session, client)
        else if client.phase = "draining"
            if client.socket.GetCountSendBuf() = 0 then compatCloseClient(session, client)
        end if
    end for
    index = session.clients.Count() - 1
    while index >= 0
        if session.clients[index].closed then session.clients.Delete(index)
        index -= 1
    end while
end sub

function compatHttpRequest(header as String, authority as String) as Object
    result = {valid: false, code: 400, method: "", path: "", range: ""}
    lines = header.Split(Chr(13) + Chr(10))
    if lines.Count() = 0 then return result
    start = lines[0].Split(" ")
    if start.Count() <> 3 then return result
    if start[0] <> "GET" and start[0] <> "HEAD"
        result.code = 405
        return result
    end if
    if start[2] <> "HTTP/1.1" and start[2] <> "HTTP/1.0" then return result
    if Left(start[1], 1) <> "/" or Instr(1,start[1],"?") > 0 or Instr(1,start[1],"%") > 0 then return result
    for index = 1 to lines.Count() - 1
        line = lines[index]
        colon = Instr(1, line, ":")
        if colon > 0
            key = LCase(Left(line, colon - 1))
            value = Mid(line, colon + 1).Trim()
            if key = "host" and value <> authority then return result
            if key = "range"
                if result.range <> "" then return result
                result.range = value
            end if
        end if
    end for
    result.valid = true
    result.method = start[0]
    result.path = start[1]
    return result
end function

function compatHttpRange(value as String, length as Integer) as Object
    result = {valid: true, start: 0, length: length, code: 200}
    if value = "" then return result
    result.valid = false
    if Left(value,6) <> "bytes=" or Instr(1,value,",") > 0 then return result
    parts = Mid(value,7).Split("-")
    if parts.Count() <> 2 or (parts[0] = "" and parts[1] = "") then return result
    for each part in parts
        for index = 1 to Len(part)
            char = Mid(part,index,1)
            if char < "0" or char > "9" then return result
        end for
        if Len(part) > 9 then return result
    end for
    first = 0
    last = length - 1
    if parts[0] = ""
        amount = Int(Val(parts[1]))
        if amount <= 0 then return result
        first = length - amount
        if first < 0 then first = 0
    else
        first = Int(Val(parts[0]))
        if parts[1] <> "" then last = Int(Val(parts[1]))
    end if
    if first >= length or last < first then return result
    if last >= length then last = length - 1
    result.valid = true
    result.start = first
    result.length = last - first + 1
    result.code = 206
    return result
end function

function compatBytes(text as String) as Object
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(text)
    return bytes
end function

sub compatReplyText(client, text as String, code as Integer, mime as String)
    bytes = compatBytes(text)
    request = client.request
    head = false
    if request <> invalid then head = request.method = "HEAD"
    compatReplySpans(client, [{data: bytes, offset: 0, length: bytes.Count()}], bytes.Count(), code, mime, "", head)
end sub

sub compatReplySpans(client, spans, length as Integer, code as Integer, mime as String, extra as String, head as Boolean)
    reasons = {"200": "OK", "206": "Partial Content", "400": "Bad Request", "404": "Not Found", "405": "Method Not Allowed", "416": "Range Not Satisfiable", "431": "Request Header Fields Too Large", "503": "Service Unavailable"}
    reason = reasons[code.ToStr()]
    if reason = invalid then reason = "Error"
    crlf = Chr(13) + Chr(10)
    header = "HTTP/1.1 " + code.ToStr() + " " + reason + crlf + "Content-Type: " + mime + crlf
    header += "Content-Length: " + length.ToStr() + crlf + "Connection: close" + crlf + "Cache-Control: no-store" + crlf + "Accept-Ranges: bytes" + crlf + extra + crlf
    bytes = compatBytes(header)
    client.spans = [{data: bytes, offset: 0, length: bytes.Count()}]
    if not head
        for each span in spans
            if span.length > 0 then client.spans.Push(span)
        end for
    end if
    client.spanIndex = 0
    client.spanOffset = 0
    client.phase = "sending"
end sub

' Build a sparse view. Large original-byte spans are sent directly by the native
' socket; only the few replacement box-type bytes have their own tiny arrays.
function compatViewSpans(bytes, patches, start as Integer, length as Integer) as Object
    result = []
    cursor = start
    finish = start + length
    for each patch in patches
        patchEnd = patch.offset + patch.bytes.Count()
        if patchEnd > cursor and patch.offset < finish
            if patch.offset > cursor
                result.Push({data: bytes, offset: cursor, length: patch.offset - cursor})
                cursor = patch.offset
            end if
            amount = patchEnd - cursor
            if cursor + amount > finish then amount = finish - cursor
            result.Push({data: patch.bytes, offset: cursor - patch.offset, length: amount})
            cursor += amount
        end if
    end for
    if cursor < finish then result.Push({data: bytes, offset: cursor, length: finish - cursor})
    return result
end function

sub compatSendClient(session, client)
    budget = 262144
    operations = 0
    while operations < 128 and budget > 0 and client.spanIndex < client.spans.Count() and client.socket.IsWritable()
        span = client.spans[client.spanIndex]
        count = span.length - client.spanOffset
        if count > budget then count = budget
        operations += 1
        sent = client.socket.Send(span.data, span.offset + client.spanOffset, count)
        if sent <= 0 then exit while
        client.spanOffset += sent
        budget -= sent
        session.servedBytes += sent
        client.touched = session.clock.TotalMilliseconds()
        if client.spanOffset = span.length
            client.spanIndex += 1
            client.spanOffset = 0
        end if
    end while
    if client.spanIndex >= client.spans.Count() then client.phase = "draining"
end sub

sub compatCloseClient(session, client)
    if client.closed then return
    client.socket.Close()
    client.closed = true
    client.spans = []
    if client.cacheKey <> "" and session.cache.DoesExist(client.cacheKey)
        session.cache[client.cacheKey].pins -= 1
    end if
    client.cacheKey = ""
end sub

function compatServerStats(session) as Object
    return {downloads: session.downloads, cacheHits: session.cacheHits, cacheBytes: session.cacheBytes,
        clients: session.clients.Count(), servedBytes: session.servedBytes}
end function

sub compatCleanupServer(session)
    for each job in session.jobs
        if job.transfer <> invalid then job.transfer.AsyncCancel()
    end for
    for each client in session.clients
        compatCloseClient(session, client)
    end for
    if session.listener <> invalid then session.listener.Close()
    for each filename in session.files
        session.fs.Delete(filename)
    end for
    session.jobs = []
    session.clients = []
    session.cache = {}
    session.cacheBytes = 0
    session.files = {}

end sub

' Native GET may follow redirects before reporting response headers. This Task
' sends no authentication headers, permits only Twitch CDN input URLs, and does
' not accept redirected bodies whose relative resource base may have changed.
function compatResponseIsDirect(event) as Boolean
    headers = event.GetResponseHeadersArray()
    if GetInterface(headers, "ifArray") = invalid then return true
    for each header in headers
        for each key in header
            if LCase(key) = "location" then return false
        end for
    end for
    return true
end function

sub compatServeRoute(session, client)
    route = client.request.path
    if route = session.pathPrefix + "/master.m3u8"
        compatReplyText(client, session.master, 200, "application/vnd.apple.mpegurl")
        return
    end if
    track = ""
    if route = session.pathPrefix + "/audio.m3u8" then track = "audio"
    if route = session.pathPrefix + "/video.m3u8" then track = "video"
    if track <> ""
        leaf = compatNeedResource(session, session.sourceUrl, "playlist")
        if leaf = invalid then return
        if not compatUpdateViews(session) then return
        compatReplyText(client, session.views[track], 200, "application/vnd.apple.mpegurl")
        return
    end if
    prefix = session.pathPrefix + "/resource/"
    if Left(route, Len(prefix)) <> prefix
        compatReplyText(client, "", 404, "text/plain")
        return
    end if
    if client.resource = invalid
        id = Mid(route, Len(prefix) + 1)
        resource = session.registry.resources[id]
        if resource = invalid
            compatReplyText(client, "", 404, "text/plain")
            return
        end if
        ' Hold the route record even if a later playlist refresh prunes it.
        client.resource = resource
    end if
    resource = client.resource
    initial = compatNeedResource(session, resource.initUrl, "init")
    if initial = invalid then return
    info = initial.initInfo
    kind = "media"
    if resource.kind = "init" then kind = "init"
    item = compatNeedResource(session, resource.url, kind)
    if item = invalid then return
    trackId = info.videoId
    if resource.track = "audio" then trackId = info.audioId
    view = fmp4ViewPatches(item.bytes, trackId, info)
    if not view.valid
        session.error = "fragment"
        return
    end if
    range = compatHttpRange(client.request.range, item.size)
    mime = "video/mp4"
    if resource.track = "audio" then mime = "audio/mp4"
    if not range.valid
        compatReplySpans(client, [], 0, 416, mime, "Content-Range: bytes */" + item.size.ToStr() + Chr(13) + Chr(10), client.request.method = "HEAD")
        return
    end if
    extra = ""
    if range.code = 206
        last = range.start + range.length - 1
        extra = "Content-Range: bytes " + range.start.ToStr() + "-" + last.ToStr() + "/" + item.size.ToStr() + Chr(13) + Chr(10)
    end if
    spans = []
    if client.request.method <> "HEAD"
        spans = compatViewSpans(item.bytes, view.patches, range.start, range.length)
        item.pins += 1
        client.cacheKey = resource.url
    end if
    compatReplySpans(client, spans, range.length, range.code, mime, extra, client.request.method = "HEAD")
end sub

function compatUpdateViews(session) as Boolean
    if session.viewVersion = session.playlistVersion then return true
    audio = compatRewriteMedia(session.rawPlaylist, session.sourceUrl, "audio", session.registry)
    video = compatRewriteMedia(session.rawPlaylist, session.sourceUrl, "video", session.registry)
    if not audio.valid or not video.valid
        session.error = "playlist"
        return false
    end if
    session.views = {audio: audio.text, video: video.text}
    session.viewVersion = session.playlistVersion
    keep = {}
    for each id in audio.resourceIds
        keep[id] = true
    end for
    for each id in video.resourceIds
        keep[id] = true
    end for
    compatPruneRegistry(session.registry, keep)
    return true
end function

sub compatPruneRegistry(registry, keep)
    ' Keep a small trailing window for the decoder's already-read playlists.
    cutoff = registry.counter - 128
    remove = []
    for each id in registry.resources
        if not keep.DoesExist(id) and Val(id) < cutoff then remove.Push(id)
    end for
    for each id in remove
        resource = registry.resources[id]
        registry.idmap.Delete(resource.registryKey)
        registry.resources.Delete(id)
    end for
end sub

' Fixed stage/error codes and numeric counters only; never print signed URLs.
sub compatTrace(session, stage as String)
    print "Playback compatibility "; stage; " request="; session.requestId; " error="; session.error; " downloads="; session.downloads; " bytes="; session.servedBytes
end sub
