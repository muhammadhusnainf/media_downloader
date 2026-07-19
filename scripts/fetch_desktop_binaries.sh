#!/usr/bin/env bash
# Downloads yt-dlp release binaries for desktop platforms.
# Run this once during your build setup (or wire it into CI).
# You still need to fetch/bundle ffmpeg separately per platform —
# ffmpeg isn't distributed by the yt-dlp project itself.
#
# Usage: ./fetch_desktop_binaries.sh
set -euo pipefail

DEST="./assets/bin"
mkdir -p "$DEST/windows" "$DEST/macos" "$DEST/linux"

BASE="https://github.com/yt-dlp/yt-dlp/releases/latest/download"

echo "Fetching yt-dlp for Windows..."
curl -L -o "$DEST/windows/yt-dlp.exe" "$BASE/yt-dlp.exe"

echo "Fetching yt-dlp for macOS..."
curl -L -o "$DEST/macos/yt-dlp_macos" "$BASE/yt-dlp_macos"
chmod +x "$DEST/macos/yt-dlp_macos"

echo "Fetching yt-dlp for Linux..."
curl -L -o "$DEST/linux/yt-dlp_linux" "$BASE/yt-dlp_linux"
chmod +x "$DEST/linux/yt-dlp_linux"

echo "Done. Remember to also grab ffmpeg builds (e.g. from"
echo "https://www.gyan.dev/ffmpeg/builds/ for Windows, or your"
echo "package manager / evermeet.cx for macOS) and place them"
echo "alongside yt-dlp in each platform folder."
echo ""
echo "At package/release time, copy the folder matching the target"
echo "platform (assets/bin/<platform>/*) into a 'bin/' folder next to"
echo "your compiled executable — see lib/services/downloader_desktop.dart"
echo "for the exact path it expects."
