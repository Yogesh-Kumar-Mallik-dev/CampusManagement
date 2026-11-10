import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:campus_client/models/fee.dart';

/// Pure-Dart institutional PDF 1.4 generator for fee receipts.
/// Zero external native or CGO dependencies.
class ReceiptPdfGenerator {
  static String _escapePDF(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  static List<int> generate(FeeReceiptModel rcp) {
    final buffer = StringBuffer();
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

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
    text('F2', 13, 55, 788, 'BABU BANARASI DAS INSTITUTE OF TECHNOLOGY', 1.0, 1.0, 1.0);
    text('F1', 9, 390, 788, 'TREASURY & ACCOUNTS DIVISION', 0.95, 0.95, 0.95);

    // Document Title & Issue Information
    text('F2', 15, 40, 745, 'OFFICIAL INSTITUTIONAL SETTLEMENT RECEIPT', 0.12, 0.12, 0.12);
    text('F1', 9.5, 40, 730, 'Electronic Remittance Acknowledgement | Issued: ${dateFmt.format(rcp.issuedAt)}', 0.45, 0.45, 0.45);

    // Status Badge: Settled / Paid
    rectFill(455, 725, 100, 22, 0.18, 0.55, 0.28); // Green
    text('F2', 10, 470, 732, 'PAID / SETTLED', 1.0, 1.0, 1.0);

    line(40, 715, 555, 715, 0.85, 0.85, 0.85, 1.0);

    // 2. Metadata Grid Card
    rectFill(40, 615, 515, 90, 0.97, 0.97, 0.98);
    rectStroke(40, 615, 515, 90, 0.88, 0.88, 0.90, 0.8);

    // Left Column
    text('F2', 9, 52, 688, 'RECEIPT NUMBER:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 155, 688, rcp.receiptNumber, 0.1, 0.1, 0.1);

    text('F2', 9, 52, 670, 'PAYMENT ID:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 155, 670, rcp.paymentId, 0.1, 0.1, 0.1);

    text('F2', 9, 52, 652, 'PAYMENT METHOD:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 155, 652, rcp.paymentMethod.toUpperCase(), 0.1, 0.1, 0.1);

    text('F2', 9, 52, 634, 'TRANSACTION REF:', 0.4, 0.4, 0.4);
    text('F2', 9.5, 155, 634, rcp.transactionRef, 0.12, 0.35, 0.65);

    // Right Column
    text('F2', 9, 310, 688, 'STUDENT NAME:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 410, 688, rcp.studentName, 0.1, 0.1, 0.1);

    text('F2', 9, 310, 670, 'CAMPUS HANDLE:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 410, 670, rcp.campusHandle, 0.1, 0.1, 0.1);

    text('F2', 9, 310, 652, 'STUDENT ID:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 410, 652, rcp.studentId, 0.1, 0.1, 0.1);

    text('F2', 9, 310, 634, 'ACCOUNT STATUS:', 0.4, 0.4, 0.4);
    text('F2', 9.5, 410, 634, 'FEE CLEARANCE APPROVED', 0.1, 0.5, 0.2);

    // 3. Settlement Item Details Table
    double curY = 585.0;
    rectFill(40, curY, 515, 24, 0.22, 0.25, 0.30);
    text('F2', 9, 52, curY + 7, 'LINE ITEM DESCRIPTION', 1.0, 1.0, 1.0);
    text('F2', 9, 290, curY + 7, 'CATEGORY', 1.0, 1.0, 1.0);
    text('F2', 9, 380, curY + 7, 'REFERENCE', 1.0, 1.0, 1.0);
    text('F2', 9, 470, curY + 7, 'AMOUNT (INR)', 1.0, 1.0, 1.0);

    curY -= 28.0;
    rectFill(40, curY, 515, 24, 0.98, 0.98, 0.99);
    line(40, curY, 555, curY, 0.88, 0.88, 0.90, 0.5);

    text('F1', 9, 52, curY + 7, rcp.title, 0.15, 0.15, 0.15);
    text('F1', 9, 290, curY + 7, rcp.category.toUpperCase(), 0.35, 0.35, 0.35);

    final refId = rcp.invoiceId ?? rcp.fineId ?? rcp.paymentId;
    text('F1', 9, 380, curY + 7, refId, 0.35, 0.35, 0.35);
    text('F2', 9.5, 470, curY + 7, rcp.amount.toStringAsFixed(2), 0.1, 0.1, 0.1);

    // 4. Totals Card
    curY -= 20.0;
    line(40, curY, 555, curY, 0.75, 0.75, 0.75, 1.0);

    rectFill(310, curY - 65, 245, 55, 0.96, 0.97, 0.99);
    rectStroke(310, curY - 65, 245, 55, 0.82, 0.85, 0.90, 1.0);

    text('F1', 9.5, 325, curY - 22, 'Gross Remittance:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 465, curY - 22, 'INR ${rcp.amount.toStringAsFixed(2)}', 0.2, 0.2, 0.2);

    text('F1', 9.5, 325, curY - 38, 'Gateway Processing:', 0.4, 0.4, 0.4);
    text('F1', 9.5, 465, curY - 38, 'INR 0.00 (Waived)', 0.2, 0.5, 0.2);

    text('F2', 10.5, 325, curY - 56, 'Total Settled Amount:', 0.18, 0.55, 0.28);
    text('F2', 11.5, 465, curY - 56, 'INR ${rcp.amount.toStringAsFixed(2)}', 0.18, 0.55, 0.28);

    // 5. Institutional Terms & Statutory Notice
    double termsY = curY - 75;
    text('F2', 9, 40, termsY, 'Institutional Treasury & Settlement Notes:', 0.25, 0.25, 0.25);
    text('F1', 8, 40, termsY - 14, '1. This receipt confirms valid financial remittance credited to Babu Banarasi Das Institute accounts.', 0.4, 0.4, 0.4);
    text('F1', 8, 40, termsY - 26, '2. Retain this digital document for semester registration, hostel clearance, and examination hall ticket issuance.', 0.4, 0.4, 0.4);
    text('F1', 8, 40, termsY - 38, '3. All electronic transactions are reconciled with authorized banking nodes and virtual account numbers.', 0.4, 0.4, 0.4);

    // 6. Verification and Security Footer
    double footerY = 75.0;
    line(40, footerY + 25, 555, footerY + 25, 0.80, 0.80, 0.80, 0.8);

    final rawHash = sha256.convert(utf8.encode('${rcp.receiptNumber}:${rcp.paymentId}:${rcp.studentId}:${rcp.amount}:${rcp.transactionRef}'));
    final hashHex = rawHash.toString().substring(0, 32).toUpperCase();

    text('F2', 8, 40, footerY + 12, 'DIGITAL TAMPER-EVIDENT VERIFICATION SEAL:', 0.4, 0.4, 0.4);
    text('F1', 7.5, 235, footerY + 12, hashHex, 0.2, 0.2, 0.2);

    text('F1', 7.5, 40, footerY, 'This document is an electronically generated official settlement voucher. Validated by Institutional Treasury.', 0.5, 0.5, 0.5);
    text('F1', 7.5, 40, footerY - 10, 'Generated on: ${DateTime.now().toUtc().toIso8601String()} | Campus Treasury Service v1.0', 0.5, 0.5, 0.5);

    // Assemble PDF 1.4 binary structure
    final pdfBytes = <int>[];
    final streamContent = utf8.encode(buffer.toString());

    void writeString(String str) {
      pdfBytes.addAll(utf8.encode(str));
    }

    writeString('%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');

    final offsets = <int>[];
    void writeObj(int objNum, String body) {
      offsets.add(pdfBytes.length);
      writeString('$objNum 0 obj\n$body\nendobj\n');
    }

    // 1 0 obj: Catalog
    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');

    // 2 0 obj: Pages
    writeObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');

    // 3 0 obj: Page
    writeObj(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>');

    // 4 0 obj: Stream
    offsets.add(pdfBytes.length);
    writeString('4 0 obj\n<< /Length ${streamContent.length} >>\nstream\n');
    pdfBytes.addAll(streamContent);
    writeString('\nendstream\nendobj\n');

    // 5 0 obj: Font F1 (Helvetica)
    writeObj(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');

    // 6 0 obj: Font F2 (Helvetica-Bold)
    writeObj(6, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

    // Xref Table
    final xrefOffset = pdfBytes.length;
    writeString('xref\n0 ${offsets.length + 1}\n');
    writeString('0000000000 65535 f \n');
    for (final off in offsets) {
      writeString('${off.toString().padLeft(10, '0')} 00000 n \n');
    }

    // Trailer
    writeString('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\n');
    writeString('startxref\n$xrefOffset\n%%EOF\n');

    return pdfBytes;
  }
}
