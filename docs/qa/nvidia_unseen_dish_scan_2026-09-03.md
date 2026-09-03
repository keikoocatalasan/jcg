# NVIDIA unseen-dish scan test — 2026-09-03

## Scope

Five open-source Filipino food images from the external dataset workspace were
sent through the complete FastAPI `/ai/scan-food` route using the live NVIDIA
NIM vision model. The images were not copied into the repository and were
chosen outside the bundled two-dish TFLite classes (`Chicken Adobo` and
`Sinigang na Baboy`).

The route test exercised authentication, image validation, multipart upload,
NVIDIA vision inference, response parsing, confidence thresholding, and the
manual-review flag. A local HS256 test token was used because production
requires a real Supabase RS/ES-signed session token.

## Results

| Expected dish | HTTP | Route status | Manual review | Top returned name | Confidence |
|---|---:|---|---|---|---:|
| Bicol Express | 200 | low_confidence | yes | unknown | 0.00 |
| Kare-kare | 200 | low_confidence | yes | Kare-kare | 0.59 |
| Beef Kaldereta | 200 | low_confidence | yes | Beef Caldereta | 0.59 |
| Sisig | 200 | low_confidence | yes | Sisig | 0.59 |
| Dinuguan | 200 | low_confidence | yes | Dinuguan | 0.59 |

## Interpretation

- The live NVIDIA connection and application upload contract work.
- The conservative fallback keeps all unseen dishes out of automatic
  confirmation, which is safer than treating a guess as a verified meal.
- Four of five images produced a usable exact or near-exact dish name; one
  returned `unknown`.
- `Beef Caldereta` is a spelling variant of the expected `Beef Kaldereta` and
  should be normalized before catalog matching.
- This is not yet a production accuracy benchmark. It is a five-image smoke
  test; a proper evaluation needs held-out images across lighting, angle,
  serving size, background, and repeated runs per class.

## Artifact location

The source images remain outside the repository at
`C:/Users/HP/Desktop/jcg-dataset-work/filipino_food_100/raw/open_source/`.
