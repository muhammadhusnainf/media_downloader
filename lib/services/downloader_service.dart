import 'dart:io';

import 'downloader_android.dart';
import 'downloader_desktop.dart';

/// Status of an in-progress download.
enum DownloadStatus { starting, downloading, finished, error }

class DownloadProgress {
  final double percent; // 0.0 - 100.0
  final int? etaSeconds;
  final DownloadStatus status;
  final String? message;
  final String? filePath; // populated when status == finished

  DownloadProgress({
    required this.percent,
    this.etaSeconds,
    required this.status,
    this.message,
    this.filePath,
  });

  @override
  String toString() =>
      'DownloadProgress(status: $status, percent: $percent, eta: $etaSeconds, message: $message)';
}

/// Common interface both platform implementations satisfy.
/// Callers (UI code) should only ever talk to this interface —
/// never import the Android or Desktop implementation directly.
abstract class DownloaderService {
  /// Must be called once before any download, e.g. in initState of your root widget.
  Future<void> init();

  /// Fetches metadata (title, formats) without downloading, equivalent to `yt-dlp --dump-json`.
  Future<String> getTitle(String url);

  /// Starts a download and streams progress updates.
  /// [outputDir] should be an absolute path with write access
  /// (see PlatformPaths.defaultDownloadDir()).
  Stream<DownloadProgress> download(String url, {required String outputDir});

  /// Pulls a newer yt-dlp build. On Android this replaces the bundled
  /// binary at runtime; on Desktop this re-downloads the release binary.
  Future<void> updateBinary();

  /// Human-readable platform name, useful for debug UI.
  String get platformName;
}

/// Picks the right implementation for the current OS.
/// iOS is intentionally unsupported here — it needs a remote backend
/// (not included in this scaffold), since neither the "bundle the binary"
/// nor the "bundle a Python interpreter as a .so" tricks work under
/// Apple's sandboxing / App Store review constraints.
class DownloaderServiceFactory {
  static DownloaderService create() {
    if (Platform.isAndroid) {
      return AndroidDownloaderService();
    }
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DesktopDownloaderService();
    }
    throw UnsupportedError(
      'iOS is not supported by this local-only scaffold. '
      'You would need a remote backend server for iOS (see project README).',
    );
  }
}
