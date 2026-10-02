# Personal Life OS — Mobile (Expo)

Local-first React Native app (Expo SDK 51) with SQLite.

## One-time setup for APK builds (EAS)

CI cannot create Expo credentials for you. Do this **once** on your machine:

```bash
cd mobile
npm install
npm install -g eas-cli

# Log into the Expo account that should own the project
eas login

# Link the project (writes projectId into app.json)
eas build:configure

# First Android build — creates keystore + validates config
eas build --platform android --profile preview
```

Then:

1. Commit the updated `app.json` (it will contain `extra.eas.projectId`).
2. Create an access token at https://expo.dev/settings/access-tokens
3. In GitHub → **Settings → Secrets and variables → Actions**, add:
   - Name: `EXPO_TOKEN`
   - Value: the token from step 2
4. Run **Actions → EAS APK Build → Run workflow** (profile: `preview`).

The workflow only *triggers* the build. Download the APK from the [Expo dashboard](https://expo.dev) when it finishes.

### Build profiles (`eas.json`)

| Profile       | Output                         |
|---------------|--------------------------------|
| `preview`     | Internal **APK** (sideload)    |
| `development` | Dev client **APK**             |
| `production`  | **AAB** for Play Store         |

## Local development

```bash
cd mobile
npm install
npx expo start
```

Use Expo Go or a development build on device/emulator.
