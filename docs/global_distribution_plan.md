# Global Android distribution plan

Status: release preparation; the site is configured for automatic latest-release updates, and the first production release is pending publication.

## Verified starting state

- GitHub repository keikoocatalasan/jcg is public. The authenticated release listing returned no releases.
- landing_page/index.html links to releases/latest/download/app-release.apk and releases/latest. Any newly published GitHub release will automatically become the download shown by the site.
- Android application ID is com.jcg.fitness; minimum Android API is 26 (Android 8). Release builds currently use debug signing and must be corrected.
- The worktree contains unpublished application changes from local QA. Review these for production behavior before tagging a release.
- Render JCG workspace: Hobby, no payment card, 3/25 services; current month 4.22/750 free instance hours, 1 MB/5 GB bandwidth, 2/500 pipeline minutes. These limits are shared with the unrelated SBMS service.
- Vercel account: Hobby, last 30 days 12.1 MB/100 GB transfer and 1.7K/1M edge requests. Only SBMS is listed as a project. Do not deploy JCG into that unrelated project.
- Supabase dashboard currently requires MFA. Actual plan, remaining usage, and bucket limits have not been verified.

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
4. Build an optimized signed release with a new version code. Produce app-release.apk as the universal compatibility download and optional ARM64/ARMv7 variants for smaller downloads. Measure actual bytes, SHA-256, signing certificate, supported ABIs, and minimum Android version. Do not publish a debug/profile APK or the training dataset.
5. Verify clean installation and launch, normal auth, API connectivity, capture/upload/manual food confirmation, date-scoped log edits, and restart persistence. Test the actual release artifact; prior debug tests alone are insufficient.
6. Create a published GitHub Release at a reviewed commit. Upload APK(s), checksums, and concise release notes. Check asset names and sizes. Keep a stable app-release.apk asset name for the existing latest/download URL.
7. Keep the landing page pointed at `latest` for both download and release notes. Only edit it when product copy or compatibility changes; release version changes do not require a site edit. Keep download links usable without JavaScript or a GitHub login.
8. Deploy the landing page to the verified JCG service, then test public HTTPS access, anonymous download redirects, checksum agreement, mobile layout, and install flow. Leave unrelated services unchanged.
9. Document rollback to the previous release and the update process: same application ID/signing key, monotonically increasing version code, and preserved local data. Record account quota headroom and avoid promising unlimited concurrent AI usage or universal regional availability.

## Update workflow

After the one-time GitHub Actions secrets are configured, each update follows this path:

1. Update `flutter_app/pubspec.yaml` with a higher semantic version and Android build number.
2. Run the tests and release build locally when possible.
3. Commit and push the change to `main`.
4. Create and push a matching tag, for example `v1.0.2`.
5. The Android release workflow builds the universal and ABI-specific APKs, signs them with the same key, creates `SHA256SUMS.txt`, and publishes the GitHub Release.
6. The unchanged landing page immediately serves the new `app-release.apk` through the `latest` redirect.
7. Verify the public download, checksum, release page, and clean install.

The signing key must remain the same for in-place Android updates. Store the keystore and its passwords in a secure backup. The workflow pins Flutter 3.44.2 for repeatable builds. Configure these GitHub Actions secrets once: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `FASTAPI_BASE_URL`.

## Completion evidence

- Public landing URL and exact release/tag/commit identified.
- Anonymous download succeeds and matches published SHA-256.
- APK certificate is a production certificate; production environment and auth verified.
- Release installation succeeds on a supported test device/emulator; physical-device gaps explicitly recorded.
- Download page accurately states size, version, Android compatibility, and online feature limits.
- Service quota inspection is complete or remaining access gaps are clearly documented.
