import 'package:flutter/material.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';

/// In-Document Search Widget - Search text within document content
class InDocumentSearch extends StatefulWidget {
  final String content;
  final Function(int index, String match)? onResultTap;
  final VoidCallback onClose;

  const InDocumentSearch({
    super.key,
    required this.content,
    this.onResultTap,
    required this.onClose,
  });

  @override
  State<InDocumentSearch> createState() => _InDocumentSearchState();
}

class _InDocumentSearchState extends State<InDocumentSearch> {
  final TextEditingController _searchController = TextEditingController();
  List<_SearchMatch> _matches = [];
  int _currentMatchIndex = 0;

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _matches = []);
      return;
    }

    final matches = <_SearchMatch>[];
    final lowerContent = widget.content.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerContent.indexOf(lowerQuery, start);
      if (index == -1) break;

      // Get context around the match
      final contextStart = (index - 30).clamp(0, widget.content.length);
      final contextEnd =
          (index + query.length + 30).clamp(0, widget.content.length);
      final context = widget.content.substring(contextStart, contextEnd);

      matches.add(_SearchMatch(
        index: index,
        text: widget.content.substring(index, index + query.length),
        context: '...$context...',
      ));

      start = index + 1;
    }

    setState(() {
      _matches = matches;
      _currentMatchIndex = 0;
    });
  }

  void _goToNext() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    });
    _notifyMatch();
  }

  void _goToPrevious() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    });
    _notifyMatch();
  }

  void _notifyMatch() {
    if (_matches.isEmpty) return;
    final match = _matches[_currentMatchIndex];
    widget.onResultTap?.call(match.index, match.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgElevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search in document...',
                    hintStyle: const TextStyle(color: AppTheme.textHint),
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              ),
            ],
          ),

          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 12),

            // Navigation
            Row(
              children: [
                Text(
                  '${_currentMatchIndex + 1} of ${_matches.length}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _goToPrevious,
                  icon: const Icon(Icons.keyboard_arrow_up,
                      color: AppTheme.primary),
                ),
                IconButton(
                  onPressed: _goToNext,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppTheme.primary),
                ),
              ],
            ),

            // Current match preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _matches[_currentMatchIndex].context,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchMatch {
  final int index;
  final String text;
  final String context;

  _SearchMatch(
      {required this.index, required this.text, required this.context});
}

/// Highlights & Notes Manager Widget
class HighlightsNotesWidget extends StatefulWidget {
  final Document document;
  final String content;
  final Function(Highlight)? onHighlightTap;
  final Function(Highlight)? onAddHighlight;
  final Function(String highlightId)? onDeleteHighlight;

  const HighlightsNotesWidget({
    super.key,
    required this.document,
    required this.content,
    this.onHighlightTap,
    this.onAddHighlight,
    this.onDeleteHighlight,
  });

  @override
  State<HighlightsNotesWidget> createState() => _HighlightsNotesWidgetState();
}

class _HighlightsNotesWidgetState extends State<HighlightsNotesWidget> {
  Color _selectedColor = Colors.yellow;

  final List<Color> _highlightColors = [
    Colors.yellow,
    Colors.lightGreen,
    Colors.lightBlue,
    Colors.pink.shade200,
    Colors.orange.shade200,
  ];

  void _showAddNoteDialog(Highlight highlight) {
    final controller = TextEditingController(text: highlight.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Note',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Write your note...',
            hintStyle: const TextStyle(color: AppTheme.textHint),
            filled: true,
            fillColor: AppTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedHighlight = Highlight(
                id: highlight.id,
                page: highlight.page,
                text: highlight.text,
                color: highlight.color,
                note: controller.text,
                createdAt: highlight.createdAt,
              );
              widget.onAddHighlight?.call(updatedHighlight);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlights = widget.document.highlights;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              const Icon(Icons.highlight, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Highlights & Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${highlights.length} items',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Color picker
          Row(
            children: [
              const Text('Highlight color: ',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              ..._highlightColors.map((color) => GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _selectedColor == color
                            ? Border.all(color: AppTheme.textPrimary, width: 2)
                            : null,
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 16),

          // Highlights list
          Expanded(
            child: highlights.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.highlight_off,
                            color: AppTheme.textHint.withValues(alpha: 0.5),
                            size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'No highlights yet',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select text to highlight',
                          style:
                              TextStyle(color: AppTheme.textHint, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: highlights.length,
                    itemBuilder: (context, index) {
                      final highlight = highlights[index];
                      return _HighlightCard(
                        highlight: highlight,
                        onTap: () => widget.onHighlightTap?.call(highlight),
                        onAddNote: () => _showAddNoteDialog(highlight),
                        onDelete: () =>
                            widget.onDeleteHighlight?.call(highlight.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final Highlight highlight;
  final VoidCallback onTap;
  final VoidCallback onAddNote;
  final VoidCallback onDelete;

  const _HighlightCard({
    required this.highlight,
    required this.onTap,
    required this.onAddNote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Highlighted text with color indicator
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: highlight.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '"${highlight.text}"',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Note if exists
              if (highlight.note != null && highlight.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgHighlight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.note,
                          color: AppTheme.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          highlight.note!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Actions
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Page ${highlight.page}',
                    style:
                        const TextStyle(color: AppTheme.textHint, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onAddNote,
                    icon: const Icon(Icons.note_add,
                        color: AppTheme.textSecondary, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.error, size: 20),
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text Selection Highlight Popup - Shows when user selects text
class TextSelectionHighlightPopup extends StatelessWidget {
  final String selectedText;
  final Offset position;
  final Function(Color color) onHighlight;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;

  const TextSelectionHighlightPopup({
    super.key,
    required this.selectedText,
    required this.position,
    required this.onHighlight,
    required this.onCopy,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.bgElevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Highlight colors
              ...[
                Colors.yellow,
                Colors.lightGreen,
                Colors.lightBlue,
                Colors.pink.shade200
              ].map((color) => IconButton(
                    onPressed: () => onHighlight(color),
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )),
              const VerticalDivider(width: 16),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy,
                    color: AppTheme.textSecondary, size: 20),
              ),
              IconButton(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up,
                    color: AppTheme.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
