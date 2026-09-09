# JCG Fitness public Android release improvement plan

Prepared: 2026-09-07. Status: implementation in progress; v1.0.4 is now the
published latest release and physical-device acceptance remains open.
The v1.0.4 CI run 34372781647 passed tests, analysis, signed universal/ABI
builds, branded packaging and fallback validation. It includes the scanner
provider-lifecycle fix and uses global Android build code 4005.
Implementation progress: CI run 34330561784 passed the full Flutter suite,
signed universal/ABI builds, branded packaging, fallback metadata validation and
release publication. The v1.0.2 assets are `JCG-Fitness.apk` (99,016,248
bytes), `JCG-Fitness-arm64-v8a.apk` (39,807,180 bytes),
`JCG-Fitness-armeabi-v7a.apk` (35,437,900 bytes),
`JCG-Fitness-x86_64.apk` (43,276,914 bytes), `release.json` and
`SHA256SUMS.txt`. The legacy `app-release.apk` alias is no longer published for
new releases, so public downloads use the JCG Fitness name consistently.
The landing ARM64 fallback has been synchronized to the exact v1.0.4 release
asset and is deployed through Render deployment dep-dago6op42hec73d6d73g.
Settings now includes an explicit update check using the installed package build
number and official release metadata, with Later/download/release-notes actions
and recoverable errors. Five release metadata tests and two update-banner tests
pass; the CI Flutter suite passes. The public metadata endpoint is verified and
the emulator upgrade path has been exercised.
The three update-related Dart files pass static analysis. The landing page has
local light-theme and content changes; it loads in the in-app browser at
127.0.0.1:8765. Screenshot replacement, viewport/contrast verification and
publication were subsequently completed on the public page. No physical Android
device was attached when checked; the available jcg_emu emulator is being used
for further verification.
Local QA captures from the seeded current app are now available as clean previews:
dashboard, dated meal/water/weight log and community feed. The local-only QA
banner and Android system bars were cropped; preview assets are not production
data. The landing gallery references these current screens. AI-scanner and
chatbot preview captures remain unverified because the emulator went offline
when opening Add Meal.
The Android 15 emulator upgraded from the exact public v1.0.1 ARM64 package to
v1.0.2 without changing first-install time. Production configuration now
includes GOOGLE_WEB_CLIENT_ID. Supabase Google provider settings, the release
SHA-1, and manual identity linking were saved. The native same-email test linked
Google to the existing email account and preserved the original user ID; the
Supabase user showed both Email and Google providers with no duplicate account.
The public Supabase authorization endpoint now redirects to Google. Required
GitHub Actions secrets are present. Full Flutter regression run: 212 pass, one
skip on desktop because native TFLite inference requires a mobile runner.
User clarified the failed device flow: Tecno Camon 20 Pro 5G, Chrome, download
stalls at the end before installation. A full ARM64 v1.0.1 GET from this laptop
returned 200 with 39,741,584 bytes in 9.7 seconds; SHA-256 matches the published
checksum. A 1024-byte Range request returned 206 and 1024 bytes. This verifies
server delivery and partial support, not the cause of the phone-specific stall.
The public landing page now offers a stable branded smaller alternative.
Because the branded GitHub ARM64 GET also timed out at 20,086,651 of 39,741,584
bytes on this laptop, the landing site includes a same-origin Render mirror of
the verified v1.0.1 ARM64 APK at /downloads/JCG-Fitness-arm64-v8a.apk. The
landing site also exposes /download.html, which requests the same bytes in 4 MiB
HTTP ranges with three attempts per range, validates Content-Range/length,
assembles a named APK Blob and retains a direct fallback. This is intended to
address a single large-request stall; a physical-device test is still required.
tools/sync_android_fallback.ps1 refreshes the mirror from a validated ARM64
build; both the local publisher and GitHub Actions reject a release whose
fallback hash differs from its ARM64 APK.
The public in-app browser completed this helper at 39,741,584/39,741,584 bytes
and displayed “Download complete.” The physical Tecno/Chrome path remains the
only unresolved download acceptance check.
The exact public branded ARM64 artifact was hash-matched to release.json, then
clean-installed on the Android 15 emulator as JCG Fitness v1.0.1/versionCode
2002. It reached the login screen with no app crash markers.
An attempted v1.0.1 alias upload was stopped after detecting that the local
universal artifact had become v1.0.2 while the split artifacts were still v1.0.1.
The partial branded asset and incomplete metadata were removed from the public
release. A complete matching branded v1.0.1 alias set and release.json are now
public; anonymous HEAD responses return 200 with attachment names
JCG-Fitness.apk and JCG-Fitness-arm64-v8a.apk. The landing page now points to
those stable branded latest URLs.
The light landing page was pushed in commit e079cb60 and Render deployment
dep-dafoj9n40ujc73c77ikg succeeded. Public browser inspection shows the light
layout, branded links and three current preview images; all four image elements
load at 1080px natural width. The current preview set is 638,482 bytes after
removing seven obsolete splash/loading files. Production backend checks returned
health=ok and readiness=ready/environment=production; /version reports scanner-v2
and NVIDIA Llama vision for scan/chat.
Dashboard automatic update discovery now shows a dismissible banner for a newer
build, with a once-per-session fetch and silent offline fallback. Seven focused
update tests pass. The emulator upgrade path is verified; physical-device
installation and upgrade remain pending.
The checker compares semantic app versions so ABI split version-code offsets do
not hide a newer release from ARM64/ARMv7 users; this regression is covered by
the focused tests.
An unpublished signed candidate build completed for explicit version 1.0.2,
build 3, using current production inputs. GOOGLE_WEB_CLIENT_ID is still absent:
this candidate is for install/upgrade verification and must not be published as
Google-ready. The emulator's observed unresponsive
dialog was Android System UI, not JCG; app process remains present and activity
manager reported no app ANR since boot. The candidate completed and installed
over v1.0.1: version code 2 -> 3 while firstInstallTime remained unchanged;
the app reached its login screen. This proves an emulator upgrade path, not
physical-device or production account persistence. All four candidate APKs pass
metadata and production-certificate checks; the candidate universal APK
installed over v1.0.1 on Android 15 and reached the login screen.
Google Cloud account access was corrected by the user to keikoocatalasan@gmail.com.
The existing jcg-fitness project is visible, but its OAuth client page redirects
to an access-blocked screen requiring account 2-step verification. User action
requested in the in-app browser; client settings have not been changed.
The required client, Supabase provider, CI and account-preservation test steps
are documented in google_signin_production_setup.md.
Two-step verification was subsequently completed and Google Cloud clients are
now accessible. The Web client ID was added to the ignored local production
.env and a newly built ARM64 v1.0.2/versionCode 2003 package upgraded the exact
public ARM64 v1.0.1/versionCode 2002 install without changing firstInstallTime.
The candidate reached the login screen with no crash markers. Before OAuth
configuration, Google Cloud used the wrong SHA-1 and Supabase lacked the OAuth
secret; those conditions are resolved below.
With the Web Client ID present, the v1.0.2 ARM64 candidate opened Google Play
Services’ account picker and displayed “Choose an account to continue to JCG
Fitness.” Cancelling returned cleanly to the app with “Google sign-in was
cancelled.” No Google account was selected and no production identity was
created or linked. The Android-client SHA-1 mismatch remains to be corrected
before treating this as a successful sign-in test.
OAuth settings were subsequently approved and saved: the Android client now
uses the JCG release SHA-1, Supabase Google has the existing Web Client ID and
a replacement secret, and Supabase manual identity linking is enabled. The
public Supabase Google authorization endpoint now returns HTTP 302 to
accounts.google.com. The secret remains in provider configuration only and is
not stored in this repository. A real same-email account test is still required.
The public Web Client ID is also stored as the GitHub Actions
GOOGLE_WEB_CLIENT_ID secret. Android signing and production API secrets remain
absent from Actions, so automated release publishing is not yet ready.
This supersedes the completion assumptions in global_distribution_plan.md.

## Objective and scope

Make the public download understandable and reliable, deliver signed JCG Fitness
packages tested on Android 10 and newer, preserve production accounts and data,
support Google access to existing email accounts, and replace the landing page
with a light presentation of the actual current app. Make subsequent publishing
repeatable and give installed users an explicit way to discover updates.

Free means no charge to download/use within available service quotas. It does
not mean unlimited hosting/AI capacity or guaranteed installation on every
managed device, region, future Android version, or device configuration.

## Evidence from this planning audit

- The user reports a failed download on a physical Android phone. Root cause is
  not established; desktop accessibility and emulator installation do not resolve it.
- GitHub latest is public v1.0.4. The release uses branded assets
  `JCG-Fitness.apk`, `JCG-Fitness-arm64-v8a.apk`,
  `JCG-Fitness-armeabi-v7a.apk` and `JCG-Fitness-x86_64.apk`, with
  `release.json` and `SHA256SUMS.txt`.
- The Android label is already JCG Fitness and package ID is com.jcg.fitness.
  minSdk is 26; targetSdk is 35; release builds require production signing.
- The landing page now uses stable branded APK names and current local QA
  dashboard/community/log previews. Runtime production behavior still needs
  its separate acceptance tests.
- Google login uses native GoogleSignIn followed by Supabase signInWithIdToken;
  Settings also supports linking Google to the current verified email account.
- Supabase Google provider settings, the release SHA-1, manual identity linking,
  and the public Google redirect have been verified. The emulator same-email
  test preserved the existing user ID and added Google without a duplicate.
- CI uses explicit dispatch, pinned tool versions and fail-fast validation. The
  v1.0.2 workflow passed and published the signed release.
- GitHub Actions secrets for signing, production Supabase/API inputs and the
  Google web client ID are configured; secret values remain outside the repo.

## Goal 1 — diagnose and repair phone download (P0)

1. Reproduce separately: tapping the website button, downloading bytes, opening
   the file, installing it, and launching. Record which stage fails and the exact
   error, Android version, browser, connection, and existing installed version.
   Collect device details when available without blocking independent work.
2. Test unsigned-in Chrome and Samsung Internet, plus an in-app browser handoff
   to an external browser. Test Wi-Fi and mobile data where devices are available.
3. Inspect the full redirect chain, final APK MIME type, attachment filename,
   bytes/checksum, partial-download handling, caching, and interrupted downloads.
   Never store GitHub's expiring signed CDN URL in the website.
4. Provide a normal HTTPS anchor to the APK, release-page fallback, and concise
   troubleshooting for download failure versus installer failure. Do not rely
   on cross-origin HTML download attributes to rename the file.
5. If GitHub delivery itself is the proven failure, evaluate an independent mirror
   against current free storage, per-object, bandwidth, billing, and availability
   limits. Publish only identical verified bytes. A second GitHub link is not an
   independent network fallback. Do not add an ad/interstitial host by default.
6. Explain Android's per-source install permission. Diagnose signature mismatch,
   insufficient storage, corrupt download, OS incompatibility, and managed-device
   policy individually. Do not tell users to disable protection or uninstall as
   a generic fix; preserve existing data.

Acceptance: a physical Android browser downloads the complete branded APK and
the Android installer accepts it; record evidence independently of ADB tests.
If no physical device is available, leave this acceptance item pending.

## Goal 2 — branded complete Android packages (P0)

- Primary asset: JCG-Fitness.apk (universal, stable name across releases).
- Optional assets: JCG-Fitness-arm64-v8a.apk, JCG-Fitness-armeabi-v7a.apk,
  JCG-Fitness-x86_64.apk. Each must be independently installable, not a split
  package requiring a separate installer. Universal is the safe default when
  architecture is unknown; label smaller alternatives clearly.
- Preserve com.jcg.fitness, launcher identity, and the current production signing
  key. Increment version/build number. Older v1.0.1 generic links remain in that
  historical release, while new releases use branded asset names only.
- Android 10+ is the supported test target. Retain minSdk 26 unless a dependency
  requires otherwise; raising it alone does not improve compatibility. Advertise
  the tested baseline. Audit native libraries including TFLite for ABI support
  and 16 KB page-size compatibility on applicable newer devices.
- Bundle necessary Flutter/native runtime and essential local assets. Training
  datasets and server credentials do not belong in the APK. State which features
  require internet and which optional models require additional downloads.
- Publish SHA256SUMS.txt, readable release notes, exact file sizes, build/version,
  and a machine-readable release.json with URLs, checksums, min Android version,
  versionCode, release date, and supported API contract version.

Acceptance: verify signatures, manifests and checksums; clean install and upgrade
from v1.0.1. Validate Android 10, 11, 12, 13, 14, 15, 16 where available; include
ARM64 physical hardware, an appropriate 32-bit device/emulator, low-memory
conditions, and newer page-size configurations. Publish tested coverage honestly.

## Goal 3 — production database and backend connectivity (P0)

1. Audit local and CI build inputs together: production Supabase URL/public key,
   HTTPS API URL, Google web client ID, and APP_ENV=production. Reject missing
   inputs, localhost addresses, production QA bypass, and bundled private secrets.
2. Verify the backend and app target the same intended Supabase project. Health
   responses are preliminary checks; test authenticated calls and persisted data.
3. On the exact candidate APK create a test account, complete onboarding, save
   food/water/weight on a selected date, edit each, restart and sign in again.
   Verify server records and a second session show the same values without duplicates.
4. Verify profile/community reads and writes, image upload, recognition and chat
   against live services. Check user ownership and admin restrictions with a
   second account. Do not change unrelated production records.
5. Test slow startup after Render idle, timeouts, lost connectivity, retry and
   reconnection. Use bounded retries and visible recoverable states. Confirm any
   offline-sync claims through conflict/duplicate tests before advertising them.

Acceptance: account and data persistence work from the downloaded release without
the development laptop; errors recover without hanging or losing edits.

## Goal 4 — Google login and existing email accounts (P0)

Interpretation: a person who registered using email/password can use Google for
that same verified email and reach the same account, not an empty duplicate.
Do not infer that new Google users should be banned from registering.

1. Verify Google provider enablement, consent/audience publication status, web
   client ID, Android OAuth client package and release certificate SHA-1 (and
   SHA-256 wherever required), token audiences and callback allowlist. Test an
   account outside the OAuth project's developer/tester list.
2. Pass GOOGLE_WEB_CLIENT_ID consistently in both universal and ABI builds.
   Resolve missing configuration before publishing. Google client secrets remain
   server-side; the web client ID itself is public configuration.
3. Use Supabase's supported identity linking, keeping auth user ID/app_user ID and
   all dependent records. Never merge records merely because a client sends an email.
4. Test provider-managed automatic linking for the same verified email. Add a
   real authenticated Settings > Connected accounts > Connect Google flow for
   explicit linking when needed; check the installed SDK supports the selected API.
5. Handle unverified email, mismatched Google email, identity already attached to
   another user, cancellation, no Play Services, revoked access and expired sessions.
   Do not silently merge different accounts. Offer normal email login; evaluate
   browser OAuth fallback with verified deep-link return for non-GMS devices.
6. Ensure profile provisioning is idempotent and Google login respects disabled
   accounts. Display Google linked status. Keep password access working where set.

Acceptance: an email-created account with saved logs signs in through Google,
retains the same IDs/data, and can still use its password. New Google users get
exactly one profile. Failed/cancelled linking leaves the original account intact.

## Goal 5 — light landing page and current previews (P1)

Files: landing_page/index.html, style.css and assets/.

- Use white/off-white surfaces, dark readable text and existing brand accent
  colors. Consistent spacing/type, restrained borders/shadows, visible keyboard
  focus, 44px touch targets, WCAG AA contrast, reduced-motion support.
- Hero: JCG Fitness, a short benefit-led description focused on Filipino meals
  and daily tracking, actual current dashboard screenshot, Download JCG Fitness
  button and See the app link. Show Android baseline, version, measured size,
  free download and online-feature requirements beside the CTA.
- Follow with useful preview cards: dashboard, meal recognition with editable
  portion/rice, dated food/water/weight tracking, community, and chatbot. Capture
  the release candidate using a consented demo account with realistic sample data.
  Use actual screens, not generated UI or old loading/splash screenshots. Keep
  app screenshots faithful even though the surrounding website is light.
- Save optimized WebP plus appropriate fallback, fixed dimensions and alt text;
  load the hero promptly and defer lower images. Record screenshot build/version
  in an asset manifest so future releases flag stale previews.
- Add three clear install steps, troubleshooting, smaller-package options,
  privacy/support/contact information that is actually available, and FAQ about
  Google/email accounts, internet needs, updates and Android compatibility.
- Replace unverified precision/instant/offline claims with confirmed behavior.
  Explain nutrition values as estimates the user can correct. No fabricated
  testimonials, user counts, ratings or accuracy statistics.
- Include a mobile CTA that does not cover content and a desktop QR pointing to
  the landing page. Downloads remain usable without JavaScript.
- Measure page view -> download click -> first launch -> onboarding completion
  only with minimal, privacy-appropriate analytics. A click is not an install;
  do not claim attribution that has not been implemented. Establish a baseline
  before setting conversion improvement targets.

Acceptance: review 360/390/412/768/1440px layouts, 200% text sizing, keyboard and
screen-reader basics, broken-image fallback, every CTA, slow mobile loading and
current screenshot fidelity. Target LCP <=2.5s, CLS <=0.1 in controlled mobile
checks and initial page transfer <=1.5 MB where image quality permits.

## Goal 6 — free public access and realistic operating limits (P1)

Keep GitHub Releases for APKs, Render for the existing landing/API, and Supabase
for authentication/data unless the download investigation proves a change needed.
Before publishing record actual plan/usage/reset dates for release hosting, CI
minutes/artifacts, Render hours/egress, Supabase storage/egress/active users/email
limits and AI quotas. Old dashboard counts are historical, not current capacity.

Configure bounded AI requests and useful quota/cold-start errors. No paid upgrade
or card-required service is implicit in this plan. Explain operational limits
without charging visitors. Verify Android developer verification/package registration
requirements for the intended regions at release time; free limited distribution
is not equivalent to unrestricted global availability. Website sideloading cannot
override Android or organization installation policies.

Acceptance: unsigned-in public download succeeds; installation instructions and
availability statements match observed behavior; service limits and any remaining
developer verification/account prerequisites are documented.

## Goal 7 — repeatable releases and installed-app updates (P1)

1. Make CI the primary release publisher after required secrets are configured;
   retain the local script as an explicit fallback without racing the tag workflow.
2. Fail immediately on every build/test/sign/upload error; build in a fresh output
   directory, validate source revision/version and production inputs, and prevent
   stale APK upload. Keep credentials out of logs and secure a signing-key backup.
3. Build/test -> sign -> stage draft assets -> verify -> publish -> update landing
   release metadata. Ensure latest URLs only advertise complete tested releases.
4. Add Settings > App version > Check for updates and a nonblocking launch check
   against static release metadata. Compare versionCode, show release notes/size,
   allow Later, handle offline gracefully, and open the official branded download.
   No silently installing APKs. Android still asks the user to approve installation.
5. Preserve the same package/signature and increase build number. Test upgrading
   over v1.0.1 without uninstalling: sessions, logs and pending local data survive.
6. Backend-only fixes can deploy separately with compatible contracts. Bundled
   Flutter/native UI changes need a newly installed APK. A latest website link
   does not update apps already installed on phones.
7. Keep the previous stable assets. Roll back bad server/site deployments where
   compatible; fix installed Android regressions with a higher-version recovery
   build because lower version codes normally cannot replace newer installs.

Acceptance: rehearse a second version from commit to release and perform an
in-place update from the previous public APK. Verify latest metadata, correct
filename, preserved data and recovery behavior. The v1.0.2 CI run and emulator
upgrade pass these checks; the physical-device download/install check remains.
Document the short maintainer runbook.

## Execution sequence and completion record

1. Download diagnosis and production/auth configuration audit.
2. Fix download packaging, connectivity and identity linking.
3. Build a candidate and exercise functional/device tests.
4. Capture that candidate; implement and check the light landing page.
5. Harden publishing, metadata and update discovery; rehearse upgrade.
6. Publish verified release, deploy landing and verify the public journey again.

For every acceptance item record commit, artifact hash/version, environment,
device/browser/OS, expected and actual result, and evidence path. Mark pass,
fail or not tested. Emulators cannot prove physical camera or browser behavior.

Current completion record:

- [x] v1.0.4 signed release published with branded packages, checksums and
  release metadata; CI run 34372781647 passed all release gates.
- [x] Local QA debug build verified the scanner fix: no provider-build
  exception on scanner entry, camera permission prompt, initialized preview,
  live analysis toggle with a confidence hint, and shutter capture to preview.
- [x] Local QA seeded flows verified meal quantity, water amount and weight
  editing with updated local rows and pending sync records; the AI sample image
  flow reached prediction results and portion confirmation.
- [x] v1.0.3 signed release published with branded packages, checksums and
  release metadata; CI run 34337170081 passed tests, analysis, builds and
  fallback validation.
- [x] Universal and ABI APKs now share global Android version code 4004. The
  exact published v1.0.3 universal APK installed over the existing v1.0.2 ABI
  installation on the Android 15 emulator without changing first-install time.
- [x] Android Chrome on the emulator rendered the public landing page, showed
  the standard unknown-app safety prompt with the branded `JCG-Fitness.apk`
  filename, completed the 94.43 MiB download, and reached the installer.
  The installer correctly required Chrome's per-source permission before
  offering the update.
- [x] v1.0.2 signed release published with branded packages, checksums and
  release metadata; CI run 34330561784 passed.
- [x] The exact published universal APK installed on the Android 15 emulator
  as `com.jcg.fitness` version 1.0.2/build 2003 and reached the live Admin
  Dashboard with production KPI data. No JCG fatal-exception or app-ANR marker
  was observed; Android System UI briefly reported its own ANR during emulator
  startup and recovered.
- [x] Google OAuth provider, release SHA-1, web client, manual linking and
  GitHub Actions production secrets configured; same-email identity preserved
  in the Android emulator test.
- [x] Landing page light theme, current previews, privacy/terms pages and
  resumable download helper are deployed in Render deployment
  dep-daghuqp42hec73cea6ig.
- [x] The Render ARM64 mirror now returns the exact published v1.0.3 asset:
  39,807,180 bytes with the release SHA-256.
- [x] v1.0.2 ARM64 fallback copied from the exact published release asset.
- [x] Backend health/readiness and production API metadata verified.
- [ ] Camera capture/live-preview, upload recognition and date-scoped edit
  persistence still require a signed-in user flow on a usable mobile runner;
  the current emulator session is an admin dashboard session.
- [ ] Physical Tecno Camon 20 Pro 5G + Chrome full download, installer and
  camera/data acceptance; this still requires the user’s phone/network.

## References checked for planning

- https://supabase.com/docs/guides/auth/auth-identity-linking
- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://developer.android.com/studio/publish
- https://developer.android.com/developer-verification/guides/faq
- https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- https://render.com/docs/free

Recheck live platform settings, quotas and relevant SDK documentation during implementation.
