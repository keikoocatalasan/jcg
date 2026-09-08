# Google Sign-In production setup

Status: required before publishing JCG Fitness v1.0.2. Do not copy a Google
client secret into Flutter, GitHub source, or the landing page.

## Current evidence

- Google Cloud project: `jcg-fitness`.
- Android package: `com.jcg.fitness`.
- JCG production signing-certificate SHA-1:
  `77:02:51:97:BB:BA:01:AE:81:DC:1D:3E:56:DC:5A:67:8F:C1:1E:51`.
- Google/email are enabled in Supabase Auth settings, but the current Google
  provider authorization endpoint reports `Unsupported provider: missing OAuth secret`.
- Google Cloud currently requires the project-owning account to enable two-step
  verification before OAuth clients can be inspected or changed.

## One-time Google Cloud configuration

1. Enable two-step verification for the Google account that owns `jcg-fitness`.
2. Open **Google Auth Platform → Branding** and complete the required app name,
   support email, developer contact and audience settings. Keep the app in test
   mode only while adding explicit test users; publish the audience before public
   release.
3. In **Google Auth Platform → Clients**, create or verify both OAuth clients:

   - **Web application**: this provides the public web client ID supplied to the
     Flutter app as `GOOGLE_WEB_CLIENT_ID` and the client secret supplied only to
     Supabase.
   - **Android**: use package `com.jcg.fitness` and the SHA-1 fingerprint above.

4. In the Web client, add the exact Supabase redirect URI:

   ```text
   https://<your-supabase-project-ref>.supabase.co/auth/v1/callback
   ```

   Obtain the project ref from the Supabase project URL; do not guess it.

## Supabase configuration

1. Open **Authentication → Providers → Google** for the same production
   Supabase project used by the Android `.env` file.
2. Enable Google and paste the Web client ID and client secret from Google Cloud.
3. Save, then verify the provider with the following public authorization
   request. It must redirect to Google instead of returning HTTP 400:

   ```text
   https://<your-supabase-project-ref>.supabase.co/auth/v1/authorize?provider=google
   ```

4. Enable manual identity linking in Supabase Auth if that option is shown.
   JCG uses native ID-token linking for a signed-in email/password account.

## Build and CI configuration

- Add the **Web client ID only** to `flutter_app/.env`:

  ```text
  GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
  ```

- Add the same value as the GitHub Actions secret `GOOGLE_WEB_CLIENT_ID`.
- Keep the Web client secret exclusively in Supabase’s Google provider settings.
- Rebuild every APK after adding the client ID; the app now refuses a production
  start when it is missing.

## Required acceptance test

Use a real test email/password account with saved logs:

1. Sign in with password and record the Supabase user ID.
2. In **Settings → Connect Google**, choose the same verified Google email.
3. Confirm the user ID and existing food/water/weight logs remain unchanged.
4. Sign out; then use **Continue with Google** and confirm the same account and
   logs return.
5. Confirm a different Google email is rejected without merging accounts.

For the full identity-linking behavior, follow the current
[Supabase identity-linking guide](https://supabase.com/docs/guides/auth/auth-identity-linking).
