import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/document.dart';
import '../services/library_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/reader_settings_sheet.dart';
import 'epub_reader_screen.dart';
import 'docx_reader_screen.dart';

class ReaderScreen extends StatefulWidget {
  final Document document;
  const ReaderScreen({super.key, required this.document});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late Document _doc;
  final PdfViewerController _pdfController = PdfViewerController();
  bool _showControls = true;
  bool _showTtsBar = false;
  Timer? _hideTimer;
  Timer? _readingTimer;
  double _fontSize = 16.0;
  ReadingTheme _theme = ReadingTheme.dark;
  ScrollMode _scrollMode = ScrollMode.vertical;
  double _brightness = 1.0;
  bool _hideMargins = false;
  bool _keepScreenAwake = false;
  int _currentPage = 1;
  int _totalPages = 1;
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    _fontSize = _doc.fontSize;
    _theme = _doc.preferredTheme;
    _scrollMode = _doc.scrollMode;
    _brightness = _doc.brightness;
    _hideMargins = _doc.hideMargins;
    _keepScreenAwake = _doc.keepScreenAwake;
    if (_keepScreenAwake) {
      WakelockPlus.enable();
    }
    WidgetsBinding.instance.addObserver(this);
    _tts.initialize();
    _startReadingTimer();
    _scheduleHideControls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveProgress();
      _tts.stop();
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      context.read<LibraryService>().addReadingTime(_doc.id, 30);
    });
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _theme == ReadingTheme.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: BrightnessOverlay(
          brightness: _brightness,
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                _buildReader(),
                if (_showControls) _buildTopBar(),
                if (_showControls) _buildBottomBar(),
                if (_showTtsBar)
                  Positioned(
                    bottom: _showControls ? 120 : 0,
                    left: 0,
                    right: 0,
                    child: TtsControlBar(
                      isPlaying: _tts.isPlaying,
                      speed: _tts.speed,
                      onPlayPause: _toggleTts,
                      onStop: () {
                        _tts.stop();
                        setState(() => _showTtsBar = false);
                      },
                      onSpeedChange: (s) => _tts.setSpeed(s),
                    ),
                  ),
                // Page indicator
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: PageIndicator(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    textColor: _textColor,
                    backgroundColor: _bgColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReader() {
    switch (_doc.type) {
      case DocumentType.pdf:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: _hideMargins ? 0 : 16),
          child: SfPdfViewer.file(
            File(_doc.filePath),
            controller: _pdfController,
            scrollDirection: _scrollMode == ScrollMode.horizontal
                ? PdfScrollDirection.horizontal
                : PdfScrollDirection.vertical,
            pageLayoutMode: _scrollMode == ScrollMode.twoPage
                ? PdfPageLayoutMode.continuous
                : PdfPageLayoutMode.continuous,
            onDocumentLoaded: (details) {
              setState(() => _totalPages = details.document.pages.count);
            },
            onPageChanged: (details) {
              setState(() => _currentPage = details.newPageNumber);
              context.read<LibraryService>().updateReadingProgress(
                    _doc.id,
                    details.newPageNumber,
                    _pdfController.pageCount,
                  );
            },
          ),
        );
      case DocumentType.txt:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: _hideMargins ? 0 : 24),
          child: _TxtReader(
              filePath: _doc.filePath,
              fontSize: _fontSize,
              textColor: _textColor,
              bgColor: _bgColor),
        );
      case DocumentType.epub:
        // Navigate to dedicated EPUB reader
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EpubReaderScreen(document: _doc),
            ),
          );
        });
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        );
      case DocumentType.docx:
        // Navigate to dedicated DOCX reader
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DocxReaderScreen(document: _doc),
            ),
          );
        });
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        );
    }
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgColor, _bgColor.withValues(alpha: 0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    _saveProgress();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: _textColor, size: 20),
                ),
                Expanded(
                  child: Text(_doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textColor)),
                ),
                IconButton(
                  onPressed: _showBookmarkDialog,
                  icon: Icon(Icons.bookmark_add_outlined,
                      color: _textColor, size: 22),
                ),
                IconButton(
                  onPressed: _showSettingsSheet,
                  icon: Icon(Icons.tune_rounded, color: _textColor, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: _showTtsBar ? 160 : 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgColor.withValues(alpha: 0), _bgColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomAction(
                icon:
                    _showTtsBar ? Icons.headphones : Icons.headphones_outlined,
                label: 'Listen',
                color: _showTtsBar
                    ? AppTheme.primary
                    : _textColor.withValues(alpha: 0.7),
                onTap: () {
                  setState(() => _showTtsBar = !_showTtsBar);
                  if (_showTtsBar) _startTts();
                },
              ),
              _BottomAction(
                icon: Icons.bookmark_outline_rounded,
                label: 'Bookmarks',
                color: _textColor.withValues(alpha: 0.7),
                onTap: _showBookmarksSheet,
              ),
              _BottomAction(
                icon: Icons.format_size_rounded,
                label: 'Font',
                color: _textColor.withValues(alpha: 0.7),
                onTap: _showFontSheet,
              ),
              _BottomAction(
                icon: Icons.share_rounded,
                label: 'Share',
                color: _textColor.withValues(alpha: 0.7),
                onTap: _shareDocument,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareDocument() async {
    try {
      final file = XFile(_doc.filePath);
      await Share.shareXFiles(
        [file],
        text: 'Check out this document: ${_doc.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _toggleTts() {
    if (_tts.isPlaying) {
      _tts.pause();
    } else if (_tts.isPaused) {
      _tts.resume();
    } else {
      _startTts();
    }
    setState(() {});
  }

  Future<void> _startTts() async {
    if (_doc.type == DocumentType.txt) {
      // Read file content asynchronously without blocking UI
      try {
        final file = File(_doc.filePath);
        final content = await file.readAsString();
        await _tts.speak(content);
      } catch (e) {
        debugPrint('Error reading file for TTS: $e');
        await _tts.speak('Unable to read file content. Please try again.');
      }
    } else {
      await _tts.speak(
          'Text to speech is ready. Please use this feature with TXT format documents for best results.');
    }
  }

  void _showBookmarkDialog() {
    final controller =
        TextEditingController(text: 'Page ${_pdfController.pageNumber}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Bookmark',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Bookmark name',
            hintStyle: TextStyle(color: AppTheme.textHint),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              final bookmark = Bookmark(
                id: const Uuid().v4(),
                page: _pdfController.pageNumber,
                title: controller.text,
                createdAt: DateTime.now(),
              );
              context.read<LibraryService>().addBookmark(_doc.id, bookmark);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Bookmark added'),
                    backgroundColor: AppTheme.primary),
              );
            },
            child: const Text('Save',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.7,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.textHint,
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bookmarks',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            Expanded(
              child: _doc.bookmarks.isEmpty
                  ? const Center(
                      child: Text('No bookmarks yet',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _doc.bookmarks.length,
                      itemBuilder: (_, i) {
                        final b = _doc.bookmarks[i];
                        return ListTile(
                          leading: const Icon(Icons.bookmark_rounded,
                              color: AppTheme.primary),
                          title: Text(b.title,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14)),
                          subtitle: Text('Page ${b.page}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          onTap: () {
                            _pdfController.jumpToPage(b.page);
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppTheme.error, size: 18),
                            onPressed: () {
                              context
                                  .read<LibraryService>()
                                  .removeBookmark(_doc.id, b.id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSheet() {
    showReaderSettingsSheet(
      context: context,
      currentTheme: _theme,
      currentScrollMode: _scrollMode,
      currentFontSize: _fontSize,
      currentBrightness: _brightness,
      hideMargins: _hideMargins,
      keepScreenAwake: _keepScreenAwake,
      showTtsToggle: true,
      isTtsEnabled: _showTtsBar,
      onThemeChanged: (theme) => setState(() => _theme = theme),
      onScrollModeChanged: (mode) => setState(() => _scrollMode = mode),
      onFontSizeChanged: (size) => setState(() => _fontSize = size),
      onBrightnessChanged: (brightness) => setState(() => _brightness = brightness),
      onHideMarginsChanged: (hide) => setState(() => _hideMargins = hide),
      onKeepScreenAwakeChanged: (awake) => setState(() => _keepScreenAwake = awake),
      onTtsToggled: (enabled) {
        setState(() => _showTtsBar = enabled);
        if (enabled) _startTts();
      },
    );
  }

  void _showSettingsSheet() => _showFontSheet();

  Future<void> _saveProgress() async {
    _doc.fontSize = _fontSize;
    _doc.preferredTheme = _theme;
    _doc.scrollMode = _scrollMode;
    _doc.brightness = _brightness;
    _doc.hideMargins = _hideMargins;
    _doc.keepScreenAwake = _keepScreenAwake;
    await context.read<LibraryService>().updateDocument(_doc);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _readingTimer?.cancel();
    _saveProgress();
    _tts.stop();
    if (_keepScreenAwake) {
      WakelockPlus.disable();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TxtReader extends StatefulWidget {
  final String filePath;
  final double fontSize;
  final Color textColor;
  final Color bgColor;

  const _TxtReader({
    required this.filePath,
    required this.fontSize,
    required this.textColor,
    required this.bgColor,
  });

  @override
  State<_TxtReader> createState() => _TxtReaderState();
}

class _TxtReaderState extends State<_TxtReader> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _content = content;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading TXT file: $e');
      if (mounted) {
        setState(() {
          _content =
              'Error loading file: ${e.toString()}\n\nPlease make sure the file exists and is a valid text file.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      child: Text(_content,
          style: TextStyle(
              fontSize: widget.fontSize,
              color: widget.textColor,
              height: 1.8,
              fontFamily: 'Georgia')),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EPUB Reader - Uses external EPUB viewer
// ══════════════════════════════════════════════════════════════════════════════
class _EpubReader extends StatefulWidget {
  final String filePath;
  final String docId;
  final Color textColor;
  final Color bgColor;

  const _EpubReader({
    required this.filePath,
    required this.docId,
    required this.textColor,
    required this.bgColor,
  });

  @override
  State<_EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<_EpubReader> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded,
                color: AppTheme.primary, size: 64),
            const SizedBox(height: 24),
            const Text('EPUB File Detected',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              widget.filePath.split('/').last,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EPUB Reading Available!',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• EPUB files can be read in ReadFlow\n'
                    '• Supports reflowable text and images\n'
                    '• Chapter navigation built-in\n'
                    '• Reading progress saved automatically\n\n'
                    'For the best experience, consider converting to PDF if you need advanced features like bookmarks and highlighting.',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Go Back to Library',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DOCX Reader - Extract text from DOCX files
// ══════════════════════════════════════════════════════════════════════════════
class _DocxReader extends StatefulWidget {
  final String filePath;
  final double fontSize;
  final Color textColor;
  final Color bgColor;

  const _DocxReader({
    required this.filePath,
    required this.fontSize,
    required this.textColor,
    required this.bgColor,
  });

  @override
  State<_DocxReader> createState() => _DocxReaderState();
}

class _DocxReaderState extends State<_DocxReader> {
  String _content = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocx();
  }

  Future<void> _loadDocx() async {
    try {
      // DOCX files are ZIP archives containing XML
      // For a full implementation, you would need a package like:
      // - docx_to_text: ^0.1.1
      // - archive: ^3.4.0

      // For now, show a helpful message
      if (mounted) {
        setState(() {
          _content = '''DOCX File Detected

Your file: ${widget.filePath.split('/').last}

Unfortunately, DOCX files require special processing to extract text content. 

To read this file:
1. Convert it to PDF using Word or an online converter
2. Or convert it to TXT format
3. Then import the converted file to ReadFlow

We're working on native DOCX support in a future update!

Pro tip: PDF format works best with ReadFlow for formatted documents.''';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading DOCX: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading DOCX file';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          _content,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: widget.textColor,
            height: 1.8,
          ),
        ),
      ),
    );
  }
}
