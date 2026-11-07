"""Convert pinned chords-db data to offline standard-tuning voicings.

Run: python3 tools/build_chord_library.py /path/to/guitar.json
Source is deliberately not fetched at app runtime. See third_party/chords-db/README.md.
"""
import hashlib
import json
from pathlib import Path
import sys

VERSION = 'df06fa7b425cf5fd29485ff6591236b3557e3fac'
SHA256 = 'cfe439962b2f444d2c341b1f0261403b4c3a3416e321147286fc608922699974'
TUNING = [40, 45, 50, 55, 59, 64]
NOTES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
QUALITIES = {
    'major': ('maj', [0, 4, 7]), 'minor': ('min', [0, 3, 7]),
    '7': ('7', [0, 4, 7, 10]), 'maj7': ('maj7', [0, 4, 7, 11]),
    'm7': ('min7', [0, 3, 7, 10]), 'dim': ('dim', [0, 3, 6]),
    'dim7': ('dim7', [0, 3, 6, 9]), 'm7b5': ('hdim7', [0, 3, 6, 10]),
    'aug': ('aug', [0, 4, 8]), 'sus2': ('sus2', [0, 2, 7]),
    'sus4': ('sus4', [0, 5, 7]), '6': ('maj6', [0, 4, 7, 9]),
    'm6': ('min6', [0, 3, 7, 9]), 'mmaj7': ('minmaj7', [0, 3, 7, 11]),
}


def pc(note):
    return (NOTES[note[0]] + {'': 0, '#': 1, 'b': -1}[note[1:]]) % 12


def convert(source):
    assert hashlib.sha256(source).hexdigest() == SHA256, 'Pinned source checksum differs'
    data = json.loads(source)
    assert data['tunings']['standard'] == ['E2', 'A2', 'D3', 'G3', 'B3', 'E4']
    voicings, excluded = [], []
    for groups in data['chords'].values():
        for chord in groups:
            suffix, _, bass = chord['suffix'].partition('/')
            suffix = {'': 'major', 'm': 'minor'}.get(suffix, suffix)
            if suffix not in QUALITIES:
                continue
            root = pc(chord['key'])
            quality, intervals = QUALITIES[suffix]
            bass_pc = pc(bass) if bass else None
            tones = {(root + n) % 12 for n in intervals}
            for index, position in enumerate(chord['positions']):
                identifier = f"std-{chord['key']}-{chord['suffix']}-{index}"
                try:
                    base = position['baseFret']
                    relative = position['frets']
                    fingers = position['fingers']
                    assert len(relative) == len(fingers) == 6
                    assert 1 <= base <= 24
                    frets = [f + base - 1 if f > 0 else f for f in relative]
                    assert all(-1 <= f <= 24 for f in frets)
                    assert all(0 <= f <= 4 for f in fingers)
                    assert all((f > 0) == (finger > 0) for f, finger in zip(frets, fingers))
                    midi = [note + f for note, f in zip(TUNING, frets) if f >= 0]
                    assert midi == position['midi']
                    pitches = {n % 12 for n in midi}
                    assert tones <= pitches <= (tones | ({bass_pc} if bass_pc is not None else set()))
                    assert bass_pc is None or min(midi) % 12 == bass_pc
                    barres = []
                    for fret in position.get('barres', []):
                        endpoints = [i for i, f in enumerate(relative) if f == fret]
                        # Some upstream barre markers have only one endpoint; do not invent a span.
                        if len(endpoints) < 2:
                            continue
                        first, last = min(endpoints), max(endpoints)
                        finger = fingers[first]
                        assert finger > 0 and fingers[last] == finger
                        assert all(f == -1 or f >= fret for f in relative[first:last + 1])
                        barres.append([fret + base - 1, first, last, finger])
                    key = f"{root}:{quality}" + (f"/{bass_pc}" if bass_pc is not None else '')
                    # Compact stable schema: id, key, absolute frets, fingers, first fret, barres.
                    voicings.append([identifier, key, frets, fingers, base, barres])
                except (AssertionError, ValueError, KeyError) as e:
                    excluded.append(identifier)
    coverage = {f'{root}:{quality}': sum(v[1] == f'{root}:{quality}' for v in voicings)
                for root in range(12) for quality, _ in QUALITIES.values()}
    result = {'schema_version': 1, 'source_version': VERSION,
              'source_sha256': SHA256, 'tuning_midi': TUNING,
              'string_order': 'low_to_high', 'voicings': voicings}
    report = {'source_version': VERSION, 'source_sha256': SHA256,
              'voicings': len(voicings), 'chord_keys': len({v[1] for v in voicings}),
              'quality_coverage': coverage, 'excluded_positions': excluded,
              'note': 'Only exact supported qualities; invalid tones, bass or fingers excluded. No simplified fallback.'}
    return result, report


if __name__ == '__main__':
    result, report = convert(Path(sys.argv[1]).read_bytes())
    root = Path(__file__).resolve().parent.parent
    (root / 'assets/chords').mkdir(parents=True, exist_ok=True)
    (root / 'assets/chords/standard_guitar_v1.json').write_text(
        json.dumps(result, separators=(',', ':')) + '\n')
    (root / 'docs/ai_audio/chord_library_coverage.json').write_text(
        json.dumps(report, indent=2) + '\n')
    print(f"{report['voicings']} voicings / {report['chord_keys']} keys; {len(report['excluded_positions'])} excluded")
