import 'package:flutter/material.dart';

enum DocumentType { pdf, epub, txt, docx }

enum ReadingTheme { dark, light, sepia }

enum ScrollMode { vertical, horizontal, twoPage }

class Document {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final DocumentType type;
  final int totalPages;
  int currentPage;
  final DateTime addedAt;
  DateTime lastReadAt;
  final int fileSize; // in bytes
  String? coverImagePath;
  String? genre;
  String? description;
  List<Bookmark> bookmarks;
  List<Highlight> highlights;
  int readingTimeSeconds; // total reading time
  bool isFavorite;
  bool isFinished;
  double readingProgress; // 0.0 to 1.0
  ReadingTheme preferredTheme;
  double fontSize;
  double ttsSpeed;
  int ttsVoiceIndex;
  ScrollMode scrollMode;
  double brightness;
  bool hideMargins;
  bool keepScreenAwake;

  Document({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.type,
    this.totalPages = 0,
    this.currentPage = 0,
    required this.addedAt,
    required this.lastReadAt,
    this.fileSize = 0,
    this.coverImagePath,
    this.genre,
    this.description,
    List<Bookmark>? bookmarks,
    List<Highlight>? highlights,
    this.readingTimeSeconds = 0,
    this.isFavorite = false,
    this.isFinished = false,
    this.readingProgress = 0.0,
    this.preferredTheme = ReadingTheme.dark,
    this.fontSize = 16.0,
    this.ttsSpeed = 1.0,
    this.ttsVoiceIndex = 0,
    this.scrollMode = ScrollMode.vertical,
    this.brightness = 1.0,
    this.hideMargins = false,
    this.keepScreenAwake = false,
  })  : bookmarks = bookmarks ?? [],
        highlights = highlights ?? [];

  String get typeLabel {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF';
      case DocumentType.epub:
        return 'EPUB';
      case DocumentType.txt:
        return 'TXT';
      case DocumentType.docx:
        return 'DOCX';
    }
  }

  String get fileSizeLabel {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get readingTimeLabel {
    final minutes = readingTimeSeconds ~/ 60;
    if (minutes < 60) return '${minutes}m read';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return '${hours}h ${rem}m read';
  }

  int get progressPercent => (readingProgress * 100).round();

  String get estimatedTimeLeft {
    if (readingProgress <= 0 || readingTimeSeconds <= 0) return 'Unknown';
    final rate = readingProgress / readingTimeSeconds;
    if (rate <= 0) return 'Unknown';
    final secondsLeft = ((1.0 - readingProgress) / rate).round();
    final minutes = secondsLeft ~/ 60;
    if (minutes < 60) return '~${minutes}m left';
    return '~${minutes ~/ 60}h left';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'type': type.index,
        'totalPages': totalPages,
        'currentPage': currentPage,
        'addedAt': addedAt.toIso8601String(),
        'lastReadAt': lastReadAt.toIso8601String(),
        'fileSize': fileSize,
        'coverImagePath': coverImagePath,
        'genre': genre,
        'description': description,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'highlights': highlights.map((h) => h.toJson()).toList(),
        'readingTimeSeconds': readingTimeSeconds,
        'isFavorite': isFavorite,
        'isFinished': isFinished,
        'readingProgress': readingProgress,
        'preferredTheme': preferredTheme.index,
        'fontSize': fontSize,
        'ttsSpeed': ttsSpeed,
        'ttsVoiceIndex': ttsVoiceIndex,
        'scrollMode': scrollMode.index,
        'brightness': brightness,
        'hideMargins': hideMargins,
        'keepScreenAwake': keepScreenAwake,
      };

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'],
        title: json['title'],
        author: json['author'] ?? 'Unknown',
        filePath: json['filePath'],
        type: DocumentType.values[json['type']],
        totalPages: json['totalPages'] ?? 0,
        currentPage: json['currentPage'] ?? 0,
        addedAt: DateTime.parse(json['addedAt']),
        lastReadAt: DateTime.parse(json['lastReadAt']),
        fileSize: json['fileSize'] ?? 0,
        coverImagePath: json['coverImagePath'],
        genre: json['genre'],
        description: json['description'],
        bookmarks: (json['bookmarks'] as List?)
                ?.map((b) => Bookmark.fromJson(b))
                .toList() ??
            [],
        highlights: (json['highlights'] as List?)
                ?.map((h) => Highlight.fromJson(h))
                .toList() ??
            [],
        readingTimeSeconds: json['readingTimeSeconds'] ?? 0,
        isFavorite: json['isFavorite'] ?? false,
        isFinished: json['isFinished'] ?? false,
        readingProgress: (json['readingProgress'] ?? 0.0).toDouble(),
        preferredTheme: ReadingTheme.values[json['preferredTheme'] ?? 0],
        fontSize: (json['fontSize'] ?? 16.0).toDouble(),
        ttsSpeed: (json['ttsSpeed'] ?? 1.0).toDouble(),
        ttsVoiceIndex: json['ttsVoiceIndex'] ?? 0,
        scrollMode: ScrollMode.values[json['scrollMode'] ?? 0],
        brightness: (json['brightness'] ?? 1.0).toDouble(),
        hideMargins: json['hideMargins'] ?? false,
        keepScreenAwake: json['keepScreenAwake'] ?? false,
      );
}

class Bookmark {
  final String id;
  final int page;
  final String title;
  final DateTime createdAt;
  final String? note;

  Bookmark({
    required this.id,
    required this.page,
    required this.title,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'page': page,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'],
        page: json['page'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        note: json['note'],
      );
}

class Highlight {
  final String id;
  final int page;
  final String text;
  final Color color;
  final DateTime createdAt;
  String? note;

  Highlight({
    required this.id,
    required this.page,
    required this.text,
    required this.color,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'page': page,
        'text': text,
        'color': color.toARGB32(),
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'],
        page: json['page'],
        text: json['text'],
        color: Color(json['color']),
        createdAt: DateTime.parse(json['createdAt']),
        note: json['note'],
      );
}

class ReadingStats {
  final int totalBooksRead;
  final int totalPagesRead;
  final int totalReadingSeconds;
  final int currentStreak; // days
  final int longestStreak;
  final Map<String, int> dailyMinutes; // date string -> minutes

  ReadingStats({
    this.totalBooksRead = 0,
    this.totalPagesRead = 0,
    this.totalReadingSeconds = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    Map<String, int>? dailyMinutes,
  }) : dailyMinutes = dailyMinutes ?? {};

  String get totalReadingTimeLabel {
    final hours = totalReadingSeconds ~/ 3600;
    if (hours < 1) return '${totalReadingSeconds ~/ 60}m';
    return '${hours}h ${(totalReadingSeconds % 3600) ~/ 60}m';
  }
}
