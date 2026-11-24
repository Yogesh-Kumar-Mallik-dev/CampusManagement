import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/library.dart';
import 'package:campus_client/screens/pdf_reader_screen.dart';

void main() {
  final sampleEbook = EBookModel(
    id: 'ebook-test-101',
    title: 'Distributed Systems & Campus Architectures',
    author: 'Dr. Alan Turing',
    category: 'Computer Science',
    publisher: 'Campus Academic Press',
    format: 'PDF',
    fileSize: '4.8 MB',
    totalReaders: 42,
    downloadUrl: 'https://example.com/ebooks/dist_sys.pdf',
    readUrl: 'https://example.com/ebooks/dist_sys/read',
    isInfiniteBorrow: true,
    description: 'Comprehensive graduate treatise on fault-tolerant distributed ledger architectures.',
    requiredSemesters: [5, 6, 7, 8],
    tags: ['Distributed Systems', 'Cryptography', 'Algorithms'],
    status: 'approved',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget createTestWidget({int initialPage = 1}) {
    return MaterialApp(
      home: PdfReaderScreen(
        ebook: sampleEbook,
        initialPage: initialPage,
      ),
    );
  }

  testWidgets('PdfReaderScreen renders ebook title, initial page, and license banner', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Distributed Systems & Campus Architectures'), findsWidgets);
    expect(find.text('Dr. Alan Turing  •  PDF (4.8 MB)'), findsOneWidget);
    expect(find.text('1 / 120'), findsOneWidget);
    expect(find.textContaining('Campus Digital Library'), findsOneWidget);
    expect(find.text('Chapter 1: Foundations & Theoretical Principles'), findsOneWidget);
  });

  testWidgets('Page navigation via next and previous buttons updates page indicator', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 1));
    await tester.pumpAndSettle();

    expect(find.text('1 / 120'), findsOneWidget);

    final nextButton = find.byKey(const Key('btn-reader-next-page'));
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('2 / 120'), findsOneWidget);

    final prevButton = find.byKey(const Key('btn-reader-prev-page'));
    expect(prevButton, findsOneWidget);
    await tester.tap(prevButton);
    await tester.pumpAndSettle();

    expect(find.text('1 / 120'), findsOneWidget);
  });

  testWidgets('Jump to page dialog updates current page directly', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 1));
    await tester.pumpAndSettle();

    final jumpBtn = find.byKey(const Key('btn-reader-jump-page'));
    await tester.tap(jumpBtn);
    await tester.pumpAndSettle();

    expect(find.text('Jump to Page'), findsOneWidget);

    final inputField = find.byKey(const Key('input-jump-page-number'));
    await tester.enterText(inputField, '55');
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const Key('btn-confirm-jump-page'));
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('55 / 120'), findsOneWidget);
    expect(find.text('Chapter 3: Algorithmic Implementation & Scaling'), findsOneWidget);
  });

  testWidgets('Bookmark toggle adds and removes bookmarks in drawer', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 10));
    await tester.pumpAndSettle();

    final bookmarkBtn = find.byKey(const Key('btn-reader-bookmark'));
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    // Open side drawer
    final tocBtn = find.byKey(const Key('btn-reader-toc'));
    await tester.tap(tocBtn);
    await tester.pumpAndSettle();

    // Switch to Bookmarks & Notes tab
    await tester.tap(find.text('Bookmarks & Notes'));
    await tester.pumpAndSettle();

    expect(find.text('Bookmarked Pages'), findsOneWidget);
    expect(find.text('Page 10'), findsOneWidget);
  });

  testWidgets('Page study note saves and renders on page', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 3));
    await tester.pumpAndSettle();

    final noteBtn = find.byKey(const Key('btn-reader-note'));
    await tester.tap(noteBtn);
    await tester.pumpAndSettle();

    expect(find.text('Study Note • Page 3'), findsOneWidget);

    final inputField = find.byKey(const Key('input-page-study-note'));
    await tester.enterText(inputField, 'Review Byzantine Fault Tolerance proofs for exam.');
    await tester.pumpAndSettle();

    final saveBtn = find.byKey(const Key('btn-save-page-study-note'));
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('My Study Note:'), findsOneWidget);
    expect(find.text('Review Byzantine Fault Tolerance proofs for exam.'), findsOneWidget);
  });

  testWidgets('Table of contents drawer jumps to selected chapter', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 1));
    await tester.pumpAndSettle();

    final tocBtn = find.byKey(const Key('btn-reader-toc'));
    await tester.tap(tocBtn);
    await tester.pumpAndSettle();

    // Chapter 2 starts at page 25
    final chapter2Tile = find.byKey(const Key('toc-chapter-1'));
    await tester.tap(chapter2Tile);
    await tester.pumpAndSettle();

    expect(find.text('25 / 120'), findsOneWidget);
    expect(find.text('Chapter 2: Structural Architecture & Design Patterns'), findsOneWidget);
  });

  testWidgets('Theme menu switches reading palettes', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 1));
    await tester.pumpAndSettle();

    final themeMenuBtn = find.byKey(const Key('btn-reader-theme-menu'));
    await tester.tap(themeMenuBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sepia (Paper)'), findsOneWidget);
    expect(find.text('Night Mode'), findsOneWidget);

    await tester.tap(find.text('Sepia (Paper)'));
    await tester.pumpAndSettle();

    // Verify widget still renders without issues
    expect(find.text('1 / 120'), findsOneWidget);
  });

  testWidgets('Zoom controls scale content', (tester) async {
    await tester.pumpWidget(createTestWidget(initialPage: 1));
    await tester.pumpAndSettle();

    final zoomInBtn = find.byKey(const Key('btn-reader-zoom-in'));
    await tester.tap(zoomInBtn);
    await tester.pumpAndSettle();

    // Reset zoom button appears
    final zoomOutBtn = find.byKey(const Key('btn-reader-zoom-out'));
    expect(zoomOutBtn, findsOneWidget);

    await tester.tap(zoomOutBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('btn-reader-zoom-out')), findsNothing);
  });
}
