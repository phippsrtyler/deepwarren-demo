# Deepwarren

Free online co-op demo. Up to **eight players** share one living world, and there's a queue when it's full.
No account, no GPU and no server setup: the game connects to our hosted world by itself.

**[Download for Android](https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download/Deepwarren.apk)** ·
[Windows setup](https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download/Deepwarren-Windows-Setup.zip) ·
[Mac setup](https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download/Deepwarren-Mac-Setup.zip)

The world runs on the developer's own PC, so the demo is online when that PC is. If it's offline,
the game tells you so instead of leaving you in the queue.

## Android phone or tablet (AYN Thor, etc.)

1. Tap **Download for Android** above.
2. Open the downloaded `Deepwarren.apk`. If Android asks, allow installs from your browser.
3. Open Deepwarren and play.

To update, install the new APK over the old one. Your character is kept. Uninstalling the app
or clearing its storage loses your character.

## Windows

1. Download **Windows setup** and open the ZIP. Click **Extract all**.
2. In the extracted folder, double-click **Play Deepwarren**.
   - If Windows shows "Windows protected your PC", click **More info**, then **Run anyway**.
3. When Google's licence terms appear, read each one and type **y** then Enter.
4. Wait. The first run downloads about 3 GB and takes 15-30 minutes. The window shows each step.

The game opens in two windows: the big one is the world, and the smaller one holds menus,
inventory and battle choices. Next time, open **Deepwarren** from the Start menu. It updates
the game by itself and starts in a minute or two.

If it says **hardware virtualization is off**: press Start, type *Turn Windows features on or off*,
tick **Windows Hypervisor Platform**, click OK and restart your PC. Then run Deepwarren again.
Some PCs also need virtualization (Intel VT-x or AMD SVM) switched on in the BIOS.

## Mac

1. Download **Mac setup** and double-click the ZIP to unpack it.
2. Right-click **Play-Deepwarren** and choose **Open**, then **Open** again. (macOS asks this once
   because the file came from the internet.)
3. When Google's licence terms appear, read each one and type **y** then Return.
4. Wait. The first run downloads about 3 GB and takes 15-30 minutes.

Next time, double-click **Play-Deepwarren** again. It works on Apple Silicon and Intel Macs.
The Mac setup has not yet been tested on a physical Mac, so please report anything that goes wrong.

## What the setup does

It downloads a small Java runtime, Google's official Android emulator tools and an Android system image.
Every download is checked against a known checksum. It creates a dedicated "Deepwarren" emulator,
installs the newest game and starts it. Everything lives in its own folder, so it never touches
another Android setup you may have:

- Windows: `%LOCALAPPDATA%\Deepwarren`
- Mac: `~/Library/Application Support/Deepwarren`

It changes no system settings. Android Studio is not needed. If you already have it, the setup
uses Android Studio's Java instead of downloading its own. You need about 8 GB of free disk space
and 8 GB of RAM.

Your character lives in the Deepwarren emulator. Keep it. To remove everything, delete the folder above.

## Controls

| Key | Action |
|---|---|
| WASD / arrow keys | Move and navigate menus |
| E or Enter | Select, interact |
| Esc | Back, pause |
| 1 | Aim at a limb in battle |
| F1 | Help |
| F2 | Full controls on the lower screen |

Click a game window once if the keyboard doesn't respond. You can also click choices in the smaller window.

## Problems

Open an issue on this repository. Include what you were doing, what you expected and what happened.
Mention your device, or Windows/Mac version. Please don't post passwords or save files.

This repository distributes the demo. It doesn't contain or license the game's source code or art.
