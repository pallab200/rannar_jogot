param(
    [string]$Alias = "upload",
    [string]$KeystorePath = "android/app/release-keystore.jks",
    [int]$ValidityDays = 10000,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-PlainTextFromSecureString {
    param([Security.SecureString]$SecureString)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-KeytoolPath {
    if ($env:JAVA_HOME) {
        $javaHomeKeytool = Join-Path $env:JAVA_HOME "bin/keytool.exe"
        if (Test-Path $javaHomeKeytool) {
            return $javaHomeKeytool
        }
    }

    $javaSettingsOutput = cmd /c "java -XshowSettings:properties -version 2>&1"
    $javaHomeLine = $javaSettingsOutput | Select-String "java.home"

    if (-not $javaHomeLine) {
        throw "Unable to determine java.home. Install a JDK and try again."
    }

    $javaHome = ($javaHomeLine -split "=")[1].Trim()
    $keytoolPath = Join-Path $javaHome "bin/keytool.exe"
    if (-not (Test-Path $keytoolPath)) {
        throw "keytool.exe not found at $keytoolPath"
    }

    return $keytoolPath
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectRoot "android"
$keystoreAbsolutePath = Join-Path $projectRoot $KeystorePath
$keyPropertiesPath = Join-Path $androidDir "key.properties"
$storeFileValue = "app/$(Split-Path -Leaf $keystoreAbsolutePath)"
$keytoolPath = Get-KeytoolPath

if ($DryRun) {
    Write-Host "Keytool: $keytoolPath"
    Write-Host "Keystore path: $keystoreAbsolutePath"
    Write-Host "key.properties path: $keyPropertiesPath"
    Write-Host "storeFile value: $storeFileValue"
    exit 0
}

New-Item -ItemType Directory -Path (Split-Path -Parent $keystoreAbsolutePath) -Force | Out-Null

Write-Host "Generating release keystore..."
Write-Host "You will be prompted by keytool for passwords and certificate details."
& $keytoolPath -genkeypair -v `
    -keystore $keystoreAbsolutePath `
    -alias $Alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity $ValidityDays

if ($LASTEXITCODE -ne 0) {
    throw "keytool failed. key.properties was not written."
}

if (-not (Test-Path $keystoreAbsolutePath)) {
    throw "Keystore was not created at $keystoreAbsolutePath. key.properties was not written."
}

$keystoreFileInfo = Get-Item $keystoreAbsolutePath
if ($keystoreFileInfo.Length -le 0) {
    throw "Keystore file is empty at $keystoreAbsolutePath. key.properties was not written."
}

Write-Host ""
Write-Host "Keystore created. Enter the same passwords again so this script can write android/key.properties."
$storePassword = Read-Host "Store password" -AsSecureString
$keyPassword = Read-Host "Key password" -AsSecureString

$storePasswordPlain = Get-PlainTextFromSecureString -SecureString $storePassword
$keyPasswordPlain = Get-PlainTextFromSecureString -SecureString $keyPassword

if ([string]::IsNullOrWhiteSpace($storePasswordPlain)) {
    throw "Store password cannot be blank. key.properties was not written."
}

if ([string]::IsNullOrWhiteSpace($keyPasswordPlain)) {
    throw "Key password cannot be blank. key.properties was not written."
}

$keyPropertiesContent = @(
    "storePassword=$storePasswordPlain"
    "keyPassword=$keyPasswordPlain"
    "keyAlias=$Alias"
    "storeFile=$storeFileValue"
) -join [Environment]::NewLine

Set-Content -Path $keyPropertiesPath -Value $keyPropertiesContent -NoNewline

Write-Host ""
Write-Host "Created: $keyPropertiesPath"
Write-Host "Next step: flutter build appbundle --release"
