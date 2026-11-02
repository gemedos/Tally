#!/usr/bin/env bash
# Builds Tally without Gradle, using only the Android SDK tools.
# Needs: JDK 17+, Android SDK with "platforms;android-34" and "build-tools;35.0.0".
# Usage: ANDROID_HOME=/path/to/sdk ./build.sh        -> out/tally.apk
# Release signing: KEYSTORE=my.jks KS_PASS=... KS_ALIAS=... ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$SDK" ] || { echo "Set ANDROID_HOME to your Android SDK path"; exit 1; }
BT="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-34/android.jar"
EXE=""; BAT=""
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) EXE=".exe"; BAT=".bat";; esac

[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"
rm -rf out && mkdir -p out/gen out/classes out/dex

echo "> resources"
"$BT/aapt2$EXE" compile --dir app/res -o out/res.zip
"$BT/aapt2$EXE" link -o out/base.apk -I "$JAR" --manifest app/AndroidManifest.xml \
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

if [ -z "${KEYSTORE:-}" ]; then
  KEYSTORE=debug.keystore; KS_PASS=android; KS_ALIAS=tally
  [ -f "$KEYSTORE" ] || keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -alias "$KS_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Tally" >/dev/null 2>&1
fi
"$BT/apksigner$BAT" sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias "$KS_ALIAS" \
  --out out/tally.apk out/aligned.apk

echo "> done: out/tally.apk ($(du -k out/tally.apk | cut -f1) KB)"
