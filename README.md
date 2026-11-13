# build-wsl

Build WSL from source using GitHub Actions. Fork this repo to build any commit from [microsoft/WSL](https://github.com/microsoft/WSL).

## Usage

1. **Fork** this repository
2. Go to **Actions** → **Build WSL MSI**
3. Click **Run workflow**
4. Enter the WSL commit SHA you want to build (from [microsoft/WSL commits](https://github.com/microsoft/WSL/commits/master))
5. Wait for the build to complete (~20-45 minutes)
6. Download the MSI from the workflow run's **Artifacts** section

## WSLC on Podman (x64)

**Actions** → **WSLC on Podman (x64)** builds the WSLC-on-Podman test bundle from forks of WSL,
WSLg and Podman:
- a system VHD built with Podman
- a WSL x64 package with that VHD inside it
- `wsltests.dll` and TAEF

With `run_tests` enabled, it also runs the WSLC tests on a self-hosted runner.
See [docs/wslc-podman-ci.md](docs/wslc-podman-ci.md).
