import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/document.dart';
import '../services/library_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/speed_reading_widget.dart';
import '../widgets/highlights_search_widget.dart';
import '../widgets/reader_settings_sheet.dart';

/// SUPERADMIN DOCX Reader - Full features with TTS, Speed Reading, Search, Highlights
class DocxReaderScreen extends StatefulWidget {
  final Document document;

  const DocxReaderScreen({super.key, required this.document});

  @override
  State<DocxReaderScreen> createState() => _DocxReaderScreenState();
}

class _DocxReaderScreenState extends State<DocxReaderScreen> {
  String _content = '';
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  double _fontSize = 16.0;
  ReadingTheme _theme = ReadingTheme.dark;
  ScrollMode _scrollMode = ScrollMode.vertical;
  double _brightness = 1.0;
  bool _hideMargins = false;
  bool _keepScreenAwake = false;

  // TTS Support
  late TtsService _ttsService;
  bool _isTtsPlaying = false;

  // Speed Reading Mode
  bool _isSpeedReadingMode = false;

  // Search Mode
  bool _isSearchMode = false;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.document.fontSize;
    _theme = widget.document.preferredTheme;
    _scrollMode = widget.document.scrollMode;
    _brightness = widget.document.brightness;
    _hideMargins = widget.document.hideMargins;
    _keepScreenAwake = widget.document.keepScreenAwake;
    if (_keepScreenAwake) {
      WakelockPlus.enable();
    }
    _ttsService = TtsService();
    _loadDocx();
  }

  Future<void> _loadDocx() async {
    try {
      final file = File(widget.document.filePath);

      if (!await file.exists()) {
        throw Exception('DOCX file not found');
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Extract text from DOCX (runs in background to avoid UI freeze)
      final extractedText = await compute(_extractDocxText, bytes);

      // Update reading progress (moved inside setState callback)
      if (mounted) {
        setState(() {
          _content = extractedText;
          _isLoading = false;
        });

        // Now safe to use context after setState
        context.read<LibraryService>().updateReadingProgress(
              widget.document.id,
              1,
              1, // DOCX is treated as single "page"
            );
      }
    } catch (e) {
      debugPrint('Error loading DOCX: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load DOCX file.\n\n$e';
          _isLoading = false;
        });
      }
    }
  }

  /// Extract text from DOCX file (static method for compute isolation)
  static String _extractDocxText(List<int> bytes) {
    try {
      // DOCX is a ZIP archive
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find document.xml which contains the text
      final documentXml = archive.findFile('word/document.xml');
      if (documentXml == null) {
        return 'Error: Could not find document content in DOCX file.';
      }

      // Parse XML
      final xmlString = String.fromCharCodes(documentXml.content as List<int>);
      final document = XmlDocument.parse(xmlString);

      // Extract text from all <w:t> (text) elements
      final textNodes = document.findAllElements('w:t');
      final buffer = StringBuffer();

      for (var node in textNodes) {
        final text = node.innerText;
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      }

      // Extract paragraphs for better formatting
      final paragraphs = document.findAllElements('w:p');
      final formattedBuffer = StringBuffer();

      for (var para in paragraphs) {
        final paraText =
            para.findAllElements('w:t').map((e) => e.innerText).join('');

        if (paraText.trim().isNotEmpty) {
          formattedBuffer.writeln(paraText);
          formattedBuffer.writeln(); // Add spacing between paragraphs
        }
      }

      final result = formattedBuffer.toString().trim();

      if (result.isEmpty) {
        return 'No text content found in this DOCX file.\n\nThe file might be:\n• Empty\n• Contain only images\n• Be corrupted';
      }

      return result;
    } catch (e) {
      return 'Error extracting text from DOCX:\n\n$e\n\nThe file might be corrupted or use an unsupported DOCX format.';
    }
  }

  Color get _bgColor {
    switch (_theme) {
      case ReadingTheme.dark:
        return AppTheme.bgDark;
      case ReadingTheme.light:
        return const Color(0xFFFAF9F6);
      case ReadingTheme.sepia:
        return const Color(0xFFF4ECD8);
    }
  }

  Color get _textColor {
    switch (_theme) {
      case ReadingTheme.dark:
        return AppTheme.textPrimary;
      case ReadingTheme.light:
        return const Color(0xFF1A1A2E);
      case ReadingTheme.sepia:
        return const Color(0xFF3D2B1F);
    }
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

  @override
  void dispose() {
    _scrollController.dispose();
    _stopTts();
    if (_keepScreenAwake) {
      WakelockPlus.disable();
    }
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
    if (_content.isEmpty) return;
    setState(() => _isTtsPlaying = true);
    await _ttsService.speak(_content);
    _ttsService.onComplete = () {
      if (mounted) setState(() => _isTtsPlaying = false);
    };
  }

  Future<void> _stopTts() async {
    await _ttsService.stop();
    setState(() => _isTtsPlaying = false);
  }

  // Speed Reading Mode
  void _startSpeedReading() {
    if (_content.isEmpty) return;
    _ttsService.startSpeedReading(_content);
    setState(() => _isSpeedReadingMode = true);
  }

  void _stopSpeedReading() {
    _ttsService.stopSpeedReading();
    setState(() => _isSpeedReadingMode = false);
  }

  // Sleep Timer
  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => SleepTimerDialog(ttsService: _ttsService),
    );
  }

  // Search
  void _toggleSearch() {
    setState(() => _isSearchMode = !_isSearchMode);
  }

  // Highlights
  void _showHighlightsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => HighlightsNotesWidget(
          document: widget.document,
          content: _content,
          onHighlightTap: (highlight) {
            Navigator.pop(context);
          },
          onDeleteHighlight: (id) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Speed Reading Full Screen Mode
    if (_isSpeedReadingMode) {
      return Scaffold(
        body: SpeedReadingWidget(
          ttsService: _ttsService,
          onClose: _stopSpeedReading,
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text('Loading DOCX...',
                  style: TextStyle(color: AppTheme.textSecondary)),
              SizedBox(height: 8),
              Text('This may take a moment for large files',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: _textColor),
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
                const Text('Error Loading DOCX',
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
          icon: Icon(Icons.arrow_back_ios_rounded, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.document.title,
          style: TextStyle(color: _textColor, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Search button
          IconButton(
            icon: Icon(Icons.search,
                color: _isSearchMode ? AppTheme.primary : _textColor),
            onPressed: _toggleSearch,
            tooltip: 'Search',
          ),
          // Speed Reading button
          IconButton(
            icon: Icon(Icons.speed_rounded, color: _textColor),
            onPressed: _startSpeedReading,
            tooltip: 'Speed Reading',
          ),
          // More options popup
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: _textColor),
            color: AppTheme.bgElevated,
            onSelected: (value) {
              switch (value) {
                case 'tts':
                  _toggleTts();
                  break;
                case 'sleep':
                  _showSleepTimerDialog();
                  break;
                case 'highlights':
                  _showHighlightsSheet();
                  break;
                case 'settings':
                  _showSettingsSheet();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'tts',
                child: Row(
                  children: [
                    Icon(_isTtsPlaying ? Icons.stop : Icons.volume_up,
                        color: _isTtsPlaying
                            ? AppTheme.primary
                            : AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    Text(_isTtsPlaying ? 'Stop Reading' : 'Read Aloud',
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sleep',
                child: Row(
                  children: [
                    Icon(Icons.bedtime,
                        color: _ttsService.hasSleepTimer
                            ? AppTheme.primary
                            : AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                        _ttsService.hasSleepTimer
                            ? 'Sleep Timer (${_ttsService.sleepMinutesRemaining}m)'
                            : 'Sleep Timer',
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'highlights',
                child: Row(
                  children: [
                    Icon(Icons.highlight, color: AppTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('Highlights & Notes',
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppTheme.textSecondary),
                    SizedBox(width: 12),
                    Text('View Settings',
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // Floating buttons
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sleep timer indicator
          if (_ttsService.hasSleepTimer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SleepTimerIndicator(
                ttsService: _ttsService,
                onTap: _showSleepTimerDialog,
              ),
            ),
          // TTS stop button
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
        child: Column(
          children: [
            // Search panel
            if (_isSearchMode)
              InDocumentSearch(
                content: _content,
                onClose: _toggleSearch,
                onResultTap: (index, match) {
                  // Estimate scroll position based on character index
                  // Approximate: each line ~50 chars, each line ~20px height
                  final estimatedLine = index ~/ 50;
                  final scrollOffset =
                      estimatedLine * 28.0; // fontSize * 1.8 line height

                  _scrollController.animateTo(
                    scrollOffset.clamp(
                        0.0, _scrollController.position.maxScrollExtent),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),

            // Main content
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                        _hideMargins ? 8 : 24, 16, _hideMargins ? 8 : 24, 80),
                    child: SelectableText(
                      _content,
                      style: TextStyle(
                        fontSize: _fontSize,
                        color: _textColor,
                        height: 1.8,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                  // Page indicator (for DOCX, show word count approximation)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: PageIndicator(
                      currentPage: 1,
                      totalPages: 1,
                      textColor: _textColor,
                      backgroundColor: _bgColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
