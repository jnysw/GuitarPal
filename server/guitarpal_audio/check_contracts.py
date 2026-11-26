"""Run from the repository root: PYTHONPATH=server python -m guitarpal_audio.check_contracts."""
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

from .contracts import validate_chord_result
from .model_profiles import validate_manifest


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    contract_dir = root / "contracts/audio"
    schema = json.loads((contract_dir / "result-v1.schema.json").read_text())
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    for fixture in sorted((contract_dir / "fixtures").glob("*.json")):
        result = json.loads(fixture.read_text())
        validator.validate(result)
        if result.get("chords") is not None:
            validate_chord_result(result)
        print(f"PASS result schema and invariants: {fixture.name}")

    api = json.loads((contract_dir / "openapi.json").read_text())
    if api["openapi"] != "3.1.0":
        raise ValueError("expected OpenAPI 3.1.0")
    components = api["components"]["schemas"]
    for value in components.values():
        Draft202012Validator.check_schema(value)

    def check_refs(value):
        if isinstance(value, dict):
            reference = value.get("$ref")
            if reference:
                if reference.startswith("#/components/schemas/"):
                    if reference.rsplit("/", 1)[-1] not in components:
                        raise ValueError(f"unresolved component: {reference}")
                elif reference.startswith("./result-v1.schema.json"):
                    target = schema
                    fragment = reference.partition("#")[2]
                    for part in fragment.lstrip("/").split("/") if fragment else []:
                        target = target[part.replace("~1", "/").replace("~0", "~")]
                else:
                    raise ValueError(f"unexpected external reference: {reference}")
            for child in value.values():
                check_refs(child)
        elif isinstance(value, list):
            for child in value:
                check_refs(child)

    check_refs(api)
    manifest = json.loads((root / "server/model_manifest.json").read_text())
    enabled = validate_manifest(manifest)
    print(f"PASS OpenAPI components and references; enabled model profiles: {len(enabled)}")
    if not enabled:
        print("M0 pending: no verified weights/config/hardware; inference is unavailable.")


if __name__ == "__main__":
    main()
