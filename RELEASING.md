# Releasing Tally

Tally keeps all data inside the app. Android deletes it if the app is **uninstalled**, and people
uninstall when an update refuses to install. An update is refused when it is:

- signed with a **different key** than the installed app, or
- a **lower versionCode** than the installed app (a downgrade), or
- a **different app id** (`io.github.gemedos.tally`). Never change it.

`bash build.sh release` checks the first two and refuses to build otherwise.

## Checklist

1. Raise `android:versionCode` (+1) and `android:versionName` in `app/AndroidManifest.xml`.
2. Build with the release key (it is never in this repo):
   ```sh
   KEYSTORE=/path/to/tally-release.jks KS_ALIAS=tally KS_PASS='...' \
     ANDROID_HOME=/path/to/sdk bash build.sh release      # -> out/tally-<version>.apk
   ```
   It must print `signing key verified against release-cert.sha256`.
3. Install it **over** the previous release on a phone that has data, and check the data is still there.
4. Create a GitHub release `v<version>` and attach `out/tally-<version>.apk`.

Never publish `out/tally-debug.apk`. It has a different app id (`io.github.gemedos.tally.debug`) so it
installs next to the real app for testing, never over it.

## The release key

- Fingerprint (SHA-256): see `release-cert.sha256`. It is public; anyone can check an APK with
  `apksigner verify --print-certs tally-x.y.apk`.
- The `.jks` file and its password must be **backed up** outside this computer. If they are lost, no
  future update can install over existing installs.

## Safety net inside the app

Even if something goes wrong, Tally writes an automatic backup to `Download/Tally/` after every
workout or change (and once a day). That folder survives uninstalling. A fresh install with no data
shows **Restore a backup** on the home screen.
