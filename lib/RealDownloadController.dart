import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'download_controller.dart';

class RealDownloadController extends DownloadController with ChangeNotifier {
  RealDownloadController({
    required this.fileName,
    required this.url,
    required this.context,
    String? imageUrl,
    String? groupTitle,
    String? tvgName,
    DownloadStatus downloadStatus = DownloadStatus.notDownloaded,
    double progress = 0.0,
  })  : _imageUrl = imageUrl,
        _groupTitle = groupTitle,
        _tvgName = tvgName,
        _downloadStatus = downloadStatus,
        _progress = progress;

  @override
  final String fileName;
  @override
  final String url;
  @override
  final BuildContext context;

  // Campos privados
  String? _imageUrl;
  String? _groupTitle;
  String? _tvgName;

  // Getters
  @override
  String? get imageUrl => _imageUrl;
  @override
  String? get groupTitle => _groupTitle;
  @override
  String? get tvgName => _tvgName;

  // Estado de descarga
  @override
  DownloadStatus _downloadStatus;
  @override
  DownloadStatus get downloadStatus => _downloadStatus;

  @override
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
        _openFile();
      } else {
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

  RealDownloadController copyWith({
    String? fileName,
    String? url,
    BuildContext? context,
    String? imageUrl,
    String? groupTitle,
    String? tvgName,
    DownloadStatus? downloadStatus,
    double? progress,
  }) {
    return RealDownloadController(
      fileName: fileName ?? this.fileName,
      url: url ?? this.url,
      context: context ?? this.context,
      imageUrl: imageUrl ?? this._imageUrl,
      groupTitle: groupTitle ?? this._groupTitle,
      tvgName: tvgName ?? this._tvgName,
      downloadStatus: downloadStatus ?? this._downloadStatus,
      progress: progress ?? this._progress,
    );
  }
}
