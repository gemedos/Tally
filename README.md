# Tally
A open source local app for gym tracking, no third parties, no accounts, no bs.

- **~30 KB APK**, Android 7.0+ (API 24)
- No account, no internet permission, no tracking — all data stays on your phone
- Export / import a backup file to move to a new phone

## Download
Get the latest APK from **[Releases](https://github.com/gemedos/Tally/releases/latest)**. Open it on your phone, allow installing from unknown sources when Android asks, and tap Install. Updates install over the old version and keep your data.

## Features
- **Home** — daily checks (default: "Took creatine today?", with streak), a big *Let's train* button, and small progress charts (volume, top weight or total reps per exercise)
- **Routines** — training days with any name, exercises with sets / reps / weight / rest, assigned to weekdays. **Supersets** by linking exercises. **Mini routines** (e.g. Abs) assigned to several days, added on top of that day's workout
- **Gym mode** — opens today's routine (switchable), ▶ an exercise, log each set (kg or lb), rest timer starts automatically with an alarm (works with the screen off). Superset rounds skip rest between exercises. Weights you lift become the routine's new weights
- **Settings** — export/import backup, add/remove daily checks, add/remove home charts, kg/lb units (switching converts your saved weights), default rest time

## Build
No Gradle, just the Android SDK tools. Needs JDK 17+ and an Android SDK with
`platforms;android-34` and `build-tools;35.0.0`:

```sh
ANDROID_HOME=/path/to/android-sdk bash build.sh   # -> out/tally.apk
```

Without `KEYSTORE` set, it signs with a generated `debug.keystore`. For releases:
`KEYSTORE=release.jks KS_PASS=... KS_ALIAS=... bash build.sh`

## Layout
```
app/AndroidManifest.xml
app/assets/index.html        # the whole UI + logic (HTML/CSS/JS, data in localStorage)
app/src/io/github/gemedos/tally/  # MainActivity (WebView + file/alarm bridge), RestAlarm
app/res/drawable/            # icon
build.sh
```
