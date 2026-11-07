# chords-db attribution

- Author: David Rubert; copyright 2016.
- Source: https://github.com/tombatossals/chords-db/tree/df06fa7b425cf5fd29485ff6591236b3557e3fac
- License: MIT; the complete upstream text is included in `LICENSE`, packaged with the app and shown from the practice fingering settings.
- Input: `lib/guitar.json` at the fixed commit above.
- Input SHA-256: `cfe439962b2f444d2c341b1f0261403b4c3a3416e321147286fc608922699974`.

The app bundles a converted subset in `assets/chords/standard_guitar_v1.json`, not a runtime web dependency. To reproduce, download the pinned JSON and run:

```sh
python3 tools/build_chord_library.py /path/to/guitar.json
```

The converter refuses another input checksum. It converts relative positive frets to absolute frets, preserves open strings, validates MIDI and exact chord tones, requires the stated inversion bass, and normalizes only supported qualities. `capo` in upstream data is not interpreted as a player capo setting. Barre endpoints and fingers are validated; ambiguous single-endpoint markers do not invent a barre. Invalid positions are excluded and listed in `docs/ai_audio/chord_library_coverage.json`.

Compact row schema: `[voicing_id, canonical_chord_key, absolute_frets, fingers, display_base_fret, barres]`. A barre is `[absolute_fret, from_string, to_string, finger]`; strings run 0–5 from low E to high e. Frets use -1 for muted and 0 for open; finger 0 means no finger. Keys use pitch classes and canonical quality with an optional absolute bass pitch class.
