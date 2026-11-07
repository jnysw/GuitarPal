"""Pure, dependency-free rules shared by future API and model workers.

This module does not provide a queue or claim durable task execution. State
transitions must eventually be applied with a database state-version/lease CAS.
"""
from __future__ import annotations

import math
import re
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from enum import Enum
from typing import Any, Iterable, Mapping, Optional


class ContractError(ValueError):
    pass


def integer(value: Any, name: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise ContractError(f"{name} must be an integer >= {minimum}")
    return value


def text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 256:
        raise ContractError(f"{name} must be non-empty text <= 256 characters")
    return value


def probability(value: Any) -> Optional[float]:
    if value is None:
        return None
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1:
        raise ContractError("confidence must be finite, in [0, 1], or null")
    return float(value)


@dataclass(frozen=True)
class MediaMapping:
    source_offset_ms: int
    input_duration_ms: int
    source_duration_ms: Optional[int] = None
    trim_start_ms: int = 0

    def __post_init__(self) -> None:
        integer(self.source_offset_ms, "source_offset_ms")
        integer(self.input_duration_ms, "input_duration_ms", 2000)
        if self.input_duration_ms > 600000:
            raise ContractError("input exceeds the v1 ten-minute limit")
        if self.source_duration_ms is not None:
            integer(self.source_duration_ms, "source_duration_ms")
            if self.end_ms > self.source_duration_ms:
                raise ContractError("input exceeds source duration")
        integer(self.trim_start_ms, "trim_start_ms")
        if self.trim_start_ms != 0:
            raise ContractError("v1 forbids silent trimming")

    @property
    def end_ms(self) -> int:
        return self.source_offset_ms + self.input_duration_ms

    def input_to_source(self, value: int) -> int:
        integer(value, "input time")
        if value > self.input_duration_ms:
            raise ContractError("input position exceeds coverage")
        return self.source_offset_ms + value


def samples_to_ms(samples: int, sample_rate: int) -> int:
    integer(samples, "samples")
    integer(sample_rate, "sample_rate", 1)
    return (samples * 1000 + sample_rate // 2) // sample_rate


def seconds_to_ms(value: Any) -> int:
    if type(value) not in (int, float, Decimal) or not math.isfinite(value) or value < 0:
        raise ContractError("engine time must be finite and non-negative")
    return int((Decimal(str(value)) * 1000).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


_QUALITIES = {
    "": ("maj", ""), "maj": ("maj", ""), "major": ("maj", ""),
    "min": ("min", "m"), "minor": ("min", "m"), "m": ("min", "m"),
    "7": ("7", "7"), "maj7": ("maj7", "maj7"),
    "min7": ("min7", "m7"), "m7": ("min7", "m7"),
    "dim": ("dim", "dim"), "dim7": ("dim7", "dim7"),
    "hdim7": ("hdim7", "m7♭5"), "m7b5": ("hdim7", "m7♭5"),
    "aug": ("aug", "aug"), "sus2": ("sus2", "sus2"), "sus4": ("sus4", "sus4"),
    "6": ("maj6", "6"), "maj6": ("maj6", "6"),
    "m6": ("min6", "m6"), "min6": ("min6", "m6"),
    "mmaj7": ("minmaj7", "m(maj7)"), "minmaj7": ("minmaj7", "m(maj7)"),
}
_LABEL = re.compile(r"^([A-G](?:#|b)?)(?::([^/]*))?(?:/([A-G](?:#|b)?))?$")


def normalize_label(raw: str) -> tuple[str, str]:
    """Keep spelling/bass and unsupported extensions; never infer an inversion."""
    text(raw, "raw_label")
    if raw in ("N", "X"):
        return raw, "无和弦" if raw == "N" else "未知"
    match = _LABEL.fullmatch(raw)
    if not match:
        return raw, raw
    root, quality, bass = match.groups()
    alias = _QUALITIES.get(quality or "")
    if alias is None:
        return raw, raw
    canonical, suffix = alias
    inversion = f"/{bass}" if bass else ""
    return f"{root}:{canonical}{inversion}", f"{root}{suffix}{inversion}"


def normalize_segments(
    raw_segments: Iterable[Mapping[str, Any]],
    mapping: MediaMapping,
    *,
    confidence_method: Optional[str] = None,
) -> list[dict[str, Any]]:
    """Map input-relative seconds exactly once. This is not a model adapter.

    Default upstream confidence values are deliberately discarded. A caller may
    pass confidence_method only after verifying real probabilities/aggregation.
    """
    if confidence_method is not None:
        text(confidence_method, "confidence_method")
    result = []
    previous_end = mapping.source_offset_ms
    for index, segment in enumerate(raw_segments):
        if index >= 20000:
            raise ContractError("too many chord segments")
        start = mapping.input_to_source(seconds_to_ms(segment["start"]))
        end = mapping.input_to_source(seconds_to_ms(segment["end"]))
        if start < previous_end or end <= start:
            raise ContractError("segments must be ordered, non-overlapping, and positive")
        raw_label = text(segment["chord"], "raw_label")
        chord_key, display_label = normalize_label(raw_label)
        result.append({
            "id": f"s{index + 1}", "start_ms": start, "end_ms": end,
            "raw_label": raw_label, "chord_key": chord_key,
            "display_label": display_label, "roman": segment.get("roman"),
            "confidence": probability(segment.get("confidence")) if confidence_method else None,
            "origin": "machine",
        })
        previous_end = end
    return result


def validate_chord_result(result: Mapping[str, Any]) -> None:
    """Cross-field rules complement the versioned JSON Schema, fail closed."""
    if type(result.get("schema_version")) is not int or result["schema_version"] != 1:
        raise ContractError("unsupported result schema; retain raw data for a newer client")
    if result.get("timebase") != "source_media_ms":
        raise ContractError("result must use source-media coordinates")
    if result.get("status") not in ("succeeded", "partially_succeeded"):
        raise ContractError("result is not available")
    separation = result.get("separation")
    if result["status"] == "succeeded" and separation is not None and separation.get("status") != "succeeded":
        raise ContractError("succeeded cannot contain a failed branch")
    for name in ("job_id", "asset_id", "media_revision_id"):
        text(result.get(name), name)
    coverage, wire_mapping = result["coverage"], result["mapping"]
    start = integer(coverage["start_ms"], "coverage.start_ms")
    end = integer(coverage["end_ms"], "coverage.end_ms")
    mapping = MediaMapping(wire_mapping["source_offset_ms"], end - start,
                           trim_start_ms=wire_mapping["trim_start_ms"])
    if start != mapping.source_offset_ms:
        raise ContractError("coverage and mapping disagree")
    chords = result["chords"]
    for name in ("analysis_id", "profile_id"):
        text(chords.get(name), name)
    integer(chords.get("revision"), "revision", 1)
    if chords.get("input_kind") != "original":
        raise ContractError("v1 only supports original-mix chord analysis")
    method = chords.get("confidence_method")
    if method is not None:
        text(method, "confidence_method")
    segments = chords["segments"]
    if not isinstance(segments, list) or len(segments) > 20000:
        raise ContractError("invalid segment list")
    previous_end, seen = start, set()
    for segment in segments:
        identity = text(segment.get("id"), "segment.id")
        a = integer(segment["start_ms"], "segment.start_ms")
        b = integer(segment["end_ms"], "segment.end_ms")
        if identity in seen or a < previous_end or b <= a or b > end:
            raise ContractError("duplicate, unordered, overlapping or out-of-coverage segment")
        seen.add(identity)
        previous_end = b
        raw = text(segment.get("raw_label"), "raw_label")
        key = text(segment.get("chord_key"), "chord_key")
        text(segment.get("display_label"), "display_label")
        if segment.get("origin") == "machine" and raw in ("N", "X") and raw != key:
            raise ContractError("N and X must remain distinct")
        if segment.get("origin") not in ("machine", "human"):
            raise ContractError("invalid segment origin")
        if segment.get("roman") is not None:
            text(segment["roman"], "roman")
        if probability(segment.get("confidence")) is not None and method is None:
            raise ContractError("a real confidence method is required")


class JobStatus(str, Enum):
    CREATED = "created"
    QUEUED = "queued"
    RUNNING = "running"
    RETRY_WAIT = "retry_wait"
    CANCEL_REQUESTED = "cancel_requested"
    SUCCEEDED = "succeeded"
    PARTIALLY_SUCCEEDED = "partially_succeeded"
    FAILED = "failed"
    CANCELED = "canceled"


_TRANSITIONS = {
    JobStatus.CREATED: {JobStatus.QUEUED, JobStatus.CANCELED, JobStatus.FAILED},
    JobStatus.QUEUED: {JobStatus.RUNNING, JobStatus.CANCELED, JobStatus.FAILED},
    JobStatus.RUNNING: {JobStatus.SUCCEEDED, JobStatus.PARTIALLY_SUCCEEDED,
                        JobStatus.FAILED, JobStatus.CANCEL_REQUESTED, JobStatus.RETRY_WAIT},
    JobStatus.RETRY_WAIT: {JobStatus.QUEUED, JobStatus.CANCELED, JobStatus.FAILED},
    JobStatus.CANCEL_REQUESTED: {JobStatus.CANCELED, JobStatus.PARTIALLY_SUCCEEDED},
}


def validate_transition(current: JobStatus, target: JobStatus) -> None:
    if current == target:  # repeated cancel/notification is idempotent
        return
    if target not in _TRANSITIONS.get(current, set()):
        raise ContractError(f"invalid transition: {current.value} -> {target.value}")
