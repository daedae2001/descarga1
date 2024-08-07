import 'package:flutter/material.dart';

abstract class DownloadController implements ChangeNotifier {
  String get fileName;
  String get url;
  DownloadStatus get downloadStatus;
  double get progress;

  // Nuevos getters
  String? get imageUrl;
  String? get groupTitle;
  String? get tvgName;

  // Métodos
  void startDownload();
  void stopDownload();
  void openDownload();
}

enum DownloadStatus { notDownloaded, fetchingDownload, downloaded }
