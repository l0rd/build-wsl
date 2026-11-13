#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Runs the WSLC TAEF tests from a test bundle produced by assemble-test-bundle.ps1.
.DESCRIPTION
    Wraps the upstream tools/test/run-tests.ps1, which installs installer.msix, imports the test
    distro, copies the Linux unit tests and then runs:
        te.exe wsltests.dll /p:Version=2 ... /select:"@TestCategory='WSLC'"
    Works in CI (test-wslc job) and by hand on any x64 machine with Hyper-V:
        .\run-wslc-tests.ps1 -LogDir C:\wslc-logs
.NOTES
    This uninstalls any installed WSL package and replaces it with the bundle's installer.msix.
#>
[CmdletBinding()]
param (
    [string]$BundleDir = $PSScriptRoot,
    [Parameter(Mandatory = $true)][string]$LogDir,
    [string]$Filter = "@TestCategory='WSLC'",
    [string]$ExtraTeArgs = "",
    [string]$SummaryFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BundleDir = (Resolve-Path $BundleDir).Path
New-Item -ItemType Directory -Force $LogDir | Out-Null
$LogDir = (Resolve-Path $LogDir).Path

$env:PATH = "$BundleDir\taef;$env:PATH"

# Same logging parameters as cloudtest/TestGroup.xml.in, minus the ETW logger.
$teArgs = @(
    "/select:$Filter",
    "/errorOnCrash",
    "/logOutput:High",
    "/enableWttLogging",
    "/logFile:$LogDir\te.wtl",
    "/p:bugReportDirectory=$LogDir\BugReportOutput",
    "/p:RedirectStdout=$LogDir\stdout.txt",
    "/p:RedirectStderr=$LogDir\stderr.txt",
    "/p:KernelLogs=$LogDir\dmesg.txt",
    "/p:DumpFolder=$LogDir",
    "/p:WerReport",
    "/p:LogDmesg"
)
if ($ExtraTeArgs) { $teArgs += ($ExtraTeArgs -split '\s+' | Where-Object { $_ }) }

$runArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "$BundleDir\run-tests.ps1",
    "-Version", "2",
    "-SetupScript", "$BundleDir\test-setup.ps1",
    "-Package", "$BundleDir\installer.msix",
    "-DistroPath", "$BundleDir\test_distro.tar.xz",
    "-TestDataPath", "$BundleDir\test_data",
    "-UnitTestsPath", "$BundleDir\unit_tests",
    "-TestDllPath", "$BundleDir\wsltests.dll"
) + $teArgs

Write-Host "pwsh $($runArgs -join ' ')"
Push-Location $BundleDir
try {
    # A child process lets us tee TE's console output and still get its exit code.
    & pwsh.exe @runArgs 2>&1 | Tee-Object -FilePath "$LogDir\console.txt"
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

$summary = Select-String -Path "$LogDir\console.txt" -Pattern '^\s*Summary: Total=.*' | Select-Object -Last 1
$failed = Select-String -Path "$LogDir\console.txt" -Pattern '^EndGroup: .*\[Failed\]\s*$' -ErrorAction Ignore
if ($SummaryFile) {
    $lines = @("### WSLC tests", "", "Filter: ``$Filter``, exit code: $exitCode", "")
    if ($summary) { $lines += "``$($summary.Line.Trim())``" } else { $lines += "No TE summary line found; see console.txt." }
    if ($failed) {
        $lines += "", "<details><summary>Failed tests</summary>", "", '```'
        $lines += ($failed | ForEach-Object { $_.Line.Trim() })
        $lines += '```', "</details>"
    }
    $lines | Add-Content -Path $SummaryFile -Encoding utf8
}

exit $exitCode
