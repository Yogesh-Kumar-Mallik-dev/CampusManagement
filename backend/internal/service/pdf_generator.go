package service

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"campus/backend/internal/model"
)

func escapePDF(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, "(", "\\(")
	s = strings.ReplaceAll(s, ")", "\\)")
	return s
}

// GenerateInvoicePDF compiles an institutional fee invoice into standard PDF 1.4 binary bytes
func GenerateInvoicePDF(inv *model.FeeInvoice) ([]byte, error) {
	if inv == nil {
		return nil, fmt.Errorf("invoice cannot be nil")
	}

	var stream bytes.Buffer

	text := func(font string, size float64, x, y float64, str string, r, g, b float64) {
		stream.WriteString(fmt.Sprintf("BT /%s %.1f Tf %.3f %.3f %.3f rg %.2f %.2f Td (%s) Tj ET\n",
			font, size, r, g, b, x, y, escapePDF(str)))
	}
	rectFill := func(x, y, w, h float64, r, g, b float64) {
		stream.WriteString(fmt.Sprintf("%.3f %.3f %.3f rg %.2f %.2f %.2f %.2f re f\n",
			r, g, b, x, y, w, h))
	}
	rectStroke := func(x, y, w, h float64, r, g, b, lineWidth float64) {
		stream.WriteString(fmt.Sprintf("%.2f w %.3f %.3f %.3f RG %.2f %.2f %.2f %.2f re S\n",
			lineWidth, r, g, b, x, y, w, h))
	}
	line := func(x1, y1, x2, y2 float64, r, g, b, lineWidth float64) {
		stream.WriteString(fmt.Sprintf("%.2f w %.3f %.3f %.3f RG %.2f %.2f m %.2f %.2f l S\n",
			lineWidth, r, g, b, x1, y1, x2, y2))
	}

	// 1. Institutional Banner
	rectFill(40, 775, 515, 36, 0.478, 0.110, 0.188) // Wine red
	text("F2", 14, 55, 788, "CAMPUS INTEGRATED ACADEMIC PORTAL", 1.0, 1.0, 1.0)
	text("F1", 9, 395, 788, "TREASURY & FEE OPERATIONS", 0.95, 0.95, 0.95)

	// Document Title & Issue Information
	text("F2", 15, 40, 745, "OFFICIAL INSTITUTIONAL FEE INVOICE", 0.12, 0.12, 0.12)
	text("F1", 9.5, 40, 730, fmt.Sprintf("Demand Statement for %s | Issued: %s", inv.Title, inv.CreatedAt.Format("02 Jan 2006")), 0.45, 0.45, 0.45)

	// Status Badge
	statusColorR, statusColorG, statusColorB := 0.18, 0.55, 0.28 // Paid Green
	statusStr := strings.ToUpper(inv.Status)
	if strings.ToLower(inv.Status) == "pending" {
		statusColorR, statusColorG, statusColorB = 0.85, 0.55, 0.08
	} else if strings.ToLower(inv.Status) == "overdue" {
		statusColorR, statusColorG, statusColorB = 0.85, 0.15, 0.15
	} else if strings.ToLower(inv.Status) == "partial" {
		statusColorR, statusColorG, statusColorB = 0.80, 0.45, 0.10
	}
	rectFill(455, 725, 100, 22, statusColorR, statusColorG, statusColorB)
	text("F2", 10, 465, 732, statusStr, 1.0, 1.0, 1.0)

	line(40, 715, 555, 715, 0.85, 0.85, 0.85, 1.0)

	// 2. Metadata Grid Card
	rectFill(40, 625, 515, 80, 0.97, 0.97, 0.98)
	rectStroke(40, 625, 515, 80, 0.88, 0.88, 0.90, 0.8)

	// Left Column
	text("F2", 9, 52, 690, "INVOICE NUMBER:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 150, 690, inv.ID, 0.1, 0.1, 0.1)

	text("F2", 9, 52, 672, "ACADEMIC YEAR:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 150, 672, fmt.Sprintf("%s (Semester %d)", inv.AcademicYear, inv.SemesterNumber), 0.1, 0.1, 0.1)

	text("F2", 9, 52, 654, "FEE CATEGORY:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 150, 654, strings.ToUpper(inv.FeeType), 0.1, 0.1, 0.1)

	text("F2", 9, 52, 636, "PAYMENT DEADLINE:", 0.4, 0.4, 0.4)
	text("F2", 9.5, 150, 636, inv.DueDate.Format("02 Jan 2006"), 0.75, 0.15, 0.15)

	// Right Column
	text("F2", 9, 310, 690, "STUDENT NAME:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 410, 690, inv.StudentName, 0.1, 0.1, 0.1)

	text("F2", 9, 310, 672, "CAMPUS HANDLE:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 410, 672, inv.CampusHandle, 0.1, 0.1, 0.1)

	text("F2", 9, 310, 654, "STUDENT ID:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 410, 654, inv.StudentID, 0.1, 0.1, 0.1)

	text("F2", 9, 310, 636, "ACCOUNT STATUS:", 0.4, 0.4, 0.4)
	text("F2", 9.5, 410, 636, "VERIFIED ACADEMIC ACCOUNT", 0.1, 0.5, 0.2)

	// 3. Line Items Table Header
	curY := 595.0
	text("F2", 11, 40, curY, "ITEMIZED FEE SCHEDULE & ALLOCATIONS", 0.15, 0.15, 0.15)
	curY -= 18

	rectFill(40, curY, 515, 20, 0.92, 0.93, 0.95)
	rectStroke(40, curY, 515, 20, 0.80, 0.82, 0.85, 0.8)
	text("F2", 9, 50, curY+6, "#", 0.2, 0.2, 0.2)
	text("F2", 9, 85, curY+6, "Fee Head / Description", 0.2, 0.2, 0.2)
	text("F2", 9, 440, curY+6, "Amount (INR)", 0.2, 0.2, 0.2)
	curY -= 20

	// Line Items Rows
	for i, head := range inv.Breakdown {
		if i%2 == 1 {
			rectFill(40, curY, 515, 20, 0.98, 0.98, 0.99)
		}
		line(40, curY, 555, curY, 0.88, 0.88, 0.90, 0.5)

		text("F1", 9, 50, curY+6, fmt.Sprintf("%02d", i+1), 0.35, 0.35, 0.35)
		text("F1", 9, 85, curY+6, head.HeadName, 0.15, 0.15, 0.15)
		amtStr := fmt.Sprintf("INR %.2f", head.Amount)
		text("F1", 9, 440, curY+6, amtStr, 0.15, 0.15, 0.15)
		curY -= 20
	}

	line(40, curY+20, 555, curY+20, 0.70, 0.72, 0.75, 1.0)
	curY -= 15

	// 4. Financial Summary Box
	rectFill(310, curY-65, 245, 75, 0.96, 0.96, 0.97)
	rectStroke(310, curY-65, 245, 75, 0.82, 0.82, 0.85, 0.8)

	text("F1", 9.5, 325, curY-12, "Total Assessed Dues:", 0.3, 0.3, 0.3)
	text("F2", 9.5, 455, curY-12, fmt.Sprintf("INR %.2f", inv.TotalAmount), 0.1, 0.1, 0.1)

	text("F1", 9.5, 325, curY-30, "Less Settled Amount:", 0.3, 0.3, 0.3)
	text("F2", 9.5, 455, curY-30, fmt.Sprintf("INR %.2f", inv.PaidAmount), 0.1, 0.5, 0.2)

	line(320, curY-42, 545, curY-42, 0.80, 0.80, 0.80, 0.8)

	text("F2", 10.5, 325, curY-58, "Net Balance Outstanding:", 0.478, 0.110, 0.188)
	text("F2", 11.5, 455, curY-58, fmt.Sprintf("INR %.2f", inv.DueAmount), 0.478, 0.110, 0.188)

	// 5. Institutional Terms
	termsY := curY - 15
	text("F2", 9, 40, termsY, "Institutional Settlement Instructions & Policy:", 0.25, 0.25, 0.25)
	text("F1", 8, 40, termsY-14, "1. Remittances can be completed via Campus Online Gateway (UPI, NetBanking, Debit/Credit Card).", 0.4, 0.4, 0.4)
	text("F1", 8, 40, termsY-26, "2. Retain verified digital transaction reference upon payment for institutional clearance and exam hall passes.", 0.4, 0.4, 0.4)
	text("F1", 8, 40, termsY-38, "3. Outstanding balances past due date attract statutory late penalty of INR 50/day up to max INR 1000.", 0.4, 0.4, 0.4)

	// 6. Verification and Security Footer
	footerY := 75.0
	line(40, footerY+25, 555, footerY+25, 0.80, 0.80, 0.80, 0.8)

	rawHash := sha256.Sum256([]byte(fmt.Sprintf("%s:%s:%.2f:%s", inv.ID, inv.StudentID, inv.TotalAmount, inv.DueDate.Format(time.RFC3339))))
	hashHex := hex.EncodeToString(rawHash[:16])

	text("F2", 8, 40, footerY+12, "DIGITAL TAMPER-EVIDENT VERIFICATION SEAL:", 0.4, 0.4, 0.4)
	text("F1", 7.5, 235, footerY+12, strings.ToUpper(hashHex), 0.2, 0.2, 0.2)

	text("F1", 7.5, 40, footerY, "This document is an electronically generated official academic fee demand. No manual signature required.", 0.5, 0.5, 0.5)
	text("F1", 7.5, 40, footerY-10, fmt.Sprintf("Generated on: %s | Campus Treasury Service v1.0", time.Now().UTC().Format(time.RFC1123)), 0.5, 0.5, 0.5)

	// Assemble PDF 1.4 binary structure
	var pdf bytes.Buffer
	pdf.WriteString("%PDF-1.4\n")
	pdf.WriteString("%\xe2\xe3\xcf\xd3\n")

	var offsets []int
	writeObj := func(objNum int, body string) {
		offsets = append(offsets, pdf.Len())
		pdf.WriteString(fmt.Sprintf("%d 0 obj\n%s\nendobj\n", objNum, body))
	}

	// 1 0 obj: Catalog
	writeObj(1, "<< /Type /Catalog /Pages 2 0 R >>")

	// 2 0 obj: Pages
	writeObj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")

	// 3 0 obj: Page
	writeObj(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>")

	// 4 0 obj: Stream
	streamBytes := stream.Bytes()
	streamObj := fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(streamBytes), string(streamBytes))
	writeObj(4, streamObj)

	// 5 0 obj: Font F1 (Helvetica)
	writeObj(5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

	// 6 0 obj: Font F2 (Helvetica-Bold)
	writeObj(6, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

	// Xref Table
	xrefOffset := pdf.Len()
	pdf.WriteString(fmt.Sprintf("xref\n0 %d\n", len(offsets)+1))
	pdf.WriteString("0000000000 65535 f \n")
	for _, off := range offsets {
		pdf.WriteString(fmt.Sprintf("%010d 00000 n \n", off))
	}

	// Trailer
	pdf.WriteString(fmt.Sprintf("trailer\n<< /Size %d /Root 1 0 R >>\n", len(offsets)+1))
	pdf.WriteString(fmt.Sprintf("startxref\n%d\n%%%%EOF\n", xrefOffset))

	return pdf.Bytes(), nil
}

// GenerateReceiptPDF compiles an official institutional payment receipt into standard PDF 1.4 binary bytes
func GenerateReceiptPDF(receipt *model.FeeReceipt) ([]byte, error) {
	if receipt == nil {
		return nil, fmt.Errorf("receipt cannot be nil")
	}

	var stream bytes.Buffer

	text := func(font string, size float64, x, y float64, str string, r, g, b float64) {
		stream.WriteString(fmt.Sprintf("BT /%s %.1f Tf %.3f %.3f %.3f rg %.2f %.2f Td (%s) Tj ET\n",
			font, size, r, g, b, x, y, escapePDF(str)))
	}
	rectFill := func(x, y, w, h float64, r, g, b float64) {
		stream.WriteString(fmt.Sprintf("%.3f %.3f %.3f rg %.2f %.2f %.2f %.2f re f\n",
			r, g, b, x, y, w, h))
	}
	rectStroke := func(x, y, w, h float64, r, g, b, lineWidth float64) {
		stream.WriteString(fmt.Sprintf("%.2f w %.3f %.3f %.3f RG %.2f %.2f %.2f %.2f re S\n",
			lineWidth, r, g, b, x, y, w, h))
	}
	line := func(x1, y1, x2, y2 float64, r, g, b, lineWidth float64) {
		stream.WriteString(fmt.Sprintf("%.2f w %.3f %.3f %.3f RG %.2f %.2f m %.2f %.2f l S\n",
			lineWidth, r, g, b, x1, y1, x2, y2))
	}

	// 1. Institutional Banner
	rectFill(40, 775, 515, 36, 0.478, 0.110, 0.188) // Wine red
	text("F2", 13, 55, 788, "BABU BANARASI DAS INSTITUTE OF TECHNOLOGY", 1.0, 1.0, 1.0)
	text("F1", 9, 390, 788, "TREASURY & ACCOUNTS DIVISION", 0.95, 0.95, 0.95)

	// Document Title & Issue Information
	text("F2", 15, 40, 745, "OFFICIAL INSTITUTIONAL SETTLEMENT RECEIPT", 0.12, 0.12, 0.12)
	text("F1", 9.5, 40, 730, fmt.Sprintf("Electronic Remittance Acknowledgement | Issued: %s", receipt.IssuedAt.Format("02 Jan 2006 15:04 MST")), 0.45, 0.45, 0.45)

	// Status Badge: Settled / Paid
	rectFill(455, 725, 100, 22, 0.18, 0.55, 0.28) // Paid Green
	text("F2", 10, 470, 732, "PAID / SETTLED", 1.0, 1.0, 1.0)

	line(40, 715, 555, 715, 0.85, 0.85, 0.85, 1.0)

	// 2. Metadata Grid Card
	rectFill(40, 615, 515, 90, 0.97, 0.97, 0.98)
	rectStroke(40, 615, 515, 90, 0.88, 0.88, 0.90, 0.8)

	// Left Column
	text("F2", 9, 52, 688, "RECEIPT NUMBER:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 155, 688, receipt.ReceiptNumber, 0.1, 0.1, 0.1)

	text("F2", 9, 52, 670, "PAYMENT ID:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 155, 670, receipt.PaymentID, 0.1, 0.1, 0.1)

	text("F2", 9, 52, 652, "PAYMENT METHOD:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 155, 652, strings.ToUpper(receipt.PaymentMethod), 0.1, 0.1, 0.1)

	text("F2", 9, 52, 634, "TRANSACTION REF:", 0.4, 0.4, 0.4)
	text("F2", 9.5, 155, 634, receipt.TransactionRef, 0.12, 0.35, 0.65)

	// Right Column
	text("F2", 9, 310, 688, "STUDENT NAME:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 410, 688, receipt.StudentName, 0.1, 0.1, 0.1)

	text("F2", 9, 310, 670, "CAMPUS HANDLE:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 410, 670, receipt.CampusHandle, 0.1, 0.1, 0.1)

	text("F2", 9, 310, 652, "STUDENT ID:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 410, 652, receipt.StudentID, 0.1, 0.1, 0.1)

	text("F2", 9, 310, 634, "ACCOUNT STATUS:", 0.4, 0.4, 0.4)
	text("F2", 9.5, 410, 634, "FEE CLEARANCE APPROVED", 0.1, 0.5, 0.2)

	// 3. Settlement Item Details Table
	curY := 585.0
	rectFill(40, curY, 515, 24, 0.22, 0.25, 0.30)
	text("F2", 9, 52, curY+7, "LINE ITEM DESCRIPTION", 1.0, 1.0, 1.0)
	text("F2", 9, 290, curY+7, "CATEGORY", 1.0, 1.0, 1.0)
	text("F2", 9, 380, curY+7, "REFERENCE", 1.0, 1.0, 1.0)
	text("F2", 9, 470, curY+7, "AMOUNT (INR)", 1.0, 1.0, 1.0)

	curY -= 28.0
	rectFill(40, curY, 515, 24, 0.98, 0.98, 0.99)
	line(40, curY, 555, curY, 0.88, 0.88, 0.90, 0.5)

	text("F1", 9, 52, curY+7, receipt.Title, 0.15, 0.15, 0.15)
	text("F1", 9, 290, curY+7, strings.ToUpper(receipt.Category), 0.35, 0.35, 0.35)

	refId := receipt.InvoiceID
	if refId == "" {
		refId = receipt.FineID
	}
	if refId == "" {
		refId = receipt.PaymentID
	}
	text("F1", 9, 380, curY+7, refId, 0.35, 0.35, 0.35)
	text("F2", 9.5, 470, curY+7, fmt.Sprintf("%.2f", receipt.Amount), 0.1, 0.1, 0.1)

	// 4. Totals Card
	curY -= 20.0
	line(40, curY, 555, curY, 0.75, 0.75, 0.75, 1.0)

	rectFill(310, curY-65, 245, 55, 0.96, 0.97, 0.99)
	rectStroke(310, curY-65, 245, 55, 0.82, 0.85, 0.90, 1.0)

	text("F1", 9.5, 325, curY-22, "Gross Remittance:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 465, curY-22, fmt.Sprintf("INR %.2f", receipt.Amount), 0.2, 0.2, 0.2)

	text("F1", 9.5, 325, curY-38, "Gateway Processing:", 0.4, 0.4, 0.4)
	text("F1", 9.5, 465, curY-38, "INR 0.00 (Waived)", 0.2, 0.5, 0.2)

	text("F2", 10.5, 325, curY-56, "Total Settled Amount:", 0.18, 0.55, 0.28)
	text("F2", 11.5, 465, curY-56, fmt.Sprintf("INR %.2f", receipt.Amount), 0.18, 0.55, 0.28)

	// 5. Institutional Terms & Statutory Notice
	termsY := curY - 75
	text("F2", 9, 40, termsY, "Institutional Treasury & Settlement Notes:", 0.25, 0.25, 0.25)
	text("F1", 8, 40, termsY-14, "1. This receipt confirms valid financial remittance credited to Babu Banarasi Das Institute accounts.", 0.4, 0.4, 0.4)
	text("F1", 8, 40, termsY-26, "2. Retain this digital document for semester registration, hostel clearance, and examination hall ticket issuance.", 0.4, 0.4, 0.4)
	text("F1", 8, 40, termsY-38, "3. All electronic transactions are reconciled with authorized banking nodes and virtual account numbers.", 0.4, 0.4, 0.4)

	// 6. Verification and Security Footer
	footerY := 75.0
	line(40, footerY+25, 555, footerY+25, 0.80, 0.80, 0.80, 0.8)

	rawHash := sha256.Sum256([]byte(fmt.Sprintf("%s:%s:%s:%.2f:%s",
		receipt.ReceiptNumber, receipt.PaymentID, receipt.StudentID, receipt.Amount, receipt.TransactionRef)))
	hashHex := hex.EncodeToString(rawHash[:16])

	text("F2", 8, 40, footerY+12, "DIGITAL TAMPER-EVIDENT VERIFICATION SEAL:", 0.4, 0.4, 0.4)
	text("F1", 7.5, 235, footerY+12, strings.ToUpper(hashHex), 0.2, 0.2, 0.2)

	text("F1", 7.5, 40, footerY, "This document is an electronically generated official settlement voucher. Validated by Institutional Treasury.", 0.5, 0.5, 0.5)
	text("F1", 7.5, 40, footerY-10, fmt.Sprintf("Generated on: %s | Campus Treasury Service v1.0", time.Now().UTC().Format(time.RFC1123)), 0.5, 0.5, 0.5)

	// Assemble PDF 1.4 binary structure
	var pdf bytes.Buffer
	pdf.WriteString("%PDF-1.4\n")
	pdf.WriteString("%\xe2\xe3\xcf\xd3\n")

	var offsets []int
	writeObj := func(objNum int, body string) {
		offsets = append(offsets, pdf.Len())
		pdf.WriteString(fmt.Sprintf("%d 0 obj\n%s\nendobj\n", objNum, body))
	}

	// 1 0 obj: Catalog
	writeObj(1, "<< /Type /Catalog /Pages 2 0 R >>")

	// 2 0 obj: Pages
	writeObj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")

	// 3 0 obj: Page
	writeObj(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>")

	// 4 0 obj: Stream
	streamBytes := stream.Bytes()
	streamObj := fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(streamBytes), string(streamBytes))
	writeObj(4, streamObj)

	// 5 0 obj: Font F1 (Helvetica)
	writeObj(5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

	// 6 0 obj: Font F2 (Helvetica-Bold)
	writeObj(6, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

	// Xref Table
	xrefOffset := pdf.Len()
	pdf.WriteString(fmt.Sprintf("xref\n0 %d\n", len(offsets)+1))
	pdf.WriteString("0000000000 65535 f \n")
	for _, off := range offsets {
		pdf.WriteString(fmt.Sprintf("%010d 00000 n \n", off))
	}

	// Trailer
	pdf.WriteString(fmt.Sprintf("trailer\n<< /Size %d /Root 1 0 R >>\n", len(offsets)+1))
	pdf.WriteString(fmt.Sprintf("startxref\n%d\n%%%%EOF\n", xrefOffset))

	return pdf.Bytes(), nil
}

// GenerateEBookPDF generates a standard PDF 1.4 document for digital institutional e-books
func GenerateEBookPDF(ebook *model.EBook) ([]byte, error) {
	if ebook == nil {
		return nil, fmt.Errorf("ebook cannot be nil")
	}

	var stream bytes.Buffer

	text := func(font string, size float64, x, y float64, str string, r, g, b float64) {
		stream.WriteString(fmt.Sprintf("BT /%s %.1f Tf %.3f %.3f %.3f rg %.2f %.2f Td (%s) Tj ET\n",
			font, size, r, g, b, x, y, escapePDF(str)))
	}
	rectFill := func(x, y, w, h float64, r, g, b float64) {
		stream.WriteString(fmt.Sprintf("%.3f %.3f %.3f rg %.2f %.2f %.2f %.2f re f\n",
			r, g, b, x, y, w, h))
	}
	rectStroke := func(x, y, w, h float64, r, g, b, lineWidth float64) {
		stream.WriteString(fmt.Sprintf("%.2f w %.3f %.3f %.3f RG %.2f %.2f %.2f %.2f re S\n",
			lineWidth, r, g, b, x, y, w, h))
	}
	line := func(x1, y1, x2, y2 float64, r, g, b, lineWidth float64) {
		stream.WriteString(fmt.Sprintf("%.2f w %.3f %.3f %.3f RG %.2f %.2f m %.2f %.2f l S\n",
			lineWidth, r, g, b, x1, y1, x2, y2))
	}

	// 1. Header Banner
	rectFill(40, 775, 515, 36, 0.478, 0.110, 0.188) // Wine red
	text("F2", 14, 55, 788, "CAMPUS CENTRAL DIGITAL LIBRARY", 1.0, 1.0, 1.0)
	text("F1", 9, 395, 788, "E-BOOK REPOSITORY & SCHOLARSHIP", 0.95, 0.95, 0.95)

	// 2. Book Title & Author
	text("F2", 18, 40, 730, ebook.Title, 0.15, 0.15, 0.15)
	text("F1", 12, 40, 705, fmt.Sprintf("Author: %s", ebook.Author), 0.3, 0.3, 0.3)
	text("F1", 10, 40, 685, fmt.Sprintf("Publisher: %s | Category: %s | Format: %s (%s)",
		ebook.Publisher, ebook.Category, ebook.Format, ebook.FileSize), 0.4, 0.4, 0.4)

	line(40, 670, 555, 670, 0.8, 0.8, 0.8, 1.0)

	// 3. Metadata Panel
	rectFill(40, 580, 515, 75, 0.96, 0.97, 0.98)
	rectStroke(40, 580, 515, 75, 0.85, 0.88, 0.92, 1.0)

	text("F2", 9, 55, 635, "ASSET ID:", 0.3, 0.3, 0.3)
	text("F1", 9, 130, 635, ebook.ID, 0.15, 0.15, 0.15)
	text("F2", 9, 320, 635, "BORROW MODEL:", 0.3, 0.3, 0.3)
	text("F1", 9, 420, 635, "Infinite Concurrent Access", 0.15, 0.15, 0.15)

	text("F2", 9, 55, 615, "STATUS:", 0.3, 0.3, 0.3)
	text("F1", 9, 130, 615, strings.ToUpper(ebook.Status), 0.15, 0.15, 0.15)
	text("F2", 9, 320, 615, "TOTAL READERS:", 0.3, 0.3, 0.3)
	text("F1", 9, 420, 615, fmt.Sprintf("%d Scholars", ebook.TotalReaders), 0.15, 0.15, 0.15)

	text("F2", 9, 55, 595, "CATALOG DATE:", 0.3, 0.3, 0.3)
	text("F1", 9, 130, 595, ebook.CreatedAt.Format("02 Jan 2006"), 0.15, 0.15, 0.15)

	// 4. Description & Synopsis
	text("F2", 11, 40, 545, "DOCUMENT SCOPE & SYNOPSIS", 0.2, 0.2, 0.2)
	line(40, 538, 555, 538, 0.85, 0.85, 0.85, 0.5)

	desc := ebook.Description
	if desc == "" {
		desc = "Institutional academic digital asset authorized for student and faculty research."
	}
	descWords := strings.Fields(desc)
	currentLine := ""
	yPos := 520.0
	for _, word := range descWords {
		if len(currentLine)+len(word)+1 > 85 {
			text("F1", 9.5, 40, yPos, currentLine, 0.25, 0.25, 0.25)
			yPos -= 16
			currentLine = word
		} else {
			if currentLine == "" {
				currentLine = word
			} else {
				currentLine += " " + word
			}
		}
	}
	if currentLine != "" {
		text("F1", 9.5, 40, yPos, currentLine, 0.25, 0.25, 0.25)
		yPos -= 25
	}

	// 5. Indexing Tags
	if len(ebook.Tags) > 0 {
		text("F2", 9.5, 40, yPos, "Associated Index Tags: "+strings.Join(ebook.Tags, " | "), 0.4, 0.4, 0.4)
		yPos -= 30
	}

	// 6. Security & Integrity Seal
	footerY := 80.0
	line(40, footerY+30, 555, footerY+30, 0.80, 0.80, 0.80, 0.8)

	rawHash := sha256.Sum256([]byte(fmt.Sprintf("%s:%s:%s", ebook.ID, ebook.Title, ebook.Author)))
	hashHex := hex.EncodeToString(rawHash[:16])

	text("F2", 8, 40, footerY+15, "DIGITAL TAMPER-EVIDENT ARCHIVAL SEAL:", 0.4, 0.4, 0.4)
	text("F1", 7.5, 235, footerY+15, strings.ToUpper(hashHex), 0.2, 0.2, 0.2)
	text("F1", 7.5, 40, footerY, "This document is an electronically catalogued PDF digital textbook verified by Institutional Library.", 0.5, 0.5, 0.5)
	text("F1", 7.5, 40, footerY-10, fmt.Sprintf("Retrieved on: %s | Campus Central Library Digital Services v1.0", time.Now().UTC().Format(time.RFC1123)), 0.5, 0.5, 0.5)

	// Assemble PDF 1.4 binary structure
	var pdf bytes.Buffer
	pdf.WriteString("%PDF-1.4\n")
	pdf.WriteString("%\xe2\xe3\xcf\xd3\n")

	var offsets []int
	writeObj := func(objNum int, body string) {
		offsets = append(offsets, pdf.Len())
		pdf.WriteString(fmt.Sprintf("%d 0 obj\n%s\nendobj\n", objNum, body))
	}

	writeObj(1, "<< /Type /Catalog /Pages 2 0 R >>")
	writeObj(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
	writeObj(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>")

	streamBytes := stream.Bytes()
	streamObj := fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(streamBytes), string(streamBytes))
	writeObj(4, streamObj)

	writeObj(5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
	writeObj(6, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

	xrefOffset := pdf.Len()
	pdf.WriteString(fmt.Sprintf("xref\n0 %d\n", len(offsets)+1))
	pdf.WriteString("0000000000 65535 f \n")
	for _, off := range offsets {
		pdf.WriteString(fmt.Sprintf("%010d 00000 n \n", off))
	}

	pdf.WriteString(fmt.Sprintf("trailer\n<< /Size %d /Root 1 0 R >>\n", len(offsets)+1))
	pdf.WriteString(fmt.Sprintf("startxref\n%d\n%%%%EOF\n", xrefOffset))

	return pdf.Bytes(), nil
}
