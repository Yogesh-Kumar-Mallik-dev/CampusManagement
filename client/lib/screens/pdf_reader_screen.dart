import 'package:flutter/material.dart';
import '../models/library.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

enum ReaderThemeMode {
  light,
  sepia,
  dark,
}

class PdfReaderScreen extends StatefulWidget {
  final EBookModel ebook;
  final int initialPage;

  const PdfReaderScreen({
    super.key,
    required this.ebook,
    this.initialPage = 1,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late int _currentPage;
  final int _totalPages = 120;
  ReaderThemeMode _themeMode = ReaderThemeMode.light;
  double _zoomLevel = 1.0;
  final Set<int> _bookmarks = {};
  final Map<int, String> _pageNotes = {};
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<({String title, int page, String summary})> _chapters = const [
    (title: 'Chapter 1: Foundations & Theoretical Principles', page: 1, summary: 'Core axioms, historical background, and fundamental models.'),
    (title: 'Chapter 2: Structural Architecture & Design Patterns', page: 25, summary: 'Component decomposition, interfaces, and relational integrity.'),
    (title: 'Chapter 3: Algorithmic Implementation & Scaling', page: 55, summary: 'Optimization techniques, concurrency, and memory management.'),
    (title: 'Chapter 4: Empirical Evaluation & Case Studies', page: 85, summary: 'Production telemetry, benchmarks, and edge case resilience.'),
    (title: 'Chapter 5: Advanced Campus Systems & Verification', page: 105, summary: 'Next-generation institutional frameworks and future paradigms.'),
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, _totalPages);
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    final target = page.clamp(1, _totalPages);
    setState(() => _currentPage = target);
    _pageController.jumpToPage(target - 1);
  }

  void _toggleBookmark(int page) {
    setState(() {
      if (_bookmarks.contains(page)) {
        _bookmarks.remove(page);
      } else {
        _bookmarks.add(page);
      }
    });
  }

  Future<void> _openJumpToPageDialog() async {
    final controller = TextEditingController(text: '$_currentPage');
    final target = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Jump to Page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            key: const Key('input-jump-page-number'),
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Page Number (1 - $_totalPages)',
              hintText: 'e.g. 42',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('btn-confirm-jump-page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wineRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed >= 1 && parsed <= _totalPages) {
                  Navigator.pop(dialogCtx, parsed);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    if (target != null && mounted) {
      _goToPage(target);
    }
  }

  Future<void> _openAddNoteDialog(int page) async {
    final controller = TextEditingController(text: _pageNotes[page] ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Study Note • Page $page', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            key: const Key('input-page-study-note'),
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Record key formulas, revision points, or research notes...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('btn-save-page-study-note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.githubGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
              child: const Text('Save Note'),
            ),
          ],
        );
      },
    );

    if (saved != null && mounted) {
      setState(() {
        if (saved.isEmpty) {
          _pageNotes.remove(page);
        } else {
          _pageNotes[page] = saved;
        }
      });
    }
  }

  ({Color background, Color surface, Color textPrimary, Color textSecondary, Color border}) _getThemeColors() {
    switch (_themeMode) {
      case ReaderThemeMode.sepia:
        return (
          background: const Color(0xFFFBF0D9),
          surface: const Color(0xFFF4E4C1),
          textPrimary: const Color(0xFF433422),
          textSecondary: const Color(0xFF6B5539),
          border: const Color(0xFFE2D0A8),
        );
      case ReaderThemeMode.dark:
        return (
          background: const Color(0xFF0F172A),
          surface: const Color(0xFF1E293B),
          textPrimary: const Color(0xFFF1F5F9),
          textSecondary: const Color(0xFF94A3B8),
          border: const Color(0xFF334155),
        );
      case ReaderThemeMode.light:
        return (
          background: const Color(0xFFF8FAFC),
          surface: Colors.white,
          textPrimary: const Color(0xFF0F172A),
          textSecondary: const Color(0xFF475569),
          border: const Color(0xFFE2E8F0),
        );
    }
  }

  ({String title, String summary}) _getChapterForPage(int page) {
    for (int i = _chapters.length - 1; i >= 0; i--) {
      if (page >= _chapters[i].page) {
        return (title: _chapters[i].title, summary: _chapters[i].summary);
      }
    }
    return (title: _chapters.first.title, summary: _chapters.first.summary);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getThemeColors();
    final isBookmarked = _bookmarks.contains(_currentPage);
    final hasNote = _pageNotes.containsKey(_currentPage);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          key: const Key('btn-reader-close'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close Reader',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ebook.title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.ebook.author}  •  ${widget.ebook.format} (${widget.ebook.fileSize})',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          // Table of Contents Drawer Button
          IconButton(
            key: const Key('btn-reader-toc'),
            icon: const Icon(Icons.toc_outlined),
            tooltip: 'Table of Contents & Bookmarks',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          // Bookmark Toggle
          IconButton(
            key: const Key('btn-reader-bookmark'),
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? AppColors.wineRed : colors.textSecondary,
            ),
            tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Page',
            onPressed: () => _toggleBookmark(_currentPage),
          ),
          // Notes Button
          IconButton(
            key: const Key('btn-reader-note'),
            icon: Icon(
              hasNote ? Icons.note : Icons.note_add_outlined,
              color: hasNote ? AppColors.githubGreen : colors.textSecondary,
            ),
            tooltip: 'Add / View Page Notes',
            onPressed: () => _openAddNoteDialog(_currentPage),
          ),
          // Reading Theme Menu
          PopupMenuButton<ReaderThemeMode>(
            key: const Key('btn-reader-theme-menu'),
            icon: Icon(Icons.palette_outlined, color: colors.textSecondary),
            tooltip: 'Reading Palette',
            onSelected: (mode) => setState(() => _themeMode = mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ReaderThemeMode.light,
                child: Row(children: [Icon(Icons.light_mode, size: 16), SizedBox(width: 8), Text('Light Mode')]),
              ),
              const PopupMenuItem(
                value: ReaderThemeMode.sepia,
                child: Row(children: [Icon(Icons.menu_book, size: 16, color: Color(0xFF8B5E3C)), SizedBox(width: 8), Text('Sepia (Paper)')]),
              ),
              const PopupMenuItem(
                value: ReaderThemeMode.dark,
                child: Row(children: [Icon(Icons.dark_mode, size: 16), SizedBox(width: 8), Text('Night Mode')]),
              ),
            ],
          ),
          // Zoom Scale
          IconButton(
            key: const Key('btn-reader-zoom-in'),
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom In',
            onPressed: () {
              setState(() {
                if (_zoomLevel < 1.5) _zoomLevel += 0.25;
              });
            },
          ),
          if (_zoomLevel > 1.0)
            IconButton(
              key: const Key('btn-reader-zoom-out'),
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Reset Zoom',
              onPressed: () => setState(() => _zoomLevel = 1.0),
            ),
        ],
      ),
      endDrawer: _buildSideDrawer(colors),
      body: Column(
        children: [
          // Institutional License Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.wineRed.withValues(alpha: 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppSvgIcon(svgString: AppSvgIcon.shield, size: 12, color: AppColors.wineRed),
                const SizedBox(width: 6),
                Text(
                  'Campus Digital Library • Institutional License for ${_getChapterForPage(_currentPage).title.split(':').first}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.wineRed),
                ),
              ],
            ),
          ),

          // Main Interactive Page Area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx + 1);
              },
              itemBuilder: (context, idx) {
                final pageNum = idx + 1;
                return _buildPageSheet(pageNum, colors);
              },
            ),
          ),

          // Bottom Control & Scrubber Bar
          _buildBottomControlBar(colors),
        ],
      ),
    );
  }

  Widget _buildPageSheet(int pageNum, ({Color background, Color surface, Color textPrimary, Color textSecondary, Color border}) colors) {
    final chapter = _getChapterForPage(pageNum);
    final note = _pageNotes[pageNum];
    final isBookmarked = _bookmarks.contains(pageNum);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720 * _zoomLevel),
          child: Container(
            padding: EdgeInsets.all(32 * _zoomLevel),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header on each page
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        widget.ebook.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9 * _zoomLevel,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        if (isBookmarked) ...[
                          const Icon(Icons.bookmark, size: 14, color: AppColors.wineRed),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'PAGE $pageNum',
                          style: TextStyle(
                            fontSize: 10 * _zoomLevel,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(height: 20, color: colors.border),
                const SizedBox(height: 8),

                // Chapter Header
                Text(
                  chapter.title,
                  style: TextStyle(
                    fontSize: 16 * _zoomLevel,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  chapter.summary,
                  style: TextStyle(
                    fontSize: 11 * _zoomLevel,
                    fontStyle: FontStyle.italic,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // Simulated Academic Content Body
                Text(
                  '1. Introduction & Contextual Background',
                  style: TextStyle(fontSize: 13 * _zoomLevel, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'The rigorous mathematical and systemic foundations of modern computing rest upon foundational paradigms established across algorithmic complexity, distributed consensus, and concurrency management. Within campus institutional ecosystems, scalable state synchronization demands resilient outbox patterns and deterministic recovery mechanisms.',
                  style: TextStyle(
                    fontSize: 12 * _zoomLevel,
                    height: 1.6,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Callout Definition Box
                Container(
                  padding: EdgeInsets.all(12 * _zoomLevel),
                  decoration: BoxDecoration(
                    color: AppColors.wineRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.wineRed.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.menu_book, size: 16, color: AppColors.wineRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Theorem $pageNum.1: Any deterministic state transition verified via cryptographic hashing guarantees non-repudiation across offline and online partitions.',
                          style: TextStyle(
                            fontSize: 11 * _zoomLevel,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  '2. Core Analysis & Empirical Observations',
                  style: TextStyle(fontSize: 13 * _zoomLevel, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'In Section ${(pageNum % 5) + 1}, performance evaluations indicate that caching ephemeral cryptographic payloads within bounded TTL stores alleviates primary database contention by over 87%. Furthermore, strict schema validation shields applications against malicious payloads.',
                  style: TextStyle(
                    fontSize: 12 * _zoomLevel,
                    height: 1.6,
                    color: colors.textPrimary,
                  ),
                ),

                // Student Study Note on this page
                if (note != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.statusYellow.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.edit_note, size: 16, color: AppColors.statusYellowDarkText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('My Study Note:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.statusYellowDarkText)),
                              const SizedBox(height: 2),
                              Text(note, style: TextStyle(fontSize: 11, color: colors.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),
                Center(
                  child: Text(
                    '— $pageNum —',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11 * _zoomLevel,
                      fontWeight: FontWeight.bold,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlBar(({Color background, Color surface, Color textPrimary, Color textSecondary, Color border}) colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // Previous Page Button
          IconButton(
            key: const Key('btn-reader-prev-page'),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous Page',
            onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          ),

          // Interactive Page Slider Scrubber
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.wineRed,
                inactiveTrackColor: colors.border,
                thumbColor: AppColors.wineRed,
                overlayColor: AppColors.wineRed.withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                key: const Key('slider-reader-page'),
                value: _currentPage.toDouble(),
                min: 1.0,
                max: _totalPages.toDouble(),
                divisions: _totalPages - 1,
                onChanged: (val) {
                  _goToPage(val.round());
                },
              ),
            ),
          ),

          // Next Page Button
          IconButton(
            key: const Key('btn-reader-next-page'),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next Page',
            onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
          ),
          const SizedBox(width: 8),

          // Jump-to-Page Indicator Chip
          InkWell(
            key: const Key('btn-reader-jump-page'),
            onTap: _openJumpToPageDialog,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '$_currentPage / $_totalPages',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideDrawer(({Color background, Color surface, Color textPrimary, Color textSecondary, Color border}) colors) {
    return Drawer(
      backgroundColor: colors.surface,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 48, bottom: 8, left: 16, right: 16),
              color: colors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ebook.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  const TabBar(
                    indicatorColor: AppColors.wineRed,
                    labelColor: AppColors.wineRed,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Contents'),
                      Tab(text: 'Bookmarks & Notes'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Table of Contents
                  ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _chapters.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
                    itemBuilder: (context, idx) {
                      final c = _chapters[idx];
                      final isCurrentChapter = _currentPage >= c.page &&
                          (idx == _chapters.length - 1 || _currentPage < _chapters[idx + 1].page);

                      return ListTile(
                        key: Key('toc-chapter-$idx'),
                        dense: true,
                        selected: isCurrentChapter,
                        selectedTileColor: AppColors.wineRed.withValues(alpha: 0.08),
                        title: Text(
                          c.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.w500,
                            color: isCurrentChapter ? AppColors.wineRed : colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          c.summary,
                          style: TextStyle(fontSize: 10, color: colors.textSecondary),
                        ),
                        trailing: Text(
                          'p. ${c.page}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: isCurrentChapter ? AppColors.wineRed : colors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context); // Close drawer
                          _goToPage(c.page);
                        },
                      );
                    },
                  ),

                  // Tab 2: Bookmarks & Notes
                  _bookmarks.isEmpty && _pageNotes.isEmpty
                      ? Center(
                          child: Text(
                            'No bookmarks or notes added yet.\nTap bookmark or note icon while reading.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (_bookmarks.isNotEmpty) ...[
                              const Text('Bookmarked Pages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ..._bookmarks.map((p) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.bookmark, size: 16, color: AppColors.wineRed),
                                  title: Text('Page $p', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  subtitle: Text(_getChapterForPage(p).title, style: const TextStyle(fontSize: 10)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, size: 14),
                                    onPressed: () => _toggleBookmark(p),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _goToPage(p);
                                  },
                                );
                              }),
                            ],
                            if (_pageNotes.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Page Study Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ..._pageNotes.entries.map((e) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.note, size: 16, color: AppColors.githubGreen),
                                  title: Text('Page ${e.key}: ${e.value}', style: const TextStyle(fontSize: 12), maxLines: 2),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _goToPage(e.key);
                                  },
                                );
                              }),
                            ],
                          ],
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
