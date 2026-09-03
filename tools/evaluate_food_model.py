"""Evaluate a TFLite food model on a locked CSV split.

This is intentionally separate from training so the held-out set can be
evaluated after the model artifact is frozen. It reports top-1/top-3 metrics,
per-class recall, unknown-class support, and the production release gate.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image


IMAGE_SIZE = 224


def _interpreter(model_path: Path):
    try:
        from tflite_runtime.interpreter import Interpreter  # type: ignore
    except ImportError:
        try:
            from tensorflow.lite import Interpreter  # type: ignore
        except ImportError as exc:
            raise RuntimeError(
                "Install tensorflow or tflite-runtime to evaluate the model."
            ) from exc
    return Interpreter(model_path=str(model_path))


def _load_rows(split_path: Path, dataset_root: Path) -> list[dict[str, str]]:
    with split_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    rows = [row for row in rows if row.get("split") == "test"]
    if not rows:
        raise ValueError("The locked split contains no test rows")
    for row in rows:
        if row.get("synthetic", "False").lower() == "true":
            raise ValueError("Synthetic rows are not allowed in the test split")
        image_path = Path(row.get("image_path") or "")
        if not image_path.is_absolute():
            image_path = dataset_root / image_path
        if not image_path.exists():
            raise FileNotFoundError(image_path)
        row["resolved_image_path"] = str(image_path)
    return rows


def _image_array(path: Path, input_details: dict[str, Any]) -> np.ndarray:
    with Image.open(path) as opened:
        image = opened.convert("RGB").resize((IMAGE_SIZE, IMAGE_SIZE), Image.Resampling.LANCZOS)
    array = np.asarray(image, dtype=np.float32)[None, ...]
    dtype = input_details["dtype"]
    if dtype == np.uint8:
        return np.clip(array, 0, 255).astype(np.uint8)
    if dtype == np.int8:
        scale, zero_point = input_details["quantization"]
        if not scale:
            raise ValueError("Quantized model has no input scale")
        return np.round(array / scale + zero_point).clip(-128, 127).astype(np.int8)
    return array


def evaluate(args: argparse.Namespace) -> dict[str, Any]:
    labels = [
        line.strip()
        for line in args.labels.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not labels:
        raise ValueError("The label file is empty")
    label_index = {label: index for index, label in enumerate(labels)}
    rows = _load_rows(args.split, args.dataset_root)
    unknown_rows = [row for row in rows if row["dish_id"] not in label_index]
    if unknown_rows:
        raise ValueError(f"Test rows contain labels missing from the model: {unknown_rows[0]['dish_id']}")

    interpreter = _interpreter(args.model)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    if list(input_details["shape"])[-3:] != [IMAGE_SIZE, IMAGE_SIZE, 3]:
        raise ValueError(f"Unexpected input shape: {input_details['shape']}")

    confusion = np.zeros((len(labels), len(labels)), dtype=np.int64)
    top1 = 0
    top3 = 0
    per_class_total = defaultdict(int)
    per_class_correct = defaultdict(int)
    for row in rows:
        interpreter.set_tensor(input_details["index"], _image_array(Path(row["resolved_image_path"]), input_details))
        interpreter.invoke()
        probabilities = interpreter.get_tensor(output_details["index"])[0].astype(np.float32)
        if output_details["dtype"] in (np.uint8, np.int8):
            scale, zero_point = output_details["quantization"]
            probabilities = (probabilities - zero_point) * scale
        actual = label_index[row["dish_id"]]
        ranked = np.argsort(probabilities)[::-1]
        predicted = int(ranked[0])
        top1 += predicted == actual
        top3 += actual in ranked[:3]
        per_class_total[row["dish_id"]] += 1
        per_class_correct[row["dish_id"]] += predicted == actual
        confusion[actual, predicted] += 1

    total = len(rows)
    per_class = {
        label: {
            "support": per_class_total[label],
            "recall": round(
                per_class_correct[label] / per_class_total[label]
                if per_class_total[label]
                else 0.0,
                6,
            ),
        }
        for label in labels
    }
    recalls = [row["recall"] for row in per_class.values()]
    report = {
        "model": str(args.model.resolve()),
        "labels": labels,
        "test_images": total,
        "top1_accuracy": round(top1 / total, 6),
        "top3_accuracy": round(top3 / total, 6),
        "macro_recall": round(float(np.mean(recalls)), 6),
        "minimum_class_recall": round(min(recalls), 6),
        "per_class": per_class,
        "confusion_matrix": confusion.tolist(),
    }
    report["release_gate"] = {
        "top1_accuracy_at_least_80_percent": report["top1_accuracy"] >= 0.80,
        "top3_accuracy_at_least_90_percent": report["top3_accuracy"] >= 0.90,
        "macro_recall_at_least_80_percent": report["macro_recall"] >= 0.80,
        "no_class_recall_below_70_percent": report["minimum_class_recall"] >= 0.70,
        "unknown_class_present": "unknown_or_unsupported" in labels,
        "unknown_class_has_test_support": per_class.get("unknown_or_unsupported", {}).get("support", 0) > 0,
    }
    report["release_ready"] = all(report["release_gate"].values())
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--split", required=True, type=Path)
    parser.add_argument("--dataset-root", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = evaluate(args)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    raise SystemExit(0 if report["release_ready"] else 2)


if __name__ == "__main__":
    main()
