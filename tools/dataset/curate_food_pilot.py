"""Apply the reviewed pilot curation decisions to an external JSONL manifest.

The contact-sheet index is the stable order of downloaded_pending_review rows
for each class at review time. Rejected candidates remain in the manifest with
provenance, but are excluded from train/validation/test splits.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


APPROVED_INDEXES = {
    "pandesal": {
        *range(0, 15),
        37, 38, 40, 41, 45, 46, 47, 48, 76, 78,
    },
    "scrambled_egg": {
        *range(0, 9),
        27, 28, 29, 30, 31, 32, 34, 35, 36, 42, 43, 44, 45, 93, 94,
    },
    "sunny_side_up_egg": {
        *range(0, 9),
        *range(10, 13),
        *range(14, 32),
        34,
    },
    "boiled_egg": {
        0, 1, 2, 4, 5, 6, 8, 12, 13, 14, 15, 22, 23, 26, 30, 41, 44,
        45, 47, 54, 56, 58,
        70, 72, 74,
    },
}

SERIES_GROUPS = {
    "scrambled_egg": {index: "cheesy_scrambled_eggs_series" for index in range(8, 27)},
    "boiled_egg": {index: "bulacan_boiled_egg_series" for index in range(45, 70)},
}

# Additional candidates collected after the first review pass. These indexes
# refer only to the newly downloaded_pending_review rows for each class.
PENDING_APPROVED_INDEXES = {
    "pandesal": {0, 41},
    "scrambled_egg": {6, 7, 8, 12, 20, 21, 22, 30, 31, 32, 33, 37, 38, 40, 42},
    "boiled_egg": {
        0, 1, 2, 3, 4, 5, 10, 11, 12, 14, 15, 16, 17,
        21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    },
}

RESCUED_STEMS = {
    "pandesal": {
        "141478350", "143175250", "145148901", "151256401", "157366468",
        "179583845", "182360524", "192206358", "61404353", "61425498",
        "61425502",
    }
}


def curate(manifest_path: Path) -> dict[str, int]:
    rows = [
        json.loads(line)
        for line in manifest_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    counters = {"approved": 0, "rejected": 0, "untouched": 0}
    by_class: dict[str, list[dict]] = {}
    for row in rows:
        stem = Path(str(row.get("image_path") or "")).stem
        if (
            row.get("dish_id") in RESCUED_STEMS
            and stem in RESCUED_STEMS[row["dish_id"]]
            and row.get("image_path")
        ):
            row["status"] = "human_approved"
            row["review_status"] = "human_approved"
            row["review_note"] = "Second contact-sheet review: rescued visually matching source image."
        if (
            row.get("dish_id") in APPROVED_INDEXES
            and row.get("status") == "human_approved"
            and not str(row.get("image_path") or "").strip()
        ):
            row["status"] = "rejected_quality"
            row["review_status"] = "human_rejected"
            row["reject_reason"] = "missing_downloaded_image_path"
        if row.get("dish_id") in PENDING_APPROVED_INDEXES and row.get("status") == "downloaded_pending_review":
            by_class.setdefault(row["dish_id"], []).append(row)

    for dish_id, candidates in by_class.items():
        for index, row in enumerate(candidates):
            if index in PENDING_APPROVED_INDEXES[dish_id]:
                row["status"] = "human_approved"
                row["review_status"] = "human_approved"
                row["review_note"] = "Contact-sheet review: visually matches the requested class."
                # The repeated series were reduced during review; keep each
                # retained source image as its own group for a conservative
                # holdout rather than manufacturing a one-image test split.
                row.pop("source_group", None)
                counters["approved"] += 1
            else:
                row["status"] = "rejected_quality"
                row["review_status"] = "human_rejected"
                row["reject_reason"] = "contact_sheet_label_mismatch_or_composite_scene"
                counters["rejected"] += 1

    temporary = manifest_path.with_suffix(manifest_path.suffix + ".curated.tmp")
    temporary.write_text(
        "\n".join(json.dumps(row, ensure_ascii=False, sort_keys=True) for row in rows) + "\n",
        encoding="utf-8",
    )
    temporary.replace(manifest_path)
    return counters


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(curate(args.manifest), indent=2))


if __name__ == "__main__":
    main()
