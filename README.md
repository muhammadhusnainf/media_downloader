# Media Downloader

A Flutter desktop app for downloading media via [yt-dlp](https://github.com/yt-dlp/yt-dlp) — runs entirely locally, no backend server involved.

![screenshot placeholder — add a GIF/screenshot of the app here]

## Features

- Paste a URL, pick a save folder, hit download
- Live progress bar with percentage + ETA
- One-click yt-dlp self-update, so extractors don't go stale
- Clean Material 3 UI, light/dark mode

## How it works

The app bundles the [yt-dlp](https://github.com/yt-dlp/yt-dlp) executable and calls it directly as a subprocess from Dart (`Process.start`) — no Python install, no remote server, everything runs on your machine.

```
Flutter UI  →  Process.start()  →  bundled yt-dlp.exe  →  downloaded file
```

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and enable Windows desktop support:
   ```bash
   flutter config --enable-windows-desktop
   ```
2. Clone this repo and get dependencies:
   ```bash
   flutter pub get
   ```
3. Fetch the yt-dlp binary:
   ```bash
   bash scripts/fetch_desktop_binaries.sh
   ```
4. Grab an `ffmpeg` build for Windows (needed to merge separate video/audio streams) from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/), and place `ffmpeg.exe` next to `yt-dlp.exe` in `assets/bin/windows/`.
5. Copy both into `build/windows/x64/runner/Debug/bin/` (create the `bin` folder if it doesn't exist) — this is where the app looks for them at runtime.
6. Run it:
   ```bash
   flutter run -d windows
   ```

## Tech stack

- Flutter (Windows desktop)
- yt-dlp (bundled binary)
- `file_picker` for the folder browser, `path_provider` for default paths

## A note on use

This app is a general-purpose wrapper around yt-dlp. Downloading content may be subject to the terms of service of the platform you're downloading from, as well as applicable copyright law — that responsibility sits with however you use it, not with the tool itself.

## License

This project bundles [yt-dlp](https://github.com/yt-dlp/yt-dlp) (Unlicense/public domain). This repo's own code is licensed under [MIT](LICENSE) — add a `LICENSE` file if you haven't yet.

## Credits

Built with [yt-dlp](https://github.com/yt-dlp/yt-dlp).
