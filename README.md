# Deepwarren

Free online co-op Android demo. The game connects to our hosted world automatically; you do not
need a GPU server, model download, VPN, or account with a model provider.

**Release preparation in progress. No public APK is published yet.**

## Android / Thor

Download the APK from Releases and open it on your device. Android may ask you to allow this
download source to install applications. Keep the same installation to retain your character.
Internet access and an available host are required. When the server is full, wait in the queue;
your character is saved when you leave. Host downtime is shown separately from a full server.

## Windows and Mac

Install [Android Studio](https://developer.android.com/studio) once (no project creation needed),
then run the appropriate Deepwarren launcher supplied with the release. The launcher uses
Studio's Java runtime, downloads Google's emulator tools, asks you to review Google's SDK
licences, creates a dedicated Deepwarren virtual device, installs the APK, and starts the game.
First setup downloads several GB; subsequent launches reuse the installed tools and device.

The Windows guide and launcher are being tested. macOS support is under preparation and is not
yet verified on a physical Mac. Apple Silicon requires the ARM64 image; Intel Macs use x86_64.
See Google's [system requirements](https://developer.android.com/studio/install).

The game and menus use separate displays. The setup configures both; a second physical monitor
is not necessary. Click the lower game window for mouse/touch input. Keyboard mappings will be
published here after the public build's input acceptance check.

## Support

Report the version, device/emulator, what you expected, and what happened using this repository's
Issues page. Do not post credentials or private save files. This repository distributes the demo;
it does not contain or license the game's private source code or production assets.
