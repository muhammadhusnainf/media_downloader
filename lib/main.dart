import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'services/downloader_service.dart';

void main() {
  runApp(const MediaDownloaderApp());
}

class MediaDownloaderApp extends StatelessWidget {
  const MediaDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.deepPurple;
    return MaterialApp(
      title: 'Media Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _urlController = TextEditingController();
  late final DownloaderService _service;

  bool _ready = false;
  String? _initError;
  String _downloadPath = '';

  double _percent = 0;
  int? _etaSeconds;
  DownloadStatus _status = DownloadStatus.starting;
  String? _statusMessage;
  String? _lastFilePath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _service = DownloaderServiceFactory.create();
      await _service.init();
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        _downloadPath = dir.path;
        _ready = true;
      });
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  Future<void> _pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download folder',
    );
    if (result != null) {
      setState(() => _downloadPath = result);
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _downloadPath.isEmpty) return;

    setState(() {
      _busy = true;
      _percent = 0;
      _status = DownloadStatus.starting;
      _statusMessage = null;
      _lastFilePath = null;
    });

    final stream = _service.download(url, outputDir: _downloadPath);

    stream.listen(
      (progress) {
        setState(() {
          _percent = progress.percent;
          _etaSeconds = progress.etaSeconds;
          _status = progress.status;
          _statusMessage = progress.message;
          if (progress.filePath != null) _lastFilePath = progress.filePath;
        });
        if (progress.status == DownloadStatus.finished ||
            progress.status == DownloadStatus.error) {
          setState(() => _busy = false);
        }
      },
      onError: (e) {
        setState(() {
          _busy = false;
          _status = DownloadStatus.error;
          _statusMessage = e.toString();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Media Downloader'),
            actions: [
              if (_ready)
                IconButton(
                  tooltip: 'Update yt-dlp',
                  icon: const Icon(Icons.system_update_alt_rounded),
                  onPressed: _busy
                      ? null
                      : () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Updating yt-dlp…')),
                          );
                          try {
                            await _service.updateBinary();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('yt-dlp updated ✓')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e')),
                              );
                            }
                          }
                        },
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.list(
              children: [
                if (!_ready) _buildInitState(scheme),
                if (_ready) ...[
                  _buildBadge(scheme),
                  const SizedBox(height: 20),
                  _buildUrlCard(scheme),
                  const SizedBox(height: 16),
                  _buildPathCard(scheme),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startDownload,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _busy ? 'Downloading…' : 'Download',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (_status != DownloadStatus.starting) ...[
                    const SizedBox(height: 24),
                    _buildProgressCard(scheme),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            _service.platformName,
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Media URL',
                    style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/watch?v=...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Save to',
                    style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _downloadPath.isEmpty ? 'No folder selected' : _downloadPath,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _downloadPath.isEmpty ? scheme.outline : scheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _busy ? null : _pickDirectory,
                  icon: const Icon(Icons.drive_folder_upload_rounded),
                  tooltip: 'Browse…',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitState(ColorScheme scheme) {
    if (_initError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to initialize downloader',
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(_initError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildProgressCard(ColorScheme scheme) {
    final isError = _status == DownloadStatus.error;
    final isDone = _status == DownloadStatus.finished;

    return Card(
      elevation: 0,
      color: isError
          ? scheme.errorContainer
          : isDone
              ? scheme.tertiaryContainer
              : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isError && !isDone) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _percent / 100,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_percent.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_etaSeconds != null) Text('ETA ${_etaSeconds}s'),
                ],
              ),
            ],
            if (isDone)
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved${_lastFilePath != null ? ': $_lastFilePath' : ''}',
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            if (isError)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_rounded, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage ?? 'Unknown error',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
