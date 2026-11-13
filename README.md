# build-wsl

Build a version of WSL with Podman as the WSLC backend using GitHub Actions.

## Usage

1. Go to **Actions** → **WSLC on Podman (x64)**
2. Click **Run workflow** (defaults: the `wslc-podman-test` branches of `l0rd/WSL`, `l0rd/wslg` and `l0rd/podman`)
3. Wait for the build to complete
4. Download `wsl-msi-x64` from the workflow run's **Artifacts** section: it contains the `wsl.msi` installer
