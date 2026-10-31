import copy
import json
from pathlib import Path
import unittest

from guitarpal_audio.contracts import (
    ContractError, JobStatus, MediaMapping, normalize_label, normalize_segments,
    samples_to_ms, seconds_to_ms, validate_chord_result, validate_transition,
)
from guitarpal_audio.model_profiles import validate_manifest


ROOT = Path(__file__).resolve().parents[2]


def fixture():
    return json.loads((ROOT / "contracts/audio/fixtures/chords_offset_v1.json").read_text())


class ContractTests(unittest.TestCase):
    def test_offset_silence_and_half_open_intervals(self):
        mapping = MediaMapping(30000, 20000, source_duration_ms=180000)
        normalized = normalize_segments([
            {"start": 0, "end": 2, "chord": "N", "confidence": 1.0},
            {"start": 2, "end": 10, "chord": "C:maj", "confidence": 1.0},
            {"start": 10, "end": 20, "chord": "X"},
        ], mapping)
        self.assertEqual([30000, 32000, 40000], [s["start_ms"] for s in normalized])
        self.assertEqual(["N", "C:maj", "X"], [s["chord_key"] for s in normalized])
        self.assertTrue(all(s["confidence"] is None for s in normalized))
        self.assertEqual(50000, mapping.input_to_source(20000))
        self.assertEqual(1, seconds_to_ms(0.0005))
        self.assertEqual(1000, samples_to_ms(44100, 44100))
        self.assertEqual(1, samples_to_ms(24, 48000))
        with self.assertRaises(ContractError):
            MediaMapping(30000, 20000, trim_start_ms=1200)
        with self.assertRaises(ContractError):
            MediaMapping(30000, 20000, source_duration_ms=49000)

    def test_semantics_preserve_spelling_bass_and_unknown_extensions(self):
        for raw, expected in {
            "C": ("C:maj", "C"), "A:min": ("A:min", "Am"),
            "G:7": ("G:7", "G7"), "Db:maj/F": ("Db:maj/F", "Db/F"),
            "C:hdim7": ("C:hdim7", "Cm7♭5"),
            "C:unrecognized": ("C:unrecognized", "C:unrecognized"),
            "X": ("X", "未知"), "N": ("N", "无和弦"),
        }.items():
            with self.subTest(raw=raw):
                self.assertEqual(expected, normalize_label(raw))

    def test_shared_result_and_invalid_mutations(self):
        validate_chord_result(fixture())
        invalid = []
        for key, value in [("start_ms", 29000), ("end_ms", 50001), ("end_ms", 30000),
                           ("confidence", float("nan")), ("confidence", 1.0),
                           ("chord_key", "X")]:
            result = fixture()
            result["chords"]["segments"][0][key] = value
            invalid.append(result)
        duplicate = fixture()
        duplicate["chords"]["segments"][1]["id"] = "s1"
        invalid.append(duplicate)
        overlap = fixture()
        overlap["chords"]["segments"][1]["start_ms"] = 31000
        invalid.append(overlap)
        for result in invalid:
            with self.assertRaises(ContractError):
                validate_chord_result(result)
        corrected = fixture()
        corrected["chords"]["segments"][3].update(
            origin="human", chord_key="G:7", display_label="G7"
        )
        validate_chord_result(corrected)

    def test_terminal_states_and_cancel_race(self):
        validate_transition(JobStatus.RUNNING, JobStatus.CANCEL_REQUESTED)
        validate_transition(JobStatus.CANCEL_REQUESTED, JobStatus.PARTIALLY_SUCCEEDED)
        validate_transition(JobStatus.CANCELED, JobStatus.CANCELED)
        for source, target in [(JobStatus.CANCELED, JobStatus.SUCCEEDED),
                               (JobStatus.SUCCEEDED, JobStatus.RUNNING),
                               (JobStatus.CANCEL_REQUESTED, JobStatus.SUCCEEDED)]:
            with self.assertRaises(ContractError):
                validate_transition(source, target)

    def test_unverified_profiles_are_disabled_and_cannot_be_enabled(self):
        manifest = json.loads((ROOT / "server/model_manifest.json").read_text())
        self.assertEqual([], validate_manifest(manifest))
        for index in range(2):
            enabled = copy.deepcopy(manifest)
            enabled["profiles"][index]["enabled"] = True
            with self.assertRaises(ContractError):
                validate_manifest(enabled)


if __name__ == "__main__":
    unittest.main()
