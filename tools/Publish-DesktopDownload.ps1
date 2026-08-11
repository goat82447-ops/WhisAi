param(
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$project = Join-Path $repositoryRoot "src\WhisAi.Desktop\WhisAi.Desktop.csproj"
$packageDirectory = Join-Path $repositoryRoot "src\WhisAi.Api\DesktopPackage"
$publishDirectory = Join-Path $repositoryRoot "artifacts\desktop-publish"
$packagePath = Join-Path $packageDirectory "KrishAI-Windows-template.zip"

New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $publishDirectory -Force | Out-Null

dotnet publish $project `
    --configuration Release `
    --runtime $Runtime `
    --self-contained true `
    --output $publishDirectory `
    -p:DebugType=None `
    -p:DebugSymbols=false

if ($LASTEXITCODE -ne 0) {
    throw "Desktop publish failed with exit code $LASTEXITCODE."
}

@"
KrishAI for Windows

1. Extract every file from this ZIP.
2. Run KrishAi.Desktop.exe.
3. If Windows SmartScreen appears, review the publisher information before continuing.

The package is configured automatically for the website it was downloaded from.
It requires Windows 10 version 2004 or newer, Windows 11, and the Microsoft Edge WebView2 Runtime.
Use Ctrl+Shift+Q or the red close button to exit immediately.
"@ | Set-Content (Join-Path $publishDirectory "README.txt") -Encoding utf8

"https://deployment-url-is-injected-when-downloaded.invalid" | Set-Content (Join-Path $publishDirectory "server-url.txt") -Encoding ascii

if (Test-Path $packagePath) {
    Remove-Item $packagePath -Force
}

Compress-Archive -Path (Join-Path $publishDirectory "*") -DestinationPath $packagePath -CompressionLevel Optimal
Get-Item $packagePath | Select-Object FullName, Length, LastWriteTime