"""Ingest project-owned Philippine captures into the dataset manifest.

The contributor supplies a non-identifying contributor token and consent ID.
Images are re-encoded to remove EXIF/GPS metadata, hashed, and marked as
human-review pending. This makes phone-capture collection usable without
putting personal metadata into the training release.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import time
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps, UnidentifiedImageError


def _load_jsonl(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    records: dict[str, dict[str, Any]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            records[str(row.get("candidate_key") or row.get("image_id"))] = row
    return records


def _write_jsonl(path: Path, records: dict[str, dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        "\n".join(json.dumps(row, ensure_ascii=False, sort_keys=True) for row in records.values()) + "\n",
        encoding="utf-8",
    )
    temp.replace(path)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _average_hash(image: Image.Image) -> str:
    small = ImageOps.fit(image.convert("L"), (16, 16), method=Image.Resampling.LANCZOS)
    values = list(small.get_flattened_data())
    average = sum(values) / len(values)
    return "".join("1" if value >= average else "0" for value in values)


def _hamming(left: str, right: str) -> int:
    return sum(a != b for a, b in zip(left, right)) if len(left) == len(right) else 10_000


def _safe_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "_", value).strip("_")[:80] or "capture"


def ingest(args: argparse.Namespace) -> dict[str, Any]:
    source_dir = Path(args.source_dir).resolve()
    work_dir = Path(args.work_dir).resolve()
    manifest_path = work_dir / "manifests" / "candidates.jsonl"
    records = _load_jsonl(manifest_path)
    known_hashes = {
        str(row.get("saved_sha256") or row.get("download_sha256"))
        for row in records.values()
        if row.get("saved_sha256") or row.get("download_sha256")
    }
    known_phashes = [
        str(row["perceptual_hash"])
        for row in records.values()
        if row.get("perceptual_hash")
    ]
    extensions = {".jpg", ".jpeg", ".png", ".webp"}
    files = sorted(path for path in source_dir.rglob("*") if path.suffix.lower() in extensions)
    imported = 0
    rejected = 0
    for source_path in files:
        try:
            raw_hash = _sha256(source_path)
            if raw_hash in known_hashes:
                rejected += 1
                continue
            with Image.open(source_path) as opened:
                image = ImageOps.exif_transpose(opened).convert("RGB")
                if min(image.size) < args.min_short_side:
                    rejected += 1
                    continue
                perceptual_hash = _average_hash(image)
                if any(_hamming(perceptual_hash, value) <= 4 for value in known_phashes):
                    rejected += 1
                    continue
                image.thumbnail((1280, 1280), Image.Resampling.LANCZOS)
                image_id = f"capture:{raw_hash[:20]}"
                destination = work_dir / "raw" / "project_capture" / args.dish_id / f"{_safe_name(image_id)}.jpg"
                destination.parent.mkdir(parents=True, exist_ok=True)
                image.save(destination, format="JPEG", quality=92, optimize=True)
                saved_hash = _sha256(destination)
                record = {
                    "candidate_key": image_id,
                    "image_id": image_id,
                    "dish_id": args.dish_id,
                    "canonical_label": args.display_name,
                    "source_type": "project_capture",
                    "source_id": image_id,
                    "source_page": "",
                    "image_url": "",
                    "mime": "image/jpeg",
                    "license": "project_owned",
                    "license_url": "",
                    "license_decision": "allow",
                    "license_reason": "project_contributor_consent",
                    "author": args.contributor_token,
                    "credit": "JCG Fitness project capture",
                    "consent_id": args.consent_id,
                    "locality": args.locality,
                    "device_model": args.device_model,
                    "angle": args.angle,
                    "meal_instance_id": args.meal_instance_id,
                    "synthetic": False,
                    "status": "human_pending",
                    "review_status": "human_pending",
                    "saved_width": image.width,
                    "saved_height": image.height,
                    "download_sha256": raw_hash,
                    "saved_sha256": saved_hash,
                    "perceptual_hash": perceptual_hash,
                    "image_path": destination.relative_to(work_dir).as_posix(),
                    "retrieved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
                records[image_id] = record
                known_hashes.update({raw_hash, saved_hash})
                known_phashes.append(perceptual_hash)
                imported += 1
        except (UnidentifiedImageError, OSError):
            rejected += 1
    _write_jsonl(manifest_path, records)
    result = {
        "dish_id": args.dish_id,
        "source_dir": str(source_dir),
        "imported": imported,
        "rejected": rejected,
        "manifest": str(manifest_path),
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--dish-id", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--contributor-token", required=True)
    parser.add_argument("--consent-id", required=True)
    parser.add_argument("--locality", required=True)
    parser.add_argument("--device-model", default="unknown")
    parser.add_argument("--angle", default="unspecified")
    parser.add_argument("--meal-instance-id", default="capture-session")
    parser.add_argument("--min-short-side", type=int, default=640)
    ingest(parser.parse_args())


if __name__ == "__main__":
    main()
