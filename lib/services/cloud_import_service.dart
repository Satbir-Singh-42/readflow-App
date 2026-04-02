import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

// ============================================================================
// DEMO MODE CONFIGURATION
// ============================================================================
// Set this to false in production to disable demo data.
// When false, cloud features require real OAuth implementation.
// ============================================================================
const bool _kDemoModeEnabled = true;

/// Demo data provider - completely isolated from production code.
/// Remove this class entirely for production release.
class _DemoDataProvider {
  static bool get isEnabled => _kDemoModeEnabled;

  static List<CloudFile> getGoogleDriveFiles() {
    if (!isEnabled) return [];
    return [
      CloudFile(
        id: 'demo_gd1',
        name: '[DEMO] Sample Book.epub',
        size: 2500000,
        type: 'epub',
        source: CloudSource.googleDrive,
        isDemo: true,
      ),
      CloudFile(
        id: 'demo_gd2',
        name: '[DEMO] Document.pdf',
        size: 1500000,
        type: 'pdf',
        source: CloudSource.googleDrive,
        isDemo: true,
      ),
      CloudFile(
        id: 'demo_gd3',
        name: '[DEMO] Notes.txt',
        size: 50000,
        type: 'txt',
        source: CloudSource.googleDrive,
        isDemo: true,
      ),
    ];
  }

  static List<CloudFile> getDropboxFiles() {
    if (!isEnabled) return [];
    return [
      CloudFile(
        id: 'demo_db1',
        name: '[DEMO] Ebook.epub',
        size: 3000000,
        type: 'epub',
        source: CloudSource.dropbox,
        isDemo: true,
      ),
      CloudFile(
        id: 'demo_db2',
        name: '[DEMO] Report.docx',
        size: 800000,
        type: 'docx',
        source: CloudSource.dropbox,
        isDemo: true,
      ),
    ];
  }
}

// ============================================================================
// PRODUCTION CLOUD IMPORT SERVICE
// ============================================================================

/// Cloud Import Service - Google Drive & Dropbox support
/// Note: Full OAuth integration requires google_sign_in and dropbox_client packages
class CloudImportService {
  static final CloudImportService _instance = CloudImportService._internal();
  factory CloudImportService() => _instance;
  CloudImportService._internal();

  bool _isGoogleConnected = false;
  bool _isDropboxConnected = false;

  bool get isGoogleConnected => _isGoogleConnected;
  bool get isDropboxConnected => _isDropboxConnected;
  bool get isDemoMode => _DemoDataProvider.isEnabled;

  /// Connect to Google Drive
  /// In production: implement with google_sign_in package
  Future<bool> connectGoogleDrive() async {
    if (_DemoDataProvider.isEnabled) {
      // Demo mode - simulate connection
      await Future.delayed(const Duration(milliseconds: 800));
      _isGoogleConnected = true;
      return true;
    }

    // final googleSignIn = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/drive.readonly']);
    // final account = await googleSignIn.signIn();
    // if (account != null) {
    //   final auth = await account.authentication;
    //   _googleAccessToken = auth.accessToken;
    //   _isGoogleConnected = true;
    //   return true;
    // }
    return false;
  }

  /// Connect to Dropbox
  /// In production: implement with dropbox_client package
  Future<bool> connectDropbox() async {
    if (_DemoDataProvider.isEnabled) {
      await Future.delayed(const Duration(milliseconds: 800));
      _isDropboxConnected = true;
      return true;
    }

    return false;
  }

  /// Disconnect Google Drive
  void disconnectGoogleDrive() {
    _isGoogleConnected = false;
  }

  /// Disconnect Dropbox
  void disconnectDropbox() {
    _isDropboxConnected = false;
  }

  /// List files from Google Drive
  Future<List<CloudFile>> listGoogleDriveFiles() async {
    if (!_isGoogleConnected) return [];

    if (_DemoDataProvider.isEnabled) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _DemoDataProvider.getGoogleDriveFiles();
    }

    // Use Google Drive API to list files
    // final response = await http.get(
    //   Uri.parse('https://www.googleapis.com/drive/v3/files'),
    //   headers: {'Authorization': 'Bearer $_googleAccessToken'},
    // );
    return [];
  }

  /// List files from Dropbox
  Future<List<CloudFile>> listDropboxFiles() async {
    if (!_isDropboxConnected) return [];

    if (_DemoDataProvider.isEnabled) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _DemoDataProvider.getDropboxFiles();
    }

    return [];
  }

  /// Download file from cloud to local storage
  Future<String?> downloadFile(CloudFile file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final readFlowDir = '${dir.path}/ReadFlow';

      // Create directory if needed
      await Directory(readFlowDir).create(recursive: true);

      if (_DemoDataProvider.isEnabled || file.isDemo) {
        // Demo mode - simulate download
        await Future.delayed(const Duration(seconds: 1));
        debugPrint('[DEMO] Simulated download: ${file.name}');
        // In demo mode, we can't actually create the file
        // Return null to indicate demo limitation
        return null;
      }

      // final response = await http.get(Uri.parse(file.downloadUrl));
      // await File(targetPath).writeAsBytes(response.bodyBytes);
      // return targetPath;

      return null;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }
}

enum CloudSource { googleDrive, dropbox }

class CloudFile {
  final String id;
  final String name;
  final int size;
  final String type;
  final CloudSource source;
  final String? downloadUrl;
  final bool isDemo; // Flag to identify demo data

  CloudFile({
    required this.id,
    required this.name,
    required this.size,
    required this.type,
    required this.source,
    this.downloadUrl,
    this.isDemo = false,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'epub':
        return Icons.menu_book;
      case 'txt':
        return Icons.description;
      case 'docx':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
}

/// Cloud Import Dialog - Shows cloud storage options
class CloudImportDialog extends StatefulWidget {
  final Function(String localPath, String fileName) onFileImported;

  const CloudImportDialog({super.key, required this.onFileImported});

  @override
  State<CloudImportDialog> createState() => _CloudImportDialogState();
}

class _CloudImportDialogState extends State<CloudImportDialog> {
  final _cloudService = CloudImportService();
  List<CloudFile> _files = [];
  bool _isLoading = false;
  CloudSource? _selectedSource;
  CloudFile? _downloadingFile;

  Future<void> _connectGoogleDrive() async {
    setState(() => _isLoading = true);
    final success = await _cloudService.connectGoogleDrive();
    if (success) {
      _selectedSource = CloudSource.googleDrive;
      _files = await _cloudService.listGoogleDriveFiles();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _connectDropbox() async {
    setState(() => _isLoading = true);
    final success = await _cloudService.connectDropbox();
    if (success) {
      _selectedSource = CloudSource.dropbox;
      _files = await _cloudService.listDropboxFiles();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _downloadFile(CloudFile file) async {
    setState(() => _downloadingFile = file);
    final localPath = await _cloudService.downloadFile(file);
    setState(() => _downloadingFile = null);

    if (localPath != null) {
      widget.onFileImported(localPath, file.name);
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to download file'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.cloud_download, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Import from Cloud',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cloud providers
            if (_selectedSource == null) ...[
              _CloudProviderButton(
                icon: Icons.drive_file_move,
                iconColor: Colors.blue,
                title: 'Google Drive',
                subtitle: _cloudService.isGoogleConnected
                    ? 'Connected'
                    : 'Tap to connect',
                isConnected: _cloudService.isGoogleConnected,
                isLoading: _isLoading,
                onTap: _connectGoogleDrive,
              ),
              const SizedBox(height: 12),
              _CloudProviderButton(
                icon: Icons.cloud,
                iconColor: Colors.blue.shade700,
                title: 'Dropbox',
                subtitle: _cloudService.isDropboxConnected
                    ? 'Connected'
                    : 'Tap to connect',
                isConnected: _cloudService.isDropboxConnected,
                isLoading: _isLoading,
                onTap: _connectDropbox,
              ),
            ] else ...[
              // Back button
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedSource = null;
                  _files = [];
                }),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(
                  _selectedSource == CloudSource.googleDrive
                      ? 'Google Drive'
                      : 'Dropbox',
                ),
              ),
              const SizedBox(height: 8),

              // File list
              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final isDownloading = _downloadingFile == file;

                      return ListTile(
                        leading: Icon(file.icon, color: AppTheme.primary),
                        title: Text(file.name,
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(file.sizeFormatted,
                            style: const TextStyle(color: AppTheme.textHint)),
                        trailing: isDownloading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.primary),
                              )
                            : IconButton(
                                onPressed: () => _downloadFile(file),
                                icon: const Icon(Icons.download,
                                    color: AppTheme.primary),
                              ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CloudProviderButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isConnected;
  final bool isLoading;
  final VoidCallback onTap;

  const _CloudProviderButton({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isConnected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: isConnected ? Border.all(color: AppTheme.success) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (isConnected)
              const Icon(Icons.check_circle, color: AppTheme.success)
            else
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
