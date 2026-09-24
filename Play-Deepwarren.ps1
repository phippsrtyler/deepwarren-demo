param([string]$Apk = (Join-Path $PSScriptRoot 'Deepwarren.apk'))
$ErrorActionPreference = 'Stop'
function Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Program (exit $LASTEXITCODE)" }
}
function Set-AvdSetting([string]$Path, [string]$Key, [string]$Value) {
    $lines = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path } else { @() }
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
    $result = New-Object System.Collections.Generic.List[string]
    $written = $false
    foreach ($line in $lines) {
        if ($line -match $pattern) {
            if ($written) { continue }
            $result.Add("$Key=$Value")
            $written = $true
        } else {
            $result.Add($line)
        }
    }
    if (!$written) { $result.Add("$Key=$Value") }
    Set-Content -LiteralPath $Path -Value $result -Encoding ascii
}
try {
    $releaseBase = 'https://github.com/phippsrtyler/deepwarren-demo/releases/latest/download'
    $release = Invoke-RestMethod "$releaseBase/release.json"
    if ($release.apkSha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid release checksum.' }
    if (!(Test-Path -LiteralPath $Apk) -or (Get-FileHash -LiteralPath $Apk -Algorithm SHA256).Hash -ne $release.apkSha256) {
        Invoke-WebRequest -UseBasicParsing "$releaseBase/Deepwarren.apk" -OutFile "$Apk.part"
        if ((Get-FileHash -LiteralPath "$Apk.part" -Algorithm SHA256).Hash -ne $release.apkSha256) { throw 'Game download checksum mismatch.' }
        Move-Item -LiteralPath "$Apk.part" -Destination $Apk -Force
    }
    $studioJava = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
    if (!(Test-Path -LiteralPath "$studioJava\bin\java.exe")) {
        Start-Process 'https://developer.android.com/studio'
        throw 'Install Android Studio, then run this launcher again. No project creation is needed.'
    }
    $env:JAVA_HOME = $studioJava
    $gameRoot = Join-Path $env:LOCALAPPDATA 'Deepwarren'
    $sdk = Join-Path $gameRoot 'sdk'
    $env:ANDROID_AVD_HOME = Join-Path $gameRoot 'avd'
    New-Item -ItemType Directory -Force -Path $sdk,$env:ANDROID_AVD_HOME | Out-Null
    $manager = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (!(Test-Path -LiteralPath $manager)) {
        Write-Host 'Google Android SDK terms: https://developer.android.com/studio#command-tools'
        if ((Read-Host 'Review the terms above. Download the Google tools? Type yes') -ne 'yes') { throw 'Setup cancelled.' }
        $archive = Join-Path $gameRoot 'google-tools.zip'
        Invoke-WebRequest -UseBasicParsing 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' -OutFile $archive
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a') { throw 'Google tools checksum mismatch.' }
        $unpack = Join-Path $gameRoot 'google-tools'
        Expand-Archive -LiteralPath $archive -DestinationPath $unpack -Force
        New-Item -ItemType Directory -Force -Path "$sdk\cmdline-tools\latest" | Out-Null
        Copy-Item -Path "$unpack\cmdline-tools\*" -Destination "$sdk\cmdline-tools\latest" -Recurse -Force
    }
    $image = 'system-images;android-35;google_apis;x86_64'
    if (!(Test-Path -LiteralPath "$sdk\system-images\android-35\google_apis\x86_64\package.xml") -or
        !(Test-Path -LiteralPath "$sdk\emulator\emulator.exe") -or !(Test-Path -LiteralPath "$sdk\platform-tools\adb.exe")) {
        Checked $manager @("--sdk_root=$sdk", '--licenses')
        Checked $manager @("--sdk_root=$sdk", 'platform-tools', 'emulator', $image)
    }
    $avd = Join-Path $env:ANDROID_AVD_HOME 'Deepwarren.avd'
    if (!(Test-Path -LiteralPath "$avd\config.ini")) {
        'no' | & "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd --name Deepwarren --package $image --device pixel
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the Deepwarren emulator.' }
    }
    # avdmanager already wrote every one of these keys for the Pixel profile, so they are replaced
    # rather than appended. Appending left two copies of each key and the device booted at the Pixel
    # portrait default (1080x1920 @ 420) instead of the landscape 1920x1080 @ 240 desktop that the
    # release was verified on. This also repairs a device made by an earlier launcher.
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
    $serial = 'emulator-5580'
    $devices = & $adb devices
    if ($devices -match $serial) {
        $name = & $adb -s $serial emu avd name
        if ($name -notcontains 'Deepwarren') { throw 'Emulator port 5580 is occupied by another device. Close it and retry.' }
    } else {
        # The emulator is a GUI application, so it has no console window to hide. Asking Windows to
        # hide it only risks suppressing the two game windows the player needs to see and click.
        Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList '-avd Deepwarren -port 5580 -no-snapshot-load -gpu auto'
    }
    $deadline = (Get-Date).AddMinutes(4)
    do {
        Start-Sleep -Seconds 2
        $booted = & $adb -s $serial shell getprop sys.boot_completed 2>$null
        if ((Get-Date) -gt $deadline) { throw 'Emulator startup timed out. Check hardware virtualization and Google emulator requirements.' }
    } until ($booted -match '^1')
    Checked $adb @('-s',$serial,'emu','multidisplay','add','1','960','540','160','0')
    $displays = & $adb -s $serial shell dumpsys display
    if ($displays -notmatch 'com.android.emulator.multidisplay') {
        throw 'The second game display did not start, so the menus and battle choices would be unreachable. Close the emulator window and run this launcher again.'
    }
    Checked $adb @('-s',$serial,'install','-r',$Apk)
    Checked $adb @('-s',$serial,'shell','am','start','-n','com.deepwarren.android/com.deepwarren.android.MainActivity')
    Write-Host 'Deepwarren is running in two emulator windows: the large one is the world, and the smaller one below it is the menus and battle choices.'
    Write-Host 'Click a game window once if the keyboard does not respond. Keep this emulator device for your saved character.'
} catch { Write-Host $_ -ForegroundColor Red; exit 1 }
