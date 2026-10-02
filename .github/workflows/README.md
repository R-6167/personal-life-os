# GitHub Actions

## EAS APK Build (`eas-build.yml`)

Manual workflow that triggers an Android build on Expo Application Services.

**Required before first successful run:**

1. `EXPO_TOKEN` repository secret (https://expo.dev/settings/access-tokens)
2. EAS `projectId` in `mobile/app.json` — run from `./mobile`:
   ```bash
   eas login
   eas build:configure
   eas build --platform android --profile preview
   ```
   Commit the updated `app.json`.

Then: **Actions → EAS APK Build → Run workflow** → choose `preview` for an APK.

The job exits after queueing the build (`--no-wait`). Artifacts live on expo.dev, not as GitHub artifacts.
