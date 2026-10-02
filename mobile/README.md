# Personal Life OS — Mobile

**Phone-first.** No Android Studio. No local emulator.

You develop on your computer, test on your phone, and build installable APKs on GitHub via Expo (EAS).

---

## Daily development (phone + Expo Go)

1. Install **[Expo Go](https://play.google.com/store/apps/details?id=host.exp.exponent)** on your Android phone.
2. On your computer:

```bash
cd mobile
npm install
npm start
```

3. Scan the QR code with Expo Go (same Wi‑Fi as the computer).

If the phone and computer are on different networks, use tunnel mode:

```bash
npm run start:tunnel
```

Then scan the QR code. Changes reload on the phone automatically.

---

## Installable APK (no Android Studio)

Use **EAS Build** on GitHub when you want a real `.apk` you can install without Expo Go.

### One-time setup (browser + terminal, ~10 minutes)

You need a free [Expo](https://expo.dev) account. You do **not** need Android Studio.

```bash
cd mobile
npm install
npm install -g eas-cli

eas login
eas build:configure
```

Then trigger the **first** cloud build (still no Android Studio):

```bash
eas build --platform android --profile preview
```

When it finishes, Expo gives you a link to download the APK onto your phone.

Commit whatever `eas build:configure` changed (usually `app.json` gains `extra.eas.projectId`).

### GitHub secret (one-time)

1. Create a token: https://expo.dev/settings/access-tokens  
2. GitHub repo → **Settings → Secrets and variables → Actions**  
3. New secret: name `EXPO_TOKEN`, value = that token

### Build APKs from GitHub

1. **Actions → EAS APK Build → Run workflow**  
2. Profile: **`preview`** (produces an APK)  
3. Wait a few minutes, then open https://expo.dev → your project → **Builds**  
4. Download the APK on your phone and install it (allow “Install from unknown sources” if asked)

| Profile       | What you get                         |
|---------------|--------------------------------------|
| `preview`     | **APK** for sideload testing         |
| `development` | Dev-client APK                       |
| `production`  | AAB for Play Store (later)           |

---

## What you never need

- Android Studio  
- Local Android SDK / Gradle  
- An emulator  
- A Mac (for Android builds)

Everything native is compiled in Expo’s cloud. Your machine only runs Metro (JS) or triggers the cloud build.
