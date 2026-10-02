# GitHub Actions

## Manual APK Build (`build-apk.yml`)

Same style as **Resonate**: GitHub builds an APK → you download the artifact → install on your phone.

**No Android Studio. No Expo Go required for the installable APK.**

### Run

1. **Actions → Manual APK Build → Run workflow**
2. Wait for the job to finish (several minutes)
3. Open the run → **Artifacts** → download `personal-life-os-debug-apk`
4. Unzip, copy `app-debug.apk` to your phone, install it

### What it does

1. Installs Node, Java 17, Android SDK
2. `npm install` in `mobile/`
3. `npx expo prebuild` (generates the `android/` folder in CI)
4. `./gradlew assembleDebug`
5. Uploads `app-debug.apk` as a GitHub Actions artifact

### Recent failures (fixed in this workflow)

| Failure | Cause | Fix |
|---------|--------|-----|
| Setup Android SDK | `setup-android@v3` still installs removed `tools` package | Use `@v4` |
| Setup Node.js | `cache: npm` + missing `mobile/package-lock.json` | Drop npm cache unless lockfile exists |
