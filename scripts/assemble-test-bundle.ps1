<#
.SYNOPSIS
    Assembles a self-contained WSLC test bundle from a WSL build tree.
.DESCRIPTION
    Copies the files that tools/test/setup-vm-for-tests.ps1 sends to a test VM, plus TAEF,
    the test distro and the test data from the restored NuGet packages. Before copying, it checks
    that the system.vhd packaged in wsl.msi is the injected Podman VHD.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$BuildType,
    [string]$Platform = "x64",
    [Parameter(Mandatory = $true)][string]$ExpectedSystemVhd,
    [string]$VersionsFile,
    [string]$RunScript,
    [string]$BuildInfo,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$SymbolsDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SourceDir = (Resolve-Path $SourceDir).Path
$bin = Join-Path $SourceDir "bin\$Platform\$BuildType"

function Get-PackageVersion([string]$Id) {
    $node = Select-Xml -Path (Join-Path $SourceDir "packages.config") -XPath "/packages/package[@id='$Id']/@version"
    if (-not $node) { throw "Package $Id not found in packages.config" }
    return $node.Node.Value
}

function Copy-Required([string]$Path, [string]$Destination, [switch]$Recurse) {
    if (-not (Test-Path $Path)) { throw "Missing build output: $Path" }
    Copy-Item -Path $Path -Destination $Destination -Recurse:$Recurse -Force
}

# 1. The packaged system.vhd must be the injected one.
$msi = Join-Path $bin "wsl.msi"
if (-not (Test-Path $msi)) { throw "Missing $msi" }
$extract = Join-Path ([System.IO.Path]::GetTempPath()) ("wsl-msi-" + [guid]::NewGuid())
$proc = Start-Process msiexec.exe -ArgumentList @("/a", "`"$msi`"", "/qn", "TARGETDIR=`"$extract`"") -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) { throw "Administrative extraction of $msi failed: $($proc.ExitCode)" }
$packaged = @(Get-ChildItem -Path $extract -Recurse -Filter system.vhd)
if ($packaged.Count -ne 1) { throw "Expected one system.vhd in $msi, found $($packaged.Count)" }
$expectedHash = (Get-FileHash $ExpectedSystemVhd -Algorithm SHA256).Hash
$packagedHash = (Get-FileHash $packaged[0].FullName -Algorithm SHA256).Hash
Remove-Item -Recurse -Force $extract
if ($expectedHash -ne $packagedHash) {
    throw "system.vhd in wsl.msi ($packagedHash) is not the Podman system VHD ($expectedHash)"
}
Write-Host "wsl.msi contains the Podman system VHD ($expectedHash)"

# 2. Test bundle.
New-Item -ItemType Directory -Force $OutDir | Out-Null
foreach ($file in "installer.msix", "wsltests.dll", "wslcsdk.dll", "testplugin.dll") {
    Copy-Required (Join-Path $bin $file) $OutDir
}
Copy-Required (Join-Path $SourceDir "tools\test\run-tests.ps1") $OutDir
Copy-Required (Join-Path $SourceDir "tools\test\test-setup.ps1") $OutDir
Copy-Required (Join-Path $SourceDir "test\linux\unit_tests") (Join-Path $OutDir "unit_tests") -Recurse

$packages = Join-Path $SourceDir "packages"
$distro = "$packages\Microsoft.WSL.TestDistro.$(Get-PackageVersion 'Microsoft.WSL.TestDistro')\$Platform\test_distro.tar.xz"
Copy-Required $distro (Join-Path $OutDir "test_distro.tar.xz")
$testData = "$packages\Microsoft.WSL.TestData.$(Get-PackageVersion 'Microsoft.WSL.TestData')\$Platform"
Copy-Required $testData (Join-Path $OutDir "test_data") -Recurse
$taef = "$packages\Microsoft.Taef.$(Get-PackageVersion 'Microsoft.Taef')\build\Binaries\$Platform"
Copy-Required $taef (Join-Path $OutDir "taef") -Recurse

if ($RunScript) { Copy-Required $RunScript $OutDir }
if ($VersionsFile -and (Test-Path $VersionsFile)) { Copy-Item $VersionsFile (Join-Path $OutDir "system-distro-versions.txt") }
if ($BuildInfo) {
    $info = $BuildInfo | ConvertFrom-Json
    $info | Add-Member -NotePropertyName system_vhd_sha256 -NotePropertyValue $expectedHash
    $info | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $OutDir "build-info.json")
}

# 3. Symbols.
New-Item -ItemType Directory -Force $SymbolsDir | Out-Null
Get-ChildItem -Path $bin -Filter *.pdb | Copy-Item -Destination $SymbolsDir -Force

Get-ChildItem $OutDir | Format-Table Name, Length -AutoSize
