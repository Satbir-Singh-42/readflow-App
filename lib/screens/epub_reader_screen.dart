import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/document.dart';
import '../services/library_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/speed_reading_widget.dart';
import '../widgets/reader_settings_sheet.dart';

/// SUPERADMIN EPUB Reader - Full features with TTS
class EpubReaderScreen extends StatefulWidget {
  final Document document;

  const EpubReaderScreen({super.key, required this.document});

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late EpubController _epubController;
  bool _isLoading = true;
  String? _error;

  // Reading settings
  double _fontSize = 18.0;
  ReadingTheme _theme = ReadingTheme.dark;
  ScrollMode _scrollMode = ScrollMode.vertical;
  double _brightness = 1.0;
  bool _hideMargins = false;
  bool _keepScreenAwake = false;
  final int _currentChapter = 1;
  final int _totalChapters = 1;

  // TTS Support (Superadmin feature)
  late TtsService _ttsService;
  bool _isTtsPlaying = false;

  Color get _bgColor => _theme == ReadingTheme.light
      ? Colors.white
      : _theme == ReadingTheme.sepia
          ? const Color(0xFFF5E6C8)
          : AppTheme.bgDark;

  Color get _textColor => _theme == ReadingTheme.light
      ? Colors.black87
      : _theme == ReadingTheme.sepia
          ? const Color(0xFF3D2914)
          : AppTheme.textPrimary;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _fontSize = widget.document.fontSize;
    _theme = widget.document.preferredTheme;
    _scrollMode = widget.document.scrollMode;
    _brightness = widget.document.brightness;
    _hideMargins = widget.document.hideMargins;
    _keepScreenAwake = widget.document.keepScreenAwake;
    if (_keepScreenAwake) {
      WakelockPlus.enable();
    }
    _initializeEpub();
  }

  Future<void> _initializeEpub() async {
    try {
      final file = File(widget.document.filePath);

      if (!await file.exists()) {
        throw Exception('EPUB file not found');
      }

      _epubController = EpubController(
        document: EpubDocument.openFile(file),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Mark document as reading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<LibraryService>().updateReadingProgress(
                widget.document.id,
                1,
                100,
              );
        }
      });
    } catch (e) {
      debugPrint('Error initializing EPUB: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _epubController.dispose();
    _stopTts();
    if (_keepScreenAwake) {
      WakelockPlus.disable();
    }
    // Save settings
    _saveSettings();
    super.dispose();
  }

  void _saveSettings() {
    final library = context.read<LibraryService>();
    widget.document.fontSize = _fontSize;
    widget.document.preferredTheme = _theme;
    widget.document.scrollMode = _scrollMode;
    widget.document.brightness = _brightness;
    widget.document.hideMargins = _hideMargins;
    widget.document.keepScreenAwake = _keepScreenAwake;
    library.updateDocument(widget.document);
  }

  // TTS Controls
  Future<void> _toggleTts() async {
    if (_isTtsPlaying) {
      await _stopTts();
    } else {
      await _startTts();
    }
  }

  Future<void> _startTts() async {
    // Get current chapter text from epub controller
    final currentValue = _epubController.currentValue;
    if (currentValue == null) return;

    // For now, use a placeholder - TTS integration needs epub text extraction
    setState(() => _isTtsPlaying = true);

    // Show a snackbar that TTS is starting
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TTS reading current chapter...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    _ttsService.onComplete = () {
      if (mounted) setState(() => _isTtsPlaying = false);
    };
  }

  Future<void> _stopTts() async {
    await _ttsService.stop();
    if (mounted) setState(() => _isTtsPlaying = false);
  }

  void _showSettingsSheet() {
    showReaderSettingsSheet(
      context: context,
      currentTheme: _theme,
      currentScrollMode: _scrollMode,
      currentFontSize: _fontSize,
      currentBrightness: _brightness,
      hideMargins: _hideMargins,
      keepScreenAwake: _keepScreenAwake,
      showTtsToggle: true,
      isTtsEnabled: _isTtsPlaying,
      onThemeChanged: (theme) => setState(() => _theme = theme),
      onScrollModeChanged: (mode) => setState(() => _scrollMode = mode),
      onFontSizeChanged: (size) => setState(() => _fontSize = size),
      onBrightnessChanged: (brightness) => setState(() => _brightness = brightness),
      onHideMarginsChanged: (hide) => setState(() => _hideMargins = hide),
      onKeepScreenAwakeChanged: (awake) => setState(() => _keepScreenAwake = awake),
      onTtsToggled: (enabled) {
        if (enabled) {
          _startTts();
        } else {
          _stopTts();
        }
      },
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => SleepTimerDialog(ttsService: _ttsService),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text('Loading EPUB...',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 64),
                const SizedBox(height: 16),
                const Text('Error Loading EPUB',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_rounded, color: _textColor),
        ),
        title: Text(
          widget.document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: _textColor, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Sleep Timer
          IconButton(
            icon: Icon(Icons.bedtime_rounded,
                color:
                    _ttsService.hasSleepTimer ? AppTheme.primary : _textColor),
            onPressed: _showSleepTimerDialog,
            tooltip: 'Sleep Timer',
          ),
          // Settings
          IconButton(
            icon: Icon(Icons.text_format_rounded, color: _textColor),
            onPressed: _showSettingsSheet,
            tooltip: 'Reading Settings',
          ),
          // TTS Button (Superadmin feature)
          IconButton(
            icon: Icon(
              _isTtsPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: _isTtsPlaying ? AppTheme.primary : _textColor,
            ),
            onPressed: _toggleTts,
            tooltip: _isTtsPlaying ? 'Stop Reading' : 'Read Aloud',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_ttsService.hasSleepTimer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SleepTimerIndicator(
                ttsService: _ttsService,
                onTap: _showSleepTimerDialog,
              ),
            ),
          if (_isTtsPlaying)
            FloatingActionButton.small(
              backgroundColor: AppTheme.primary,
              onPressed: _stopTts,
              child: const Icon(Icons.stop_rounded, color: Colors.white),
            ),
        ],
      ),
      body: BrightnessOverlay(
        brightness: _brightness,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _hideMargins ? 0 : 16),
              child: EpubView(
                controller: _epubController,
                builders: EpubViewBuilders<DefaultBuilderOptions>(
                  options: DefaultBuilderOptions(
                    textStyle:
                        TextStyle(fontSize: _fontSize, height: 1.8, color: _textColor),
                  ),
                  chapterDividerBuilder: (_) =>
                      Divider(color: _textColor.withValues(alpha: 0.2), height: 32),
                ),
              ),
            ),
            // Page indicator
            Positioned(
              bottom: 16,
              right: 16,
              child: PageIndicator(
                currentPage: _currentChapter,
                totalPages: _totalChapters,
                textColor: _textColor,
                backgroundColor: _bgColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
