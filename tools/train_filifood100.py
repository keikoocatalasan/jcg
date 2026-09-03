"""Train the leakage-safe Filipino food classifier and export TFLite.

The script consumes the approved CSV produced by
``tools/dataset/build_food_splits.py``. It deliberately refuses to train when
the split has no real validation/test data and keeps synthetic images in the
training split only.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import Counter
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf


IMAGE_SIZE = 224
SEED = 20260903


def load_registry(path: Path) -> tuple[list[str], dict[str, str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    ids = [entry["id"] for entry in payload["classes"]]
    names = {entry["id"]: entry["display_name"] for entry in payload["classes"]}
    return ids, names


def load_split_rows(
    path: Path,
    dataset_root: Path,
) -> tuple[dict[str, list[tuple[str, int]]], list[str], dict[str, int]]:
    raw: list[dict[str, str]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        raw = list(csv.DictReader(handle))
    if not raw:
        raise ValueError("The split CSV is empty")
    labels = sorted({row["dish_id"] for row in raw})
    label_index = {label: index for index, label in enumerate(labels)}
    split_rows: dict[str, list[tuple[str, int]]] = {"train": [], "val": [], "test": []}
    synthetic_counts = {"train": 0, "val": 0, "test": 0}
    for row in raw:
        split = row["split"]
        if split not in split_rows:
            raise ValueError(f"Unexpected split {split!r}")
        is_synthetic = row.get("synthetic", "False").lower() == "true"
        if is_synthetic and split != "train":
            raise ValueError("Synthetic images may only appear in the training split")
        if is_synthetic:
            synthetic_counts[split] += 1
        image_path = row.get("image_path") or ""
        path_value = Path(image_path)
        if not path_value.is_absolute():
            path_value = dataset_root / path_value
        if not path_value.exists():
            raise FileNotFoundError(path_value)
        split_rows[split].append((str(path_value), label_index[row["dish_id"]]))
    if not split_rows["train"] or not split_rows["val"] or not split_rows["test"]:
        raise ValueError("Train, validation and test splits must all contain images")
    return split_rows, labels, synthetic_counts


def decode_image(path: tf.Tensor, label: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
    image = tf.io.read_file(path)
    image = tf.io.decode_image(image, channels=3, expand_animations=False)
    image.set_shape([None, None, 3])
    image = tf.image.resize(image, [IMAGE_SIZE, IMAGE_SIZE], antialias=True)
    return tf.cast(image, tf.float32), label


def make_dataset(
    rows: list[tuple[str, int]],
    *,
    batch_size: int,
    shuffle: bool,
) -> tf.data.Dataset:
    paths = [row[0] for row in rows]
    labels = [row[1] for row in rows]
    dataset = tf.data.Dataset.from_tensor_slices((paths, labels))
    if shuffle:
        dataset = dataset.shuffle(len(rows), seed=SEED, reshuffle_each_iteration=True)
    return dataset.map(decode_image, num_parallel_calls=tf.data.AUTOTUNE).batch(
        batch_size
    ).prefetch(tf.data.AUTOTUNE)


def build_model(class_count: int) -> tuple[tf.keras.Model, tf.keras.Model]:
    augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.08),
            tf.keras.layers.RandomZoom(0.15),
            tf.keras.layers.RandomContrast(0.15),
        ],
        name="filipino_food_augmentation",
    )
    base = tf.keras.applications.MobileNetV2(
        input_shape=(IMAGE_SIZE, IMAGE_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False
    inputs = tf.keras.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, 3), name="food_image")
    x = augmentation(inputs)
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.30)(x)
    outputs = tf.keras.layers.Dense(class_count, activation="softmax", name="dish_probabilities")(x)
    return tf.keras.Model(inputs, outputs, name="jcg_filifood100_classifier"), base


def class_weights(rows: list[tuple[str, int]]) -> dict[int, float]:
    counts = Counter(label for _, label in rows)
    total = len(rows)
    classes = len(counts)
    return {label: total / (classes * count) for label, count in counts.items()}


def evaluate_model(
    model: tf.keras.Model,
    dataset: tf.data.Dataset,
    labels: list[str],
) -> dict[str, Any]:
    matrix = np.zeros((len(labels), len(labels)), dtype=np.int64)
    for images, expected in dataset:
        probabilities = model(images, training=False).numpy()
        predicted = np.argmax(probabilities, axis=1)
        for actual, guess in zip(expected.numpy().tolist(), predicted.tolist()):
            matrix[actual, guess] += 1
    per_class: dict[str, dict[str, float | int]] = {}
    precisions: list[float] = []
    recalls: list[float] = []
    for index, label in enumerate(labels):
        true_positive = int(matrix[index, index])
        actual = int(matrix[index, :].sum())
        predicted = int(matrix[:, index].sum())
        precision = true_positive / predicted if predicted else 0.0
        recall = true_positive / actual if actual else 0.0
        precisions.append(precision)
        recalls.append(recall)
        per_class[label] = {
            "support": actual,
            "precision": round(precision, 6),
            "recall": round(recall, 6),
        }
    total = int(matrix.sum())
    accuracy = float(np.trace(matrix) / total) if total else 0.0
    return {
        "accuracy": round(accuracy, 6),
        "macro_precision": round(float(np.mean(precisions)), 6),
        "macro_recall": round(float(np.mean(recalls)), 6),
        "confusion_matrix": matrix.tolist(),
        "per_class": per_class,
    }


def release_gate(test_report: dict[str, Any], labels: list[str]) -> dict[str, Any]:
    """Return the measurable production gate without hiding weak classes."""

    per_class = test_report.get("per_class", {})
    recalls = [float(row.get("recall", 0)) for row in per_class.values()]
    unknown = per_class.get("unknown_or_unsupported")
    return {
        "top1_accuracy_at_least_80_percent": test_report.get("accuracy", 0) >= 0.80,
        "macro_recall_at_least_80_percent": test_report.get("macro_recall", 0) >= 0.80,
        "no_class_recall_below_70_percent": bool(recalls) and min(recalls) >= 0.70,
        "unknown_class_present": "unknown_or_unsupported" in labels,
        "unknown_class_has_test_support": bool(unknown and unknown.get("support", 0) > 0),
    }


def train(args: argparse.Namespace) -> dict[str, Any]:
    random.seed(args.seed)
    np.random.seed(args.seed)
    tf.keras.utils.set_random_seed(args.seed)
    model_name = args.model_name.strip()
    if not model_name or not model_name.replace("_", "").replace("-", "").isalnum():
        raise ValueError("model-name may contain only letters, numbers, underscores, and hyphens")
    registry_ids, display_names = load_registry(args.registry)
    split_rows, split_labels, synthetic_counts = load_split_rows(
        args.split_file, args.dataset_root
    )
    missing_registry_labels = [label for label in split_labels if label not in registry_ids and label != "unknown_or_unsupported"]
    if missing_registry_labels:
        raise ValueError(f"Split contains labels missing from registry: {missing_registry_labels}")
    missing_required_labels = [label for label in registry_ids if label not in split_labels]
    if missing_required_labels and not args.allow_partial:
        raise ValueError(
            "Refusing to train a partial production model. Missing registry labels: "
            + ", ".join(missing_required_labels)
            + ". Use --allow-partial only for experiments."
        )
    if "unknown_or_unsupported" not in split_labels and not args.allow_missing_unknown:
        raise ValueError(
            "Refusing to train without unknown_or_unsupported evaluation data. "
            "Use --allow-missing-unknown only for experiments."
        )
    labels = [label for label in registry_ids if label in split_labels]
    if "unknown_or_unsupported" in split_labels:
        labels.append("unknown_or_unsupported")
    if labels != split_labels:
        labels = split_labels
    label_index = {label: index for index, label in enumerate(labels)}
    split_rows = {
        key: [(path, label_index[split_labels[label]]) for path, label in value]
        for key, value in split_rows.items()
    }
    train_dataset = make_dataset(split_rows["train"], batch_size=args.batch_size, shuffle=True)
    val_dataset = make_dataset(split_rows["val"], batch_size=args.batch_size, shuffle=False)
    test_dataset = make_dataset(split_rows["test"], batch_size=args.batch_size, shuffle=False)
    model, base = build_model(len(labels))
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=5, restore_best_weights=True
    )
    history = model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=args.epochs,
        class_weight=class_weights(split_rows["train"]),
        callbacks=[early_stop],
        verbose=2,
    )
    base.trainable = True
    for layer in base.layers[:-args.fine_tune_layers]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=2e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    fine_history = model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=args.fine_tune_epochs,
        class_weight=class_weights(split_rows["train"]),
        callbacks=[early_stop],
        verbose=2,
    )

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    test_report = evaluate_model(model, test_dataset, labels)
    gate = release_gate(test_report, labels)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    model_path = output_dir / f"{model_name}.tflite"
    model_path.write_bytes(tflite_model)
    (output_dir / f"{model_name}_labels.txt").write_text(
        "\n".join(labels) + "\n", encoding="utf-8"
    )
    (output_dir / f"{model_name}_display_names.json").write_text(
        json.dumps(
            {label: display_names.get(label, "Unknown or unsupported food") for label in labels},
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    report = {
        "model": model_name,
        "labels": labels,
        "image_size": IMAGE_SIZE,
        "train_images": len(split_rows["train"]),
        "validation_images": len(split_rows["val"]),
        "test_images": len(split_rows["test"]),
        "synthetic_train_images": synthetic_counts["train"],
        "initial_epochs": len(history.history["loss"]),
        "fine_tune_epochs": len(fine_history.history["loss"]),
        "model_bytes": len(tflite_model),
        "test": test_report,
        "release_gate": gate,
        "release_ready": all(gate.values()),
    }
    (output_dir / f"{model_name}_training_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--split-file", required=True, type=Path)
    parser.add_argument("--dataset-root", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument(
        "--model-name",
        default="filifood100_v1",
        help="Output artifact basename; use a distinct name for pilot experiments.",
    )
    parser.add_argument("--epochs", type=int, default=18)
    parser.add_argument("--fine-tune-epochs", type=int, default=8)
    parser.add_argument("--fine-tune-layers", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument(
        "--allow-partial",
        action="store_true",
        help="Allow an incomplete registry for experiments; never use for a release.",
    )
    parser.add_argument(
        "--allow-missing-unknown",
        action="store_true",
        help="Allow experiments without unknown-class test data; never use for a release.",
    )
    args = parser.parse_args()
    print(json.dumps(train(args), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
