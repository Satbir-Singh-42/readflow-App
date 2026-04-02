import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf_lib;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xml/xml.dart';

import '../models/document.dart';
import '../services/library_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/speed_reading_widget.dart';
import '../widgets/highlights_search_widget.dart';

/// Unified Reader Screen - Handles PDF, EPUB, DOCX, TXT with all features
class UnifiedReaderScreen extends StatefulWidget {
  final Document document;

  const UnifiedReaderScreen({super.key, required this.document});

  @override
  State<UnifiedReaderScreen> createState() => _UnifiedReaderScreenState();
}

class _UnifiedReaderScreenState extends State<UnifiedReaderScreen>
    with WidgetsBindingObserver {
  // Document state
  late Document _doc;
  bool _isLoading = true;
  String? _error;
  String _extractedText = '';
  Map<int, String> _pdfPageTexts = {}; // Cache of extracted PDF page texts

  // Controllers
  PdfViewerController? _pdfController;
  EpubController? _epubController;
  ScrollController? _scrollController;

  // UI state
  bool _showControls = true;
  bool _showTtsBar = false;
  bool _isSearchMode = false;
  Timer? _hideTimer;
  Timer? _readingTimer;

  // Reading settings
  double _fontSize = 16.0;
  ReadingTheme _theme = ReadingTheme.dark;
  ScrollMode _scrollMode = ScrollMode.vertical;
  double _brightness = 1.0;
  bool _hideMargins = false;
  bool _keepScreenAwake = false;

  // Page/Chapter tracking
  int _currentPage = 1;
  int _totalPages = 1;
  final String _currentChapterTitle = '';

  // TTS
  late TtsService _tts;
  bool _isTtsPlaying = false;

  // Theme colors
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
  void initState() {
    super.initState();
    _doc = widget.document;
    _loadSettings();
    _tts = TtsService();
    _tts.initialize();
    WidgetsBinding.instance.addObserver(this);

    if (_keepScreenAwake) {
      WakelockPlus.enable();
    }

    _initializeReader();
    _startReadingTimer();
    _scheduleHideControls();
  }

  void _loadSettings() {
    _fontSize = _doc.fontSize;
    _theme = _doc.preferredTheme;
    _scrollMode = _doc.scrollMode;
    _brightness = _doc.brightness;
    _hideMargins = _doc.hideMargins;
    _keepScreenAwake = _doc.keepScreenAwake;
  }

  Future<void> _initializeReader() async {
    try {
      final file = File(_doc.filePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${_doc.filePath}');
      }

      switch (_doc.type) {
        case DocumentType.pdf:
          _pdfController = PdfViewerController();
          // Extract PDF text in background for TTS
          final bytes = await file.readAsBytes();
          _pdfPageTexts = await compute(_extractAllPdfText, bytes);
          break;

        case DocumentType.epub:
          _epubController = EpubController(
            document: EpubDocument.openFile(file),
          );
          break;

        case DocumentType.docx:
          _scrollController = ScrollController();
          final bytes = await file.readAsBytes();
          _extractedText = await compute(_extractDocxText, bytes);
          _totalPages =
              (_extractedText.split(' ').length / 250).ceil().clamp(1, 9999);
          break;

        case DocumentType.txt:
          _scrollController = ScrollController();
          _extractedText = await file.readAsString();
          _totalPages =
              (_extractedText.split(' ').length / 250).ceil().clamp(1, 9999);
          break;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error initializing reader: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Extracts text from all pages of a PDF document
  static Map<int, String> _extractAllPdfText(List<int> bytes) {
    final Map<int, String> pageTexts = {};
    try {
      final pdfDocument = pdf_lib.PdfDocument(inputBytes: bytes);
      
      for (int i = 0; i < pdfDocument.pages.count; i++) {
        final textExtractor = pdf_lib.PdfTextExtractor(pdfDocument);
        final text = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
        pageTexts[i + 1] = text.trim();
      }
      
      pdfDocument.dispose();
    } catch (e) {
      debugPrint('Error extracting PDF text: $e');
    }
    return pageTexts;
  }

  static String _extractDocxText(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = archive.findFile('word/document.xml');
      if (documentXml == null) {
        return 'Error: Could not find document content in DOCX file.';
      }

      final xmlString = String.fromCharCodes(documentXml.content as List<int>);
      final document = XmlDocument.parse(xmlString);
      final paragraphs = document.findAllElements('w:p');
      final buffer = StringBuffer();

      for (var para in paragraphs) {
        final paraText =
            para.findAllElements('w:t').map((e) => e.innerText).join('');
        if (paraText.trim().isNotEmpty) {
          buffer.writeln(paraText);
          buffer.writeln();
        }
      }

      final result = buffer.toString().trim();
      return result.isEmpty
          ? 'No text content found in this DOCX file.'
          : result;
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<LibraryService>().addReadingTime(_doc.id, 30);
      }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveSettings();
      _tts.stop();
    }
  }

  Future<void> _saveSettings() async {
    _doc.fontSize = _fontSize;
    _doc.preferredTheme = _theme;
    _doc.scrollMode = _scrollMode;
    _doc.brightness = _brightness;
    _doc.hideMargins = _hideMargins;
    _doc.keepScreenAwake = _keepScreenAwake;
    _doc.currentPage = _currentPage;
    _doc.readingProgress = _totalPages > 0 ? _currentPage / _totalPages : 0;
    await context.read<LibraryService>().updateDocument(_doc);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _readingTimer?.cancel();
    _saveSettings();
    _tts.stop();
    _pdfController?.dispose();
    _epubController?.dispose();
    _scrollController?.dispose();
    if (_keepScreenAwake) {
      WakelockPlus.disable();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TTS FUNCTIONALITY - REAL IMPLEMENTATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleTts() async {
    if (_tts.isPlaying) {
      await _tts.pause();
    } else if (_tts.isPaused) {
      await _tts.resume();
    } else {
      await _startTts();
    }
    setState(() => _isTtsPlaying = _tts.isPlaying);
  }

  Future<void> _startTts() async {
    String textToRead = '';

    switch (_doc.type) {
      case DocumentType.txt:
      case DocumentType.docx:
        textToRead = _extractedText;
        break;

      case DocumentType.epub:
        // Extract current chapter text from EPUB
        final currentValue = _epubController?.currentValue;
        if (currentValue != null) {
          // Get chapter content from the paragraph element
          textToRead = _extractEpubChapterText(currentValue);
        }
        break;

      case DocumentType.pdf:
        // Read current page or all pages based on user preference
        if (_pdfController != null) {
          // Get current page text
          final pageText = await _extractPdfPageText(_pdfController!.pageNumber);
          if (pageText.isNotEmpty) {
            textToRead = pageText;
          } else {
            // If current page has no text, try to get full document
            textToRead = _getAllPdfText();
          }
        }
        break;
    }

    if (textToRead.isNotEmpty) {
      setState(() => _isTtsPlaying = true);
      _tts.onComplete = () {
        if (mounted) setState(() => _isTtsPlaying = false);
      };
      await _tts.speak(textToRead);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_doc.type == DocumentType.pdf 
              ? 'This PDF appears to be scanned. Text extraction is not available for image-based PDFs.'
              : 'No text content available to read'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _extractEpubChapterText(dynamic value) {
    // Extract text from current chapter's paragraphs
    try {
      final chapter = value?.chapter;
      if (chapter == null) return '';

      // Get the HTML content and extract plain text
      final content = chapter.HtmlContent ?? '';
      // Simple HTML tag removal - extract text content
      final plainText = content
          .replaceAll(
              RegExp(r'<style[^>]*>.*?</style>', multiLine: true, dotAll: true),
              '')
          .replaceAll(
              RegExp(r'<script[^>]*>.*?</script>',
                  multiLine: true, dotAll: true),
              '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return plainText;
    } catch (e) {
      debugPrint('Error extracting EPUB text: $e');
      return '';
    }
  }

  Future<String> _extractPdfPageText(int pageNumber) async {
    // Use pre-extracted text from initialization
    if (_pdfPageTexts.containsKey(pageNumber)) {
      return _pdfPageTexts[pageNumber]!;
    }
    
    // If no text available (scanned PDF or extraction failed)
    return '';
  }
  
  /// Get all PDF text for full document TTS
  String _getAllPdfText() {
    final buffer = StringBuffer();
    for (int i = 1; i <= _pdfPageTexts.length; i++) {
      final pageText = _pdfPageTexts[i];
      if (pageText != null && pageText.isNotEmpty) {
        buffer.writeln('Page $i:');
        buffer.writeln(pageText);
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  Future<void> _stopTts() async {
    await _tts.stop();
    if (mounted) setState(() => _isTtsPlaying = false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPEED READING MODE
  // ══════════════════════════════════════════════════════════════════════════

  void _startSpeedReading() {
    String text = '';
    
    switch (_doc.type) {
      case DocumentType.txt:
      case DocumentType.docx:
        text = _extractedText;
        break;
      case DocumentType.epub:
        final value = _epubController?.currentValue;
        if (value != null) {
          text = _extractEpubChapterText(value);
        }
        break;
      case DocumentType.pdf:
        // Use current page text for speed reading
        final pageText = _pdfPageTexts[_currentPage];
        if (pageText != null && pageText.isNotEmpty) {
          text = pageText;
        } else {
          text = _getAllPdfText();
        }
        break;
    }

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_doc.type == DocumentType.pdf 
            ? 'This PDF appears to be scanned. Speed reading is not available for image-based PDFs.'
            : 'No text content available for speed reading'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    _tts.startSpeedReading(text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SpeedReadingWidget(
        ttsService: _tts,
        onClose: () {
          _tts.stopSpeedReading();
          Navigator.pop(context);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH FUNCTIONALITY
  // ══════════════════════════════════════════════════════════════════════════

  void _toggleSearch() {
    setState(() => _isSearchMode = !_isSearchMode);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOOKMARKS
  // ══════════════════════════════════════════════════════════════════════════

  void _showBookmarkDialog() {
    final controller = TextEditingController(
      text: _doc.type == DocumentType.epub
          ? _currentChapterTitle.isNotEmpty
              ? _currentChapterTitle
              : 'Chapter $_currentPage'
          : 'Page $_currentPage',
    );

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
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final bookmark = Bookmark(
                id: const Uuid().v4(),
                page: _currentPage,
                title: controller.text,
                createdAt: DateTime.now(),
              );
              context.read<LibraryService>().addBookmark(_doc.id, bookmark);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bookmark added'),
                  backgroundColor: AppTheme.primary,
                ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                          subtitle: Text(
                              _doc.type == DocumentType.epub
                                  ? 'Chapter ${b.page}'
                                  : 'Page ${b.page}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          onTap: () {
                            _jumpToPage(b.page);
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

  void _jumpToPage(int page) {
    switch (_doc.type) {
      case DocumentType.pdf:
        _pdfController?.jumpToPage(page);
        break;
      case DocumentType.epub:
        // EPUB chapter navigation
        final chapters = _epubController?.tableOfContentsListenable.value;
        if (chapters != null && page > 0 && page <= chapters.length) {
          _epubController?.scrollTo(index: page - 1);
        }
        break;
      case DocumentType.txt:
      case DocumentType.docx:
        // Estimate scroll position for text documents
        if (_scrollController != null && _totalPages > 0) {
          final maxScroll = _scrollController!.position.maxScrollExtent;
          final targetScroll = (page / _totalPages) * maxScroll;
          _scrollController!.animateTo(
            targetScroll.clamp(0.0, maxScroll),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
        break;
    }
    setState(() => _currentPage = page);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GO TO PAGE DIALOG
  // ══════════════════════════════════════════════════════════════════════════

  void _showGoToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _doc.type == DocumentType.epub ? 'Go to Chapter' : 'Go to Page',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter ${_doc.type == DocumentType.epub ? "chapter" : "page"} number (1-$_totalPages)',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? 1;
              if (page >= 1 && page <= _totalPages) {
                _jumpToPage(page);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Please enter a number between 1 and $_totalPages'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('Go',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DOCUMENT ACTIONS (SHARE, EMAIL, SAVE, DELETE)
  // ══════════════════════════════════════════════════════════════════════════

  void _showDocumentActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Share row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: _shareDocument,
                    ),
                    _ActionButton(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      onTap: _emailDocument,
                    ),
                    _ActionButton(
                      icon: Icons.cloud_upload_rounded,
                      label: 'Upload',
                      onTap: _showUploadOptions,
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.bgHighlight),

              // Action list
              _ActionTile(
                icon: Icons.tune_rounded,
                label: 'View Settings',
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsSheet();
                },
              ),
              _ActionTile(
                icon: Icons.arrow_forward_rounded,
                label: _doc.type == DocumentType.epub
                    ? 'Go to Chapter'
                    : 'Go to Page',
                onTap: () {
                  Navigator.pop(context);
                  _showGoToPageDialog();
                },
              ),
              _ActionTile(
                icon: Icons.copy_rounded,
                label: 'Save a Copy',
                onTap: () {
                  Navigator.pop(context);
                  _saveCopy();
                },
              ),
              _ActionTile(
                icon: Icons.timer_rounded,
                label: 'Set Reminder',
                onTap: () {
                  Navigator.pop(context);
                  _showReminderDialog();
                },
              ),
              const Divider(color: AppTheme.bgHighlight),
              _ActionTile(
                icon: Icons.delete_rounded,
                label: 'Delete',
                color: AppTheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareDocument() async {
    Navigator.pop(context);
    try {
      final file = XFile(_doc.filePath);
      await Share.shareXFiles(
        [file],
        text: 'Check out: ${_doc.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unable to share: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _emailDocument() async {
    Navigator.pop(context);
    try {
      final file = XFile(_doc.filePath);
      await Share.shareXFiles(
        [file],
        subject: _doc.title,
        text: 'Sharing "${_doc.title}" from ReadFlow',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unable to email: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showUploadOptions() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cloud upload coming soon!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _saveCopy() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document saved to Downloads'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showReminderDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set Reading Reminder',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Remind me to continue reading:',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReminderChip(label: 'In 1 hour', onTap: () => _setReminder(1)),
                _ReminderChip(label: 'Tonight', onTap: () => _setReminder(6)),
                _ReminderChip(label: 'Tomorrow', onTap: () => _setReminder(24)),
                _ReminderChip(
                    label: 'This weekend', onTap: () => _setReminder(48)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _setReminder(int hours) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Reminder set for ${hours == 1 ? "1 hour" : hours == 6 ? "tonight" : hours == 24 ? "tomorrow" : "this weekend"}'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Document?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${_doc.title}"? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<LibraryService>().deleteDocument(_doc.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close reader
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HIGHLIGHTS
  // ══════════════════════════════════════════════════════════════════════════

  void _showHighlightsSheet() {
    if (_doc.type != DocumentType.docx && _doc.type != DocumentType.txt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Highlights available for text documents'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => HighlightsNotesWidget(
          document: _doc,
          content: _extractedText,
          onHighlightTap: (highlight) => Navigator.pop(context),
          onDeleteHighlight: (id) {
            context.read<LibraryService>().removeHighlight(_doc.id, id);
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SETTINGS SHEET
  // ══════════════════════════════════════════════════════════════════════════

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
      onBrightnessChanged: (brightness) =>
          setState(() => _brightness = brightness),
      onHideMarginsChanged: (hide) => setState(() => _hideMargins = hide),
      onKeepScreenAwakeChanged: (awake) {
        setState(() => _keepScreenAwake = awake);
        if (awake) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      },
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
      builder: (context) => SleepTimerDialog(ttsService: _tts),
    ).then((_) => setState(() {}));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD UI
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('Loading ${_doc.typeLabel}...',
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

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
                // Main content
                Column(
                  children: [
                    // Search bar (if active)
                    if (_isSearchMode &&
                        (_doc.type == DocumentType.txt ||
                            _doc.type == DocumentType.docx))
                      InDocumentSearch(
                        content: _extractedText,
                        onClose: _toggleSearch,
                        onResultTap: (index, match) {
                          final estimatedLine = index ~/ 50;
                          final scrollOffset = estimatedLine * 28.0;
                          _scrollController?.animateTo(
                            scrollOffset.clamp(0.0,
                                _scrollController!.position.maxScrollExtent),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),

                    // Reader content
                    Expanded(child: _buildReaderContent()),
                  ],
                ),

                // Top bar
                if (_showControls) _buildTopBar(),

                // Bottom bar
                if (_showControls) _buildBottomBar(),

                // TTS Control bar
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
                        _stopTts();
                        setState(() => _showTtsBar = false);
                      },
                      onSpeedChange: (s) => _tts.setSpeed(s),
                      onSleepTimer: _showSleepTimerDialog,
                    ),
                  ),

                // Page indicator
                Positioned(
                  bottom: _showTtsBar ? 180 : (_showControls ? 120 : 16),
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

  Widget _buildErrorScreen() {
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
              Text('Error Loading ${_doc.typeLabel}',
                  style: const TextStyle(
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

  Widget _buildReaderContent() {
    switch (_doc.type) {
      case DocumentType.pdf:
        return SfPdfViewer.file(
          File(_doc.filePath),
          controller: _pdfController,
          scrollDirection: _scrollMode == ScrollMode.horizontal
              ? PdfScrollDirection.horizontal
              : PdfScrollDirection.vertical,
          pageLayoutMode: _scrollMode == ScrollMode.twoPage
              ? PdfPageLayoutMode.single
              : PdfPageLayoutMode.continuous,
          onDocumentLoaded: (details) {
            setState(() => _totalPages = details.document.pages.count);
          },
          onPageChanged: (details) {
            setState(() => _currentPage = details.newPageNumber);
            context.read<LibraryService>().updateReadingProgress(
                  _doc.id,
                  details.newPageNumber,
                  _pdfController!.pageCount,
                );
          },
        );

      case DocumentType.epub:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: _hideMargins ? 0 : 16),
          child: EpubView(
            controller: _epubController!,
            builders: EpubViewBuilders<DefaultBuilderOptions>(
              options: DefaultBuilderOptions(
                textStyle: TextStyle(
                  fontSize: _fontSize,
                  height: 1.8,
                  color: _textColor,
                ),
              ),
              chapterDividerBuilder: (_) =>
                  Divider(color: _textColor.withValues(alpha: 0.2), height: 32),
            ),
          ),
        );

      case DocumentType.txt:
      case DocumentType.docx:
        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            _hideMargins ? 8 : 24,
            80,
            _hideMargins ? 8 : 24,
            120,
          ),
          child: SelectableText(
            _extractedText,
            style: TextStyle(
              fontSize: _fontSize,
              color: _textColor,
              height: 1.8,
              fontFamily: 'Georgia',
            ),
          ),
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
                    _saveSettings();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: _textColor, size: 20),
                ),
                Expanded(
                  child: Text(
                    _doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                ),
                // Search (for text documents)
                if (_doc.type == DocumentType.txt ||
                    _doc.type == DocumentType.docx)
                  IconButton(
                    onPressed: _toggleSearch,
                    icon: Icon(
                      Icons.search_rounded,
                      color: _isSearchMode ? AppTheme.primary : _textColor,
                      size: 22,
                    ),
                  ),
                // Highlights (for text documents)
                if (_doc.type == DocumentType.txt ||
                    _doc.type == DocumentType.docx)
                  IconButton(
                    onPressed: _showHighlightsSheet,
                    icon: Icon(Icons.highlight_rounded,
                        color: _textColor, size: 22),
                  ),
                IconButton(
                  onPressed: _showBookmarkDialog,
                  icon: Icon(Icons.bookmark_add_outlined,
                      color: _textColor, size: 22),
                ),
                IconButton(
                  onPressed: _showDocumentActionsSheet,
                  icon: Icon(Icons.more_vert, color: _textColor, size: 22),
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
                label: 'Settings',
                color: _textColor.withValues(alpha: 0.7),
                onTap: _showSettingsSheet,
              ),
              // Speed reading now available for all document types with text
              _BottomAction(
                icon: Icons.speed_rounded,
                label: 'Speed Read',
                color: _textColor.withValues(alpha: 0.7),
                onTap: _startSpeedReading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.textPrimary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textSecondary),
      title:
          Text(label, style: TextStyle(color: color ?? AppTheme.textPrimary)),
      onTap: onTap,
    );
  }
}

class _ReminderChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReminderChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.bgHighlight),
        ),
        child: Text(label,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      ),
    );
  }
}
