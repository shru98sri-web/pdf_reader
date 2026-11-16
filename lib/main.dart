import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() => runApp(const ReaderApp());

const navy = Color(0xFF14213D);
const blue = Color(0xFF2563EB);
const pink = Color(0xFFEC4899);
const paleBlue = Color(0xFFEFF6FF);
const palePink = Color(0xFFFCE7F3);
const ink = Color(0xFF172033);

class ReaderApp extends StatelessWidget {
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BluePink PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
          primary: blue,
          secondary: pink,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const ReaderHome(),
    );
  }
}

class OnlineBook {
  final String title;
  final String subtitle;
  final String url;
  final String tag;
  const OnlineBook(this.title, this.subtitle, this.url, this.tag);
}

const onlineBooks = <OnlineBook>[
  OnlineBook(
    'Biology 2e — OpenStax',
    'Openly licensed college biology textbook PDF',
    'https://d3bxy9euw4e147.cloudfront.net/oscms-prodcms/media/documents/Biology2e-OP_aHSFm3Y.pdf',
    'SCIENCE',
  ),
  OnlineBook(
    'Flutter Succinctly',
    'A technical learning book from Syncfusion',
    'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
    'TECHNOLOGY',
  ),
];

class ReaderHome extends StatefulWidget {
  const ReaderHome({super.key});

  @override
  State<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends State<ReaderHome> {
  Uint8List? _pdfBytes;
  String? _documentUrl;
  String _documentName = 'Welcome to your library';
  String _documentId = '';
  bool _isDarkReader = false;
  bool _isLoading = false;
  bool _showLibrary = true;
  int _currentPage = 1;
  int _pageCount = 0;
  double _zoom = 1.0;
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _pageController = TextEditingController(text: '1');
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  List<int> _bookmarks = [];
  Map<String, int> _savedPages = {};

  bool get _hasDocument => _pdfBytes != null || _documentUrl != null;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('pdf_reader_bookmarks') ?? [];
    final pages = prefs.getStringList('pdf_reader_pages') ?? [];
    final map = <String, int>{};
    for (final item in pages) {
      final parts = item.split('|');
      if (parts.length == 2) {
        final page = int.tryParse(parts[1]);
        if (page != null) map[parts[0]] = page;
      }
    }
    if (!mounted) return;
    setState(() {
      _bookmarks = raw.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
      _savedPages = map;
    });
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdf_reader_bookmarks', _bookmarks.map((e) => e.toString()).toList());
    final pages = _savedPages.entries.map((e) => '${e.key}|${e.value}').toList();
    await prefs.setStringList('pdf_reader_pages', pages);
  }

  Future<void> _pickPdf() async {
    try {
      setState(() => _isLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final file = result.files.single;
      if (file.bytes == null) throw Exception('The selected file could not be read. Please select the PDF again.');
      _openBytes(file.bytes!, file.name);
    } catch (e) {
      _showMessage('Could not open PDF: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openBytes(Uint8List bytes, String name) {
    _searchResult?.clear();
    setState(() {
      _pdfBytes = bytes;
      _documentUrl = null;
      _documentName = name;
      _documentId = name;
      _currentPage = 1;
      _pageCount = 0;
      _pageController.text = '1';
      _searchResult = null;
      _showLibrary = false;
      _isLoading = false;
    });
  }

  Future<void> _openOfflineSample() async {
    try {
      final data = await rootBundle.load('assets/sample_study_guide.pdf');
      _openBytes(data.buffer.asUint8List(), 'Sample_Study_Guide.pdf');
    } catch (e) {
      _showMessage('Could not open the bundled sample: $e');
    }
  }

  void _openOnline(OnlineBook book) {
    _searchResult?.clear();
    setState(() {
      _pdfBytes = null;
      _documentUrl = book.url;
      _documentName = book.title;
      _documentId = book.title;
      _currentPage = _savedPages[book.title] ?? 1;
      _pageController.text = '$_currentPage';
      _pageCount = 0;
      _searchResult = null;
      _showLibrary = false;
      _isLoading = false;
    });
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
      _pageController.text = '${details.newPageNumber}';
      if (_documentId.isNotEmpty) _savedPages[_documentId] = details.newPageNumber;
    });
    _persistState();
  }

  void _jumpToPage() {
    final page = int.tryParse(_pageController.text.trim());
    if (page == null || page < 1 || (_pageCount > 0 && page > _pageCount)) {
      _showMessage('Enter a page between 1 and ${_pageCount == 0 ? 'the total page count' : _pageCount}.');
      return;
    }
    _pdfController.jumpToPage(page);
    FocusScope.of(context).unfocus();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showMessage('Enter a word or phrase to search.');
      return;
    }
    setState(() => _searchResult = _pdfController.searchText(query));
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
    });
    _persistState();
    _showMessage(_bookmarks.contains(_currentPage) ? 'Page bookmarked.' : 'Bookmark removed.');
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bookmarks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 12),
              if (_bookmarks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text('No bookmarks yet. Tap the bookmark icon while reading.'),
                )
              else
                ..._bookmarks.map((page) => ListTile(
                  leading: const Icon(Icons.bookmark, color: pink),
                  title: Text('Page $page'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _pdfController.jumpToPage(page);
                  },
                )),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _searchResult?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [blue, pink]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ReadSpace', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
                Text('INTERACTIVE PDF READER', style: TextStyle(fontSize: 9, letterSpacing: 1.4, color: blue, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Library',
            onPressed: () => setState(() => _showLibrary = true),
            icon: const Icon(Icons.library_books_outlined),
          ),
          IconButton(
            tooltip: 'Open PDF',
            onPressed: _pickPdf,
            icon: const Icon(Icons.upload_file_rounded, color: pink),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Row(
            children: [
              if (wide) _sideRail(),
              Expanded(
                child: _showLibrary || !_hasDocument
                    ? _libraryView()
                    : _readerView(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sideRail() {
    return Container(
      width: 76,
      margin: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          _railButton(Icons.home_rounded, 'Home', true, () => setState(() => _showLibrary = true)),
          _railButton(Icons.menu_book_rounded, 'Reader', false, () {
            if (_hasDocument) setState(() => _showLibrary = false);
          }),
          _railButton(Icons.bookmarks_outlined, 'Saved', false, _showBookmarks),
          const Spacer(),
          _railButton(_isDarkReader ? Icons.light_mode : Icons.dark_mode, 'Theme', false,
              () => setState(() => _isDarkReader = !_isDarkReader)),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _railButton(IconData icon, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? paleBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? blue : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: selected ? blue : const Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _libraryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF172554), Color(0xFF2563EB), Color(0xFFDB2777)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: LayoutBuilder(
                  builder: (context, c) => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(30)),
                              child: const Text('YOUR DIGITAL STUDY DESK', style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 18),
                            Text('A better way to\\nread, learn & focus.', style: TextStyle(color: Colors.white, fontSize: c.maxWidth < 500 ? 28 : 38, height: 1.12, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            const Text('Open your own PDF or explore free sample learning books.', style: TextStyle(color: Color(0xFFEAF1FF), fontSize: 14)),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: _pickPdf,
                              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: navy, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15)),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Upload a PDF', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                      if (c.maxWidth > 520) const SizedBox(width: 24),
                      if (c.maxWidth > 520)
                        Container(
                          width: 150, height: 170,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(26)),
                          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 100),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Text('Explore sample books', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: palePink, borderRadius: BorderRadius.circular(30)), child: const Text('FREE RESOURCES', style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Open sample PDFs directly from the web. An internet connection is required.', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final count = c.maxWidth > 850 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: onlineBooks.length + 1,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 164,
                    ),
                    itemBuilder: (context, index) => index == 0
                        ? _offlineBookCard()
                        : _bookCard(onlineBooks[index - 1], index - 1),
                  );
                },
              ),
              const SizedBox(height: 26),
              const Text('Your reading workspace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: const [
                  _FeatureChip(icon: Icons.search_rounded, title: 'Text search'),
                  _FeatureChip(icon: Icons.zoom_in_rounded, title: 'Zoom controls'),
                  _FeatureChip(icon: Icons.bookmark_add_outlined, title: 'Bookmarks'),
                  _FeatureChip(icon: Icons.history_rounded, title: 'Reading progress'),
                  _FeatureChip(icon: Icons.dark_mode_outlined, title: 'Night reading'),
                  _FeatureChip(icon: Icons.touch_app_outlined, title: 'Text selection'),
                ],
              ),
              const SizedBox(height: 22),
              const Text('Note: Online sample textbooks are hosted by their publishers. Availability and download permissions are controlled by those websites.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }


  Widget _offlineBookCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 82, height: 112,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF172554), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('OFFLINE SAMPLE', style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  const Text('Sample Study Guide', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 5),
                  const Text('Included in this project for instant testing', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _openOfflineSample,
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: const Text('Read sample'),
                      style: FilledButton.styleFrom(foregroundColor: blue, backgroundColor: paleBlue),
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

  Widget _bookCard(OnlineBook book, int index) {
    final isPink = index.isOdd;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 82, height: 112,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPink ? [const Color(0xFFFBCFE8), const Color(0xFFEC4899)] : [const Color(0xFFBFDBFE), const Color(0xFF2563EB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(index == 0 ? Icons.biotech_rounded : Icons.code_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(book.tag, style: TextStyle(color: isPink ? pink : blue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 5),
                  Text(book.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openOnline(book),
                      icon: const Icon(Icons.menu_book_rounded, size: 17),
                      label: const Text('Read online'),
                      style: FilledButton.styleFrom(foregroundColor: blue, backgroundColor: paleBlue),
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

  Widget _readerView() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8EDF5))),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8, runSpacing: 8,
            children: [
              IconButton(tooltip: 'Back to library', onPressed: () => setState(() => _showLibrary = true), icon: const Icon(Icons.arrow_back_rounded)),
              SizedBox(
                width: 220,
                child: Text(_documentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
              ),
              const SizedBox(width: 4),
              IconButton(tooltip: 'Previous page', onPressed: _currentPage > 1 ? () => _pdfController.previousPage() : null, icon: const Icon(Icons.chevron_left)),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _pageController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 5), border: OutlineInputBorder()),
                  onSubmitted: (_) => _jumpToPage(),
                ),
              ),
              Text('/ ${_pageCount == 0 ? '—' : _pageCount}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              IconButton(tooltip: 'Go to page', onPressed: _jumpToPage, icon: const Icon(Icons.keyboard_return_rounded, color: blue)),
              IconButton(tooltip: 'Next page', onPressed: _pageCount == 0 || _currentPage < _pageCount ? () => _pdfController.nextPage() : null, icon: const Icon(Icons.chevron_right)),
              const SizedBox(width: 8),
              SizedBox(
                width: 190,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Find in document',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward, size: 18)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              IconButton(tooltip: 'Previous match', onPressed: _searchResult == null ? null : () => _searchResult!.previousInstance(), icon: const Icon(Icons.keyboard_arrow_up)),
              IconButton(tooltip: 'Next match', onPressed: _searchResult == null ? null : () => _searchResult!.nextInstance(), icon: const Icon(Icons.keyboard_arrow_down)),
              IconButton(tooltip: 'Bookmark page', onPressed: _toggleBookmark, icon: Icon(_bookmarks.contains(_currentPage) ? Icons.bookmark : Icons.bookmark_border, color: pink)),
              IconButton(tooltip: 'Bookmarks', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
              IconButton(tooltip: 'Zoom out', onPressed: () => setState(() => _zoom = (_zoom - .1).clamp(.6, 2.5)), icon: const Icon(Icons.zoom_out)),
              Text('${(_zoom * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              IconButton(tooltip: 'Zoom in', onPressed: () => setState(() => _zoom = (_zoom + .1).clamp(.6, 2.5)), icon: const Icon(Icons.zoom_in)),
              IconButton(tooltip: 'Toggle reader theme', onPressed: () => setState(() => _isDarkReader = !_isDarkReader), icon: Icon(_isDarkReader ? Icons.light_mode : Icons.dark_mode)),
            ],
          ),
        ),
        if (_searchResult != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: palePink, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: Text(_searchResult!.hasResult ? 'Match ${_searchResult!.currentInstanceIndex} of ${_searchResult!.totalInstanceCount}' : 'Searching document…', style: const TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 12))),
                IconButton(onPressed: () { _searchResult?.clear(); setState(() => _searchResult = null); }, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: _isDarkReader ? const Color(0xFF202634) : const Color(0xFFE9EEF6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E7F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _pdfBytes != null
                ? SfPdfViewer.memory(
                    _pdfBytes!,
                    key: ValueKey(_documentId),
                    controller: _pdfController,
                    initialPageNumber: _savedPages[_documentId] ?? 1,
                    initialZoomLevel: _zoom,
                    onDocumentLoaded: (details) => setState(() {
                      _pageCount = details.document.pages.count;
                      _isLoading = false;
                    }),
                    onPageChanged: _onPageChanged,
                    onDocumentLoadFailed: (details) => _showMessage('PDF could not be loaded: ${details.error}'),
                  )
                : SfPdfViewer.network(
                    _documentUrl!,
                    key: ValueKey(_documentId),
                    controller: _pdfController,
                    initialPageNumber: _savedPages[_documentId] ?? 1,
                    initialZoomLevel: _zoom,
                    onDocumentLoaded: (details) => setState(() {
                      _pageCount = details.document.pages.count;
                      _isLoading = false;
                    }),
                    onPageChanged: _onPageChanged,
                    onDocumentLoadFailed: (details) => _showMessage('Could not load online PDF. Check internet access or try another source. ${details.description}'),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String title;
  const _FeatureChip({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE8EDF5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: pink, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}