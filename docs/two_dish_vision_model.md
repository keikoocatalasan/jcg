# Two-dish on-device vision model

The Flutter scanner includes a small TensorFlow Lite classifier for the
key-free demonstration path. It recognizes two labels:

- `chicken_adobo` → Chicken Adobo
- `sinigang` → Sinigang na Baboy

The model is a MobileNetV2 transfer-learning classifier trained on 34
Wikimedia Commons photographs. The generated training report and full source
manifest are bundled beside the model in `flutter_app/assets/models/`.

This is intentionally a two-dish prototype. A high score means the image looks
similar to one of the curated classes; it does not prove ingredients, serving
size, or nutrition. The UI keeps confidence visible and retains manual
correction. Authenticated, online users can still use the server-side OpenAI
vision path when the local model is uncertain.

## Bundled sample-image attribution

- **Chicken Adobo** — “Chicken adobo.jpg” by dbgg1979, licensed under
  [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/). Source:
  <https://commons.wikimedia.org/wiki/File:Chicken_adobo.jpg>
- **Fish Sinigang** — “Fish sinigang.jpg” by Copperhead02, licensed under
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Source:
  <https://commons.wikimedia.org/wiki/File:Fish_sinigang.jpg>

The training script is `tools/train_two_dish_model.py`. Training downloads are
kept outside the repository; only the compact TFLite artifact, labels, report,
manifest, and the two attributed samples are shipped.
