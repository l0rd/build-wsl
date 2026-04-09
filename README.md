# build-wsl

Build WSL from source using GitHub Actions. Fork this repo to build any commit from [microsoft/WSL](https://github.com/microsoft/WSL).

## Usage

1. **Fork** this repository
2. Go to **Actions** → **Build WSL MSI**
3. Click **Run workflow**
4. Enter the WSL commit SHA you want to build (from [microsoft/WSL commits](https://github.com/microsoft/WSL/commits/master))
5. Wait for the build to complete (~20-45 minutes)
6. Download the MSI from the workflow run's **Artifacts** section
