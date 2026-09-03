# Filipino Food Five-Class Pilot — 2026-09-03

## Scope

This is an explicitly limited pilot for five dish labels plus the
`unknown_or_unsupported` class. It is not the unfinished 100-dish production
model.

Selected dishes:

- Chicken Adobo
- Pork Adobo
- Sinigang na Baboy
- Sinigang na Hipon
- Kare-kare

## Dataset

The source dataset is kept outside the repository at
`C:\Users\HP\Desktop\jcg-dataset-work\filipino_food_100`.

The pilot contains 428 approved real-image records, split 70/15/15 into 300
training, 65 validation, and 63 test images. Per-class approved counts are:

| Class | Approved images |
| --- | ---: |
| Chicken Adobo | 100 |
| Pork Adobo | 50 |
| Sinigang na Baboy | 100 |
| Sinigang na Hipon | 68 |
| Kare-kare | 65 |
| Unknown or unsupported | 45 |

The records were approved for this pilot at the user's direction. Wikimedia
provenance, hashes, and license fields were retained. 127 CC BY-SA records
require attribution in any public distribution.

## Held-out test result

| Metric | Result |
| --- | ---: |
| Top-1 accuracy | 77.78% |
| Macro precision | 76.36% |
| Macro recall | 79.31% |

Per-class recall:

- Chicken Adobo: 80.00%
- Kare-kare: 77.78%
- Pork Adobo: 71.43%
- Sinigang na Baboy: 66.67%
- Sinigang na Hipon: 80.00%
- Unknown or unsupported: 100.00%

The pilot clears the requested 50% accuracy floor, but it does not clear the
stronger production gate: 80% top-1 accuracy, 80% macro recall, and no class
below 70% recall. Keep user confirmation and manual correction enabled.

## Artifact

The app includes the explicitly named `filifood5_pilot_v1` TFLite artifact,
labels, and display names. The 100-dish asset remains absent until its full
dataset and release gate are complete.
