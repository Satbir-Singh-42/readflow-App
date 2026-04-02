import 'package:flutter/material.dart';
import '../models/document.dart';
import 'unified_reader_screen.dart';

/// Main reader router - directs all document types to UnifiedReaderScreen
class ReaderScreen extends StatelessWidget {
  final Document document;
  const ReaderScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    // All document types now use the unified reader
    return UnifiedReaderScreen(document: document);
  }
}
