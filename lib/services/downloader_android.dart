import 'dart:async';
import 'package:flutter/services.dart';
import 'downloader_service.dart';

/// Talks to native Android code (Kotlin) over a MethodChannel + EventChannel.
/// The native side wraps `io.github.junkfood02.youtubedl-android`, which
/// bundles a Python interpreter + yt-dlp + ffmpeg as native libraries — so
/// everything here runs entirely on-device, no server involved.
///
/// See: android_native_snippet/MainActivity.kt for the Kotlin counterpart,
/// and android_native_snippet/build.gradle.snippet for the required deps.
class AndroidDownloaderService implements DownloaderService {
  static const _methodChannel = MethodChannel('media_downloader/ytdlp');
  static const _progressChannel = EventChannel('media_downloader/ytdlp/progress');

  bool _initialized = false;

  @override
  String get platformName => 'Android (local, on-device)';

  @override
  Future<void> init() async {
    if (_initialized) return;
    await _methodChannel.invokeMethod('init');
    _initialized = true;
  }

  @override
  Future<String> getTitle(String url) async {
    final result = await _methodChannel.invokeMethod<String>('getTitle', {'url': url});
    return result ?? 'Unknown title';
  }

  @override
  Stream<DownloadProgress> download(String url, {required String outputDir}) {
    final controller = StreamController<DownloadProgress>();

    // Kick off the native download; the native side pushes progress events
    // over the EventChannel tagged with a processId so multiple concurrent
    // downloads don't get mixed up.
    final processId = DateTime.now().microsecondsSinceEpoch.toString();

    late final StreamSubscription sub;
    sub = _progressChannel.receiveBroadcastStream({'processId': processId}).listen(
      (event) {
        final map = Map<String, dynamic>.from(event as Map);
        final statusStr = map['status'] as String? ?? 'downloading';
        final status = DownloadStatus.values.firstWhere(
          (s) => s.name == statusStr,
          orElse: () => DownloadStatus.downloading,
        );
        controller.add(DownloadProgress(
          percent: (map['percent'] as num?)?.toDouble() ?? 0.0,
          etaSeconds: map['etaSeconds'] as int?,
          status: status,
          message: map['message'] as String?,
          filePath: map['filePath'] as String?,
        ));
        if (status == DownloadStatus.finished || status == DownloadStatus.error) {
          sub.cancel();
          controller.close();
        }
      },
      onError: (e) {
        controller.add(DownloadProgress(
          percent: 0,
          status: DownloadStatus.error,
          message: e.toString(),
        ));
        controller.close();
      },
    );

    _methodChannel.invokeMethod('download', {
      'url': url,
      'outputDir': outputDir,
      'processId': processId,
    }).catchError((e) {
      controller.add(DownloadProgress(
        percent: 0,
        status: DownloadStatus.error,
        message: e.toString(),
      ));
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> updateBinary() async {
    // Maps to YoutubeDL.getInstance().updateYoutubeDL(context, UpdateChannel.STABLE)
    await _methodChannel.invokeMethod('updateBinary');
  }
}
