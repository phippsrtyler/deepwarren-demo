#!/bin/bash
# Deepwarren for Mac: sets up Google's Android emulator and starts the game in it.
# Double-click this file (the first time: right-click it, choose Open, then Open).
set -euo pipefail

release_base='https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download'
game_root="$HOME/Library/Application Support/Deepwarren"
sdk="$game_root/sdk"
export ANDROID_AVD_HOME="$game_root/avd"
apk="$game_root/Deepwarren.apk"
serial=emulator-5580
tools_build=15859902

step() { printf '\n\033[36m%s\033[0m\n' "$1"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$1"; printf '\nPress Return to close this window.'; read -r _; exit 1; }
trap 'fail "Setup stopped unexpectedly. Double-click Play-Deepwarren again to retry; nothing you downloaded is lost."' ERR
fetch() { curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error "$1" -o "$2"; }
verified_download() {
  fetch "$1" "$2.part"
  [[ "$(shasum -a 256 "$2.part" | cut -d ' ' -f 1)" == "$3" ]] || { rm -f "$2.part"; fail "The download from $1 was damaged or changed (checksum mismatch). Run the setup again."; }
  mv -f "$2.part" "$2"
}

case "$(uname -m)" in
  arm64)
    arch=arm64-v8a; tools=mac_arm64; tools_sha=835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e
    java_url='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_aarch64_mac_hotspot_21.0.12.1_1.tar.gz'
    java_sha=dec50fc6f9fcd4fe3ae8cabf5a5fa68f6afc48841f7698e468e9aa5d54beed84 ;;
  x86_64)
    arch=x86_64; tools=mac_x86_64; tools_sha=c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3
    java_url='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_x64_mac_hotspot_21.0.12.1_1.tar.gz'
    java_sha=6717ec641fd9ce0bb209ca083ee23b42202ac68cb6fcc5753496e0e4a0f41989 ;;
  *) fail 'This Mac type is not supported.' ;;
esac
image="system-images;android-35;google_apis;$arch"

printf '\033[32mDeepwarren setup\033[0m\n'
echo 'The first run downloads about 3 GB and can take 15-30 minutes. Later runs start in a minute or two.'
mkdir -p "$sdk" "$ANDROID_AVD_HOME"
first_run=0; [[ -x "$sdk/emulator/emulator" ]] || first_run=1
free_gb=$(( $(df -k "$game_root" | awk 'NR==2 {print $4}') / 1048576 ))
if (( first_run && free_gb < 8 )); then fail "Deepwarren needs about 8 GB of free disk space and only $free_gb GB is free. Free up space and run the setup again."; fi

step '[1/6] Getting the latest Deepwarren'
fetch "$release_base/Deepwarren.apk.sha256" "$game_root/Deepwarren.apk.sha256"
apk_sha="$(cut -d ' ' -f 1 < "$game_root/Deepwarren.apk.sha256" | tr -d '\r\n')"
[[ "$apk_sha" =~ ^[a-f0-9]{64}$ ]] || fail 'The release information is invalid. Try again later.'
if [[ ! -f "$apk" || "$(shasum -a 256 "$apk" | cut -d ' ' -f 1)" != "$apk_sha" ]]; then
  verified_download "$release_base/Deepwarren.apk" "$apk" "$apk_sha"; echo 'Downloaded the newest game.'
else echo 'You already have the newest game.'; fi

step '[2/6] Java runtime'
studio_java='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
if [[ -x "$studio_java/bin/java" ]]; then export JAVA_HOME="$studio_java"; echo 'Using the Java that came with Android Studio.'
else
  own_java="$(find "$game_root/java" -maxdepth 4 -path '*/Contents/Home/bin/java' 2>/dev/null | head -n 1 || true)"
  if [[ -z "$own_java" ]]; then
    echo 'Downloading a small Java runtime (Eclipse Temurin, about 50 MB)...'
    verified_download "$java_url" "$game_root/java.tar.gz" "$java_sha"
    mkdir -p "$game_root/java"; tar -xzf "$game_root/java.tar.gz" -C "$game_root/java"; rm -f "$game_root/java.tar.gz"
    own_java="$(find "$game_root/java" -maxdepth 4 -path '*/Contents/Home/bin/java' | head -n 1)"
  fi
  export JAVA_HOME="${own_java%/bin/java}"; echo 'Java is ready.'
fi

step '[3/6] Google Android emulator'
manager="$sdk/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$manager" ]]; then
  echo "Downloading Google's Android command-line tools..."
  verified_download "https://dl.google.com/android/repository/commandlinetools-${tools}-${tools_build}_latest.zip" "$game_root/google-tools.zip" "$tools_sha"
  rm -rf "$game_root/google-tools"; mkdir -p "$game_root/google-tools" "$sdk/cmdline-tools/latest"
  unzip -oq "$game_root/google-tools.zip" -d "$game_root/google-tools"
  cp -R "$game_root/google-tools/cmdline-tools/." "$sdk/cmdline-tools/latest/"
  rm -rf "$game_root/google-tools" "$game_root/google-tools.zip"
fi
if (( first_run )) || [[ ! -f "$sdk/system-images/android-35/google_apis/$arch/package.xml" || ! -x "$sdk/platform-tools/adb" ]]; then
  echo
  echo "Google now shows its Android SDK licence terms. Read each one and type y then Return to accept it."
  echo 'Deepwarren cannot install the emulator unless you accept them.'
  "$manager" "--sdk_root=$sdk" --licenses
  echo 'Downloading the emulator and an Android system image (about 3 GB). This is the long part...'
  "$manager" "--sdk_root=$sdk" platform-tools emulator "$image"
else echo 'The emulator is already installed.'; fi

step '[4/6] Checking that this Mac can run the emulator'
if ! accel="$("$sdk/emulator/emulator" -accel-check 2>&1)"; then
  echo "$accel"
  fail 'This Mac cannot run the Android emulator (hardware virtualization is unavailable). Google lists the requirements at https://developer.android.com/studio/run/emulator-acceleration'
fi
echo 'Virtualization is available.'

step '[5/6] Starting the Deepwarren emulator'
avd="$ANDROID_AVD_HOME/Deepwarren.avd"
if [[ ! -f "$avd/config.ini" ]]; then
  printf 'no\n' | "$sdk/cmdline-tools/latest/bin/avdmanager" create avd --name Deepwarren --package "$image" --device pixel
fi
# avdmanager writes these keys for the Pixel profile, so replace them rather than append:
# a duplicated key left the device in portrait instead of the tested 1920x1080 landscape.
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
if "$adb" devices | grep -q "$serial"; then
  [[ "$("$adb" -s "$serial" emu avd name | head -n 1 | tr -d '\r')" == Deepwarren ]] || fail 'Another emulator is using port 5580. Close it and run Play-Deepwarren again.'
  echo 'The emulator is already running.'
else
  nohup "$sdk/emulator/emulator" -avd Deepwarren -port 5580 -no-snapshot-load -gpu auto > "$game_root/emulator.log" 2>&1 &
  printf 'Waiting for Android to start (the first start can take several minutes)'
fi
ready=0
for ((attempt=0; attempt<200; attempt++)); do
  if [[ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" == 1 ]]; then ready=1; break; fi
  printf '.'; sleep 3
done
echo
(( ready )) || fail "Android did not finish starting within 10 minutes. Close the emulator and run Play-Deepwarren again. Details: $game_root/emulator.log"

step '[6/6] Opening Deepwarren'
"$adb" -s "$serial" emu multidisplay add 1 960 540 160 0
displays="$("$adb" -s "$serial" shell dumpsys display | tr -d '\r' || true)"
[[ "$displays" == *com.android.emulator.multidisplay* ]] || fail 'The second game window (menus and battle choices) did not open. Close the emulator and run Play-Deepwarren again.'
"$adb" -s "$serial" install -r "$apk"
"$adb" -s "$serial" shell am start -n com.deepwarren.android/com.deepwarren.android.MainActivity

trap - ERR
printf '\n\033[32mDeepwarren is running.\033[0m\n'
echo '  - The large window is the world. The smaller window is menus, inventory and battle choices.'
echo '  - Move with WASD or the arrow keys. E or Return selects. Esc goes back. F2 shows all controls.'
echo '  - Click a game window once if the keyboard does not respond.'
echo '  - Next time, double-click Play-Deepwarren again. It updates the game automatically.'
echo '  - Keep the Deepwarren emulator: your character lives in it.'
printf '\nYou can close this window. The game keeps running.\n'
