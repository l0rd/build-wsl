# build-wsl

Build a version of WSL with Podman as WSLC backend using GitHub Actions, and test it.

## Usage

1. Go to **Actions** → **WSLC on Podman (x64)**
2. Click **Run workflow** (defaults: the `wslc-podman-test` branches of `l0rd/WSL`, `l0rd/wslg` and `l0rd/podman`)
3. Wait for the build to complete (~2-3 hours; less when the system VHD is cached)
4. Download `wslc-tests-x64` from the workflow run's **Artifacts** section
5. On an x64 Windows 11 machine with Hyper-V, run `.\run-wslc-tests.ps1 -LogDir C:\wslc-logs` as administrator

To run the tests in the workflow, enable `run_tests`. This requires a self-hosted runner labelled `wslc`:
x64 Windows 11 (not Server) with Hyper-V, Developer Mode on, and the runner service running as an admin user.
