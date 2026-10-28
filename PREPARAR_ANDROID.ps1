$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$flutter = 'flutter'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  $options = @('C:\src\flutter\bin\flutter.bat', "$HOME\Documents\flutter\bin\flutter.bat")
  foreach ($candidate in $options) { if (Test-Path $candidate) { $flutter = $candidate; break } }
}
Write-Host 'Cusco Limpio: preparando Android...' -ForegroundColor Cyan
& $flutter --version
if ($LASTEXITCODE -ne 0) {throw 'Flutter SDK no disponible. Configura Flutter en PATH.'}
& $flutter create --platforms=android --org com.unsaac --project-name cusco_limpio_flutter .
if ($LASTEXITCODE -ne 0) {throw 'No se pudo completar la estructura Android.'}
$manifest = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
$xml = Get-Content $manifest -Raw
$permissions = @'
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.CAMERA" />
'@
if ($xml -notmatch 'android.permission.ACCESS_FINE_LOCATION') {
  $xml = $xml.Replace('<application', "$permissions`r`n    <application")
}
if ($xml -notmatch 'android.permission.CAMERA') {
  $xml = $xml.Replace('<application', '    <uses-permission android:name="android.permission.CAMERA" />' + "`r`n    <application")
}
$xml = $xml.Replace('android:label="cusco_limpio_flutter"', 'android:label="Cusco Limpio"')
Set-Content $manifest $xml -Encoding UTF8
& $flutter pub get
if ($LASTEXITCODE -ne 0) {throw 'No se pudieron descargar las dependencias.'}
& $flutter analyze
if ($LASTEXITCODE -ne 0) {throw 'Flutter analyze detecto errores; revisalos antes de ejecutar.'}
Write-Host 'Preparacion terminada. Conecta Android por USB y ejecuta flutter run.' -ForegroundColor Green
