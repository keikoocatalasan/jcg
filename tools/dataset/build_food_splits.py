"""Build leakage-safe train/validation/test split files.

All angles from one meal instance, original source series or manually supplied
source group stay in a single split. Synthetic images are training-only.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import defaultdict
from pathlib import Path
from typing import Any


TRAINABLE_STATUSES = {"human_approved", "approved"}


def load_rows(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def build(args: argparse.Namespace) -> dict[str, Any]:
    registry = json.loads(Path(args.registry).read_text(encoding="utf-8"))
    class_ids = {entry["id"] for entry in registry["classes"]}
    class_ids.add("unknown_or_unsupported")
    rows = [
        row
        for row in load_rows(Path(args.manifest))
        if row.get("dish_id") in class_ids and row.get("status") in TRAINABLE_STATUSES
    ]
    rng = random.Random(args.seed)
    assignments: list[dict[str, Any]] = []
    class_summary: list[dict[str, Any]] = []
    for dish_id in sorted(class_ids):
        dish_rows = [row for row in rows if row.get("dish_id") == dish_id]
        real_rows = [row for row in dish_rows if not row.get("synthetic")]
        synthetic_rows = [row for row in dish_rows if row.get("synthetic")]
        groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for row in real_rows:
            group = str(
                row.get("meal_instance_id")
                or row.get("source_group")
                or row.get("source_id")
                or row.get("candidate_key")
            )
            groups[group].append(row)
        group_items = list(groups.items())
        rng.shuffle(group_items)
        group_items.sort(key=lambda item: len(item[1]), reverse=True)
        total = len(real_rows)
        targets = {
            "train": max(0, round(total * 0.70)),
            "val": max(0, round(total * 0.15)),
            "test": max(0, total - round(total * 0.70) - round(total * 0.15)),
        }
        counts = {key: 0 for key in targets}
        split_groups: dict[str, list[str]] = defaultdict(list)
        for group, group_rows in group_items:
            split = min(
                targets,
                key=lambda key: (
                    counts[key] / max(1, targets[key]),
                    counts[key],
                    key,
                ),
            )
            split_groups[split].append(group)
            counts[split] += len(group_rows)
            for row in group_rows:
                assignments.append(
                    {
                        "candidate_key": row.get("candidate_key") or row.get("image_id"),
                        "dish_id": dish_id,
                        "split": split,
                        "synthetic": False,
                        "image_path": row.get("image_path") or "",
                    }
                )
        for row in synthetic_rows:
            assignments.append(
                {
                    "candidate_key": row.get("candidate_key") or row.get("image_id"),
                    "dish_id": dish_id,
                    "split": "train",
                    "synthetic": True,
                    "image_path": row.get("image_path") or "",
                }
            )
        class_summary.append(
            {
                "dish_id": dish_id,
                "real_images": len(real_rows),
                "synthetic_images": len(synthetic_rows),
                "train": sum(row["split"] == "train" for row in assignments if row["dish_id"] == dish_id),
                "val": sum(row["split"] == "val" for row in assignments if row["dish_id"] == dish_id),
                "test": sum(row["split"] == "test" for row in assignments if row["dish_id"] == dish_id),
                "groups": len(groups),
                "groups_by_split": {key: len(value) for key, value in split_groups.items()},
            }
        )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=("candidate_key", "dish_id", "split", "synthetic", "image_path"),
        )
        writer.writeheader()
        writer.writerows(assignments)
    summary = {
        "manifest": str(Path(args.manifest).resolve()),
        "output": str(output.resolve()),
        "seed": args.seed,
        "approved_rows": len(rows),
        "assignments": len(assignments),
        "synthetic_train_only": all(row["split"] == "train" for row in assignments if row["synthetic"]),
        "class_summary": class_summary,
    }
    summary_path = output.with_suffix(".summary.json")
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20260903)
    args = parser.parse_args()
    print(json.dumps(build(args), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
