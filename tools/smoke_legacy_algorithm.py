#!/usr/bin/env python3
"""Explicit live contract smoke with generated audio, never a quality benchmark.

python3 tools/smoke_legacy_algorithm.py --base-url https://YOUR_TAILNET_HOST
Results stay in --output (default /tmp); no private host or audio is committed.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import wave


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', required=True)
    parser.add_argument('--output', default='/tmp/guitarpal-live-smoke')
    parser.add_argument('--timeout', type=int, default=900)
    parser.add_argument('--operation', choices=['both', 'chords', 'separation'], default='both')
    args = parser.parse_args()
    origin = urllib.parse.urlsplit(args.base_url)
    if origin.scheme != 'https' or not origin.netloc or origin.path not in ('', '/'):
        parser.error('Use the HTTPS origin without /api/v1')
    base = args.base_url.rstrip('/')
    # Tailnet traffic goes directly; retain default OS TLS verification.
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    def request(path, data=None, headers=None, method=None):
        req = urllib.request.Request(base + path, data, headers or {}, method=method)
        return client.open(req, timeout=90)

    def read_json(path):
        with request(path) as response:
            return json.load(response)

    assert read_json('/api/v1/health/ping') == {'ping': 'pong'}
    buffer = io.BytesIO()
    rate = 44100
    with wave.open(buffer, 'wb') as audio:
        audio.setparams((2, 2, rate, 0, 'NONE', 'not compressed'))
        samples = bytearray()
        for i in range(8 * rate):
            beat = (i / rate) % .5
            envelope = min(1, beat * 1000) * math.exp(-7 * beat)
            chord = 4500 * envelope * sum(math.sin(2 * math.pi * f * i / rate)
                                          for f in (261.63, 329.63, 392.00))
            click = 8000 * math.exp(-100 * beat) * math.sin(2 * math.pi * 1500 * i / rate)
            value = int(chord + click)
            samples.extend(struct.pack('<hh', value, value))
        audio.writeframes(samples)
    payload = buffer.getvalue()
    report = {'input': 'generated 8-second rhythmic C-major triad; contract test only',
              'input_sha256': hashlib.sha256(payload).hexdigest(), 'operations': {}}
    for operation, root, query in (
        ('chords', '/api/v1/jobs', 'smooth_method=hmm&device=cpu&include_raw_chords=false'),
        ('separation', '/api/v1/separation/jobs', 'output_format=wav_s16'),
    ):
        if args.operation != 'both' and args.operation != operation:
            continue
        boundary = 'guitarpal-' + uuid.uuid4().hex
        multipart = (f'--{boundary}\r\nContent-Disposition: form-data; name="audio"; filename="synthetic-triad.wav"\r\n'
                     'Content-Type: audio/wav\r\n\r\n').encode() + payload + f'\r\n--{boundary}--\r\n'.encode()
        start = time.monotonic()
        with request(root + '?' + query, multipart,
                     {'Content-Type': 'multipart/form-data; boundary=' + boundary}) as response:
            assert response.status == 202
            receipt = json.load(response)
        job = receipt['job_id']
        assert receipt['poll_url'] == f'{root}/{job}/status'
        assert receipt['result_url'] == f'{root}/{job}/result'
        print(operation, 'accepted', job, flush=True)
        stages = []
        while time.monotonic() - start < args.timeout:
            status = read_json(f'{root}/{job}/status')
            assert status['job_id'] == job
            if not stages or stages[-1] != status['status']:
                stages.append(status['status'])
                print(operation, status['status'], status.get('progress'), flush=True)
            if status['status'] == 'failed':
                raise RuntimeError(json.dumps(status, ensure_ascii=False))
            if status['status'] == 'completed':
                break
            time.sleep(3)
        else:
            raise TimeoutError(operation + ' did not complete')
        result = read_json(f'{root}/{job}/result')
        assert result['job_id'] == job and result['status'] == 'completed'
        (output / f'{operation}-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
        details = {'stages': stages, 'elapsed_seconds': round(time.monotonic() - start, 2),
                   'duration_seconds': result['duration_seconds']}
        if operation == 'separation':
            stems = result['stems']
            assert {s['id'] for s in stems} == {'vocals', 'drums', 'bass', 'guitar', 'piano', 'other', 'instrumental'}
            details['files'] = []
            for stem in stems:
                route = f'{root}/{job}/files/{stem["id"]}'
                assert stem['download_url'] == route
                assert stem['origin'] == ('derived' if stem['id'] == 'instrumental' else 'model')
                with request(route, method='HEAD') as response:
                    assert int(response.headers['Content-Length']) == stem['size_bytes']
                with request(route, headers={'Range': 'bytes=0-11'}) as response:
                    assert response.status == 206
                    assert len(response.read()) == 12
                with request(route) as response:
                    data = response.read(stem['size_bytes'] + 1)
                    assert len(data) == stem['size_bytes']
                    assert response.headers['Content-Type'].split(';')[0] == stem['content_type']
                with wave.open(io.BytesIO(data)) as audio:
                    assert audio.getframerate() == stem['sample_rate']
                    assert audio.getnchannels() == stem['channels']
                    assert abs(audio.getnframes() / audio.getframerate() - stem['duration_seconds']) < .02
                (output / f'{stem["id"]}.wav').write_bytes(data)
                details['files'].append({'id': stem['id'], 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        report['operations'][operation] = details
        (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print(operation, 'verified', details['elapsed_seconds'], 'seconds', flush=True)
    print('PASS: transport, task lifecycle, seven downloads and Range; no quality or Flutter UI claim', flush=True)


if __name__ == '__main__':
    main()
