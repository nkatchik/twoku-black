#!/usr/bin/env python3
"""Verify production BrightScript track views preserve encoded and decoded media.

Requires brs, ffmpeg and ffprobe. With no --fixture, generates a small audio-first
fragmented MP4 in a temporary directory. --fixture accepts an existing init plus
media recording; no third-party binaries or media are added to the repository.
The test-only roArray bridge substitutes native roByteArray storage in brs, which
has no roByteArray implementation. Every parser and patch decision is production
BrightScript. Full media bytes are supplied, but the production parser only reads
bounded container metadata and never traverses mdat payload bytes.
"""
import argparse
from fractions import Fraction
import hashlib
import json
import re
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def invoke(command, *, timeout=120):
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'{Path(command[0]).name} failed: {result.stderr[:2000]} {result.stdout[:1000]}')
    return result.stdout, result.stderr


def boxes(data):
    position = 0
    while position < len(data):
        if len(data) - position < 8:
            raise ValueError('Truncated fixture box')
        size, kind = struct.unpack_from('>I4s', data, position)
        header = 8
        if size == 1:
            if len(data) - position < 16:
                raise ValueError('Truncated extended fixture box')
            size = struct.unpack_from('>Q', data, position + 8)[0]
            header = 16
        elif size == 0:
            size = len(data) - position
        if size < header or size > len(data) - position:
            raise ValueError('Invalid fixture box bounds')
        yield position, size, kind
        position += size


def production_views(brs, source, work, server_spans=False):
    top = list(boxes(source))
    media_offset = next(offset for offset, _, kind in top if kind == b'moof')
    # Preserve the original init/segment boundary, as the on-device server does.
    # JSON is only an off-device binary transport into the brs interpreter.
    (work / 'init.json').write_text(json.dumps(list(source[:media_offset]), separators=(',', ':')))
    (work / 'media.json').write_text(json.dumps(list(source[media_offset:]), separators=(',', ':')))
    implementation = (ROOT / 'components/Fmp4Compat.brs').read_text().replace('CreateObject(', 'testCreateObject(')
    bridge = '''
function testCreateObject(kind as String)
    if kind = "roByteArray" then return []
    return invalid
end function
sub emitPatches(data, id, info, kind, part)
    result = fmp4ViewPatches(data,id,info)
    if not result.valid
        print "FMP4_FAIL "; result.error
        stop
    end if
    for each patch in result.patches
        print "FMP4_PATCH "; kind; " "; part; " "; patch.offset.ToStr(); " "; patch.bytes[0].ToStr(); " "; patch.bytes[1].ToStr(); " "; patch.bytes[2].ToStr(); " "; patch.bytes[3].ToStr()
    end for
end sub
sub main()
    initialization = ParseJson(ReadAsciiFile("pkg:/init.json"))
    media = ParseJson(ReadAsciiFile("pkg:/media.json"))
    info = fmp4TrackInfo(initialization)
    if not info.valid or not info.muxed
        print "FMP4_FAIL "; info.error
        stop
    end if
    emitPatches(initialization,info.audioId,info,"audio","init")
    emitPatches(media,info.audioId,info,"audio","media")
    emitPatches(initialization,info.videoId,info,"video","init")
    emitPatches(media,info.videoId,info,"video","media")
    print "FMP4_PASS"
end sub
'''
    if server_spans:
        server = (ROOT / 'components/PlaybackCompatibility.brs').read_text()
        for name in ('compatViewSpans', 'compatSendClient', 'compatTrackView', 'compatSliceSpans'):
            match = re.search(r'(?ims)^(?:function|sub)\s+' + name + r'\([^\n]*\n.*?^end (?:function|sub)', server)
            if match is None:
                raise ValueError('Missing production server helper: ' + name)
            implementation += '\n' + match.group()
        bridge = bridge.replace('    for each patch in result.patches', '    emitServerProof(data,result.patches,kind,part)\n    for each patch in result.patches', 1)
        # MP4 file indexes are not present in an HLS segment. Keep the original
        # file for the size-preserving proof and omit only its trailing mfra here.
        media = source[media_offset:]
        media_boxes = list(boxes(media))
        if media_boxes[-1][2] == b'mfra':
            media = media[:media_boxes[-1][0]]
        (work / 'compact.json').write_text(json.dumps(list(media), separators=(',', ':')))
        bridge = bridge.replace('    print "FMP4_PASS"', '''
    compact = ParseJson(ReadAsciiFile("pkg:/compact.json"))
    emitCompactProof(compact,info.audioId,info,"audio")
    emitCompactProof(compact,info.videoId,info,"video")
    print "FMP4_PASS"
''')
        bridge += SERVER_BRIDGE + COMPACT_BRIDGE
    program = work / 'verify.brs'
    program.write_text(implementation + '\n' + bridge)
    output, diagnostics = invoke([brs, '--root', str(work), str(program)])
    if 'FMP4_PASS' not in output or 'FMP4_FAIL' in output or diagnostics.strip():
        raise AssertionError('Production BrightScript verification failed: ' + output[-2000:] + diagnostics[:2000])
    patches = {'audio': [], 'video': []}
    for line in output.splitlines():
        if not line.startswith('FMP4_PATCH '):
            continue
        _, kind, part, offset, *values = line.split()
        offset = int(offset) + (media_offset if part == 'media' else 0)
        replacement = bytes(map(int, values))
        if replacement != b'free':
            raise AssertionError('A patch modifies more than a box type')
        patches[kind].append((offset, replacement))
    if server_spans:
        verify_spans(output, source, media_offset, patches)
    compact = {}
    if server_spans:
        for line in output.splitlines():
            if not line.startswith('FMP4_COMPACT '):
                continue
            proof = json.loads(line.removeprefix('FMP4_COMPACT '))
            def reconstruct(spans):
                result = bytearray()
                for span in spans:
                    data = media if span['patch'] is None else bytes(span['patch'])
                    offset, size = span['offset'], span['length']
                    if size <= 0 or offset < 0 or offset + size > len(data):
                        raise AssertionError('Invalid compact span bounds')
                    result.extend(data[offset:offset + size])
                return result
            target = reconstruct(proof['spans'])
            if len(target) != proof['length'] or len(target) >= len(media):
                raise AssertionError('Track payload was not compacted')
            for case in proof['ranges']:
                first, size = case['first'], case['length']
                if reconstruct(case['spans']) != target[first:first + size]:
                    raise AssertionError('Compact HTTP range or partial socket write changed bytes')
            compact[proof['kind']] = target
        if set(compact) != {'audio', 'video'}:
            raise AssertionError('Missing compact track proof')
    return patches, compact



SERVER_BRIDGE = r"""
sub emitServerRange(data, patches, kind, part, name, first, amount)
    spans = compatViewSpans(data,patches,first,amount)
    print "FMP4_RANGE "; kind; " "; part; " "; name; " "; first.ToStr(); " "; amount.ToStr()
    for each span in spans
        storage = "original"
        if span.data.Count() = 4 then storage = "free"
        print "FMP4_SPAN "; kind; " "; part; " "; name; " "; storage; " "; span.offset.ToStr(); " "; span.length.ToStr()
    end for
end sub
sub emitServerProof(data, patches, kind, part)
    emitServerRange(data,patches,kind,part,"full",0,data.Count())
    number = 0
    for each patch in patches
        for byte = 0 to 3
            emitServerRange(data,patches,kind,part,number.ToStr(),patch.offset+byte,1)
            number += 1
        end for
        emitServerRange(data,patches,kind,part,number.ToStr(),patch.offset-1,6)
        number += 1
        emitServerRange(data,patches,kind,part,number.ToStr(),patch.offset+1,2)
        number += 1
    end for
    socket = {chunks: [], calls: 0,
        IsWritable: function()
            return true
        end function,
        Send: function(data,offset,amount)
            m.calls += 1
            ' Exercise transient backpressure and partial native writes.
            if m.calls mod 7 = 0 then return 0
            if amount > 13007 then amount = 13007
            if amount > 1 then amount = Int(amount/2)
            m.chunks.Push({original: data.Count() <> 4, offset: offset, length: amount})
            return amount
        end function}
    clock = {TotalMilliseconds: function()
        return 123
    end function}
    session = {servedBytes: 0, clock: clock}
    client = {socket: socket, spans: compatViewSpans(data,patches,0,data.Count()), spanIndex: 0, spanOffset: 0, phase: "sending"}
    attempts = 0
    while client.phase = "sending" and attempts < 10000
        compatSendClient(session,client)
        attempts += 1
    end while
    if client.phase <> "draining" or session.servedBytes <> data.Count()
        print "FMP4_FAIL partial socket writes did not drain exactly once"
        stop
    end if
    print "FMP4_RANGE "; kind; " "; part; " socket 0 "; data.Count().ToStr()
    for each chunk in socket.chunks
        storage = "free"
        if chunk.original then storage = "original"
        print "FMP4_SPAN "; kind; " "; part; " socket "; storage; " "; chunk.offset.ToStr(); " "; chunk.length.ToStr()
    end for
end sub
"""


COMPACT_BRIDGE = r"""
function describeSpans(spans)
    result = []
    for each span in spans
        patch = invalid
        if span.data.Count() = 4
            patch = []
            patch.Append(span.data)
        end if
        result.Push({patch: patch, offset: span.offset, length: span.length})
    end for
    return result
end function
sub emitCompactProof(data, id, info, kind)
    item = {bytes: data, size: data.Count(), kind: "media"}
    view = compatTrackView(item,id,info)
    if not view.valid
        print "FMP4_FAIL compact track is invalid"
        stop
    end if
    proof = {kind: kind, length: view.length, spans: describeSpans(view.spans), ranges: []}
    cursor = 0
    for each span in view.spans
        first = cursor - 2
        if first < 0 then first = 0
        amount = 6
        if first + amount > view.length then amount = view.length - first
        proof.ranges.Push({first: first, length: amount, spans: describeSpans(compatSliceSpans(view.spans,first,amount))})
        cursor += span.length
    end for
    proof.ranges.Push({first: view.length-3, length: 3, spans: describeSpans(compatSliceSpans(view.spans,view.length-3,3))})
    socket = {chunks: [], calls: 0,
        IsWritable: function()
            return true
        end function,
        Send: function(data,offset,amount)
            m.calls += 1
            if m.calls mod 7 = 0 then return 0
            if amount > 13007 then amount = 13007
            if amount > 1 then amount = Int(amount/2)
            m.chunks.Push({data: data, offset: offset, length: amount})
            return amount
        end function}
    session = {servedBytes: 0, clock: {TotalMilliseconds: function()
        return 123
    end function}}
    client = {socket: socket, spans: view.spans, spanIndex: 0, spanOffset: 0, phase: "sending"}
    attempts = 0
    while client.phase = "sending" and attempts < 10000
        compatSendClient(session,client)
        attempts += 1
    end while
    if client.phase <> "draining" or session.servedBytes <> view.length
        print "FMP4_FAIL compact socket did not drain exactly once"
        stop
    end if
    proof.ranges.Push({first: 0, length: view.length, spans: describeSpans(socket.chunks)})
    print "FMP4_COMPACT "; FormatJson(proof)
end sub
"""


def verify_spans(output, source, media_offset, patches):
    parts = {'init': source[:media_offset], 'media': source[media_offset:]}
    expected = {}
    for kind, changes in patches.items():
        patched = bytearray(source)
        for offset, replacement in changes:
            patched[offset:offset + 4] = replacement
        expected[kind, 'init'] = patched[:media_offset]
        expected[kind, 'media'] = patched[media_offset:]
    cases = {}
    for line in output.splitlines():
        if line.startswith('FMP4_RANGE '):
            _, kind, part, name, first, amount = line.split()
            key = kind, part, name
            if key in cases:
                raise AssertionError('Duplicate server range case')
            cases[key] = {'first': int(first), 'amount': int(amount), 'chunks': []}
        elif line.startswith('FMP4_SPAN '):
            _, kind, part, name, storage, offset, amount = line.split()
            cases[kind, part, name]['chunks'].append((storage, int(offset), int(amount)))
    if not cases:
        raise AssertionError('No production sparse server ranges were checked')
    for (kind, part, name), case in cases.items():
        actual = bytearray()
        for storage, offset, amount in case['chunks']:
            original = b'free' if storage == 'free' else parts[part]
            if amount <= 0 or offset < 0 or offset + amount > len(original):
                raise AssertionError('Invalid sparse send range')
            actual.extend(original[offset:offset + amount])
        first, amount = case['first'], case['amount']
        if actual != expected[kind, part][first:first + amount]:
            raise AssertionError('Production sparse server changed range bytes: ' + name)


def probe(ffprobe, path):
    output, diagnostics = invoke([
        ffprobe, '-v', 'error', '-show_streams', '-show_packets', '-show_data_hash', 'sha256',
        '-show_entries', 'stream=index,codec_type,codec_name,width,height,sample_rate,time_base:packet=stream_index,pts,dts,duration,size,data_hash',
        '-of', 'json', str(path),
    ])
    if diagnostics.strip():
        raise AssertionError('ffprobe diagnostics: ' + diagnostics[:2000])
    data = json.loads(output)
    for stream in data['streams']:
        missing_audio_duration = stream['codec_type'] == 'audio' and any(
            packet['stream_index'] == stream['index'] and 'duration' not in packet
            for packet in data['packets']
        )
        if missing_audio_duration:
            output, diagnostics = invoke([
                ffprobe, '-v', 'error', '-select_streams', str(stream['index']),
                '-show_frames', '-show_entries', 'frame=pts,nb_samples', '-of', 'json', str(path),
            ])
            if diagnostics.strip():
                raise AssertionError('ffprobe audio decoding diagnostics: ' + diagnostics[:2000])
            stream['decoded_frames'] = json.loads(output)['frames']
    return data


def packets_for(data, kind):
    stream = next(stream for stream in data['streams'] if stream['codec_type'] == kind)
    packets = [{key: value for key, value in packet.items() if key != 'stream_index'}
               for packet in data['packets'] if packet['stream_index'] == stream['index']]
    for position, packet in enumerate(packets):
        if 'duration' in packet:
            continue
        # FFprobe 6.1 can omit the first AAC packet's duration in an audio-only
        # fragmented MP4. Use the decoded sample count at that packet's PTS;
        # adjacent DTS values can include gaps and are not the sample duration.
        frames = [frame for frame in stream.get('decoded_frames', [])
                  if 'pts' in packet and frame.get('pts') == packet['pts']]
        if len(frames) != 1 or frames[0].get('nb_samples', 0) <= 0:
            raise AssertionError(f'Cannot determine {kind} packet {position} duration')
        duration = Fraction(frames[0]['nb_samples'], int(stream['sample_rate'])) / Fraction(stream['time_base'])
        if duration.denominator != 1:
            raise AssertionError(f'Non-integral {kind} packet {position} duration')
        packet['duration'] = int(duration)
    return packets


def frame_hashes(ffmpeg, path, kind):
    selector = 'v:0' if kind == 'video' else 'a:0'
    output, diagnostics = invoke([ffmpeg, '-v', 'error', '-copyts', '-i', str(path), '-map', '0:' + selector, '-f', 'framemd5', '-'])
    if diagnostics.strip():
        raise AssertionError('ffmpeg diagnostics: ' + diagnostics[:2000])
    return [line for line in output.splitlines() if line and not line.startswith('#')]


def verify_fixture(args, fixture, work):
    source = fixture.read_bytes()
    patches, compact = production_views(args.brs, source, work, args.server_spans)
    baseline = probe(args.ffprobe, fixture)
    results = []
    cases = [(kind, changes, False) for kind, changes in patches.items()]
    cases += [(kind, patches[kind], True) for kind in compact]
    for kind, changes, is_compact in cases:
        target = bytearray(source)
        previous_end = 0
        for offset, replacement in changes:
            if offset < previous_end or offset + 4 > len(source):
                raise AssertionError('Patches overlap or exceed the source')
            target[offset:offset + 4] = replacement
            previous_end = offset + 4
        for offset, size, box_kind in boxes(source):
            if box_kind == b'mdat' and source[offset:offset + size] != target[offset:offset + size]:
                raise AssertionError('Compressed media payload changed')
        if is_compact:
            media_offset = next(offset for offset, _, box_kind in boxes(source) if box_kind == b'moof')
            target = target[:media_offset] + compact[kind]
        path = work / (kind + ('-compact' if is_compact else '') + '.mp4')
        path.write_bytes(target)
        actual = probe(args.ffprobe, path)
        if len(actual['streams']) != 1 or actual['streams'][0]['codec_type'] != kind:
            raise AssertionError('Unexpected streams in ' + kind + ' view')
        expected_packets, actual_packets = packets_for(baseline, kind), packets_for(actual, kind)
        if not actual_packets or len(expected_packets) != len(actual_packets):
            raise AssertionError(f'{kind} packet count changed: {len(expected_packets)} -> {len(actual_packets)}')
        for position, (expected, observed) in enumerate(zip(expected_packets, actual_packets)):
            if expected != observed:
                raise AssertionError(f'{kind} packet {position} changed: {expected} -> {observed}')
        expected_frames, actual_frames = frame_hashes(args.ffmpeg, fixture, kind), frame_hashes(args.ffmpeg, path, kind)
        if not actual_frames or expected_frames != actual_frames:
            raise AssertionError('Decoded frame hashes or timestamps changed')
        result = {'kind': kind, 'compact': is_compact, 'output_bytes': len(target),
                  'packets': len(actual_packets), 'decoded_frames': len(actual_frames),
                  'payload_and_timing_unchanged': True}
        if not is_compact:
            result.update(patches=len(changes), patch_bytes=len(changes) * 4)
        results.append(result)
    return {'fixture': fixture.name, 'source_bytes': len(source), 'sha256': hashlib.sha256(source).hexdigest(), 'server_spans_verified': args.server_spans, 'views': results}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--brs', default='brs')
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--ffprobe', default='ffprobe')
    parser.add_argument('--server-spans', action='store_true', help='Also verify compact track views, sparse ranges and partial socket sends')
    parser.add_argument('--fixture', type=Path, action='append', default=[])
    args = parser.parse_args()
    for name in ('brs', 'ffmpeg', 'ffprobe'):
        if shutil.which(getattr(args, name)) is None:
            parser.error(f'{name} executable is required')
    with tempfile.TemporaryDirectory(prefix='twoku-fmp4-proof-') as directory:
        workspace = Path(directory)
        fixtures = args.fixture
        if not fixtures:
            generated = workspace / 'generated-audio-first.mp4'
            invoke([args.ffmpeg, '-v', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=60',
                    '-f', 'lavfi', '-i', 'sine=frequency=880:sample_rate=48000', '-t', '2',
                    '-map', '1:a:0', '-map', '0:v:0', '-c:a', 'aac', '-c:v', 'libx264',
                    '-g', '30', '-pix_fmt', 'yuv420p', '-movflags', '+empty_moov+default_base_moof+frag_keyframe',
                    '-frag_duration', '100000', str(generated)])
            # Model an HLS segment with several complete audio/video fragments,
            # without the MP4 file index or the encoder's final audio-only drain.
            data = generated.read_bytes()
            fragments = [offset for offset, _, kind in boxes(data) if kind == b'moof']
            generated.write_bytes(data[:fragments[10]])
            fixtures = [generated]
        for number, fixture in enumerate(fixtures):
            work = workspace / str(number)
            work.mkdir()
            result = verify_fixture(args, fixture.resolve(), work)
            print('PASS production fMP4 packet/frame proof ' + json.dumps(result, separators=(',', ':')))


if __name__ == '__main__':
    main()
