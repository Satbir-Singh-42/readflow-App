import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../services/library_service.dart';
import '../services/cloud_import_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'reader_screen.dart';
import 'search_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _navIndex = 0;
  bool _isGrid = true;
  late TabController _tabController;

  final List<String> _tabs = ['All', 'Reading', 'Recent', 'Favourites'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryService>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _LibraryTab(
            isGrid: _isGrid,
            tabController: _tabController,
            tabs: _tabs,
            onGridToggle: () => setState(() => _isGrid = !_isGrid),
            onImport: () => _importAndHandle(context),
          ),
          const SearchScreen(),
          const StatsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
      floatingActionButton: _navIndex == 0 ? _ImportFab() : null,
    );
  }
}

class _LibraryTab extends StatelessWidget {
  final bool isGrid;
  final TabController tabController;
  final List<String> tabs;
  final VoidCallback onGridToggle;
  final VoidCallback onImport;

  const _LibraryTab({
    required this.isGrid,
    required this.tabController,
    required this.tabs,
    required this.onGridToggle,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _LibraryHeader(
              isGrid: isGrid, onGridToggle: onGridToggle, onImport: onImport),
          _ContinueReading(),
          _TabBar(controller: tabController, tabs: tabs),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _DocumentList(filter: 'all', isGrid: isGrid),
                _DocumentList(filter: 'reading', isGrid: isGrid),
                _DocumentList(filter: 'recent', isGrid: isGrid),
                _DocumentList(filter: 'favorites', isGrid: isGrid),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onGridToggle;
  final VoidCallback onImport;

  const _LibraryHeader({
    required this.isGrid,
    required this.onGridToggle,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ReadFlow',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              Selector<LibraryService, int>(
                selector: (_, lib) => lib.documents.length,
                builder: (_, docCount, __) => Text(
                  '$docCount documents',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onGridToggle,
            icon: Icon(
              isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppTheme.textSecondary,
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => CloudImportDialog(
                  onFileImported: (localPath, fileName) async {
                    // File imported from cloud - add to library
                    final doc = await Provider.of<LibraryService>(context,
                            listen: false)
                        .importFromPath(localPath);
                    if (doc != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Imported: $fileName')),
                      );
                    }
                  },
                ),
              );
            },
            tooltip: 'Cloud Import',
            icon: const Icon(Icons.cloud_download_outlined,
                color: AppTheme.textSecondary),
          ),
          IconButton(
            onPressed: onImport,
            tooltip: 'Import documents',
            icon: const Icon(Icons.upload_file_rounded,
                color: AppTheme.textSecondary),
          ),
          _SortButton(),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryService>(
      builder: (_, lib, __) => PopupMenuButton<String>(
        color: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.sort_rounded, color: AppTheme.textSecondary),
        onSelected: lib.setSortBy,
        itemBuilder: (_) => [
          _menuItem('lastRead', 'Last Read', lib.sortBy),
          _menuItem('title', 'Title', lib.sortBy),
          _menuItem('author', 'Author', lib.sortBy),
          _menuItem('progress', 'Progress', lib.sortBy),
          _menuItem('dateAdded', 'Date Added', lib.sortBy),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, String current) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (current == value)
            const Icon(Icons.check_rounded, color: AppTheme.primary, size: 16),
          if (current != value) const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ContinueReading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<LibraryService, List<Document>>(
      selector: (_, lib) => lib.currentlyReading.take(3).toList(),
      shouldRebuild: (prev, next) =>
          prev.length != next.length || !_listEquals(prev, next),
      builder: (_, docs, __) {
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Continue reading',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (_, i) => _ContinueCard(
                  key: ValueKey(docs[i].id),
                  doc: docs[i],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  bool _listEquals(List<Document> a, List<Document> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].readingProgress != b[i].readingProgress) {
        return false;
      }
    }
    return true;
  }
}

class _ContinueCard extends StatelessWidget {
  final Document doc;
  const _ContinueCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDoc(context, doc),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary.withValues(alpha: 0.15), AppTheme.bgCard],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                doc.type == DocumentType.pdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.menu_book_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: doc.readingProgress,
                    backgroundColor: AppTheme.bgHighlight,
                    color: AppTheme.primary,
                    minHeight: 3,
                  ),
                  const SizedBox(height: 4),
                  Text('${doc.progressPercent}% · ${doc.estimatedTimeLeft}',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;
  const _TabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textHint,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: tabs.map((t) => Tab(text: t, height: 36)).toList(),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  final String filter;
  final bool isGrid;
  const _DocumentList({required this.filter, required this.isGrid});

  @override
  Widget build(BuildContext context) {
    return Selector<LibraryService, List<Document>>(
      selector: (_, lib) {
        switch (filter) {
          case 'reading':
            return lib.currentlyReading;
          case 'recent':
            return lib.recentDocuments;
          case 'favorites':
            return lib.favoriteDocuments;
          default:
            return lib.documents;
        }
      },
      shouldRebuild: (prev, next) =>
          prev.length != next.length || !_docsEqual(prev, next),
      builder: (_, docs, __) {
        if (docs.isEmpty) {
          return EmptyLibraryWidget(onImport: () => _importAndHandle(context));
        }

        if (isGrid) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) => DocumentGridCard(
              key: ValueKey(docs[i].id),
              doc: docs[i],
              onTap: () => _openDoc(context, docs[i]),
              onLongPress: () => _showDocOptions(
                  context, docs[i], context.read<LibraryService>()),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => DocumentListTile(
            key: ValueKey(docs[i].id),
            doc: docs[i],
            onTap: () => _openDoc(context, docs[i]),
            onLongPress: () => _showDocOptions(
                context, docs[i], context.read<LibraryService>()),
          ),
        );
      },
    );
  }

  bool _docsEqual(List<Document> a, List<Document> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _showDocOptions(BuildContext context, Document doc, LibraryService lib) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DocOptionsSheet(doc: doc, lib: lib),
    );
  }
}

class _DocOptionsSheet extends StatelessWidget {
  final Document doc;
  final LibraryService lib;
  const _DocOptionsSheet({required this.doc, required this.lib});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _option(
              Icons.favorite_rounded,
              doc.isFavorite ? 'Remove from Favourites' : 'Add to Favourites',
              doc.isFavorite ? Colors.red : AppTheme.textPrimary, () {
            lib.toggleFavorite(doc.id);
            Navigator.pop(context);
          }),
          _option(
              Icons.info_outline_rounded, 'Document Info', AppTheme.textPrimary,
              () {
            Navigator.pop(context);
            _showInfo(context);
          }),
          _option(Icons.delete_outline_rounded, 'Delete', AppTheme.error, () {
            _confirmDelete(context);
          }),
        ],
      ),
    );
  }

  Widget _option(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w500)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Document Info',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Title', doc.title),
            _infoRow('Author', doc.author),
            _infoRow('Format', doc.typeLabel),
            _infoRow('Size', doc.fileSizeLabel),
            _infoRow('Progress', '${doc.progressPercent}%'),
            _infoRow('Reading time', doc.readingTimeLabel),
            _infoRow('Added', doc.addedAt.toString().substring(0, 10)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',
                  style: TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        title: const Text('Delete document?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '"${doc.title}" will be removed from your library.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await lib.deleteDocument(doc.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    }
  }
}

class _ImportFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: FloatingActionButton(
        onPressed: () => _importAndHandle(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.elasticOut);
  }
}

void _openDoc(BuildContext context, Document doc) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ReaderScreen(document: doc)),
  );
}

Future<void> _importAndHandle(BuildContext context) async {
  final lib = context.read<LibraryService>();
  final result = await lib.importDocuments();
  if (!context.mounted) return;

  if (result.importedDocs.isNotEmpty) {
    _openDoc(context, result.importedDocs.first);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.summary)),
  );
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 64,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books_rounded),
              label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}
