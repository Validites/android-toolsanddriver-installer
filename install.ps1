# installs android platform tools (adb/fastboot) + the google usb driver
# dumps everything into C:\Android and adds it to the system path
# run as admin - it'll try to relaunch itself elevated if you forget

$InstallDir = "C:\Android"

# check admin first since pnputil and the machine path both need it
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "needs admin rights, trying to elevate..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# powershell 5.1 draws a progress bar for every iwr call and it makes downloads
# take like 10x longer, so kill it
$ProgressPreference = 'SilentlyContinue'

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$platformToolsZip = Join-Path $InstallDir "platform-tools.zip"
$usbDriverZip     = Join-Path $InstallDir "usb_driver.zip"

Write-Host "downloading platform-tools..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $platformToolsZip

Write-Host "downloading usb drivers..." -ForegroundColor Cyan
try {
    # the rolling 'latest' link usually works
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/latest_usb_driver_windows.zip" -OutFile $usbDriverZip -ErrorAction Stop
} catch {
    Write-Host "latest alias failed, using the stable r13 link instead" -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/usb_driver_r13-windows.zip" -OutFile $usbDriverZip
}

Expand-Archive -Path $platformToolsZip -DestinationPath $InstallDir -Force
Expand-Archive -Path $usbDriverZip -DestinationPath $InstallDir -Force

# get rid of the zips, no reason to keep them around
Remove-Item $platformToolsZip, $usbDriverZip -Force

# add platform-tools to the machine path so adb works in fresh shells
$toolsPath = Join-Path $InstallDir "platform-tools"
$sysPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($sysPath -notmatch [regex]::Escape($toolsPath)) {
    [Environment]::SetEnvironmentVariable("Path", $sysPath.TrimEnd(';') + ";" + $toolsPath, "Machine")
    Write-Host "added $toolsPath to system path" -ForegroundColor Green
} else {
    Write-Host "already in the path, skipping" -ForegroundColor Yellow
}

# install the usb driver through pnputil (took me a while to remember the syntax)
$inf = Join-Path $InstallDir "usb_driver\android_winusb.inf"
if (Test-Path $inf) {
    pnputil.exe /add-driver "$inf" /install
    Write-Host "driver installed" -ForegroundColor Green
} else {
    Write-Warning "couldnt find $inf - skipping driver install"
}

# todo: verify checksums on the downloads at some point

Write-Host ""
Write-Host "all done, adb and fastboot should work now" -ForegroundColor Green
Write-Host "heads up: close this window and open a new powershell for the path change to kick in" -ForegroundColor Yellow

