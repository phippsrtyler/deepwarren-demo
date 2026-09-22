param([string]$Apk = (Join-Path $PSScriptRoot 'Deepwarren.apk'))
$ErrorActionPreference = 'Stop'
function Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Program (exit $LASTEXITCODE)" }
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
        Add-Content -LiteralPath "$avd\config.ini" -Value "`nhw.lcd.width=960`nhw.lcd.height=540`nhw.lcd.density=160`nhw.ramSize=4096`nhw.keyboard=yes`nshowDeviceFrame=no"
    }
    $adb = "$sdk\platform-tools\adb.exe"
    $serial = 'emulator-5580'
    $devices = & $adb devices
    if ($devices -match $serial) {
        $name = & $adb -s $serial emu avd name
        if ($name -notcontains 'Deepwarren') { throw 'Emulator port 5580 is occupied by another device. Close it and retry.' }
    } else {
        Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList '-avd Deepwarren -port 5580 -no-snapshot-load -gpu auto' -WindowStyle Hidden
    }
    $deadline = (Get-Date).AddMinutes(4)
    do {
        Start-Sleep -Seconds 2
        $booted = & $adb -s $serial shell getprop sys.boot_completed 2>$null
        if ((Get-Date) -gt $deadline) { throw 'Emulator startup timed out. Check hardware virtualization and Google emulator requirements.' }
    } until ($booted -match '^1')
    Checked $adb @('-s',$serial,'emu','multidisplay','add','1','960','540','160','0')
    Checked $adb @('-s',$serial,'install','-r',$Apk)
    Checked $adb @('-s',$serial,'shell','am','start','-n','com.deepwarren.android/com.deepwarren.android.MainActivity')
    Write-Host 'Deepwarren is running. Keep this emulator device for your saved character.'
} catch { Write-Host $_ -ForegroundColor Red; exit 1 }
