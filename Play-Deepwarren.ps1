# Deepwarren for Windows: sets up Google's Android emulator and starts the game in it.
# Run it through "Play Deepwarren.cmd" (double-click). Every later run starts the game directly.
param([string]$Apk = '')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # the progress bar makes Invoke-WebRequest many times slower

$releaseBase = 'https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download'
$gameRoot = Join-Path $env:LOCALAPPDATA 'Deepwarren'
$sdk = Join-Path $gameRoot 'sdk'
$env:ANDROID_AVD_HOME = Join-Path $gameRoot 'avd'
if (!$Apk) { $Apk = Join-Path $gameRoot 'Deepwarren.apk' }
# Pinned downloads, each checked against its published SHA-256 before use.
$javaUrl = 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_x64_windows_hotspot_21.0.12.1_1.zip'
$javaSha = 'd35f31e712f0fcf6ac5a093edc90204fbff22f720ba3950bd09d331d5e621636'
$toolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
$toolsSha = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
$image = 'system-images;android-35;google_apis;x86_64'
$serial = 'emulator-5580'

function Step([string]$Text) { Write-Host ''; Write-Host $Text -ForegroundColor Cyan }
function Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Program (exit $LASTEXITCODE)" }
}
function Download([string]$Url, [string]$Out, [string]$Sha) {
    Invoke-WebRequest -UseBasicParsing $Url -OutFile "$Out.part"
    if ((Get-FileHash -LiteralPath "$Out.part" -Algorithm SHA256).Hash -ne $Sha) {
        Remove-Item -LiteralPath "$Out.part" -Force
        throw "The download from $Url was damaged or changed (checksum mismatch). Run the setup again."
    }
    Move-Item -LiteralPath "$Out.part" -Destination $Out -Force
}
function Set-AvdSetting([string]$Path, [string]$Key, [string]$Value) {
    # avdmanager writes these keys for the Pixel profile, so replace them rather than append:
    # a duplicated key left the device in portrait instead of the tested 1920x1080 landscape.
    $lines = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path } else { @() }
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
    $result = New-Object System.Collections.Generic.List[string]
    $written = $false
    foreach ($line in $lines) {
        if ($line -match $pattern) { if (!$written) { $result.Add("$Key=$Value"); $written = $true } }
        else { $result.Add($line) }
    }
    if (!$written) { $result.Add("$Key=$Value") }
    Set-Content -LiteralPath $Path -Value $result -Encoding ascii
}

try {
    Write-Host 'Deepwarren setup' -ForegroundColor Green
    Write-Host 'The first run downloads about 3 GB and can take 15-30 minutes. Later runs start in a minute or two.'
    New-Item -ItemType Directory -Force -Path $gameRoot, $sdk, $env:ANDROID_AVD_HOME | Out-Null
    $drive = Get-PSDrive -Name ($gameRoot.Substring(0, 1))
    $firstRun = !(Test-Path -LiteralPath "$sdk\emulator\emulator.exe")
    if ($firstRun -and $drive.Free -lt 8GB) {
        throw "Deepwarren needs about 8 GB free on drive $($drive.Name): and only $([math]::Floor($drive.Free / 1GB)) GB is free. Free up space and run the setup again."
    }

    Step '[1/6] Getting the latest Deepwarren'
    $release = Invoke-RestMethod "$releaseBase/release.json"
    if ($release.apkSha256 -notmatch '^[a-f0-9]{64}$') { throw 'The release information is invalid. Try again later.' }
    if (!(Test-Path -LiteralPath $Apk) -or (Get-FileHash -LiteralPath $Apk -Algorithm SHA256).Hash -ne $release.apkSha256) {
        Download "$releaseBase/Deepwarren.apk" $Apk $release.apkSha256
        Write-Host 'Downloaded the newest game.'
    } else { Write-Host 'You already have the newest game.' }

    Step '[2/6] Java runtime'
    $studioJava = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
    $ownJava = Join-Path $gameRoot 'java'
    if (Test-Path -LiteralPath "$studioJava\bin\java.exe") { $env:JAVA_HOME = $studioJava; Write-Host 'Using the Java that came with Android Studio.' }
    else {
        $found = Get-ChildItem -LiteralPath $ownJava -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
        if (!$found) {
            Write-Host 'Downloading a small Java runtime (Eclipse Temurin, about 50 MB)...'
            $zip = Join-Path $gameRoot 'java.zip'
            Download $javaUrl $zip $javaSha
            Expand-Archive -LiteralPath $zip -DestinationPath $ownJava -Force
            Remove-Item -LiteralPath $zip -Force
            $found = Get-ChildItem -LiteralPath $ownJava -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
        }
        $env:JAVA_HOME = $found.FullName
        Write-Host 'Java is ready.'
    }

    Step '[3/6] Google Android emulator'
    $manager = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (!(Test-Path -LiteralPath $manager)) {
        Write-Host "Downloading Google's Android command-line tools..."
        $zip = Join-Path $gameRoot 'google-tools.zip'
        Download $toolsUrl $zip $toolsSha
        $unpack = Join-Path $gameRoot 'google-tools'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpack -Force
        New-Item -ItemType Directory -Force -Path "$sdk\cmdline-tools\latest" | Out-Null
        Copy-Item -Path "$unpack\cmdline-tools\*" -Destination "$sdk\cmdline-tools\latest" -Recurse -Force
        Remove-Item -LiteralPath $zip, $unpack -Recurse -Force
    }
    if ($firstRun -or !(Test-Path -LiteralPath "$sdk\system-images\android-35\google_apis\x86_64\package.xml") -or
        !(Test-Path -LiteralPath "$sdk\platform-tools\adb.exe")) {
        Write-Host ''
        Write-Host "Google now shows its Android SDK licence terms. Read each one and type y then Enter to accept it."
        Write-Host 'Deepwarren cannot install the emulator unless you accept them.'
        Checked $manager @("--sdk_root=$sdk", '--licenses')
        Write-Host 'Downloading the emulator and an Android system image (about 3 GB). This is the long part...'
        Checked $manager @("--sdk_root=$sdk", 'platform-tools', 'emulator', $image)
    } else { Write-Host 'The emulator is already installed.' }

    Step '[4/6] Checking that this PC can run the emulator'
    # cmd merges the tool's stderr so Windows PowerShell never turns it into a terminating error.
    $accel = (cmd /c "`"$sdk\emulator\emulator.exe`" -accel-check 2>&1") -join "`n"
    if ($LASTEXITCODE -ne 0) {
        Write-Host $accel
        throw ("This PC cannot run the Android emulator yet: hardware virtualization is off.`n" +
            "  1. Press Start, type 'Turn Windows features on or off', open it, tick 'Windows Hypervisor Platform', click OK and restart.`n" +
            "  2. If that is not enough, turn on virtualization (Intel VT-x or AMD SVM) in your PC's BIOS/UEFI settings.`n" +
            'Then double-click Play Deepwarren again. Nothing you downloaded is lost.')
    }
    Write-Host 'Virtualization is on.'

    Step '[5/6] Starting the Deepwarren emulator'
    $avd = Join-Path $env:ANDROID_AVD_HOME 'Deepwarren.avd'
    if (!(Test-Path -LiteralPath "$avd\config.ini")) {
        'no' | & "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd --name Deepwarren --package $image --device pixel
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the Deepwarren emulator.' }
    }
    $config = Join-Path $avd 'config.ini'
    Set-AvdSetting $config 'hw.lcd.width' '1920'
    Set-AvdSetting $config 'hw.lcd.height' '1080'
    Set-AvdSetting $config 'hw.lcd.density' '240'
    Set-AvdSetting $config 'hw.initialOrientation' 'landscape'
    Set-AvdSetting $config 'skin.dynamic' 'yes'
    Set-AvdSetting $config 'hw.ramSize' '4096'
    Set-AvdSetting $config 'hw.keyboard' 'yes'
    Set-AvdSetting $config 'showDeviceFrame' 'no'
    $adb = "$sdk\platform-tools\adb.exe"
    $devices = & $adb devices
    if ($devices -match $serial) {
        $name = & $adb -s $serial emu avd name
        if ($name -notcontains 'Deepwarren') { throw 'Another emulator is using port 5580. Close it and run Play Deepwarren again.' }
        Write-Host 'The emulator is already running.'
    } else {
        Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList '-avd Deepwarren -port 5580 -no-snapshot-load -gpu auto'
        Write-Host 'Waiting for Android to start (the first start can take several minutes)' -NoNewline
    }
    $deadline = (Get-Date).AddMinutes(10)
    do {
        Start-Sleep -Seconds 3
        Write-Host '.' -NoNewline
        $booted = & $adb -s $serial shell getprop sys.boot_completed 2>$null
        if ((Get-Date) -gt $deadline) { throw 'Android did not finish starting within 10 minutes. Close the emulator window and run Play Deepwarren again.' }
    } until ($booted -match '^1')
    Write-Host ''

    Step '[6/6] Opening Deepwarren'
    Checked $adb @('-s', $serial, 'emu', 'multidisplay', 'add', '1', '960', '540', '160', '0')
    $displays = & $adb -s $serial shell dumpsys display
    if ($displays -notmatch 'com.android.emulator.multidisplay') {
        throw 'The second game window (menus and battle choices) did not open. Close the emulator window and run Play Deepwarren again.'
    }
    Checked $adb @('-s', $serial, 'install', '-r', $Apk)
    Checked $adb @('-s', $serial, 'shell', 'am', 'start', '-n', 'com.deepwarren.android/com.deepwarren.android.MainActivity')

    # Keep a copy of the launcher with the game so the Start menu entry works after the download folder is gone.
    $launcher = Join-Path $gameRoot 'launcher'
    New-Item -ItemType Directory -Force -Path $launcher | Out-Null
    if ($PSScriptRoot -ne $launcher) {
        Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $launcher 'Play-Deepwarren.ps1') -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Play Deepwarren.cmd') -Destination (Join-Path $launcher 'Play Deepwarren.cmd') -Force -ErrorAction SilentlyContinue
    }
    $shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Deepwarren.lnk'
    if (!(Test-Path -LiteralPath $shortcut) -and (Test-Path -LiteralPath (Join-Path $launcher 'Play Deepwarren.cmd'))) {
        $link = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
        $link.TargetPath = Join-Path $launcher 'Play Deepwarren.cmd'
        $link.WorkingDirectory = $launcher
        $link.Description = 'Start Deepwarren in its Android emulator'
        $link.Save()
    }

    Write-Host ''
    Write-Host 'Deepwarren is running.' -ForegroundColor Green
    Write-Host '  - The large window is the world. The smaller window is menus, inventory and battle choices.'
    Write-Host '  - Move with WASD or the arrow keys. E or Enter selects. Esc goes back. F2 shows all controls.'
    Write-Host '  - Click a game window once if the keyboard does not respond.'
    Write-Host '  - Next time, open Deepwarren from the Start menu. It updates the game automatically.'
    Write-Host '  - Keep the Deepwarren emulator: your character lives in it.'
} catch {
    Write-Host ''
    Write-Host $_ -ForegroundColor Red
    exit 1
}
