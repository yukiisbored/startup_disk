#!/usr/bin/env bash
# Build a Linux AppImage for startup_disk.
#
# Requires: flutter, cargo, rinf, and an x86_64 Linux host. Downloads
# appimagetool on first run into build/appimage/.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

ARCH="${ARCH:-x86_64}"
APP_NAME="startup_disk"
DISPLAY_NAME="Startup Disk"
VERSION="$(awk '/^version:/ {split($2, a, "+"); print a[1]; exit}' pubspec.yaml)"

BUNDLE_DIR="build/linux/x64/release/bundle"
APPDIR="build/appimage/${APP_NAME}.AppDir"
TOOL_DIR="build/appimage"
TOOL="${TOOL_DIR}/appimagetool-${ARCH}.AppImage"
OUTPUT="build/appimage/${APP_NAME}-${VERSION}-${ARCH}.AppImage"

echo "==> Building Flutter Linux release bundle"
flutter build linux --release

echo "==> Staging AppDir at ${APPDIR}"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/applications" \
         "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

# Preserve the Flutter bundle layout (binary alongside data/ and lib/) so the
# embedder can locate icudtl.dat and libapp.so via its built-in relative paths
# and the binary's $ORIGIN/lib RPATH.
cp -r "${BUNDLE_DIR}/." "${APPDIR}/usr/bin/"
chmod +x "${APPDIR}/usr/bin/${APP_NAME}"

cp packaging/linux/AppRun "${APPDIR}/AppRun"
chmod +x "${APPDIR}/AppRun"

cp packaging/linux/${APP_NAME}.desktop "${APPDIR}/${APP_NAME}.desktop"
cp packaging/linux/${APP_NAME}.desktop "${APPDIR}/usr/share/applications/${APP_NAME}.desktop"

cp assets/icon/icon.png "${APPDIR}/${APP_NAME}.png"
cp assets/icon/icon.png "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png"

if [ ! -x "${TOOL}" ]; then
  echo "==> Fetching appimagetool"
  mkdir -p "${TOOL_DIR}"
  curl -fL -o "${TOOL}" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod +x "${TOOL}"
fi

echo "==> Packaging AppImage -> ${OUTPUT}"
ARCH="${ARCH}" "${TOOL}" --no-appstream "${APPDIR}" "${OUTPUT}"

echo "==> Built $(realpath "${OUTPUT}")"
