# Tally
A open source local app for gym tracking, no third parties, no accounts, no bs.

- **~40 KB APK**, Android 7.0+ (API 24)
- No account, no internet permission, no tracking — all data stays on your phone
- Automatic backup to `Download/Tally` (survives reinstalling), plus manual export / import to move to a new phone

## Download
Get the latest APK from **[Releases](https://github.com/gemedos/Tally/releases/latest)**. Open it on your phone, allow installing from unknown sources when Android asks, and tap Install. Updates install over the old version and keep your data.

Releases are signed with one key; its SHA-256 fingerprint is in [`release-cert.sha256`](release-cert.sha256).

## Features
- **Home** — daily checks (default: "Took creatine today?", with streak), a big ▶ *Let's train* button, and progress charts: biggest gains over 4 weeks to all time, volume, top weight or total reps per exercise
- **Routines** — training days with any name, exercises with sets / reps / weight / rest, assigned to weekdays. **Supersets** by linking exercises. **Mini routines** (e.g. Abs) assigned to several days, added on top of that day's workout
- **Gym mode** — opens today's routine (switchable), ▶ an exercise, log each set with big −/+ steppers (kg or lb). Beat your best and you get a **NEW PR** celebration. Rest timer starts automatically with an alarm (works with the screen off). Superset rounds skip rest between exercises. Weights you lift become the routine's new weights
- **Settings** — workout history (view, edit, delete), backups, daily checks, home charts, kg/lb units (switching converts your saved weights), default rest time

## Build
No Gradle, just the Android SDK tools. Needs JDK 17+ and an Android SDK with
`platforms;android-34` and `build-tools;35.0.0`:

```sh
ANDROID_HOME=/path/to/android-sdk bash build.sh          # -> out/tally-debug.apk
```

Debug builds use the app id `io.github.gemedos.tally.debug`, so they install next to the real app
and never touch its data. Publishing a release: see [RELEASING.md](RELEASING.md).

## Layout
```
app/AndroidManifest.xml
app/assets/index.html             # the whole UI + logic (HTML/CSS/JS, data in localStorage)
app/src/io/github/gemedos/tally/  # MainActivity (WebView + file/alarm/backup bridge), RestAlarm
app/res/drawable/                 # icon
build.sh                          # debug / release builds, with release safety checks
release-cert.sha256               # public fingerprint of the release signing key
```
