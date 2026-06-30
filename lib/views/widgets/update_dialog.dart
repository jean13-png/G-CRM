import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onLater,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _downloadProgress = 0.0;
  UpdateStatus _status = UpdateStatus.available;
  String? _errorMessage;
  String? _localApkPath;

  @override
  void initState() {
    super.initState();
    _status = widget.updateInfo.status;
  }

  Future<void> _startDownload() async {
    setState(() {
      _status = UpdateStatus.downloading;
      _errorMessage = null;
    });

    final updateService = UpdateService();
    final result = await updateService.startFlexibleUpdate(
      apkUrl: widget.updateInfo.apkUrl!,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
    );

    if (!mounted) return;

    if (result.status == UpdateStatus.downloaded) {
      setState(() {
        _status = UpdateStatus.downloaded;
        _localApkPath = result.apkUrl;
      });
    } else if (result.status == UpdateStatus.error) {
      setState(() {
        _status = UpdateStatus.error;
        _errorMessage = result.errorMessage;
      });
    }
  }

  Future<void> _installUpdate() async {
    setState(() {
      _status = UpdateStatus.installing;
    });

    final updateService = UpdateService();
    final result = await updateService.completeFlexibleUpdate(
      apkPath: _localApkPath!,
    );

    if (!mounted) return;

    if (result.status == UpdateStatus.error) {
      setState(() {
        _status = UpdateStatus.error;
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_status == UpdateStatus.available) ...[
              const Icon(
                Icons.system_update,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Mise à jour disponible',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version ${widget.updateInfo.newVersion ?? ""} est disponible',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textLight,
                ),
              ),
              if (widget.updateInfo.updateDescription != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.updateInfo.updateDescription!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: widget.onLater,
                    child: const Text('Plus tard'),
                  ),
                  ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Mettre à jour'),
                  ),
                ],
              ),
            ] else if (_status == UpdateStatus.downloading) ...[
              const Icon(
                Icons.downloading,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Téléchargement en cours',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_downloadProgress.toStringAsFixed(1)}% téléchargé',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
            ] else if (_status == UpdateStatus.downloaded) ...[
              const Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Téléchargement terminé',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prêt à installer la mise à jour',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _installUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Installer'),
              ),
            ] else if (_status == UpdateStatus.installing) ...[
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Installation en cours...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Veuillez suivre les instructions à l\'écran',
                style: TextStyle(fontSize: 14),
              ),
            ] else if (_status == UpdateStatus.error) ...[
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Erreur',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Une erreur est survenue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.updateInfo.apkUrl != null) {
                        _startDownload();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class UpdateHelper {
  static Future<bool> checkAndShowUpdateDialog(BuildContext context) async {
    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdate();

    if (updateInfo.status == UpdateStatus.available) {
      if (!context.mounted) return false;

      await showDialog<UpdateStatus>(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(
          updateInfo: updateInfo,
          onLater: () => Navigator.of(context).pop(),
        ),
      );

      return true;
    }

    return false;
  }

  static Future<void> checkForUpdatesOnStart(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 2));
    await checkAndShowUpdateDialog(context);
  }
