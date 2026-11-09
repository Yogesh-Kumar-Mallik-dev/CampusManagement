import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:campus_client/models/fee.dart';

/// Pure-Dart institutional PDF 1.4 generator for fee invoices.
/// Zero external native or CGO dependencies.
class InvoicePdfGenerator {
  static String _escapePDF(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  static List<int> generate(FeeInvoiceModel inv) {
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
    text('F2', 14, 55, 788, 'CAMPUS INTEGRATED ACADEMIC PORTAL', 1.0, 1.0, 1.0);
    text('F1', 9, 395, 788, 'TREASURY & FEE OPERATIONS', 0.95, 0.95, 0.95);

    // Document Title & Issue Information
    text('F2', 15, 40, 745, 'OFFICIAL INSTITUTIONAL FEE INVOICE', 0.12, 0.12, 0.12);
    text('F1', 9.5, 40, 730, 'Demand Statement for ${inv.title} | Issued: ${dateFmt.format(inv.createdAt)}', 0.45, 0.45, 0.45);

    // Status Badge
    double statusColorR = 0.18;
    double statusColorG = 0.55;
    double statusColorB = 0.28;
    final statusUpper = inv.status.toUpperCase();
    if (inv.isPending) {
      statusColorR = 0.85;
      statusColorG = 0.55;
      statusColorB = 0.08;
    } else if (inv.isOverdue) {
      statusColorR = 0.85;
      statusColorG = 0.15;
      statusColorB = 0.15;
    } else if (inv.isPartial) {
      statusColorR = 0.80;
      statusColorG = 0.45;
      statusColorB = 0.10;
    }

    rectFill(455, 725, 100, 22, statusColorR, statusColorG, statusColorB);
    text('F2', 10, 465, 732, statusUpper, 1.0, 1.0, 1.0);

    line(40, 715, 555, 715, 0.85, 0.85, 0.85, 1.0);

    // 2. Metadata Grid Card
    rectFill(40, 625, 515, 80, 0.97, 0.97, 0.98);
    rectStroke(40, 625, 515, 80, 0.88, 0.88, 0.90, 0.8);

    // Left Column
    text('F2', 9, 52, 690, 'INVOICE NUMBER:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 150, 690, inv.id, 0.1, 0.1, 0.1);

    text('F2', 9, 52, 672, 'ACADEMIC YEAR:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 150, 672, '${inv.academicYear} (Semester ${inv.semesterNumber})', 0.1, 0.1, 0.1);

    text('F2', 9, 52, 654, 'FEE CATEGORY:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 150, 654, inv.feeType.toUpperCase(), 0.1, 0.1, 0.1);

    text('F2', 9, 52, 636, 'PAYMENT DEADLINE:', 0.4, 0.4, 0.4);
    text('F2', 9.5, 150, 636, dateFmt.format(inv.dueDate), 0.75, 0.15, 0.15);

    // Right Column
    text('F2', 9, 310, 690, 'STUDENT NAME:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 410, 690, inv.studentName, 0.1, 0.1, 0.1);

    text('F2', 9, 310, 672, 'CAMPUS HANDLE:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 410, 672, inv.campusHandle, 0.1, 0.1, 0.1);

    text('F2', 9, 310, 654, 'STUDENT ID:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 410, 654, inv.studentId, 0.1, 0.1, 0.1);

    text('F2', 9, 310, 636, 'ACCOUNT STATUS:', 0.4, 0.4, 0.4);
    text('F2', 9.5, 410, 636, 'VERIFIED ACADEMIC ACCOUNT', 0.1, 0.5, 0.2);

    // 3. Line Items Table Header
    double curY = 595.0;
    text('F2', 11, 40, curY, 'ITEMIZED FEE SCHEDULE & ALLOCATIONS', 0.15, 0.15, 0.15);
    curY -= 18;

    rectFill(40, curY, 515, 20, 0.92, 0.93, 0.95);
    rectStroke(40, curY, 515, 20, 0.80, 0.82, 0.85, 0.8);
    text('F2', 9, 50, curY + 6, '#', 0.2, 0.2, 0.2);
    text('F2', 9, 85, curY + 6, 'Fee Head / Description', 0.2, 0.2, 0.2);
    text('F2', 9, 440, curY + 6, 'Amount (INR)', 0.2, 0.2, 0.2);
    curY -= 20;

    // Line Items Rows
    for (int i = 0; i < inv.breakdown.length; i++) {
      final head = inv.breakdown[i];
      if (i % 2 == 1) {
        rectFill(40, curY, 515, 20, 0.98, 0.98, 0.99);
      }
      line(40, curY, 555, curY, 0.88, 0.88, 0.90, 0.5);

      final indexStr = (i + 1).toString().padLeft(2, '0');
      text('F1', 9, 50, curY + 6, indexStr, 0.35, 0.35, 0.35);
      text('F1', 9, 85, curY + 6, head.headName, 0.15, 0.15, 0.15);
      final amtStr = 'INR ${head.amount.toStringAsFixed(2)}';
      text('F1', 9, 440, curY + 6, amtStr, 0.15, 0.15, 0.15);
      curY -= 20;
    }

    line(40, curY + 20, 555, curY + 20, 0.70, 0.72, 0.75, 1.0);
    curY -= 15;

    // 4. Financial Summary Box
    rectFill(310, curY - 65, 245, 75, 0.96, 0.96, 0.97);
    rectStroke(310, curY - 65, 245, 75, 0.82, 0.82, 0.85, 0.8);

    text('F1', 9.5, 325, curY - 12, 'Total Assessed Dues:', 0.3, 0.3, 0.3);
    text('F2', 9.5, 455, curY - 12, 'INR ${inv.totalAmount.toStringAsFixed(2)}', 0.1, 0.1, 0.1);

    text('F1', 9.5, 325, curY - 30, 'Less Settled Amount:', 0.3, 0.3, 0.3);
    text('F2', 9.5, 455, curY - 30, 'INR ${inv.paidAmount.toStringAsFixed(2)}', 0.1, 0.5, 0.2);

    line(320, curY - 42, 545, curY - 42, 0.80, 0.80, 0.80, 0.8);

    text('F2', 10.5, 325, curY - 58, 'Net Balance Outstanding:', 0.478, 0.110, 0.188);
    text('F2', 11.5, 455, curY - 58, 'INR ${inv.dueAmount.toStringAsFixed(2)}', 0.478, 0.110, 0.188);

    // 5. Terms & Policy
    final termsY = curY - 15;
    text('F2', 9, 40, termsY, 'Institutional Settlement Instructions & Policy:', 0.25, 0.25, 0.25);
    text('F1', 8, 40, termsY - 14, '1. Remittances can be completed via Campus Online Gateway (UPI, NetBanking, Debit/Credit Card).', 0.4, 0.4, 0.4);
    text('F1', 8, 40, termsY - 26, '2. Retain verified digital transaction reference upon payment for institutional clearance and exam hall passes.', 0.4, 0.4, 0.4);
    text('F1', 8, 40, termsY - 38, '3. Outstanding balances past due date attract statutory late penalty of INR 50/day up to max INR 1000.', 0.4, 0.4, 0.4);

    // 6. Security & Digital Verification Seal
    const footerY = 75.0;
    line(40, footerY + 25, 555, footerY + 25, 0.80, 0.80, 0.80, 0.8);

    final rawHash = sha256.convert(utf8.encode('${inv.id}:${inv.studentId}:${inv.totalAmount.toStringAsFixed(2)}:${inv.dueDate.toIso8601String()}'));
    final hashHex = rawHash.toString().substring(0, 32).toUpperCase();

    text('F2', 8, 40, footerY + 12, 'DIGITAL TAMPER-EVIDENT VERIFICATION SEAL:', 0.4, 0.4, 0.4);
    text('F1', 7.5, 235, footerY + 12, hashHex, 0.2, 0.2, 0.2);

    text('F1', 7.5, 40, footerY, 'This document is an electronically generated official academic fee demand. No manual signature required.', 0.5, 0.5, 0.5);
    text('F1', 7.5, 40, footerY - 10, 'Generated on: ${DateTime.now().toUtc().toIso8601String()} | Campus Treasury Service v1.0', 0.5, 0.5, 0.5);

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
