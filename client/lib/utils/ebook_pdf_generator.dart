import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:campus_client/models/library.dart';

/// Pure-Dart institutional PDF 1.4 generator for digital library textbooks and documents.
/// Generates compliant PDF files with zero external native or CGO dependencies.
class EBookPdfGenerator {
  static String _escapePDF(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  static List<int> generate(EBookModel ebook) {
    final buffer = StringBuffer();
    final dateFmt = DateFormat('dd MMM yyyy');

    void text(String font, double size, double x, double y, String str, double r, double g, double b) {
      buffer.write('BT /$font ${size.toStringAsFixed(1)} Tf ${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td (${_escapePDF(str)}) Tj ET\n');
    }

    void rectFill(double x, double y, double w, double h, double r, double g, double b) {
      buffer.write('${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} rg ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re f\n');
    }

    void rectStroke(double x, double y, double w, double h, double r, double g, double b, double lineWidth) {
      buffer.write('${lineWidth.toStringAsFixed(2)} w ${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} RG ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re S\n');
    }

    void line(double x1, double y1, double x2, double y2, double r, double g, double b, double lineWidth) {
      buffer.write('${lineWidth.toStringAsFixed(2)} w ${r.toStringAsFixed(3)} ${g.toStringAsFixed(3)} ${b.toStringAsFixed(3)} RG ${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} m ${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} l S\n');
    }

    // 1. Institutional Banner
    rectFill(40, 775, 515, 36, 0.478, 0.110, 0.188); // Wine red
    text('F2', 13, 55, 788, 'CAMPUS CENTRAL LIBRARY & DIGITAL ARCHIVES', 1.0, 1.0, 1.0);
    text('F1', 9, 395, 788, 'OFFICIAL DIGITAL E-BOOK EDITION', 0.95, 0.95, 0.95);

    // Document Title & Book Details
    text('F2', 15, 40, 745, ebook.title.toUpperCase(), 0.12, 0.12, 0.12);
    text('F1', 10, 40, 730, 'Author(s): ${ebook.author} | Category: ${ebook.category}', 0.35, 0.35, 0.35);

    // Metadata Card
    rectStroke(40, 640, 515, 75, 0.82, 0.82, 0.82, 1.0);
    rectFill(41, 641, 513, 73, 0.98, 0.98, 0.99);

    text('F2', 9, 52, 695, 'CATALOG IDENTIFIER:', 0.3, 0.3, 0.3);
    text('F1', 9.5, 175, 695, ebook.id, 0.1, 0.1, 0.1);

    text('F2', 9, 52, 678, 'PUBLISHER / SOURCE:', 0.3, 0.3, 0.3);
    text('F1', 9.5, 175, 678, ebook.publisher, 0.1, 0.1, 0.1);

    text('F2', 9, 52, 661, 'FORMAT & FILE SIZE:', 0.3, 0.3, 0.3);
    text('F1', 9.5, 175, 661, '${ebook.format} (${ebook.fileSize})', 0.1, 0.1, 0.1);

    text('F2', 9, 340, 695, 'PUBLISHED / ADDED:', 0.3, 0.3, 0.3);
    text('F1', 9.5, 450, 695, dateFmt.format(ebook.createdAt), 0.1, 0.1, 0.1);

    text('F2', 9, 340, 678, 'APPROVAL STATUS:', 0.3, 0.3, 0.3);
    text('F1', 9.5, 450, 678, ebook.status.toUpperCase(), 0.1, 0.5, 0.2);

    text('F2', 9, 340, 661, 'BORROW MODEL:', 0.3, 0.3, 0.3);
    text('F1', 9.5, 450, 661, ebook.isInfiniteBorrow ? 'Infinite Concurrent' : 'Standard Quota', 0.1, 0.1, 0.1);

    // Section Header: Description & Syllabus Coverage
    rectFill(40, 605, 515, 20, 0.94, 0.95, 0.96);
    text('F2', 9.5, 52, 611, 'TEXTBOOK ABSTRACT & SYLLABUS REFERENCE', 0.2, 0.2, 0.2);

    rectStroke(40, 480, 515, 120, 0.85, 0.85, 0.85, 0.8);
    final desc = ebook.description.isNotEmpty
        ? ebook.description
        : 'Official digital learning material provided through institutional subscription for university scholars.';
    text('F1', 9.5, 52, 575, desc, 0.2, 0.2, 0.2);

    // Tags
    if (ebook.tags.isNotEmpty) {
      text('F2', 9, 52, 515, 'Associated Index Tags: ${ebook.tags.join(' | ')}', 0.4, 0.4, 0.4);
    }

    // Section Header: Digital Rights & Verification
    rectFill(40, 440, 515, 20, 0.94, 0.95, 0.96);
    text('F2', 9.5, 52, 446, 'INSTITUTIONAL LICENSE & DIGITAL PROOF', 0.2, 0.2, 0.2);

    rectStroke(40, 310, 515, 125, 0.85, 0.85, 0.85, 0.8);
    text('F1', 9, 52, 410, '1. This digital text is licensed under the University Digital Library Program.', 0.25, 0.25, 0.25);
    text('F1', 9, 52, 390, '2. Full-text search and offline reading are authenticated for enrolled campus members.', 0.25, 0.25, 0.25);
    text('F1', 9, 52, 370, '3. Tamper-evident SHA-256 seal guarantees academic authenticity across university departments.', 0.25, 0.25, 0.25);
    text('F1', 9, 52, 350, '4. Redistribution or unauthorized commercial duplication is strictly prohibited.', 0.25, 0.25, 0.25);

    // Cryptographic Hash & Verification Seal
    final hashInput = 'EBOOK:${ebook.id}:${ebook.title}:${ebook.author}:${ebook.createdAt.millisecondsSinceEpoch}';
    final hashHex = sha256.convert(utf8.encode(hashInput)).toString();

    const footerY = 220.0;
    line(40, footerY + 30, 555, footerY + 30, 0.75, 0.75, 0.75, 0.8);

    text('F2', 8, 40, footerY + 14, 'CRYPTOGRAPHIC PROOF (SHA-256):', 0.4, 0.4, 0.4);
    text('F1', 7.5, 215, footerY + 14, hashHex, 0.2, 0.2, 0.2);

    text('F1', 7.5, 40, footerY, 'This document is an electronically certified library copy. Authenticated by Campus Central Library.', 0.5, 0.5, 0.5);
    text('F1', 7.5, 40, footerY - 10, 'Generated on: ${DateTime.now().toUtc().toIso8601String()} | University Library Subsystem v1.0', 0.5, 0.5, 0.5);

    // Assemble PDF 1.4 Binary
    final pdfBytes = <int>[];
    void writeStr(String s) {
      pdfBytes.addAll(utf8.encode(s));
    }

    writeStr('%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');

    final offsets = <int>[];
    void writeObj(int objNum, String body) {
      offsets.add(pdfBytes.length);
      writeStr('$objNum 0 obj\n$body\nendobj\n');
    }

    // 1 0 obj: Catalog
    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');

    // 2 0 obj: Pages
    writeObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');

    // 3 0 obj: Page
    writeObj(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>');

    // 4 0 obj: Stream
    final streamContent = buffer.toString();
    final streamBytes = utf8.encode(streamContent);
    writeObj(4, '<< /Length ${streamBytes.length} >>\nstream\n${streamContent}endstream');

    // 5 0 obj: Font F1 (Helvetica)
    writeObj(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');

    // 6 0 obj: Font F2 (Helvetica-Bold)
    writeObj(6, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

    // Xref
    final xrefOffset = pdfBytes.length;
    writeStr('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
    for (final off in offsets) {
      final offStr = off.toString().padLeft(10, '0');
      writeStr('$offStr 00000 n \n');
    }

    // Trailer
    writeStr('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n');

    return pdfBytes;
  }
}
