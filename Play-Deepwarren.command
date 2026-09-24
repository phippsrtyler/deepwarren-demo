#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
apk="$PWD/Deepwarren.apk"
release_base='https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download'
curl --fail --location --proto '=https' --tlsv1.2 "$release_base/Deepwarren.apk.sha256" -o "$PWD/Deepwarren.apk.sha256"
apk_checksum="$(cut -d ' ' -f 1 < "$PWD/Deepwarren.apk.sha256" | tr -d '\r\n')"
[[ "$apk_checksum" =~ ^[a-f0-9]{64}$ ]] || { echo 'Invalid release checksum'; exit 1; }
if [[ ! -f "$apk" ]] || [[ "$(shasum -a 256 "$apk" | cut -d ' ' -f 1)" != "$apk_checksum" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 "$release_base/Deepwarren.apk" -o "$apk.part"
  [[ "$(shasum -a 256 "$apk.part" | cut -d ' ' -f 1)" == "$apk_checksum" ]] || { echo 'Game checksum mismatch'; exit 1; }
  mv -f "$apk.part" "$apk"
fi
studio_java='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
if [[ ! -x "$studio_java/bin/java" ]]; then
  open 'https://developer.android.com/studio'
  echo 'Install Android Studio in Applications, then run this launcher again. No project needed.'
  exit 1
fi
export JAVA_HOME="$studio_java"
game_root="$HOME/Library/Application Support/Deepwarren"
sdk="$game_root/sdk"
export ANDROID_AVD_HOME="$game_root/avd"
mkdir -p "$sdk" "$ANDROID_AVD_HOME"
case "$(uname -m)" in
  arm64) arch=arm64-v8a; tool=mac_arm64; checksum=835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e ;;
  x86_64) arch=x86_64; tool=mac_x86_64; checksum=c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3 ;;
  *) echo 'Unsupported Mac architecture.'; exit 1 ;;
esac
manager="$sdk/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$manager" ]]; then
  echo 'Google Android SDK terms: https://developer.android.com/studio#command-tools'
  read -r -p 'Review those terms. Download Google tools? Type yes: ' consent
  [[ "$consent" == yes ]] || exit 1
  archive="$game_root/google-tools.zip"
  curl --fail --location --proto '=https' --tlsv1.2 "https://dl.google.com/android/repository/commandlinetools-${tool}-15859902_latest.zip" -o "$archive"
  [[ "$(shasum -a 256 "$archive" | cut -d ' ' -f 1)" == "$checksum" ]] || { echo 'Google tools checksum mismatch'; exit 1; }
  mkdir -p "$game_root/google-tools" "$sdk/cmdline-tools/latest"
  unzip -oq "$archive" -d "$game_root/google-tools"
  cp -R "$game_root/google-tools/cmdline-tools/." "$sdk/cmdline-tools/latest/"
fi
image="system-images;android-35;google_apis;$arch"
if [[ ! -f "$sdk/system-images/android-35/google_apis/$arch/package.xml" || ! -x "$sdk/emulator/emulator" || ! -x "$sdk/platform-tools/adb" ]]; then
  "$manager" "--sdk_root=$sdk" --licenses
  "$manager" "--sdk_root=$sdk" platform-tools emulator "$image"
fi
avd="$ANDROID_AVD_HOME/Deepwarren.avd"
if [[ ! -f "$avd/config.ini" ]]; then
  printf 'no\n' | "$sdk/cmdline-tools/latest/bin/avdmanager" create avd --name Deepwarren --package "$image" --device pixel
fi
# avdmanager already wrote every one of these keys for the Pixel profile, so they are replaced
# rather than appended. Appending left two copies of each key and the device booted at the Pixel
# portrait default (1080x1920 @ 420) instead of the landscape 1920x1080 @ 240 desktop that the
# release was verified on. This also repairs a device made by an earlier launcher.
set_avd_setting() {
  local key="$1" value="$2" file="$avd/config.ini" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { escaped = key; gsub(/\./, "\\.", escaped); written = 0 }
    $0 ~ "^[[:space:]]*" escaped "[[:space:]]*=" { if (!written) { print key "=" value; written = 1 }; next }
    { print }
    END { if (!written) print key "=" value }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}
set_avd_setting hw.lcd.width 1920
set_avd_setting hw.lcd.height 1080
set_avd_setting hw.lcd.density 240
set_avd_setting hw.initialOrientation landscape
set_avd_setting skin.dynamic yes
set_avd_setting hw.ramSize 4096
set_avd_setting hw.keyboard yes
set_avd_setting showDeviceFrame no
adb="$sdk/platform-tools/adb"
serial=emulator-5580
if "$adb" devices | grep -q "$serial"; then
  [[ "$("$adb" -s "$serial" emu avd name | head -n 1 | tr -d '\r')" == Deepwarren ]] || { echo 'Emulator port 5580 is occupied by another device.'; exit 1; }
else
  nohup "$sdk/emulator/emulator" -avd Deepwarren -port 5580 -no-snapshot-load -gpu auto > "$game_root/emulator.log" 2>&1 &
fi
ready=0
for ((attempt=0; attempt<120; attempt++)); do
  if [[ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" == 1 ]]; then ready=1; break; fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo "Emulator startup timed out. Details: $game_root/emulator.log"; exit 1; }
"$adb" -s "$serial" emu multidisplay add 1 960 540 160 0
displays="$("$adb" -s "$serial" shell dumpsys display | tr -d '\r' || true)"
[[ "$displays" == *com.android.emulator.multidisplay* ]] || { echo 'The second game display did not start, so the menus and battle choices would be unreachable. Close the emulator and run this launcher again.'; exit 1; }
"$adb" -s "$serial" install -r "$apk"
"$adb" -s "$serial" shell am start -n com.deepwarren.android/com.deepwarren.android.MainActivity
echo 'Deepwarren is running in two emulator windows: the large one is the world, and the smaller one below it is the menus and battle choices.'
echo 'Click a game window once if the keyboard does not respond. Keep this emulator device for your saved character.'
