import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';

class ImportResult {
  final int selected;
  final int imported;
  final int skippedDuplicates;
  final int unsupported;
  final int failed;
  final List<Document> importedDocs;

  const ImportResult({
    required this.selected,
    required this.imported,
    required this.skippedDuplicates,
    required this.unsupported,
    required this.failed,
    required this.importedDocs,
  });

  bool get hasChanges => imported > 0;

  String get summary {
    if (selected == 0) return 'Import cancelled';

    final parts = <String>['Imported $imported of $selected'];
    if (skippedDuplicates > 0) parts.add('$skippedDuplicates duplicate');
    if (unsupported > 0) parts.add('$unsupported unsupported');
    if (failed > 0) parts.add('$failed failed');
    return parts.join(' · ');
  }
}

class LibraryService extends ChangeNotifier {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  List<Document> _documents = [];
  ReadingStats _stats = ReadingStats();
  String _sortBy = 'lastRead'; // lastRead, title, author, progress
  String _filterGenre = 'All';
  bool _isPro = false;

  // Cache for expensive computations
  List<Document>? _cachedFilteredSorted;
  String? _cachedSortBy;
  String? _cachedFilterGenre;
  int? _cachedDocumentsHash;

  List<Document>? _cachedFavorites;
  List<Document>? _cachedFinished;
  List<Document>? _cachedReading;
  List<Document>? _cachedRecent;

  List<Document> get documents => _filteredAndSorted;
  ReadingStats get stats => _stats;
  bool get isLoading => false; // Always false - instant loading
  String get sortBy => _sortBy;
  String get filterGenre => _filterGenre;
  bool get isPro => _isPro;

  List<Document> get recentDocuments {
    if (_cachedRecent == null || _documentsChanged) {
      _cachedRecent = [..._documents]
        ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    }
    return _cachedRecent!;
  }

  List<Document> get favoriteDocuments {
    if (_cachedFavorites == null || _documentsChanged) {
      _cachedFavorites = _documents.where((d) => d.isFavorite).toList();
    }
    return _cachedFavorites!;
  }

  List<Document> get finishedDocuments {
    if (_cachedFinished == null || _documentsChanged) {
      _cachedFinished = _documents.where((d) => d.isFinished).toList();
    }
    return _cachedFinished!;
  }

  List<Document> get currentlyReading {
    if (_cachedReading == null || _documentsChanged) {
      _cachedReading = _documents
          .where((d) => d.readingProgress > 0 && !d.isFinished)
          .toList();
    }
    return _cachedReading!;
  }

  bool get _documentsChanged {
    final currentHash = _documents.length.hashCode ^
        _documents.fold(
            0, (h, d) => h ^ d.id.hashCode ^ d.readingProgress.hashCode);
    if (_cachedDocumentsHash != currentHash) {
      _cachedDocumentsHash = currentHash;
      return true;
    }
    return false;
  }

  List<String> get allGenres {
    final genres = _documents
        .map((d) => d.genre)
        .where((g) => g != null)
        .cast<String>()
        .toSet()
        .toList();
    genres.sort();
    return ['All', ...genres];
  }

  List<Document> get _filteredAndSorted {
    // Check if cache is valid
    if (_cachedFilteredSorted != null &&
        _cachedSortBy == _sortBy &&
        _cachedFilterGenre == _filterGenre &&
        !_documentsChanged) {
      return _cachedFilteredSorted!;
    }

    // Rebuild cache
    var docs = [..._documents];
    if (_filterGenre != 'All') {
      docs = docs.where((d) => d.genre == _filterGenre).toList();
    }
    switch (_sortBy) {
      case 'title':
        docs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'author':
        docs.sort((a, b) => a.author.compareTo(b.author));
        break;
      case 'progress':
        docs.sort((a, b) => b.readingProgress.compareTo(a.readingProgress));
        break;
      case 'dateAdded':
        docs.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      default:
        docs.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    }

    // Update cache
    _cachedFilteredSorted = docs;
    _cachedSortBy = _sortBy;
    _cachedFilterGenre = _filterGenre;

    return docs;
  }

  void _invalidateCache() {
    _cachedFilteredSorted = null;
    _cachedFavorites = null;
    _cachedFinished = null;
    _cachedReading = null;
    _cachedRecent = null;
    _cachedDocumentsHash = null;
  }

  Future<void> initialize() async {
    // Load data instantly from storage (no loading indicator)
    await _loadFromStorage();
    await _loadStats();
    await _loadProStatus();
    notifyListeners();

    // Validate files in background (non-blocking)
    if (!kIsWeb) {
      _validateDocumentFiles().then((_) {
        notifyListeners();
      });
    }
  }

  Future<Document?> importDocument() async {
    final result = await importDocuments(allowMultiple: false);
    if (result.importedDocs.isEmpty) return null;
    return result.importedDocs.first;
  }

  Future<ImportResult> importDocuments({bool allowMultiple = true}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'docx'],
        allowMultiple: allowMultiple,
        withData: kIsWeb, // Load bytes on web
      );
      if (result == null || result.files.isEmpty) {
        return const ImportResult(
          selected: 0,
          imported: 0,
          skippedDuplicates: 0,
          unsupported: 0,
          failed: 0,
          importedDocs: [],
        );
      }

      final files = result.files;
      var imported = 0;
      var skippedDuplicates = 0;
      var unsupported = 0;
      var failed = 0;
      final importedDocs = <Document>[];

      // Directory preparation - only for non-web platforms
      String? docsDirPath;
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final docsDir = Directory('${appDir.path}/readflow_docs');
        await docsDir.create(recursive: true);
        docsDirPath = docsDir.path;
      }

      for (final file in files) {
        // On web, file.path is null but we have file.bytes and file.name
        final fileName = file.name;
        final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
        final type = _documentTypeFromExtension(ext);
        if (type == null) {
          unsupported++;
          continue;
        }

        final title = _titleFromFileName(fileName);
        final duplicate = _documents.any((d) =>
            d.type == type &&
            d.fileSize == file.size &&
            d.title.toLowerCase() == title.toLowerCase());
        if (duplicate) {
          skippedDuplicates++;
          continue;
        }

        try {
          String destPath;

          if (kIsWeb) {
            // On web, store a reference path (actual data is in bytes)
            // We'll need to handle web storage differently
            destPath = 'web_storage://${const Uuid().v4()}_$fileName';

            // Store the bytes in SharedPreferences (base64 encoded) for web
            if (file.bytes != null) {
              final prefs = await SharedPreferences.getInstance();
              final base64Data = base64Encode(file.bytes!);
              await prefs.setString('file_$destPath', base64Data);
            }
          } else {
            // On native platforms, copy file to app directory
            final filePath = file.path;
            if (filePath == null) {
              failed++;
              continue;
            }
            final newFileName = '${const Uuid().v4()}_${p.basename(filePath)}';
            destPath = '$docsDirPath/$newFileName';
            await File(filePath).copy(destPath);
          }

          final doc = Document(
            id: const Uuid().v4(),
            title: title,
            author: 'Unknown Author',
            filePath: destPath,
            type: type,
            addedAt: DateTime.now(),
            lastReadAt: DateTime.now(),
            fileSize: file.size,
          );

          importedDocs.add(doc);
          imported++;
        } catch (e) {
          debugPrint('Import file error: $e');
          failed++;
        }
      }

      if (importedDocs.isNotEmpty) {
        _documents.insertAll(0, importedDocs);
        _invalidateCache();
        await _saveToStorage();
        notifyListeners();
      }

      return ImportResult(
        selected: files.length,
        imported: imported,
        skippedDuplicates: skippedDuplicates,
        unsupported: unsupported,
        failed: failed,
        importedDocs: importedDocs,
      );
    } catch (e) {
      debugPrint('Import error: $e');
      return const ImportResult(
        selected: 0,
        imported: 0,
        skippedDuplicates: 0,
        unsupported: 0,
        failed: 1,
        importedDocs: [],
      );
    }
  }

  String _titleFromFileName(String fileName) {
    final rawName = p.basenameWithoutExtension(fileName);
    return rawName.replaceAll(RegExp(r'[_\-]'), ' ').trim();
  }

  /// Import a document from a file path (used by cloud import)
  Future<Document?> importFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
      final type = _documentTypeFromExtension(ext);
      if (type == null) return null;

      final title = _titleFromPath(filePath);
      final fileSize = await file.length();

      // Check for duplicate
      final duplicate = _documents.any((d) =>
          d.type == type &&
          d.fileSize == fileSize &&
          d.title.toLowerCase() == title.toLowerCase());
      if (duplicate) return null;

      // Copy to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/readflow_docs');
      await docsDir.create(recursive: true);

      final fileName = '${const Uuid().v4()}_${p.basename(filePath)}';
      final destPath = '${docsDir.path}/$fileName';
      await file.copy(destPath);

      final doc = Document(
        id: const Uuid().v4(),
        title: title,
        author: 'Unknown Author',
        filePath: destPath,
        type: type,
        addedAt: DateTime.now(),
        lastReadAt: DateTime.now(),
        fileSize: fileSize,
      );

      _documents.add(doc);
      await _saveToStorage();
      notifyListeners();

      return doc;
    } catch (e) {
      debugPrint('Import from path error: $e');
      return null;
    }
  }

  DocumentType? _documentTypeFromExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return DocumentType.pdf;
      case 'epub':
        return DocumentType.epub;
      case 'txt':
        return DocumentType.txt;
      case 'docx':
        return DocumentType.docx;
      default:
        return null;
    }
  }

  String _titleFromPath(String filePath) {
    final rawName = p.basenameWithoutExtension(filePath);
    return rawName.replaceAll(RegExp(r'[_\-]'), ' ').trim();
  }

  Future<void> updateDocument(Document doc) async {
    final index = _documents.indexWhere((d) => d.id == doc.id);
    if (index != -1) {
      _documents[index] = doc;
      _invalidateCache();
      await _saveToStorage();
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String id) async {
    final doc = _documents.firstWhere((d) => d.id == id);
    try {
      final file = File(doc.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _documents.removeWhere((d) => d.id == id);
    _invalidateCache();
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final doc = _documents.firstWhere((d) => d.id == id);
    doc.isFavorite = !doc.isFavorite;
    _invalidateCache();
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> updateReadingProgress(
      String id, int currentPage, int totalPages) async {
    final doc = _documents.firstWhere((d) => d.id == id);
    doc.currentPage = currentPage;
    if (totalPages > 0) doc.readingProgress = currentPage / totalPages;
    doc.lastReadAt = DateTime.now();
    if (doc.readingProgress >= 0.99) doc.isFinished = true;
    _invalidateCache();
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> addReadingTime(String id, int seconds) async {
    final doc = _documents.firstWhere((d) => d.id == id);
    doc.readingTimeSeconds += seconds;
    _invalidateCache();
    await _saveToStorage();
    await _updateStats(seconds);
    notifyListeners();
  }

  Future<void> addBookmark(String docId, Bookmark bookmark) async {
    final doc = _documents.firstWhere((d) => d.id == docId);
    doc.bookmarks.add(bookmark);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> removeBookmark(String docId, String bookmarkId) async {
    final doc = _documents.firstWhere((d) => d.id == docId);
    doc.bookmarks.removeWhere((b) => b.id == bookmarkId);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> addHighlight(String docId, Highlight highlight) async {
    final doc = _documents.firstWhere((d) => d.id == docId);
    doc.highlights.add(highlight);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> removeHighlight(String docId, String highlightId) async {
    final doc = _documents.firstWhere((d) => d.id == docId);
    doc.highlights.removeWhere((h) => h.id == highlightId);
    await _saveToStorage();
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void setFilterGenre(String genre) {
    _filterGenre = genre;
    notifyListeners();
  }

  List<Document> search(String query) {
    if (query.isEmpty) return _filteredAndSorted;
    final q = query.toLowerCase();
    return _documents
        .where((d) =>
            d.title.toLowerCase().contains(q) ||
            d.author.toLowerCase().contains(q) ||
            (d.genre?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('library_documents');
      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        _documents = jsonList.map((j) => Document.fromJson(j)).toList();
        // File validation moved to _validateDocumentFiles() for async processing
      }
    } catch (e) {
      debugPrint('Load error: $e');
      _documents = [];
    }
  }

  Future<void> _validateDocumentFiles() async {
    if (_documents.isEmpty || kIsWeb) return;

    final validDocs = <Document>[];
    for (var doc in _documents) {
      try {
        // Skip web storage paths
        if (doc.filePath.startsWith('web_storage://')) {
          validDocs.add(doc);
          continue;
        }
        final exists = await File(doc.filePath).exists();
        if (exists) {
          validDocs.add(doc);
        } else {
          debugPrint('Removing missing file: ${doc.filePath}');
        }
      } catch (e) {
        debugPrint('File check error for ${doc.filePath}: $e');
      }
    }
    if (validDocs.length != _documents.length) {
      _documents = validDocs;
      _invalidateCache();
      await _saveToStorage();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_documents.map((d) => d.toJson()).toList());
      await prefs.setString('library_documents', jsonStr);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('reading_stats');
      if (jsonStr != null) {
        final j = json.decode(jsonStr);
        _stats = ReadingStats(
          totalBooksRead: j['totalBooksRead'] ?? 0,
          totalPagesRead: j['totalPagesRead'] ?? 0,
          totalReadingSeconds: j['totalReadingSeconds'] ?? 0,
          currentStreak: j['currentStreak'] ?? 0,
          longestStreak: j['longestStreak'] ?? 0,
          dailyMinutes: Map<String, int>.from(j['dailyMinutes'] ?? {}),
        );
      }
    } catch (_) {}
  }

  Future<void> _updateStats(int secondsAdded) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final dailyMinutes = Map<String, int>.from(_stats.dailyMinutes);
      dailyMinutes[today] = (dailyMinutes[today] ?? 0) + (secondsAdded ~/ 60);

      _stats = ReadingStats(
        totalBooksRead: _documents.where((d) => d.isFinished).length,
        totalPagesRead: _documents.fold(0, (s, d) => s + d.currentPage),
        totalReadingSeconds: _stats.totalReadingSeconds + secondsAdded,
        currentStreak: _stats.currentStreak,
        longestStreak: _stats.longestStreak,
        dailyMinutes: dailyMinutes,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'reading_stats',
          json.encode({
            'totalBooksRead': _stats.totalBooksRead,
            'totalPagesRead': _stats.totalPagesRead,
            'totalReadingSeconds': _stats.totalReadingSeconds,
            'currentStreak': _stats.currentStreak,
            'longestStreak': _stats.longestStreak,
            'dailyMinutes': _stats.dailyMinutes,
          }));
    } catch (_) {}
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool('is_pro') ?? false;
  }

  Future<void> unlockPro() async {
    _isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro', true);
    notifyListeners();
  }
}
