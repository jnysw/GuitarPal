"""Fail-closed profile inventory; no model download, load or public path input."""
from __future__ import annotations

import re
from typing import Any, Mapping

from .contracts import ContractError, integer, text


def validate_manifest(manifest: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    if type(manifest.get("schema_version")) is not int or manifest["schema_version"] != 1:
        raise ContractError("unsupported model manifest")
    profiles = manifest.get("profiles")
    if not isinstance(profiles, list):
        raise ContractError("profiles must be a list")
    seen = set()
    enabled = []
    for profile in profiles:
        identity = text(profile.get("profile_id"), "profile_id")
        if identity in seen:
            raise ContractError("duplicate model profile")
        seen.add(identity)
        if type(profile.get("enabled")) is not bool:
            raise ContractError("enabled must be explicit")
        if not profile["enabled"]:
            continue
        if profile.get("engine") not in ("chord_engine", "bs_roformer"):
            raise ContractError("unsupported engine")
        if not re.fullmatch(r"[0-9a-f]{40}", profile.get("code_commit") or ""):
            raise ContractError("enabled profile needs a fixed code commit")
        for name in ("checkpoint_sha256", "config_sha256"):
            if not re.fullmatch(r"[0-9a-f]{64}", profile.get(name) or ""):
                raise ContractError(f"enabled profile needs {name}")
        text(profile.get("checkpoint_uri"), "checkpoint_uri")
        integer(profile.get("sample_rate"), "sample_rate", 1)
        if profile.get("channels") not in (1, 2):
            raise ContractError("enabled profile requires mono/stereo channel count")
        for name in ("license_evidence", "benchmark_evidence"):
            evidence = profile.get(name)
            if not isinstance(evidence, list) or not evidence:
                raise ContractError(f"enabled profile needs {name}")
            for item in evidence:
                text(item, name)
        if profile["engine"] == "bs_roformer":
            targets = profile.get("targets")
            if not isinstance(targets, list) or not targets or len(set(targets)) != len(targets):
                raise ContractError("separation targets must be explicit and unique")
            for target in targets:
                text(target, "target")
            chunk = integer(profile.get("chunk_samples"), "chunk_samples", 1)
            overlap = integer(profile.get("overlap_samples"), "overlap_samples")
            if overlap >= chunk:
                raise ContractError("overlap must be smaller than a chunk")
            text(profile.get("precision"), "precision")
        else:
            if not re.fullmatch(r"[0-9a-f]{64}", profile.get("vocabulary_sha256") or ""):
                raise ContractError("chord profile needs a vocabulary hash")
            integer(profile.get("hop_length"), "hop_length", 1)
            text(profile.get("detector_type"), "detector_type")
            text(profile.get("smoothing"), "smoothing")
        enabled.append(profile)
    return enabled
