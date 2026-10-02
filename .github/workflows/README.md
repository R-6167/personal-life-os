# GitHub Actions

## EAS APK Build

Builds an Android **APK in the cloud** so you can install it on your phone.

**No Android Studio. No local SDK.**

### Before first run

1. Free Expo account + one terminal setup (see `mobile/README.md`)
2. Repo secret **`EXPO_TOKEN`** from https://expo.dev/settings/access-tokens
3. `projectId` present in `mobile/app.json` (written by `eas build:configure`)

### Run

**Actions → EAS APK Build → Run workflow** → profile **`preview`**

APK appears under your project on https://expo.dev (Builds). Open that link on your phone to download and install.
