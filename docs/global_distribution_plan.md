# Global Android distribution plan

Status: v1.0.5 is being prepared with branded packages, checksums and release metadata.
The user reported a failed physical Android download on 2026-09-07; the physical
Tecno/Chrome acceptance check is still open. The current remediation and release
goals are in [public_android_release_improvement_plan.md](public_android_release_improvement_plan.md).

## Verified starting state

- GitHub repository keikoocatalasan/jcg is public. Release `v1.0.1` is published from commit `902b6ad3fd145a262ab13007acc6d1f6a10034e5`.
- landing_page/index.html links to releases/latest/download/JCG-Fitness.apk and releases/latest. It also exposes a same-origin Render ARM64 mirror and resumable /download.html helper for the reported large-download stall. The mirror must be replaced and reverified with each release.
- Android application ID is com.jcg.fitness; release `1.0.1` uses version code 2, minimum Android API 26 (Android 8), and the JCG Fitness release certificate.
- v1.0.5 is the next release from the tested source. Universal and ABI APKs
  share global Android version code 4006 so the universal package can update
  previous ABI-offset installs.
- Render JCG workspace: Hobby, no payment card, 3/25 services; current month 4.22/750 free instance hours, 1 MB/5 GB bandwidth, 2/500 pipeline minutes. These limits are shared with the unrelated SBMS service.
- Vercel account: Hobby, last 30 days 12.1 MB/100 GB transfer and 1.7K/1M edge requests. Only SBMS is listed as a project. Do not deploy JCG into that unrelated project.
- Supabase dashboard currently requires MFA. Actual plan, remaining usage, and bucket limits have not been verified.
- Public landing URL: https://nutrismart-ai-sce8.onrender.com/ . Render deployment `dep-dafactn40ujc73adjofg` succeeded from commit `902b6ad3`.
- Public API URL: https://nutrismart-ai-backend.onrender.com/ . Render deployment `dep-dafahhtg1s2s73dnknrg` is live from commit `1271b4ce` and reports production readiness.

Release asset sizes and checksums are published in `SHA256SUMS.txt`; the
universal APK is 98,786,812 bytes (about 94.2 MiB), ARM64 is about 37.9 MiB,
ARMv7 is about 33.8 MiB, and x86_64 is about 41.1 MiB.

## Distribution architecture

Keep the existing JCG landing-page host after verifying its service and public URL. Serve APK binaries directly from public GitHub Release assets. The landing page links directly to the asset; neither Render nor Supabase proxies the download. Supabase continues to serve application data/authentication, and Render continues to serve the API.

GitHub documents no total release binary storage or delivery bandwidth cap, subject to individual asset limits and service policies. Supabase Free lists 50 MB maximum uploads and 1 GB file storage; its database/storage egress should be reserved for application use. Render Free services sleep after 15 idle minutes and share 750 hours monthly. Download availability and AI/API availability are separate constraints.

Sources:
- https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
- https://supabase.com/pricing
- https://render.com/docs/free
- https://vercel.com/docs/limits

## Ordered implementation

1. Finish service inspection: identify the JCG static landing-page service, root directory, deployed commit, public domain, and deployment settings. Inspect Supabase usage if authenticated access becomes available. Inspect actual AI provider availability/quota before describing online features as verified.
2. Audit production readiness: normal login and admin authorization, production HTTPS API, no QA identity/seed/bypass, correct scanner and chatbot behavior, no secrets in bundled assets. Resolve known log-editor placeholders and persistence defects before labeling the app production-ready.
3. Establish release signing: locate an existing production keystore first. If none exists, generate a dedicated local release keystore and ignored signing properties. Record its certificate fingerprint and backup location without exposing passwords. Remove debug-signing fallback from release builds. Previously debug-signed installs cannot accept a differently signed update; provide migration guidance without silently deleting user data.
4. Build an optimized signed release with a new version code. Produce
   `JCG-Fitness.apk` as the universal compatibility download and optional
   ARM64/ARMv7 variants for smaller downloads. Measure actual bytes, SHA-256,
   signing certificate, supported ABIs, and minimum Android version. Do not
   publish a debug/profile APK or the training dataset.
5. Verify clean installation and launch, normal auth, API connectivity, capture/upload/manual food confirmation, date-scoped log edits, and restart persistence. Test the actual release artifact; prior debug tests alone are insufficient.
6. [x] Create a published GitHub Release at a reviewed commit. `v1.0.4`
   contains the branded universal APK, three ABI-specific APKs, checksums,
   release metadata and release notes. New releases no longer publish the
   confusing `app-release.apk` alias.
7. [x] Keep the landing page pointed at `latest` for both download and release notes. Release version changes do not require a site edit. Keep download links usable without JavaScript or a GitHub login.
8. [x] Deploy the landing page to the verified JCG service, then test public HTTPS access, anonymous download redirects, checksum agreement, mobile layout, and install flow. Leave unrelated services unchanged.
9. Document rollback to the previous release and the update process: same application ID/signing key, monotonically increasing version code, and preserved local data. Record account quota headroom and avoid promising unlimited concurrent AI usage or universal regional availability.

## Update workflow

After the one-time GitHub Actions secrets are configured, each update follows this path:

1. Update `flutter_app/pubspec.yaml` with a higher semantic version and Android build number.
2. Run the tests and release build locally when possible.
3. Commit and push the change to `main`.
4. Create and push a matching tag, for example `v1.0.4`. Keep Android build
   numbers globally monotonic; do not reuse the old ABI-offset scheme.
5. Explicitly dispatch the Android release workflow on that tag (`gh workflow run android-release.yml --ref v1.0.4`). It builds a draft with branded APKs, `SHA256SUMS.txt` and `release.json`. Verify the candidate before publishing the draft. Do not run the local publisher for the same version.
6. The unchanged landing page immediately serves the new `JCG-Fitness.apk` through the `latest` redirect; deploy the synchronized ARM64 fallback when the source changes.
7. Verify the public download, checksum, release page, and clean install.

The signing key must remain the same for in-place Android updates. Store the keystore and its passwords in a secure backup. The workflow pins Flutter 3.44.2 for repeatable builds. Configure these GitHub Actions secrets once: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FASTAPI_BASE_URL`, and `GOOGLE_WEB_CLIENT_ID`.

The first tag workflow run correctly stopped at its signing-secret check because
those GitHub Actions secrets are not configured yet. The release was published
from the locally verified APKs. Until the secrets are added, repeat the same
local build/upload steps using `tools/publish_android_release.ps1`; once the
secrets are added, workflow dispatch builds the draft release. Both paths now
require `GOOGLE_WEB_CLIENT_ID`. Tag pushes alone do not publish a release.

## Completion evidence

- [x] Public landing URL and exact release/tag/commit identified.
- [x] Anonymous download succeeds and matches published SHA-256.
- [x] APK certificate is a production certificate; production login screen verified.
- [x] Release installation and in-place upgrade succeed on the Android emulator; physical-device verification remains a separate check.
- [x] Download page accurately states Android compatibility and latest-release behavior.
- [x] Service quota inspection is complete where authenticated, and remaining Supabase/GitHub Actions access gaps are clearly documented.
