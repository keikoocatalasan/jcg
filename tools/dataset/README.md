# Filipino food image dataset pipeline

This pipeline is the source-of-truth workflow for expanding the two-dish
scanner to the 100-class Filipino food registry. Raw images stay outside the
Git repository. Only reviewed metadata, split files and the final compact
TFLite model should be copied into the Flutter app.

## Current registry

`dish_registry.json` contains 100 provisional dish IDs. A class is not
complete merely because search returned 100 URLs. It needs 100 accepted images,
at least 80 real images, complete provenance, duplicate checks and a human
review status of `approved` or `human_approved`.

## Collect open-source candidates

Use a conservative, slow batch. Wikimedia Commons is queried through its API;
the collector sets a unique user-agent and backs off when the provider returns
HTTP 429.

```powershell
$py = 'C:\Users\HP\AppData\Local\Temp\jcg-two-dish-vision-env\Scripts\python.exe'
& $py -u tools\dataset\collect_food_images.py `
  --registry tools\dataset\dish_registry.json `
  --work-dir 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100' `
  --target-real 40 `
  --max-dishes 10 `
  --source commons `
  --download-delay 2.0
```

Resume with the same command. For a single dish, add one or more
`--dish-id` flags. Openverse can be used with `--source both` for discovery,
but its results are marked `needs_manual_review` until the original source
page and license are confirmed.

## Create synthetic gap prompts

The prompt generator creates a deterministic queue. It does not pretend that
generated images are real or independently sourced.

```powershell
& $py tools\dataset\generate_synthetic_prompts.py `
  --registry tools\dataset\dish_registry.json `
  --output 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\manifests\synthetic_prompts.jsonl' `
  --per-dish 20
```

Generated files must be added with `synthetic: true`, the generator model,
model license, prompt ID and seed. Synthetic files are training-only and must
not exceed 20% of a class.

Collect the real open-set examples separately. The collector uses non-food,
other-food and ordinary Philippine-scene queries and writes them under the
`unknown_or_unsupported` class:

```powershell
& $py -u tools\dataset\collect_unknown_images.py `
  --work-dir 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100' `
  --target-real 100 `
  --download-delay 5.0
```

Unknown examples are also human-review pending. They are required for the
expanded model to reject photos that are not one of the supported dishes.

## Audit and split

```powershell
& $py tools\dataset\audit_food_dataset.py `
  --registry tools\dataset\dish_registry.json `
  --manifest 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\manifests\candidates.jsonl' `
  --work-dir 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100' `
  --output 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\manifests\audit_report.json'
```

Only rows with `approved` or `human_approved` status are included in the
leakage-safe split:

```powershell
& $py tools\dataset\build_food_splits.py `
  --registry tools\dataset\dish_registry.json `
  --manifest 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\manifests\candidates.jsonl' `
  --output 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\manifests\splits.csv'
```

All images from one meal instance, source series or manually assigned source
group stay in one split. Synthetic images are forced into `train`.

## Train and export

```powershell
& $py tools\train_filifood100.py `
  --registry tools\dataset\dish_registry.json `
  --split-file 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\manifests\splits.csv' `
  --dataset-root 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100' `
  --output-dir 'C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100\model'
```

The training script uses MobileNetV2 transfer learning, balanced class
weights, deterministic augmentation, grouped splits, float16 TFLite export,
per-class metrics and a confusion matrix. It includes an
`unknown_or_unsupported` class when that class is present in the split.

## Dataset completion rule

Do not ship a new model until every class has at least 100 approved images,
80 real images, complete license/provenance fields, no exact duplicates, no
source-group leakage and a fresh phone-camera test set.
