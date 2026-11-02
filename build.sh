#!/usr/bin/env bash
# Builds Tally without Gradle, using only the Android SDK tools.
# Needs: JDK 17+, Android SDK with "platforms;android-34" and "build-tools;35.0.0".
#
#   bash build.sh            debug build  -> out/tally-debug.apk
#                            (app id io.github.gemedos.tally.debug, installs NEXT TO the real app, never over it)
#   bash build.sh release    release build -> out/tally-<version>.apk
#                            needs KEYSTORE, KS_PASS, KS_ALIAS. Refuses to build if:
#                            - the key's fingerprint differs from release-cert.sha256 (phones would reject the
#                              update, and users would have to uninstall = lose their data)
#                            - versionCode is lower than the last release built with that key (downgrade)
#
# See RELEASING.md before publishing.
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-debug}"
case "$MODE" in debug|release) ;; *) echo "usage: bash build.sh [debug|release]"; exit 1;; esac

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$SDK" ] || { echo "Set ANDROID_HOME to your Android SDK path"; exit 1; }
BT="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-34/android.jar"
EXE=""; BAT=""
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) EXE=".exe"; BAT=".bat";; esac
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"

VCODE=$(sed -n 's/.*android:versionCode="\([0-9]*\)".*/\1/p' app/AndroidManifest.xml)
VNAME=$(sed -n 's/.*android:versionName="\([^"]*\)".*/\1/p' app/AndroidManifest.xml)

if [ "$MODE" = release ]; then
  : "${KEYSTORE:?release builds need KEYSTORE (your release .jks)}"
  : "${KS_PASS:?release builds need KS_PASS}"
  : "${KS_ALIAS:?release builds need KS_ALIAS}"
  [ -f "$KEYSTORE" ] || { echo "Keystore not found: $KEYSTORE"; exit 1; }
  LAST_FILE="$(dirname "$KEYSTORE")/last-versioncode"
  LAST=$(cat "$LAST_FILE" 2>/dev/null || echo 0)
  if [ "$VCODE" -lt "$LAST" ]; then
    echo "REFUSING: versionCode $VCODE is lower than the last release ($LAST). Phones block downgrades,"
    echo "so users would have to uninstall and lose their data. Raise android:versionCode in app/AndroidManifest.xml."
    exit 1
  fi
fi

rm -rf out && mkdir -p out/gen out/classes out/dex

echo "> resources ($MODE, version $VNAME / code $VCODE)"
"$BT/aapt2$EXE" compile --dir app/res -o out/res.zip
MANIFEST=app/AndroidManifest.xml; EXTRA=()
if [ "$MODE" = debug ]; then
  sed 's/android:label="Tally"/android:label="Tally (debug)"/' app/AndroidManifest.xml > out/AndroidManifest.xml
  MANIFEST=out/AndroidManifest.xml; EXTRA=(--rename-manifest-package io.github.gemedos.tally.debug)
fi
"$BT/aapt2$EXE" link -o out/base.apk -I "$JAR" --manifest "$MANIFEST" ${EXTRA[@]+"${EXTRA[@]}"} \
  -A app/assets --java out/gen out/res.zip

echo "> java"
javac -nowarn -Xlint:-options --release 8 -classpath "$JAR" -d out/classes \
  $(find app/src out/gen -name '*.java') 2>&1 | grep -v '^warning\|^1 warning' || true
[ -n "$(find out/classes -name '*.class')" ] || { echo "javac failed"; exit 1; }

echo "> dex"
jar cf out/classes.jar -C out/classes .
"$BT/d8$BAT" --release --min-api 24 --lib "$JAR" --output out/dex out/classes.jar

echo "> package"
cp out/base.apk out/unsigned.apk
(cd out/dex && "$BT/aapt$EXE" add -k ../unsigned.apk classes.dex >/dev/null)
"$BT/zipalign$EXE" -f -p 4 out/unsigned.apk out/aligned.apk

if [ "$MODE" = debug ]; then
  KEYSTORE=debug.keystore; KS_PASS=android; KS_ALIAS=tally; OUT=out/tally-debug.apk
  [ -f "$KEYSTORE" ] || keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -alias "$KS_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Tally debug" >/dev/null 2>&1
else
  OUT="out/tally-$VNAME.apk"
fi
"$BT/apksigner$BAT" sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias "$KS_ALIAS" --out "$OUT" out/aligned.apk
rm -f out/unsigned.apk out/aligned.apk out/base.apk

if [ "$MODE" = release ]; then
  CERT=$("$BT/apksigner$BAT" verify --print-certs "$OUT" | grep -m1 'SHA-256 digest' | awk '{print $NF}' | tr -d '\r')
  WANT=$(tr -d ' \r\n' < release-cert.sha256)
  if [ "$CERT" != "$WANT" ]; then
    rm -f "$OUT"
    echo "REFUSING: APK is signed with the wrong key ($CERT), expected $WANT (release-cert.sha256)."
    echo "Phones would reject it as an update and users would have to uninstall = lose their data."
    exit 1
  fi
  echo "$VCODE" > "$LAST_FILE"
  echo "> signing key verified against release-cert.sha256"
fi

echo "> done: $OUT ($(du -k "$OUT" | cut -f1) KB)"
