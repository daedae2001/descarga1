import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart'; // Asegúrate de añadir este paquete en tu pubspec.yaml

void main() {
  runApp(
    const MaterialApp(
      home: ExampleCupertinoDownloadButton(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

@immutable
class ExampleCupertinoDownloadButton extends StatefulWidget {
  const ExampleCupertinoDownloadButton({super.key});

  @override
  State<ExampleCupertinoDownloadButton> createState() =>
      _ExampleCupertinoDownloadButtonState();
}

class _ExampleCupertinoDownloadButtonState
    extends State<ExampleCupertinoDownloadButton> {
  late final List<DownloadController> _downloadControllers;

  @override
  void initState() {
    super.initState();
    _loadM3UFile();
  }

  Future<void> _loadM3UFile() async {
    // Aquí debes colocar la URL del archivo M3U
    final m3uUrl = 'https://daedae.pro/peliculas1.m3u';
    final response = await Dio().get(m3uUrl);
    final content = response.data as String;

    final entries = _parseM3UContent(content);

    setState(() {
      _downloadControllers = entries.map((entry) {
        return RealDownloadController(
          fileName: path.basename(Uri.parse(entry['url']!).path),
          url: entry['url']!,
          context: context,
          imageUrl: entry['logo'],
          groupTitle: entry['group'],
          tvgName: entry['name'],
        );
      }).toList();
    });
  }

  List<Map<String, String>> _parseM3UContent(String content) {
    final lines = content.split('\n');
    final List<Map<String, String>> entries = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF')) {
        final data = line.substring(8).split(',');
        final metaData = data[0].split(' ');

        final logo = _extractAttribute(metaData, 'tvg-logo');
        final group = _extractAttribute(metaData, 'group-title');
        final name = _extractAttribute(metaData, 'tvg-name');

        final url = lines[i + 1].trim();

        if (url.isNotEmpty) {
          entries.add({
            'logo': logo,
            'group': group,
            'name': name,
            'url': url,
          });
        }
      }
    }

    return entries;
  }

  String _extractAttribute(List<String> attributes, String key) {
    final attribute = attributes.firstWhere(
      (attr) => attr.startsWith('$key="'),
      orElse: () => '',
    );
    return attribute.split('=')[1].replaceAll('"', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download Files')),
      body: ListView.builder(
        itemCount: _downloadControllers.length,
        itemBuilder: _buildListItem,
      ),
    );
  }

  Widget _buildListItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    final downloadController = _downloadControllers[index];

    return ListTile(
      leading: downloadController.imageUrl != null
          ? Image.network(downloadController.imageUrl!)
          : const DemoAppIcon(),
      title: Text(
        downloadController.groupTitle ?? 'Unknown Group',
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge,
      ),
      subtitle: Text(
        downloadController.tvgName ?? 'Unknown Name',
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: SizedBox(
        width: 96,
        child: AnimatedBuilder(
          animation: downloadController,
          builder: (context, child) {
            return DownloadButton(
              status: downloadController.downloadStatus,
              downloadProgress: downloadController.progress,
              onDownload: downloadController.startDownload,
              onCancel: downloadController.stopDownload,
              onOpen: downloadController.openDownload,
              isVideo: downloadController.fileName.endsWith('.mp4') ||
                  downloadController.fileName.endsWith('.mkv') ||
                  downloadController.fileName.endsWith('.avi'),
            );
          },
        ),
      ),
    );
  }
}

@immutable
class DemoAppIcon extends StatelessWidget {
  const DemoAppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 1,
      child: FittedBox(
        child: SizedBox(
          width: 80,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red, Colors.blue],
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Center(
              child: Icon(
                Icons.file_download,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum DownloadStatus {
  notDownloaded,
  fetchingDownload,
  downloading,
  downloaded,
}

class RealDownloadController extends DownloadController with ChangeNotifier {
  RealDownloadController({
    required this.fileName,
    required this.url,
    required this.context,
    this.imageUrl,
    this.groupTitle,
    this.tvgName,
    DownloadStatus downloadStatus = DownloadStatus.notDownloaded,
    double progress = 0.0,
  })  : _downloadStatus = downloadStatus,
        _progress = progress;

  final String fileName;
  final String url;
  final BuildContext context;
  final String? imageUrl;
  final String? groupTitle;
  final String? tvgName;

  DownloadStatus _downloadStatus;
  @override
  DownloadStatus get downloadStatus => _downloadStatus;

  double _progress;
  @override
  double get progress => _progress;

  bool _isDownloading = false;

  @override
  void startDownload() {
    if (downloadStatus == DownloadStatus.notDownloaded) {
      _doDownload();
    }
  }

  @override
  void stopDownload() {
    if (_isDownloading) {
      _isDownloading = false;
      _downloadStatus = DownloadStatus.notDownloaded;
      _progress = 0.0;
      notifyListeners();
    }
  }

  @override
  void openDownload() {
    if (downloadStatus == DownloadStatus.downloaded) {
      if (fileName.endsWith('.mp4') ||
          fileName.endsWith('.mkv') ||
          fileName.endsWith('.avi')) {
        // Si el archivo es un video, abre el archivo.
        _openFile();
      } else {
        // Si no es un video, abre el enlace.
        OpenFile.open(url);
      }
    }
  }

  Future<void> _doDownload() async {
    _isDownloading = true;
    _downloadStatus = DownloadStatus.fetchingDownload;
    notifyListeners();

    try {
      final dir = await getExternalStorageDirectory();
      final downloadPath = dir?.path ?? '';
      final filePath = path.join(downloadPath, fileName);

      final dio = Dio();

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _progress = received / total;
            notifyListeners();
          }
        },
      );

      _downloadStatus = DownloadStatus.downloaded;
    } catch (e) {
      print("Download error: $e");
      _downloadStatus = DownloadStatus.notDownloaded;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _openFile() async {
    final dir = await getExternalStorageDirectory();
    final filePath = path.join(dir?.path ?? '', fileName);

    final file = File(filePath);
    if (await file.exists()) {
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: ${result.message}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File does not exist: $filePath')),
      );
    }
  }
}

@immutable
class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    required this.status,
    this.downloadProgress = 0.0,
    required this.onDownload,
    required this.onCancel,
    required this.onOpen,
    this.isVideo = false,
    this.transitionDuration = const Duration(milliseconds: 500),
  });

  final DownloadStatus status;
  final double downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final bool isVideo;
  final Duration transitionDuration;

  bool get _isDownloading => status == DownloadStatus.downloading;

  bool get _isFetching => status == DownloadStatus.fetchingDownload;

  bool get _isDownloaded => status == DownloadStatus.downloaded;

  void _onPressed() {
    if (isVideo) {
      switch (status) {
        case DownloadStatus.notDownloaded:
          onDownload();
          break;
        case DownloadStatus.fetchingDownload:
          // do nothing.
          break;
        case DownloadStatus.downloading:
          onCancel();
          break;
        case DownloadStatus.downloaded:
          onOpen();
          break;
      }
    } else {
      onOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onPressed,
      child: Stack(
        children: [
          ButtonShapeWidget(
            transitionDuration: transitionDuration,
            isDownloaded: _isDownloaded,
            isDownloading: _isDownloading,
            isFetching: _isFetching,
          ),
          Positioned.fill(
            child: AnimatedOpacity(
              duration: transitionDuration,
              opacity: _isDownloading || _isFetching ? 1.0 : 0.0,
              curve: Curves.ease,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ProgressIndicatorWidget(
                    downloadProgress: downloadProgress,
                    isDownloading: _isDownloading,
                    isFetching: _isFetching,
                  ),
                  if (_isDownloading)
                    const Icon(
                      Icons.stop,
                      size: 14,
                      color: CupertinoColors.activeBlue,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class ButtonShapeWidget extends StatelessWidget {
  const ButtonShapeWidget({
    super.key,
    required this.isDownloading,
    required this.isDownloaded,
    required this.isFetching,
    required this.transitionDuration,
  });

  final bool isDownloading;
  final bool isDownloaded;
  final bool isFetching;
  final Duration transitionDuration;

  @override
  Widget build(BuildContext context) {
    var shape = const ShapeDecoration(
      shape: StadiumBorder(),
      color: CupertinoColors.lightBackgroundGray,
    );

    if (isDownloading || isFetching) {
      shape = ShapeDecoration(
        shape: const CircleBorder(),
        color: Colors.white.withOpacity(0),
      );
    }

    return AnimatedContainer(
      duration: transitionDuration,
      curve: Curves.ease,
      width: double.infinity,
      decoration: shape,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: AnimatedOpacity(
          duration: transitionDuration,
          opacity: isDownloading || isFetching ? 0.0 : 1.0,
          curve: Curves.ease,
          child: Text(
            isDownloaded ? 'OPEN' : 'GET',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue,
                ),
          ),
        ),
      ),
    );
  }
}

@immutable
class ProgressIndicatorWidget extends StatelessWidget {
  const ProgressIndicatorWidget({
    super.key,
    required this.downloadProgress,
    required this.isDownloading,
    required this.isFetching,
  });

  final double downloadProgress;
  final bool isDownloading;
  final bool isFetching;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: downloadProgress),
        duration: const Duration(milliseconds: 200),
        builder: (context, progress, child) {
          return CircularProgressIndicator(
            backgroundColor: isDownloading
                ? CupertinoColors.lightBackgroundGray
                : Colors.white.withOpacity(0),
            valueColor: AlwaysStoppedAnimation(isFetching
                ? CupertinoColors.lightBackgroundGray
                : CupertinoColors.activeBlue),
            strokeWidth: 2,
            value: isFetching ? null : progress,
          );
        },
      ),
    );
  }
}

abstract class DownloadController implements ChangeNotifier {
  String get fileName;
  String get url;
  DownloadStatus get downloadStatus;
  double get progress;

  // Nuevos getters
  String? get imageUrl;
  String? get groupTitle;
  String? get tvgName;

  void startDownload();
  void stopDownload();
  void openDownload();
}
