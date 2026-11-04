# Builds the fixture camera's media source (mediapipe_vcam.dll) and host
# (vcam_host.exe) into -Out with the Visual Studio C++ toolchain and the
# Windows SDK. Static CRT, so the Frame Server services need nothing else.
param([Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'No Visual Studio installation with the x64 C++ tools.' }
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
"Visual Studio: $vs"
"Windows SDK: $env:WindowsSDKVersion"

& (Join-Path $here 'make_fixture.ps1') -Out (Join-Path $Out 'fixture.bgra')
Set-Content -Path (Join-Path $Out 'fixture.rc') -Value '101 RCDATA "fixture.bgra"' -Encoding ascii

Push-Location $Out
try {
  rc /nologo /fo fixture.res fixture.rc
  if ($LASTEXITCODE) { throw 'rc failed' }
  # 0x0A00000C is NTDDI_WIN10_NI (22621), which declares the virtual camera
  # and sensor profile APIs; the runner is newer.
  $common = @('/nologo', '/std:c++17', '/EHsc', '/O2', '/MT', '/W3', '/DUNICODE', '/D_UNICODE',
    '/DNTDDI_VERSION=0x0A00000C', '/D_WIN32_WINNT=0x0A00', "/I$here")
  cl @common /LD (Join-Path $here 'vcam_source.cpp') fixture.res /Fe:mediapipe_vcam.dll `
    /link "/DEF:$(Join-Path $here 'vcam_source.def')" mfplat.lib mfuuid.lib mfsensorgroup.lib ole32.lib advapi32.lib runtimeobject.lib
  if ($LASTEXITCODE) { throw 'building the media source failed' }
  cl @common (Join-Path $here 'vcam_host.cpp') fixture.res /Fe:vcam_host.exe `
    /link mfplat.lib mf.lib mfreadwrite.lib mfuuid.lib mfsensorgroup.lib ole32.lib
  if ($LASTEXITCODE) { throw 'building the host failed' }
  & dumpbin /nologo /dependents mediapipe_vcam.dll
  & dumpbin /nologo /exports mediapipe_vcam.dll
} finally {
  Pop-Location
}
Get-ChildItem $Out -Include *.dll, *.exe -Recurse | Format-Table Name, Length -AutoSize | Out-String
