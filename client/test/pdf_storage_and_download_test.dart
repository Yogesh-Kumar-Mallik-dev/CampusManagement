import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/models/fee.dart';
import 'package:campus_client/models/library.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';
import 'package:campus_client/facade/campus_facade.dart';
import 'package:campus_client/utils/invoice_pdf_generator.dart';
import 'package:campus_client/utils/ebook_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Storage, Download & Zero Dummy Data Verification', () {
    test('Zero dummy data when enableMockSeeding is false', () async {
      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api, enableMockSeeding: false);

      // Verify no dummy fees
      final invoices = await storage.getInvoices(studentId: 'usr-harish_2025_l_btech_1');
      expect(invoices, isEmpty);

      final fines = await storage.getFines(studentId: 'usr-harish_2025_l_btech_1');
      expect(fines, isEmpty);

      // Verify no dummy library books
      final books = await storage.getPhysicalBooks();
      expect(books, isEmpty);

      final ebooks = await storage.getEBooks();
      expect(ebooks, isEmpty);

      // Verify no dummy complaints
      final complaints = await storage.getComplaints();
      expect(complaints, isEmpty);

      // Verify only campus_admin exists for admin bootstrap
      final users = await storage.getUsers();
      expect(users.length, 1);
      expect(users.first.campusHandle, 'campus_admin');
      expect(users.first.id, 'usr-campus_admin');
    });

    test('EBookPdfGenerator compiles compliant PDF 1.4 binary bytes', () {
      final ebook = EBookModel(
        id: 'ebk-test-1',
        title: 'Advanced Compiler Design & Implementation',
        author: 'Steven S. Muchnick',
        category: 'Computer Science',
        publisher: 'Morgan Kaufmann',
        format: 'PDF',
        fileSize: '18.4 MB',
        downloadUrl: '/api/v1/library/ebooks/download/ebk-test-1.pdf',
        readUrl: '/library/reader/ebk-test-1',
        isInfiniteBorrow: true,
        description: 'Comprehensive textbook on intermediate representations and SSA optimization.',
        tags: const ['Compilers', 'Optimization', 'Computer Science'],
        status: EBookStatus.approved,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bytes = EBookPdfGenerator.generate(ebook);
      expect(bytes, isNotEmpty);

      final pdfHeader = utf8.decode(bytes.sublist(0, 8));
      expect(pdfHeader, startsWith('%PDF-1.4'));

      final pdfContent = utf8.decode(bytes, allowMalformed: true);
      expect(pdfContent, contains('ADVANCED COMPILER DESIGN'));
      expect(pdfContent, contains('Steven S. Muchnick'));
      expect(pdfContent, contains('Morgan Kaufmann'));
      expect(pdfContent, contains('%%EOF'));
    });

    test('InvoicePdfGenerator compiles compliant PDF 1.4 binary bytes', () {
      final invoice = FeeInvoiceModel(
        id: 'inv-test-101',
        studentId: 'usr-student_1',
        studentName: 'Rahul Verma',
        campusHandle: 'rahul_verma',
        academicYear: '2026-2027',
        semesterNumber: 4,
        feeType: FeeType.tuition,
        title: 'B.Tech Semester 4 Curriculum Fee',
        totalAmount: 60000.0,
        paidAmount: 20000.0,
        dueAmount: 40000.0,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: InvoiceStatus.partial,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bytes = InvoicePdfGenerator.generate(invoice);
      expect(bytes, isNotEmpty);

      final pdfHeader = utf8.decode(bytes.sublist(0, 8));
      expect(pdfHeader, startsWith('%PDF-1.4'));

      final pdfContent = utf8.decode(bytes, allowMalformed: true);
      expect(pdfContent, contains('OFFICIAL INSTITUTIONAL FEE INVOICE'));
      expect(pdfContent, contains('inv-test-101'));
      expect(pdfContent, contains('%%EOF'));
    });

    test('uploadPdfDocument persists bytes to storage and downloadPdfDocument retrieves them', () async {
      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api, enableMockSeeding: false);
      final facade = CampusFacade(api: api, storage: storage);

      final originalBytes = utf8.encode('%PDF-1.4 sample uploaded textbook content binary');
      final filename = 'test_algorithms.pdf';

      // 1. Upload
      final uploadRes = await facade.uploadPdfDocument(
        bytes: originalBytes,
        filename: filename,
      );

      expect(uploadRes['file_id'], isNotNull);
      final fileId = uploadRes['file_id'] as String;
      expect(uploadRes['size_bytes'], originalBytes.length);
      expect(uploadRes['url'], contains(fileId));

      // 2. Download via downloadPdfDocument
      final downloadedBytes = await facade.downloadPdfDocument(fileId);
      expect(downloadedBytes, equals(originalBytes));
    });

    test('downloadEBookPdf retrieves authentic uploaded PDF or generates PDF copy', () async {
      final api = ApiService(baseUrl: 'http://localhost:8080');
      final storage = OfflineStorageService(api: api, enableMockSeeding: false);
      final facade = CampusFacade(api: api, storage: storage);

      final originalPdfBytes = utf8.encode('%PDF-1.4 genuine textbook binary stream');
      final uploadMeta = await facade.uploadPdfDocument(
        bytes: originalPdfBytes,
        filename: 'data_structures.pdf',
      );
      final fileId = uploadMeta['file_id'] as String;

      // Create an E-Book with the uploaded file ID
      final ebook = EBookModel(
        id: 'ebk-ds-01',
        title: 'Mastering Data Structures',
        author: 'Narasimha Karumanchi',
        category: 'Computer Science',
        publisher: 'CareerMonk',
        format: 'PDF',
        fileSize: '12.0 MB',
        downloadUrl: '/api/v1/uploads?id=$fileId',
        readUrl: '/library/reader/ebk-ds-01',
        isInfiniteBorrow: true,
        description: 'Complete data structures and algorithms preparation guide.',
        status: EBookStatus.approved,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await storage.createEBook(ebook);

      // Download should return the exact uploaded binary bytes
      final retrievedBytes = await facade.downloadEBookPdf(ebook.id);
      expect(retrievedBytes, equals(originalPdfBytes));

      // Download an ebook registered without uploaded binary generates compliant PDF 1.4
      final metadataOnlyEbook = EBookModel(
        id: 'ebk-meta-02',
        title: 'Operating System Concepts (Silberschatz)',
        author: 'Abraham Silberschatz',
        category: 'Computer Science',
        publisher: 'Wiley',
        format: 'PDF',
        fileSize: '22.0 MB',
        downloadUrl: '/api/v1/library/ebooks/download/ebk-meta-02.pdf',
        readUrl: '/library/reader/ebk-meta-02',
        isInfiniteBorrow: true,
        description: 'Silberschatz operating systems 10th edition.',
        status: EBookStatus.approved,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await storage.createEBook(metadataOnlyEbook);

      final generatedBytes = await facade.downloadEBookPdf(metadataOnlyEbook.id);
      expect(generatedBytes, isNotEmpty);
      expect(utf8.decode(generatedBytes.sublist(0, 8)), startsWith('%PDF-1.4'));
      expect(utf8.decode(generatedBytes, allowMalformed: true), contains('OPERATING SYSTEM CONCEPTS'));
    });
  });
}
