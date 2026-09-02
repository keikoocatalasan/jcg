"""Train the key-free Chicken Adobo vs Sinigang TFLite demo model.

The source photographs are resolved from Wikimedia Commons at training time.
Only the compact model, two CC0 sample images, labels, and source manifest are
written into the Flutter application.
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
import time
from pathlib import Path
from typing import Any

import requests
import tensorflow as tf
from PIL import Image


COMMONS_API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "JCG-Fitness-Two-Dish-Model/1.0 (academic prototype)"
SEED = 20260902
IMAGE_SIZE = 224

SOURCES = {
    "chicken_adobo": [
        "File:0959Filipino chicken adobo with potatoes in lemon grass 03.jpg",
        "File:0959Filipino chicken adobo with potatoes in lemon grass 04.jpg",
        "File:Chicken Adobo Rice Topping with eggs.jpg",
        "File:Chicken Adobo over rice.jpg",
        "File:Chicken Adobo with Coconut Milk.jpg",
        "File:Chicken Adobo with Potatoes.jpg",
        "File:Chicken adobo.jpg",
        "File:Chicken adobo (Philippines).jpg",
        "File:Chicken adobo (Philippines) 2.jpg",
        "File:Chicken adobo meal 20231025.jpg",
        "File:Chicken adobo with potato.jpg",
        "File:Filipino Chicken Adobo 1.jpg",
        "File:Filipino Chicken Adobo with rice.jpg",
        "File:Filipino Chicken Adobo with rice 2.jpg",
        "File:Homemade chicken adobo 1.JPG",
        "File:Homemade chicken adobo 2.JPG",
        "File:Homemade chicken adobo 3.JPG",
    ],
    "sinigang": [
        "File:1466Cuisine of Bulacan Sinigang 08.jpg",
        "File:1466Cuisine of Bulacan Sinigang 15.jpg",
        "File:1466Cuisine of Bulacan Sinigang 17.jpg",
        "File:1466Cuisine of Bulacan Sinigang 26.jpg",
        "File:1466Cuisine of Bulacan Sinigang 28.jpg",
        "File:1466Cuisine of Bulacan Sinigang 29.jpg",
        "File:1466Cuisine of Bulacan Sinigang 33.jpg",
        "File:1466Cuisine of Bulacan Sinigang 36.jpg",
        "File:1466Cuisine of Bulacan Sinigang 40.jpg",
        "File:1466Cuisine of Bulacan Sinigang 42.jpg",
        "File:2949Cuisine Meals in Bulacan Sinigang 01.jpg",
        "File:2949Cuisine Meals in Bulacan Sinigang 02.jpg",
        "File:Cagayan - Genaro's Sinigang na Malaga.jpg",
        "File:Fely J's Sinigang with Guava.jpg",
        "File:Fish sinigang.jpg",
        "File:Sinigang na Baboy.jpg",
        "File:Sinigang na Baboy DSCF4234.jpg",
    ],
}


def _plain(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(
        value.replace("<br>", " ")
        .replace("<br/>", " ")
        .replace("<br />", " ")
        .split()
    )


def request_with_backoff(
    url: str,
    *,
    params: dict[str, str] | None = None,
    timeout: int = 60,
) -> requests.Response:
    for attempt in range(6):
        response = requests.get(
            url,
            params=params,
            headers={"User-Agent": USER_AGENT},
            timeout=timeout,
        )
        if response.status_code != 429:
            response.raise_for_status()
            return response
        retry_after = response.headers.get("Retry-After")
        delay = float(retry_after) if retry_after else min(60.0, 5.0 * (2**attempt))
        print(f"Wikimedia rate limit; waiting {delay:.0f}s before retry")
        time.sleep(delay)
    response.raise_for_status()
    return response


def resolve_commons_file(title: str) -> dict[str, Any]:
    response = request_with_backoff(
        COMMONS_API,
        params={
            "action": "query",
            "titles": title,
            "prop": "imageinfo",
            "iiprop": "url|mime|extmetadata",
            "iiurlwidth": "960",
            "format": "json",
        },
        timeout=30,
    )
    pages = response.json()["query"]["pages"]
    page = next(iter(pages.values()))
    info = page["imageinfo"][0]
    metadata = info.get("extmetadata", {})

    def meta(name: str) -> str:
        return _plain(metadata.get(name, {}).get("value"))

    return {
        "title": page["title"],
        "file_page": f"https://commons.wikimedia.org/wiki/{page['title'].replace(' ', '_')}",
        "image_url": info.get("thumburl") or info["url"],
        "mime": info.get("mime", "image/jpeg"),
        "license": meta("LicenseShortName"),
        "license_url": meta("LicenseUrl"),
        "artist": meta("Artist"),
        "credit": meta("Credit"),
    }


def download_dataset(dataset_dir: Path) -> list[dict[str, Any]]:
    partial_manifest_path = dataset_dir.parent / "source_manifest.partial.json"
    cached_records: dict[str, dict[str, Any]] = {}
    if partial_manifest_path.exists():
        cached_records = {
            record["title"]: record
            for record in json.loads(partial_manifest_path.read_text(encoding="utf-8"))
        }
    manifest: list[dict[str, Any]] = []
    for label, titles in SOURCES.items():
        class_dir = dataset_dir / label
        class_dir.mkdir(parents=True, exist_ok=True)
        for index, title in enumerate(titles):
            target = class_dir / f"{index:02d}.jpg"
            record = cached_records.get(title)
            if record is None and target.exists():
                record = {
                    "title": title,
                    "file_page": f"https://commons.wikimedia.org/wiki/{title.replace(' ', '_')}",
                    "image_url": "",
                    "mime": "image/jpeg",
                    "license": "See Wikimedia Commons file page",
                    "license_url": "",
                    "artist": "",
                    "credit": "",
                }
            if record is None:
                record = resolve_commons_file(title)
            record["label"] = label
            record["local_training_file"] = target.name
            if not target.exists():
                response = request_with_backoff(
                    record["image_url"],
                    timeout=60,
                )
                target.write_bytes(response.content)
            try:
                with Image.open(target) as image:
                    image = image.convert("RGB")
                    image.thumbnail((1280, 1280))
                    image.save(target, format="JPEG", quality=90, optimize=True)
            except Exception:
                target.unlink(missing_ok=True)
                raise
            manifest.append(record)
            cached_records[title] = record
            partial_manifest_path.write_text(
                json.dumps(list(cached_records.values()), indent=2, ensure_ascii=False),
                encoding="utf-8",
            )
            print(f"downloaded {label}: {record['title']}")
            time.sleep(1.0)
    return manifest


def build_model(class_count: int) -> tuple[tf.keras.Model, tf.keras.Model]:
    augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.08),
            tf.keras.layers.RandomZoom(0.12),
            tf.keras.layers.RandomContrast(0.15),
        ],
        name="training_augmentation",
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
    x = tf.keras.layers.Dropout(0.25)(x)
    outputs = tf.keras.layers.Dense(
        class_count, activation="softmax", name="dish_probabilities"
    )(x)
    return tf.keras.Model(inputs, outputs, name="jcg_two_dish_classifier"), base


def train_and_export(
    dataset_dir: Path,
    output_dir: Path,
    sample_dir: Path,
    manifest: list[dict[str, Any]],
) -> dict[str, Any]:
    train_ds = tf.keras.utils.image_dataset_from_directory(
        dataset_dir,
        validation_split=0.25,
        subset="training",
        seed=SEED,
        image_size=(IMAGE_SIZE, IMAGE_SIZE),
        batch_size=8,
        label_mode="int",
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        dataset_dir,
        validation_split=0.25,
        subset="validation",
        seed=SEED,
        image_size=(IMAGE_SIZE, IMAGE_SIZE),
        batch_size=8,
        label_mode="int",
    )
    class_names = train_ds.class_names
    if class_names != ["chicken_adobo", "sinigang"]:
        raise RuntimeError(f"Unexpected label order: {class_names}")

    autotune = tf.data.AUTOTUNE
    train_ds = train_ds.cache().shuffle(64, seed=SEED).prefetch(autotune)
    val_ds = val_ds.cache().prefetch(autotune)
    model, base = build_model(len(class_names))
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_accuracy", patience=4, restore_best_weights=True
    )
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=18,
        callbacks=[early_stop],
        verbose=2,
    )

    base.trainable = True
    for layer in base.layers[:-24]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=2e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    fine_history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=6,
        callbacks=[early_stop],
        verbose=2,
    )
    validation_loss, validation_accuracy = model.evaluate(val_ds, verbose=0)

    output_dir.mkdir(parents=True, exist_ok=True)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    model_path = output_dir / "two_dish_classifier.tflite"
    model_path.write_bytes(tflite_model)
    (output_dir / "two_dish_labels.txt").write_text(
        "\n".join(class_names) + "\n", encoding="utf-8"
    )

    sample_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dataset_dir / "chicken_adobo" / "00.jpg", sample_dir / "chicken_adobo.jpg")
    shutil.copy2(dataset_dir / "sinigang" / "00.jpg", sample_dir / "sinigang.jpg")
    (output_dir / "two_dish_sources.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    report = {
        "labels": class_names,
        "image_size": IMAGE_SIZE,
        "training_images": len(manifest),
        "validation_loss": float(validation_loss),
        "validation_accuracy": float(validation_accuracy),
        "model_bytes": len(tflite_model),
        "initial_epochs": len(history.history["loss"]),
        "fine_tune_epochs": len(fine_history.history["loss"]),
    }
    (output_dir / "two_dish_training_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--sample-dir", type=Path, required=True)
    args = parser.parse_args()
    random.seed(SEED)
    tf.keras.utils.set_random_seed(SEED)
    dataset_dir = args.work_dir / "dataset"
    dataset_dir.mkdir(parents=True, exist_ok=True)
    manifest = download_dataset(dataset_dir)
    report = train_and_export(
        dataset_dir=dataset_dir,
        output_dir=args.output_dir,
        sample_dir=args.sample_dir,
        manifest=manifest,
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
