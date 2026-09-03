"""Collect real non-target images for the classifier's unknown class.

The expanded food model must see more than supported dishes. This collector
uses openly licensed Commons images from non-food, other-food and ordinary
scene queries. All rows stay human-review pending and must not be mistaken for
one of the 100 supported dish labels.
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import requests

from collect_food_images import (
    ProviderRateLimitError,
    _download_and_validate,
    discover_commons,
    _load_jsonl,
    _write_jsonl,
)


UNKNOWN_QUERIES = (
    "landscape Philippines",
    "street Philippines",
    "dog Philippines",
    "car Philippines",
    "pizza food",
    "salad food",
    "bread food",
    "fruit market Philippines",
    "empty dining table",
    "kitchen Philippines",
)


def collect(args: argparse.Namespace) -> dict[str, Any]:
    work_dir = Path(args.work_dir).resolve()
    manifest_path = work_dir / "manifests" / "candidates.jsonl"
    records = _load_jsonl(manifest_path)
    session = requests.Session()
    session.headers.update(
        {"User-Agent": "JCG-Fitness-Filipino-Food-Unknown-Dataset/0.1"}
    )
    known_hashes = {
        str(row.get("download_sha256") or row.get("saved_sha256"))
        for row in records.values()
        if row.get("download_sha256") or row.get("saved_sha256")
    }
    known_phashes = [
        str(row["perceptual_hash"])
        for row in records.values()
        if row.get("perceptual_hash")
    ]
    existing = [
        row
        for row in records.values()
        if row.get("dish_id") == "unknown_or_unsupported"
        and row.get("status") == "downloaded_pending_review"
    ]
    remaining = max(0, args.target_real - len(existing))
    candidates: dict[str, dict[str, Any]] = {}
    for query in UNKNOWN_QUERIES:
        for candidate in discover_commons(
            session,
            query,
            max_results=args.search_limit,
        ):
            if candidate["license_decision"] not in ("allow", "allow_with_review"):
                continue
            candidate["candidate_key"] = f"unknown:{candidate['source_id']}"
            candidate["dish_id"] = "unknown_or_unsupported"
            candidate["canonical_label"] = "Unknown or unsupported food"
            candidate["synthetic"] = False
            candidate["unknown_query"] = query
            candidates[candidate["candidate_key"]] = candidate
    for key, candidate in list(candidates.items())[:remaining]:
        stem = candidate["source_id"].split(":", 1)[-1].replace("/", "_")
        destination = work_dir / "raw" / "open_source" / "unknown_or_unsupported" / f"{stem}.jpg"
        try:
            status, details = _download_and_validate(
                session,
                candidate,
                destination,
                min_short_side=args.min_short_side,
                known_hashes=known_hashes,
                known_perceptual_hashes=known_phashes,
            )
        except ProviderRateLimitError:
            print("Provider rate limit reached; save progress and resume later")
            break
        candidate.update(details)
        candidate["status"] = status
        if status == "downloaded_pending_review":
            candidate["image_path"] = destination.relative_to(work_dir).as_posix()
            known_hashes.add(candidate["download_sha256"])
            known_phashes.append(candidate["perceptual_hash"])
        records[key] = candidate
        time.sleep(args.download_delay)
    _write_jsonl(manifest_path, records.values())
    result = {
        "dish_id": "unknown_or_unsupported",
        "discovered": len(candidates),
        "downloaded_pending_review": sum(
            row.get("dish_id") == "unknown_or_unsupported"
            and row.get("status") == "downloaded_pending_review"
            for row in records.values()
        ),
        "manifest": str(manifest_path),
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--target-real", type=int, default=3000)
    parser.add_argument("--search-limit", type=int, default=30)
    parser.add_argument("--min-short-side", type=int, default=640)
    parser.add_argument("--download-delay", type=float, default=5.0)
    collect(parser.parse_args())


if __name__ == "__main__":
    main()
