import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'downloader_service.dart';

/// Runs the bundled yt-dlp executable directly as a subprocess.
/// Works on Windows / macOS / Linux since those platforms allow
/// running arbitrary bundled binaries (unlike Android/iOS sandboxes).
///
/// IMPORTANT: this expects platform binaries to already be present in
/// `assets/bin/<platform>/`. They are NOT downloaded automatically by
/// this app — run `scripts/fetch_desktop_binaries.sh` once during your
/// build setup (see README). Ship them alongside your app (e.g. via
/// `flutter_distributor` or manual packaging), don't rely on `pub get`.
class DesktopDownloaderService implements DownloaderService {
  @override
  String get platformName => 'Desktop (local, bundled binary)';

  late String _ytDlpPath;
  late String _ffmpegPath;

  @override
  Future<void> init() async {
    final supportDir = await getApplicationSupportDirectory();
    final binDir = Directory('${supportDir.path}/bin');
    if (!binDir.existsSync()) binDir.createSync(recursive: true);

    // Assumes binaries were copied next to the executable at build time.
    // Adjust these paths to match how you package your release build.
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    if (Platform.isWindows) {
      _ytDlpPath = '$exeDir/bin/yt-dlp.exe';
      _ffmpegPath = '$exeDir/bin/ffmpeg.exe';
    } else if (Platform.isMacOS) {
      _ytDlpPath = '$exeDir/bin/yt-dlp_macos';
      _ffmpegPath = '$exeDir/bin/ffmpeg';
    } else {
      _ytDlpPath = '$exeDir/bin/yt-dlp_linux';
      _ffmpegPath = '$exeDir/bin/ffmpeg';
    }

    if (!File(_ytDlpPath).existsSync()) {
      throw StateError(
        'yt-dlp binary not found at $_ytDlpPath.\n'
        'Run scripts/fetch_desktop_binaries.sh and make sure your build '
        'copies the bin/ folder next to the compiled executable.',
      );
    }
  }

  @override
  Future<String> getTitle(String url) async {
    final result = await Process.run(_ytDlpPath, ['--dump-json', '--no-download', url]);
    if (result.exitCode != 0) {
      throw Exception('yt-dlp failed: ${result.stderr}');
    }
    final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    return data['title'] as String? ?? 'Unknown title';
  }

  @override
  Stream<DownloadProgress> download(String url, {required String outputDir}) {
    final controller = StreamController<DownloadProgress>();

    () async {
      final process = await Process.start(_ytDlpPath, [
        '--newline', // forces one progress line per update, easy to parse
        '--ffmpeg-location', _ffmpegPath,
        '-o', '$outputDir/%(title)s.%(ext)s',
        url,
      ]);

      // yt-dlp --newline progress lines look like:
      // [download]  42.1% of 10.00MiB at 1.20MiB/s ETA 00:05
      final progressRegex = RegExp(
        r'\[download\]\s+([\d.]+)% of.*?ETA\s+(\d+):(\d+)',
      );

      String? finalFilePath;
      final destRegex = RegExp(r'\[download\] Destination:\s+(.+)');
      final mergeRegex = RegExp(r'\[Merger\] Merging formats into "(.+)"');

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        final destMatch = destRegex.firstMatch(line);
        if (destMatch != null) finalFilePath = destMatch.group(1);

        final mergeMatch = mergeRegex.firstMatch(line);
        if (mergeMatch != null) finalFilePath = mergeMatch.group(1);

        final match = progressRegex.firstMatch(line);
        if (match != null) {
          final percent = double.tryParse(match.group(1) ?? '0') ?? 0;
          final etaMin = int.tryParse(match.group(2) ?? '0') ?? 0;
          final etaSec = int.tryParse(match.group(3) ?? '0') ?? 0;
          controller.add(DownloadProgress(
            percent: percent,
            etaSeconds: etaMin * 60 + etaSec,
            status: DownloadStatus.downloading,
          ));
        }
      });

      final stderrBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        controller.add(DownloadProgress(
          percent: 100,
          status: DownloadStatus.finished,
          filePath: finalFilePath,
        ));
      } else {
        controller.add(DownloadProgress(
          percent: 0,
          status: DownloadStatus.error,
          message: stderrBuffer.toString(),
        ));
      }
      await controller.close();
    }();

    return controller.stream;
  }

  @override
  Future<void> updateBinary() async {
    // yt-dlp can self-update in place.
    final result = await Process.run(_ytDlpPath, ['-U']);
    if (result.exitCode != 0) {
      throw Exception('yt-dlp self-update failed: ${result.stderr}');
    }
  }
}
