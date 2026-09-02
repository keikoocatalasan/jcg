"""Create a deterministic prompt manifest for controlled synthetic gaps.

This script does not call an image-generation service. It creates a resumable
JSONL queue so any approved generator can produce only the missing training
conditions. Synthetic outputs must be added back with the prompt, seed, model
and license metadata; they are never valid validation or test images.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import random
from pathlib import Path


ANGLES = (
    "top-down 80 degree view",
    "three-quarter 45 degree view",
    "eye-level side view",
    "close-up macro detail",
    "wide dining-context view",
    "slightly overhead 30 degree view",
)
SETTINGS = (
    "a Filipino home dining table",
    "a clean local carinderia counter in the Philippines",
    "a Filipino street-food stall",
    "a casual Philippine restaurant table",
    "a banana-leaf serving tray",
    "a realistic takeout container",
)
LIGHTING = (
    "soft daylight",
    "warm indoor light",
    "overcast daylight",
    "dim but usable phone-camera light",
)
PRESENTATIONS = (
    "one clearly visible serving with natural imperfections",
    "a shared serving bowl with realistic portion variation",
    "a partially served plate with a spoon nearby",
    "a freshly prepared portion with authentic ingredients visible",
)
NEGATIVE_PROMPT = (
    "illustration, painting, CGI, 3d render, fantasy ingredients, wrong dish, "
    "Westernized garnish, duplicate utensils, malformed food, fake text, "
    "watermark, logo, faces, readable brand packaging, collage, split image"
)


def prompt_for(entry: dict[str, object], angle: str, setting: str, lighting: str, presentation: str) -> str:
    return (
        f"Documentary smartphone photograph of authentic {entry['display_name']}, "
        f"a Filipino dish associated with {entry['region']}, {angle}, in {setting}, "
        f"under {lighting}, showing {presentation}. The food is the clear subject, "
        "with realistic color, texture, serving size, camera noise and ordinary "
        "Philippine presentation. No text, logo, watermark or people."
    )


def build(args: argparse.Namespace) -> dict[str, object]:
    registry = json.loads(Path(args.registry).read_text(encoding="utf-8"))
    entries = registry["classes"]
    selected = set(args.dish_id or [])
    if selected:
        entries = [entry for entry in entries if entry["id"] in selected]
    if args.max_dishes:
        entries = entries[: args.max_dishes]

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    rows: list[dict[str, object]] = []
    combinations = list(itertools.product(ANGLES, SETTINGS, LIGHTING, PRESENTATIONS))
    for entry in entries:
        local = combinations[:]
        rng.shuffle(local)
        for index, (angle, setting, lighting, presentation) in enumerate(local[: args.per_dish]):
            prompt = prompt_for(entry, angle, setting, lighting, presentation)
            prompt_id = hashlib.sha256(
                f"{entry['id']}|{index}|{prompt}".encode("utf-8")
            ).hexdigest()[:20]
            rows.append(
                {
                    "prompt_id": prompt_id,
                    "dish_id": entry["id"],
                    "display_name": entry["display_name"],
                    "region": entry["region"],
                    "angle": angle,
                    "setting": setting,
                    "lighting": lighting,
                    "presentation": presentation,
                    "prompt": prompt,
                    "negative_prompt": NEGATIVE_PROMPT,
                    "synthetic": True,
                    "status": "queued",
                    "split_policy": "train_only",
                    "generator_model": None,
                    "generator_license": None,
                    "seed": None,
                }
            )
    output.write_text(
        "\n".join(json.dumps(row, ensure_ascii=False, sort_keys=True) for row in rows) + "\n",
        encoding="utf-8",
    )
    return {
        "output": str(output),
        "classes": len(entries),
        "prompts": len(rows),
        "per_dish": args.per_dish,
        "split_policy": "synthetic images are training-only",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--dish-id", action="append")
    parser.add_argument("--max-dishes", type=int)
    parser.add_argument("--per-dish", type=int, default=20)
    parser.add_argument("--seed", type=int, default=20260903)
    args = parser.parse_args()
    print(json.dumps(build(args), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
