"""Audit image-manifest quality before a food model is trained.

The audit is intentionally conservative: downloaded images remain pending
until a human verifies the dish and provenance. It checks class balance,
real/synthetic quotas, required metadata, duplicate hashes, source/group
concentration and angle coverage.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps, UnidentifiedImageError


TRAINABLE_STATUSES = {"human_approved", "approved"}
PENDING_STATUSES = {"downloaded_pending_review", "human_pending"}


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _required_provenance(row: dict[str, Any]) -> list[str]:
    if row.get("synthetic"):
        required = ("generator_model", "generator_license", "prompt_id")
    elif row.get("source_type") in {"wikimedia_commons", "openverse"}:
        required = ("source_page", "image_url", "author", "license", "license_decision")
    else:
        required = ("source_type",)
    return [field for field in required if not str(row.get(field) or "").strip()]


def audit(args: argparse.Namespace) -> dict[str, Any]:
    registry = json.loads(Path(args.registry).read_text(encoding="utf-8"))
    expected = {entry["id"]: entry for entry in registry["classes"]}
    expected["unknown_or_unsupported"] = {
        "id": "unknown_or_unsupported",
        "display_name": "Unknown or unsupported food",
    }
    rows = _load_jsonl(Path(args.manifest))
    rows = [row for row in rows if row.get("dish_id") in expected]
    by_dish: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_dish[str(row["dish_id"])].append(row)

    exact_hashes: dict[str, list[str]] = defaultdict(list)
    missing_provenance: list[dict[str, Any]] = []
    corrupted: list[dict[str, Any]] = []
    for row in rows:
        status = str(row.get("status") or "")
        if status not in TRAINABLE_STATUSES | PENDING_STATUSES:
            continue
        image_hash = str(row.get("saved_sha256") or row.get("download_sha256") or "")
        image_path = row.get("image_path")
        if not image_hash and image_path and args.work_dir:
            path = Path(args.work_dir) / str(image_path)
            if path.exists():
                image_hash = _sha256_file(path)
        if image_hash:
            exact_hashes[image_hash].append(str(row.get("candidate_key") or row.get("image_id")))
        missing = _required_provenance(row)
        if missing:
            missing_provenance.append(
                {
                    "candidate_key": row.get("candidate_key"),
                    "dish_id": row.get("dish_id"),
                    "missing": missing,
                }
            )
        if image_path and args.work_dir:
            path = Path(args.work_dir) / str(image_path)
            try:
                with Image.open(path) as image:
                    image = ImageOps.exif_transpose(image)
                    recorded_size = (
                        int(row.get("decoded_width") or row.get("width") or image.width),
                        int(row.get("decoded_height") or row.get("height") or image.height),
                    )
                    if min(recorded_size) < args.min_short_side:
                        corrupted.append(
                            {
                                "candidate_key": row.get("candidate_key"),
                                "reason": "short_side_below_minimum",
                                "size": recorded_size,
                            }
                        )
            except (FileNotFoundError, UnidentifiedImageError, OSError) as exc:
                corrupted.append(
                    {
                        "candidate_key": row.get("candidate_key"),
                        "reason": f"image_unreadable:{type(exc).__name__}",
                    }
                )

    duplicate_groups = [
        {"sha256": image_hash, "candidate_keys": keys}
        for image_hash, keys in exact_hashes.items()
        if len(keys) > 1
    ]
    classes: list[dict[str, Any]] = []
    for dish_id, entry in expected.items():
        dish_rows = by_dish.get(dish_id, [])
        eligible = [
            row
            for row in dish_rows
            if row.get("status") in TRAINABLE_STATUSES | PENDING_STATUSES
        ]
        trainable = [row for row in eligible if row.get("status") in TRAINABLE_STATUSES]
        real = [row for row in eligible if not row.get("synthetic")]
        synthetic = [row for row in eligible if row.get("synthetic")]
        groups = Counter(
            str(row.get("meal_instance_id") or row.get("source_group") or row.get("source_id") or "unknown")
            for row in eligible
        )
        angles = Counter(str(row.get("angle") or "unspecified") for row in eligible)
        classes.append(
            {
                "dish_id": dish_id,
                "display_name": entry["display_name"],
                "eligible_images": len(eligible),
                "trainable_images": len(trainable),
                "pending_review_images": sum(row.get("status") in PENDING_STATUSES for row in eligible),
                "real_images": len(real),
                "synthetic_images": len(synthetic),
                "synthetic_fraction": round(len(synthetic) / len(eligible), 4) if eligible else 0,
                "distinct_groups": len(groups),
                "largest_group": max(groups.values(), default=0),
                "angle_counts": dict(angles),
                "complete_target": len(eligible) >= args.min_per_dish,
                "real_target_met": len(real) >= args.min_real_per_dish,
                "trainable_target_met": len(trainable) >= args.min_per_dish,
            }
        )

    incomplete = [row["dish_id"] for row in classes if not row["complete_target"]]
    insufficient_real = [row["dish_id"] for row in classes if not row["real_target_met"]]
    untrainable = [row["dish_id"] for row in classes if not row["trainable_target_met"]]
    report = {
        "dataset_id": registry.get("dataset_id"),
        "registry_version": registry.get("version"),
        "manifest_rows": len(rows),
        "classes": len(classes),
        "target_images_per_class": args.min_per_dish,
        "minimum_real_images_per_class": args.min_real_per_dish,
        "trainable_statuses": sorted(TRAINABLE_STATUSES),
        "pending_statuses": sorted(PENDING_STATUSES),
        "class_summary": classes,
        "incomplete_classes": incomplete,
        "insufficient_real_classes": insufficient_real,
        "not_trainable_classes": untrainable,
        "duplicate_sha256_groups": duplicate_groups,
        "missing_provenance": missing_provenance,
        "corrupted_or_missing_images": corrupted,
        "ready_for_training": not incomplete
        and not insufficient_real
        and not untrainable
        and not duplicate_groups
        and not missing_provenance
        and not corrupted,
    }
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--work-dir", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--min-per-dish", type=int, default=300)
    parser.add_argument("--min-real-per-dish", type=int, default=240)
    parser.add_argument("--min-short-side", type=int, default=640)
    args = parser.parse_args()
    report = audit(args)
    print(
        json.dumps(
            {
                "ready_for_training": report["ready_for_training"],
                "classes": report["classes"],
                "incomplete_classes": len(report["incomplete_classes"]),
                "insufficient_real_classes": len(report["insufficient_real_classes"]),
                "duplicate_groups": len(report["duplicate_sha256_groups"]),
                "missing_provenance": len(report["missing_provenance"]),
                "corrupted_or_missing_images": len(report["corrupted_or_missing_images"]),
            },
            indent=2,
        )
    )
    raise SystemExit(0 if report["ready_for_training"] else 2)


if __name__ == "__main__":
    main()
