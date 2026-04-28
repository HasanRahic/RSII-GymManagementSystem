$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$date = Get-Date -Format "yy-MM-dd"
$archiveName = "fit-build-$date.zip"
$archivePath = Join-Path $PSScriptRoot $archiveName
$password = "fit"

$mobileBuild = Join-Path $root "flutter-mobile\build\app\outputs\flutter-apk"
$desktopBuild = Join-Path $root "flutter-desktop\build\windows\x64\runner\Release"

if (-not (Test-Path $mobileBuild)) {
    throw "Nije pronadjen Android build folder: $mobileBuild"
}

if (-not (Test-Path $desktopBuild)) {
    throw "Nije pronadjen Windows build folder: $desktopBuild"
}

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
$bundledPython = "C:\Users\hasor\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

if ($pythonCommand -and $pythonCommand.Source -like "*WindowsApps*") {
    $pythonCommand = $null
}

if (
    -not $pythonCommand -and
    -not $pyLauncher -and
    -not (Test-Path $bundledPython)
) {
    throw "Python nije dostupan. Potreban je za kreiranje sifrovane zip arhive."
}

$pythonScript = @"
import os
import sys
import subprocess

try:
    import pyzipper
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyzipper"])
    import pyzipper

archive_path = r"$archivePath"
password = b"$password"
root = r"$root"
sources = [
    (r"$mobileBuild", "flutter-mobile/build/app/outputs/flutter-apk"),
    (r"$desktopBuild", "flutter-desktop/build/windows/x64/runner/Release"),
]

with pyzipper.AESZipFile(
    archive_path,
    "w",
    compression=pyzipper.ZIP_DEFLATED,
    encryption=pyzipper.WZ_AES,
) as zf:
    zf.setpassword(password)
    for src, prefix in sources:
        for current_root, _, files in os.walk(src):
            for file_name in files:
                full_path = os.path.join(current_root, file_name)
                relative = os.path.relpath(full_path, src)
                arcname = os.path.join(prefix, relative).replace("\\\\", "/")
                zf.write(full_path, arcname)

print(archive_path)
"@

if ($pythonCommand) {
    $pythonScript | & $pythonCommand.Source -
} elseif (Test-Path $bundledPython) {
    $pythonScript | & $bundledPython -
} else {
    $pythonScript | & $pyLauncher.Source -3 -
}

Write-Host "Predajna arhiva kreirana: $archivePath" -ForegroundColor Green
