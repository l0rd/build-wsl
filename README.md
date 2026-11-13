# build-wsl: WSLC on Podman

GitHub Actions that build and test WSLC (WSL containers) with Podman as the container backend, from
forks of WSL, WSLg and Podman. Forked from [chemwolf6922/build-wsl](https://github.com/chemwolf6922/build-wsl).

## Usage

1. Go to **Actions** → **WSLC on Podman (x64)** → **Run workflow**.
2. Pick the repositories and refs (defaults: the `wslc-podman-test` branches of `l0rd/WSL`, `l0rd/wslg`
   and `l0rd/podman`) and the build type (default `Release`).
3. Download the artifacts from the run:
   - `system-vhd-x64`: the WSLg system VHD built with Podman
   - `wslc-tests-x64`: a WSL x64 `installer.msix` with that VHD inside, `wsltests.dll`, TAEF, the
     test distro and data, and `run-wslc-tests.ps1`
   - `wsl-symbols-x64`: PDBs

With `run_tests` enabled, the workflow also runs the WSLC tests on a self-hosted x64 runner with
Hyper-V. GitHub-hosted runners cannot boot the WSLC VM.

See [docs/wslc-podman-ci.md](docs/wslc-podman-ci.md) for how the jobs work and how to set up the runner.
