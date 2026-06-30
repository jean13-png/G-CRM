import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

enum UpdateStatus {
  notAvailable,
  available,
  downloadStarted,
  downloading,
  downloaded,
  installing,
  error,
}

class UpdateInfo {
  final UpdateStatus status;
  final double? downloadProgress;
  final String? errorMessage;
  final String? newVersion;
  final int? newBuildNumber;
  final String? apkUrl;
  final String? updateDescription;

  UpdateInfo({
    required this.status,
    this.downloadProgress,
    this.errorMessage,
    this.newVersion,
    this.newBuildNumber,
    this.apkUrl,
    this.updateDescription,
  });
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // TODO: Replace this with your actual update server URL
  // Example JSON structure:
  // {
  //   "version": "1.0.1",
  //   "buildNumber": 2,
  //   "apkUrl": "https://your-server.com/app-release.apk",
  //   "description": "Nouvelles fonctionnalités et corrections de bugs"
  // }
  static const String updateCheckUrl = 'https://your-server.com/update.json';

  CancelToken? _downloadCancelToken;

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await Dio().get(updateCheckUrl);
      final data = response.data;

      final newVersion = data['version'] as String?;
      final newBuildNumber = data['buildNumber'] as int?;
      final apkUrl = data['apkUrl'] as String?;
      final description = data['description'] as String?;

      if (newBuildNumber != null && newBuildNumber > currentBuildNumber) {
        return UpdateInfo(
          status: UpdateStatus.available,
          newVersion: newVersion,
          newBuildNumber: newBuildNumber,
          apkUrl: apkUrl,
          updateDescription: description,
        );
      }

      return UpdateInfo(
        status: UpdateStatus.notAvailable,
        newVersion: currentVersion,
        newBuildNumber: currentBuildNumber,
      );
    } catch (e) {
      debugPrint("Error checking for update: $e");
      return UpdateInfo(
        status: UpdateStatus.error,
        errorMessage: 'Impossible de vérifier les mises à jour',
      );
    }
  }

  Future<UpdateInfo> startFlexibleUpdate({
    required Function(double) onProgress,
    required String apkUrl,
  }) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          return UpdateInfo(
            status: UpdateStatus.error,
            errorMessage: 'Permission de stockage refusée',
          );
        }
      }

      _downloadCancelToken = CancelToken();

      final directory = await getExternalStorageDirectory();
      final savePath = '${directory?.path}/g_crm_update.apk';

      // Delete existing file if present
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      await Dio().download(
        apkUrl,
        savePath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total) * 100;
            onProgress(progress);
          }
        },
      );

      return UpdateInfo(
        status: UpdateStatus.downloaded,
        apkUrl: savePath,
      );
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        return UpdateInfo(
          status: UpdateStatus.error,
          errorMessage: 'Téléchargement annulé',
        );
      }
      debugPrint("Error starting download: $e");
      return UpdateInfo(
        status: UpdateStatus.error,
        errorMessage: 'Erreur lors du téléchargement: $e',
      );
    }
  }

  Future<UpdateInfo> completeFlexibleUpdate({required String apkPath}) async {
    try {
      final result = await OpenFilex.open(apkPath);
      if (result.type == ResultType.done) {
        return UpdateInfo(status: UpdateStatus.installing);
      } else {
        return UpdateInfo(
          status: UpdateStatus.error,
          errorMessage: 'Impossible d\'ouvrir le fichier APK',
        );
      }
    } catch (e) {
      debugPrint("Error installing update: $e");
      return UpdateInfo(
        status: UpdateStatus.error,
        errorMessage: 'Erreur lors de l\'installation: $e',
      );
    }
  }

  void cancelDownload() {
    _downloadCancelToken?.cancel();
  }

  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return 'Inconnu';
    }
  }

  static Future<int> getCurrentBuildNumber() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return int.tryParse(packageInfo.buildNumber) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
