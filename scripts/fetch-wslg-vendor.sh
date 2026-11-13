#!/usr/bin/env bash
# Populate the WSLg vendor/ directory as described in WSLg config/BUILD.md,
# pinned to exact commits so that every job of a run builds the same sources.
#
# Usage: fetch-wslg-vendor.sh <vendor-dir>
# Environment:
#   FREERDP_SHA, WESTON_SHA, PULSEAUDIO_SHA   commits of the microsoft/*-mirror "working" branches
#   MESA_VERSION                              e.g. 23.1.0
#   DIRECTX_HEADERS_VERSION                   e.g. 1.608.0 (without the leading "v")
set -euo pipefail

vendor=${1:?usage: fetch-wslg-vendor.sh <vendor-dir>}
: "${FREERDP_SHA:?}" "${WESTON_SHA:?}" "${PULSEAUDIO_SHA:?}" "${MESA_VERSION:?}" "${DIRECTX_HEADERS_VERSION:?}"

mkdir -p "$vendor"

# fetch_commit <url> <sha> <dest>: shallow checkout of one commit.
fetch_commit() {
    local url=$1 sha=$2 dest=$3
    rm -rf "$dest"
    git init -q "$dest"
    git -C "$dest" remote add origin "$url"
    git -C "$dest" fetch -q --depth 1 origin "$sha"
    git -C "$dest" checkout -q --detach FETCH_HEAD
    echo "$dest: $(git -C "$dest" rev-parse HEAD)"
}

fetch_commit https://github.com/microsoft/FreeRDP-mirror.git "$FREERDP_SHA" "$vendor/FreeRDP"
fetch_commit https://github.com/microsoft/weston-mirror.git "$WESTON_SHA" "$vendor/weston"
fetch_commit https://github.com/microsoft/pulseaudio-mirror.git "$PULSEAUDIO_SHA" "$vendor/pulseaudio"

rm -rf "$vendor/mesa" "$vendor/mesa-$MESA_VERSION"
curl -fsSL --retry 3 "https://azurelinuxsrcstorage.blob.core.windows.net/sources/core/mesa-$MESA_VERSION.tar.xz" \
    | tar -xJ -C "$vendor"
mv "$vendor/mesa-$MESA_VERSION" "$vendor/mesa"
echo "$vendor/mesa: $MESA_VERSION"

rm -rf "$vendor/DirectX-Headers-1.0" "$vendor/DirectX-Headers-$DIRECTX_HEADERS_VERSION"
curl -fsSL --retry 3 "https://github.com/microsoft/DirectX-Headers/archive/refs/tags/v$DIRECTX_HEADERS_VERSION.tar.gz" \
    | tar -xz -C "$vendor"
mv "$vendor/DirectX-Headers-$DIRECTX_HEADERS_VERSION" "$vendor/DirectX-Headers-1.0"
echo "$vendor/DirectX-Headers-1.0: v$DIRECTX_HEADERS_VERSION"
