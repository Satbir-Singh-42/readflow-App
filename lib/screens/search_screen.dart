// ═══════════════════════════════════════════
// search_screen.dart
// ═══════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Document> _results = [];
  bool _searched = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, LibraryService lib) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _results = lib.search(query);
          _searched = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryService>();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: false,
              onChanged: (q) => _onSearchChanged(q, lib),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by title, author, genre...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppTheme.textHint),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppTheme.textHint),
                        onPressed: () {
                          _controller.clear();
                          _debounceTimer?.cancel();
                          setState(() {
                            _results = [];
                            _searched = false;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (!_searched) ...[
            const SizedBox(height: 60),
            const Icon(Icons.search_rounded,
                color: AppTheme.textHint, size: 64),
            const SizedBox(height: 16),
            const Text('Search your library',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Find books by title, author or genre',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ] else if (_results.isEmpty) ...[
            const SizedBox(height: 60),
            const Icon(Icons.search_off_rounded,
                color: AppTheme.textHint, size: 64),
            const SizedBox(height: 16),
            const Text('No results found',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ] else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                itemBuilder: (_, i) => DocumentListTile(
                  key: ValueKey(_results[i].id),
                  doc: _results[i],
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReaderScreen(document: _results[i]))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
