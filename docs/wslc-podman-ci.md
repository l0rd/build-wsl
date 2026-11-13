# WSLC on Podman: x64 build and test workflow

`.github/workflows/wslc-podman.yml` builds the WSLC-on-Podman test artifacts from forks and can run the
WSLC TAEF suite on a self-hosted x64 machine. It exists to tell real regressions apart from failures that
only show up on one machine (ARM64 dev boxes, networking or DNS setup, timing).

It starts only by hand (**Actions → WSLC on Podman (x64) → Run workflow**). Every job checks
`github.actor == github.repository_owner`. The workflow has no `push` or `pull_request` triggers, so
nobody else can make the self-hosted runner execute code.

## Jobs

```
resolve ──► system-vhd ──► build-wsl ──► test-wslc (optional, self-hosted)
```

| job | runner | does | artifacts |
|---|---|---|---|
| `resolve` | `ubuntu-24.04` | resolves every input ref (and the WSLg vendor `working` branches) to a commit, so all jobs build the same code | — |
| `system-vhd` | `ubuntu-24.04` | builds the WSLg system distro with Podman from source, exports it and converts it with `tar2ext4 -vhd`; skipped on a cache hit | `system-vhd-x64` |
| `build-wsl` | `windows-2022` | builds WSL x64 (Release by default) with the Podman `system.vhd` inside the package | `wslc-tests-x64`, `wsl-symbols-x64` |
| `test-wslc` | `[self-hosted, windows, x64, wslc]` | installs the package and runs `te.exe wsltests.dll /p:Version=2 /select:"@TestCategory='WSLC'"` | `wslc-test-logs-x64` |

### Inputs

| input | default | notes |
|---|---|---|
| `wsl_repo` / `wsl_ref` | `l0rd/WSL` / `wslc-podman-test` | branch, tag or full SHA |
| `wslg_repo` / `wslg_ref` | `l0rd/wslg` / `wslc-podman-test` | the Dockerfile on this branch is what gets built |
| `podman_repo` / `podman_ref` | `l0rd/podman` / `wslc-podman-test` | branch or tag only: passed as `PODMAN_REPO`/`PODMAN_VERSION`, and the resolved commit is passed as `PODMAN_COMMIT`, so the build fails if the branch moved mid-run |
| `build_type` | `Release` | `Release` matches upstream CI; `Debug` turns on assertions, debug-only checks and `WSL_LOG_DEBUG` events, and makes unknown exceptions fail fast |
| `rebuild_vhd` | `false` | ignore the VHD cache |
| `run_tests` | `false` | needs the self-hosted runner described below |
| `test_filter` | `@TestCategory='WSLC'` | TAEF `/select:` |
| `extra_te_args` | (empty) | e.g. `/name:*Network*` |

### System VHD (`system-vhd`)

This job follows WSLg `config/BUILD.md` and `build-and-export.sh`:

1. `scripts/fetch-wslg-vendor.sh` clones FreeRDP, weston and pulseaudio at the commits `resolve` pinned,
   and unpacks mesa `23.1.0` and DirectX-Headers `v1.608.0` into `vendor/`.
2. `docker build` runs with `WSLG_ARCH=x86_64`, the `PODMAN_*` args and the vendor commits.
   `build-and-export.sh` is not used because it does not forward the Podman args.
3. `docker export` produces the rootfs tar, and `go run github.com/Microsoft/hcsshim/cmd/tar2ext4@v0.13.0 -vhd`
   converts it to `system.vhd`. `/etc/versions.txt` from the image is saved alongside.

The result is cached under a key made of the WSLg commit, the Podman commit and the vendor inputs. Runs
that only change WSL skip the 60–90 minute Linux build. To invalidate every cached VHD, bump
`VHD_CACHE_EPOCH` in the workflow.

### WSL build (`build-wsl`)

1. `cmake . -A x64 -DCMAKE_BUILD_TYPE=<build_type>` restores the NuGet packages into `packages/`.
2. The workflow overwrites `packages/Microsoft.WSLg.<ver>/build/native/bin/x64/system.vhd` with the
   Podman VHD. That file is `${WSLG_SOURCE_DIR}/x64/system.vhd`, which `msipackage/package.wix.in` puts
   into `wsl.msi`, and `installer.msix` carries `wsl.msi`.
3. `cmake --build . --config <build_type> -- -m` builds everything, including the tests.
4. `scripts/assemble-test-bundle.ps1` extracts `wsl.msi` (`msiexec /a`) and fails if its `system.vhd`
   is not the injected one. It then assembles the bundle:

```
installer.msix  wsltests.dll  wslcsdk.dll  testplugin.dll
run-tests.ps1  test-setup.ps1            upstream tools/test scripts
run-wslc-tests.ps1                       this repo's wrapper (see below)
unit_tests/                              test/linux/unit_tests
test_distro.tar.xz  test_data/           Microsoft.WSL.TestDistro / TestData NuGet packages
taef/                                    Microsoft.Taef NuGet package, build/Binaries/x64
system-distro-versions.txt  build-info.json
```

PDBs go into `wsl-symbols-x64`.

The workflow does not use the `C:\wsldev` development layout (`WSL_DEV_BINARY_PATH`) on purpose. A
package built that way reads `C:\wsldev\system.vhd`, `kernel`, `artifacts.vhd` and `lib\` from the
machine, so every test host would need that folder rebuilt by hand. The approach above yields a
self-contained `installer.msix`, which is also what upstream CI installs.

Both build types link the C runtime statically (`/MT` for Release, `/MTd` for Debug), so test machines
need no Visual Studio or extra runtime libraries.

### Tests (`test-wslc`)

GitHub-hosted Windows runners cannot boot the WSLC VM, so this job needs a self-hosted runner.
`run-wslc-tests.ps1` calls the upstream `run-tests.ps1`, which:
- uninstalls any WSL package and installs `installer.msix` with `-AllowUnsigned`
- imports `test_distro`
- copies the unit tests
- runs TE with the logging parameters from `cloudtest/TestGroup.xml.in`

Console output, `te.wtl`, the redirected stdout and stderr, `dmesg.txt`, dumps and bug reports land in the
`wslc-test-logs-x64` artifact. The job summary shows the TE `Summary:` line and the names of failed tests.

The bundle also works without CI. Download `wslc-tests-x64` onto any x64 machine that meets the
requirements below, then run from an elevated PowerShell:

```powershell
.\run-wslc-tests.ps1 -LogDir C:\wslc-logs
.\run-wslc-tests.ps1 -LogDir C:\wslc-logs -ExtraTeArgs '/name:*Network*'
```

This replaces the installed WSL package.

## Self-hosted runner setup

Requirements:

- **x64 Windows 11 (Pro or Enterprise), not a Server SKU.** Upstream skips WSLC on Server images
  because of a Hyper-V VMBus PowerOff hang during VM teardown (`cloudtest/CMakeLists.txt`).
- **Hardware virtualization exposed to the OS**, from either:
  - bare metal
  - a Hyper-V VM with `Set-VMProcessor -VMName <vm> -ExposeVirtualizationExtensions $true`
  - a cloud VM size with nested virtualization, e.g. Azure Dv5/Dsv5/Ev5 with the Windows 11 Enterprise image
- **Optional features**, followed by a reboot:
  ```powershell
  Enable-WindowsOptionalFeature -Online -All -NoRestart -FeatureName VirtualMachinePlatform, Microsoft-Hyper-V-Management-PowerShell, Microsoft-Windows-Subsystem-Linux
  ```
- **PowerShell 7** (`pwsh`) installed.
- **Developer Mode on** (Settings → System → For developers), so that unsigned `installer.msix` can be
  installed.
- **Runner service running as a local administrator user, not LocalSystem.** `run-tests.ps1` requires
  elevation, and WSL distributions are per user.
  ```powershell
  .\config.cmd --url https://github.com/l0rd/build-wsl --token <token> `
      --labels wslc --runasservice --windowslogonaccount .\wslci --windowslogonpassword <password>
  ```
  The default labels `self-hosted`, `Windows` and `X64` are added automatically. Labels are
  case-insensitive.
- **One runner per machine.** The job already serializes runs through a `concurrency` group. Ideally,
  checkpoint the VM and revert it between runs.
- **Keep the repo's triggers manual.** Do not add `pull_request` workflows to a repo that has this runner
  attached.

## Differences from upstream CI

Upstream CloudTest runs Release builds of signed bundles on fixed images and records ETW traces. This
workflow also builds Release by default, but installs an unsigned `installer.msix`, records no ETW traces,
and runs on whatever machine hosts the runner. To chase a crash or an assertion, run with
`build_type: Debug`.

The vendor `working` branches and the fork branches move over time. `build-info.json` and the `resolve`
job summary record exactly which commits a run built.

arm64 is not covered yet. It would need a `ubuntu-24.04-arm` VHD job (`WSLG_ARCH=aarch64`) and a
`-A arm64` WSL build.
