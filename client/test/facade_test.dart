import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_client/facade/campus_facade.dart';
import 'package:campus_client/models/academic.dart';
import 'package:campus_client/models/complaint.dart';
import 'package:campus_client/models/fee.dart';
import 'package:campus_client/services/api_service.dart';
import 'package:campus_client/services/offline_storage_service.dart';

void main() {
  group('CampusFacade Unified Domain Orchestration Tests', () {
    late OfflineStorageService storage;
    late ApiService api;
    late CampusFacade facade;

    setUp(() {
      api = ApiService(baseUrl: 'http://localhost:8080');
      storage = OfflineStorageService(api: api);
      facade = CampusFacade(storage: storage, api: api);
    });

    test('Facade handles authentication, session, and user profile lifecycle',
        () async {
      // 1. Authenticate student
      final user = await facade.login('harish_student', 'password123');
      expect(user.campusHandle, equals('harish_2025_l_btech_1'));
      expect(user.archetype, equals('student'));

      // 2. Fetch profile
      final profile = await facade.getUserProfile(user.id);
      expect(profile.campusHandle, equals('harish_2025_l_btech_1'));

      // 3. User listings
      final users = await facade.getUsers();
      expect(users.isNotEmpty, isTrue);

      // 4. Logout
      facade.logout();
    });

    test('Facade orchestrates Timetable, Courses, and Day-Off declarations',
        () async {
      final timetable = await facade.getTimetable('sec:cse-3a');
      expect(timetable.isNotEmpty, isTrue);

      final courses = facade.getCachedCourses();
      expect(courses, isA<List<CourseModel>>());

      // Conflict check
      final candidateSlot = TimetableSlotModel(
        id: 'slot-test-candidate',
        courseId: 'crs-cse-301',
        courseCode: 'CS301',
        courseName: 'Operating Systems',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Dr. John Doe',
        dayOfWeek: 1, // Monday
        startTime: '09:00',
        endTime: '10:00',
        roomNumber: 'LH-101',
        slotType: 'regular',
      );
      final conflicts = await facade.checkTimetableConflicts(candidateSlot);
      expect(conflicts, isA<List<TimetableConflictModel>>());

      // Day-off declaration
      await facade.declareDayOff(
        dayOfWeek: 2, // Tuesday
        reason: 'National Holiday',
        scopeCode: 'sec:cse-3a',
      );
      final tuesdaySlots = await facade.getTimetable('sec:cse-3a');
      expect(
        tuesdaySlots.where((s) => s.dayOfWeek == 2 && s.isOff).length,
        equals(8),
      );

      // Restore day
      await facade.restoreDaySchedule(
        dayOfWeek: 2,
        scopeCode: 'sec:cse-3a',
      );
      final restoredSlots = await facade.getTimetable('sec:cse-3a');
      expect(
        restoredSlots.any((s) => s.dayOfWeek == 2 && !s.isOff),
        isTrue,
      );
    });

    test('Facade manages Academic Hierarchy: Departments, Programs, Subjects, and Sections',
        () async {
      final depts = await facade.getDepartments();
      expect(depts.isNotEmpty, isTrue);

      final programs = await facade.getPrograms();
      expect(programs.isNotEmpty, isTrue);

      final subjects = await facade.getSubjects();
      expect(subjects.isNotEmpty, isTrue);

      final semesters = await facade.getSemesters();
      expect(semesters.isNotEmpty, isTrue);

      final sections = await facade.getSections();
      expect(sections.isNotEmpty, isTrue);

      // Department detail
      final deptDetail = await facade.getDepartmentDetail(depts.first.id);
      expect(deptDetail.department.id, equals(depts.first.id));
      expect(deptDetail.teachers.isNotEmpty, isTrue);

      // Syllabus audit trail
      final audit = await facade.getSubjectSyllabusAudit(subjects.first.id);
      expect(audit, isA<List<SyllabusVersionModel>>());
    });

    test('Facade manages Hostel residential operations and fixtures', () async {
      final rooms = await facade.getHostelRooms();
      expect(rooms.isNotEmpty, isTrue);

      // Create new hostel room
      final newRoom = await facade.createHostelRoom(242, 'North Wing');
      expect(newRoom.roomNumber, equals(242));
      expect(newRoom.blockName, equals('North Wing'));

      // Add asset to room
      final asset = await facade.addHostelAsset(
        242,
        'fan',
        'FAN-242-01',
        'good',
      );
      expect(asset.roomNumber, equals(242));
      expect(asset.serialNumber, equals('FAN-242-01'));

      // Assign occupant
      final occupant = await facade.assignHostelOccupant(
        242,
        'usr-test-student',
        'test_student',
        'Test Student',
      );
      expect(occupant.userId, equals('usr-test-student'));
      expect(occupant.campusHandle, equals('test_student'));

      // Remove occupant
      await facade.removeHostelOccupant(242, 'usr-test-student');

      // Remove asset
      await facade.removeHostelAsset(242, asset.id);
    });

    test('Facade coordinates Dining Mess timetable, meals, and rating reviews',
        () async {
      final meals = await facade.getMessTimetable();
      expect(meals.isNotEmpty, isTrue);

      // Submit valid rating
      final rating = await facade.submitMessRating(
        mealId: meals.first.id,
        userId: 'usr-student-harish',
        userName: 'Harish Kumar',
        campusHandle: 'harish_student',
        rating: 'good',
        message: 'The meal was well prepared and nutritious.',
      );
      expect(rating.rating, equals('good'));

      // Get feedback report
      final report = await facade.getMessRatingsReport();
      expect(report.totalRatings, greaterThanOrEqualTo(1));
    });

    test('Facade orchestrates Institutional Complaints and status updates',
        () async {
      final initialComplaints = await facade.getComplaints();
      expect(initialComplaints.isNotEmpty, isTrue);

      // Create new complaint
      final now = DateTime.now();
      final complaint = ComplaintModel(
        id: 'complaint-facade-test',
        title: 'Water filter maintenance required',
        description: 'First floor North wing water purifier requires filter replacement',
        category: ComplaintCategory.hostel,
        urgency: ComplaintUrgency.medium,
        isAnonymous: false,
        submittedBy: 'usr-student-harish',
        submitterHandle: 'harish_student',
        submitterName: 'Harish Kumar',
        submitterRole: 'student',
        createdAt: now,
        updatedAt: now,
      );

      final created = await facade.createComplaint(complaint);
      expect(created.id, isNotEmpty);
      expect(created.status, equals(ComplaintStatus.open));

      // Update complaint status
      final updated = await facade.updateComplaintStatus(
        complaintId: created.id,
        status: ComplaintStatus.inProgress,
        remarks: 'Assigned to hostel maintenance crew',
        resolvedBy: 'warden_kumar',
      );
      expect(updated.status, equals(ComplaintStatus.inProgress));
      expect(updated.resolvedBy, equals('warden_kumar'));
    });

    test('Facade orchestrates Institutional Disputes and queries by target type', () async {
      // 1. Fetch seeded disputes
      final allDisputes = await facade.getDisputes();
      expect(allDisputes.isNotEmpty, isTrue);
      expect(allDisputes.every((d) => d.isDispute), isTrue);

      // 2. Query disputes by specific target type
      final fineDisputes = await facade.getDisputes(targetType: DisputeTargetType.fine);
      expect(fineDisputes.isNotEmpty, isTrue);
      expect(fineDisputes.every((d) => d.disputeTargetType == DisputeTargetType.fine), isTrue);

      final feeDisputes = await facade.getDisputes(targetType: DisputeTargetType.fee);
      expect(feeDisputes.isNotEmpty, isTrue);
      expect(feeDisputes.every((d) => d.disputeTargetType == DisputeTargetType.fee), isTrue);

      // 3. Raise a formal dispute through facade
      final now = DateTime.now();
      final newDispute = ComplaintModel(
        id: 'dispute-facade-test-1',
        title: 'Dispute over Duplicate Library Charge',
        description: 'Billed twice for standard overdue late return fee',
        category: ComplaintCategory.student,
        urgency: ComplaintUrgency.high,
        isAnonymous: false,
        submittedBy: 'usr-facade-test',
        submitterHandle: 'facade_student',
        submitterName: 'Facade Student',
        submitterRole: 'student',
        createdAt: now,
        updatedAt: now,
        isDispute: true,
        disputeTargetType: DisputeTargetType.fine,
        disputeTargetId: 'fine-lib-dup-01',
        disputeEvidence: 'Transaction receipt showing earlier debit',
        requestedResolution: 'Reversal of duplicate debit',
      );

      final raised = await facade.raiseDispute(newDispute);
      expect(raised.id, isNotEmpty);
      expect(raised.isDispute, isTrue);
      expect(raised.disputeTargetType, equals(DisputeTargetType.fine));
      expect(raised.disputeTargetId, equals('fine-lib-dup-01'));
      expect(raised.requestedResolution, equals('Reversal of duplicate debit'));
      expect(raised.status, equals(ComplaintStatus.open));

      // 4. Verify the newly raised dispute appears in dispute queries
      final updatedFineDisputes = await facade.getDisputes(targetType: DisputeTargetType.fine);
      expect(updatedFineDisputes.any((d) => d.disputeTargetId == 'fine-lib-dup-01'), isTrue);
    });

    test('Facade comprehensive coverage for users, timetable, and attendance', () async {
      // User lifecycle
      final student = await facade.createStudent({
        'first_name': 'Test',
        'admission_year': 2026,
        'entry_type': 'regular',
        'program': 'BTECH',
      });
      expect(student.id, isNotEmpty);

      final emp = await facade.createEmployee({
        'first_name': 'Dr. Test',
        'joining_year': 2026,
      });
      expect(emp.id, isNotEmpty);

      final cont = await facade.createContractor({
        'company_name': 'Test Corp',
        'representative_name': 'Vendor',
      });
      expect(cont.id, isNotEmpty);

      final disc = await facade.discontinueUser(
        userId: student.id,
        status: 'graduated',
        reason: 'Course completed',
        discontinuedBy: 'admin',
      );
      expect(disc.isActive, isFalse);

      final react = await facade.reactivateUser(student.id);
      expect(react.isActive, isTrue);

      // Timetable Slot CRUD & restore
      final slot = TimetableSlotModel(
        id: 'slot-facade-new',
        courseId: 'crs-1',
        courseCode: 'CS101',
        courseName: 'Intro',
        scopeCode: 'sec:cse-3a',
        instructorName: 'Teacher',
        dayOfWeek: 3,
        startTime: '11:00',
        endTime: '12:00',
        roomNumber: 'LH-1',
        slotType: 'regular',
      );
      final saved = await facade.saveTimetableSlot(slot);
      expect(saved.id, equals(slot.id));

      await facade.restoreDaySchedule(dayOfWeek: 2, scopeCode: 'sec:cse-3a');
      final deleted = await facade.deleteTimetableSlot(slot.id);
      expect(deleted, isTrue);

      // Notices & Attendance summary
      final notices = await facade.getNotices(['global']);
      expect(notices, isA<List<NoticeModel>>());

      final summaries = await facade.getAttendanceSummary(student.id);
      expect(summaries, isA<List<AttendanceSummaryModel>>());

      // Optical attendance
      final session = await facade.startOpticalSession(
        courseId: 'crs-1',
        courseCode: 'CS101',
        courseName: 'Intro',
        roomNumber: 'LH-1',
        scopeCode: 'sec:cse-3a',
        markedByUserId: 'usr-prof',
        markedByName: 'Prof',
      );
      expect(session.id, isNotEmpty);
      expect(facade.activeOpticalSession?.id, equals(session.id));

      final roster = await facade.getOpticalRoster(session.id);
      expect(roster, isA<List<AttendanceRecordModel>>());

      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const nonce = 'a1b2c3d4';
      final key = utf8.encode(session.sessionSecret);
      final msgBytes = utf8.encode('${session.id}:1:$ts:$nonce');
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(msgBytes).toString();
      final sig = digest.length > 16 ? digest.substring(0, 16) : digest;

      final packet = OpticalFramePacket(
        sessionId: session.id,
        courseCode: 'CS101',
        courseName: 'Intro',
        room: 'LH-1',
        sequence: 1,
        timestamp: ts,
        nonce: nonce,
        signature: sig,
      );
      final ver = await facade.verifyOpticalAttendance(
        packet: packet,
        student: student,
      );
      expect(ver.verified, isTrue);

      await facade.endOpticalSession(session.id);
      expect(facade.activeOpticalSession, isNull);

      // Connectivity
      final online = await facade.checkConnectivity(force: true);
      expect(online, isA<bool>());
      await facade.refreshAndSync(student.id);
    });

    test('Facade comprehensive coverage for academic hierarchy, hostel, and mess', () async {
      // Departments & Programs
      final depts = await facade.getDepartments(forceRefresh: true);
      expect(depts, isNotEmpty);
      final deptId = depts.first.id;

      final deptDetail = await facade.getDepartmentDetail(deptId);
      expect(deptDetail.department.id, equals(deptId));

      final programs = await facade.getPrograms();
      expect(programs, isNotEmpty);

      final subjects = await facade.getSubjects();
      expect(subjects, isNotEmpty);

      final createdSub = await facade.createSubject({
        'code': 'CS999',
        'name': 'Quantum Computing',
        'department_ids': [deptId],
        'credits': 4,
      });
      expect(createdSub.code, equals('CS999'));

      final audit = await facade.getSubjectSyllabusAudit(createdSub.id);
      expect(audit, isA<List<SyllabusVersionModel>>());

      final revised = await facade.reviseSubjectSyllabus({
        'subject_id': createdSub.id,
        'revision_code': 'Rev-2026',
        'effective_from_year': '2026-2027',
      });
      expect(revised.revisionCode, equals('Rev-2026'));

      // Semesters & Sections
      final semesters = await facade.getSemesters();
      expect(semesters, isNotEmpty);

      final semDetail = await facade.getSemesterDetail(semesters.first.id);
      expect(semDetail.semester.id, equals(semesters.first.id));

      final sections = await facade.getSections(forceRefresh: true);
      expect(sections, isNotEmpty);
      final secId = sections.first.id;

      final secDetail = await facade.getSectionDetail(secId);
      expect(secDetail.section.id, equals(secId));

      await facade.assignStudentToSection(
        sectionId: secId,
        studentId: 'usr-student-1',
        programId: programs.first.id,
      );

      if (sections.length > 1) {
        await facade.transferStudentSection(
          studentId: 'usr-student-1',
          targetSectionId: sections[1].id,
        );
        await facade.mergeSectionCohorts(
          sourceSectionId: sections[1].id,
          targetSectionId: secId,
        );
      }

      // Lab Batches
      final batches = await facade.getSectionBatches(secId);
      expect(batches, isA<List<LabBatchModel>>());

      final createdBatch = await facade.createLabBatch({
        'section_id': secId,
        'name': 'Batch B9',
        'capacity': 20,
      });
      expect(createdBatch.id, isNotEmpty);

      await facade.assignStudentBatch(
        batchId: createdBatch.id,
        studentId: 'usr-student-1',
      );

      final partitioned = await facade.autoPartitionBatches({
        'section_id': secId,
        'batch_size': 15,
      });
      expect(partitioned, isNotEmpty);

      // Faculty Allocations
      final allocs = await facade.getSectionFacultyAllocations(secId);
      expect(allocs, isA<List<FacultyAllocationModel>>());

      final assignedAlloc = await facade.assignFacultyAllocation({
        'section_id': secId,
        'teacher_id': 'usr-faculty-1',
        'subject_id': createdSub.id,
        'component_type': 'theory',
        'weekly_hours': 3,
      });
      expect(assignedAlloc.id, isNotEmpty);

      final workloads = await facade.getFacultyWorkloadSummaries();
      expect(workloads, isA<List<FacultyWorkloadSummaryModel>>());

      await facade.removeFacultyAllocation(secId, assignedAlloc.id);

      // Hostel
      final rooms = await facade.getHostelRooms(floor: 1);
      expect(rooms, isNotEmpty);

      final createdRoom = await facade.createHostelRoom(401, 'Block D');
      expect(createdRoom.roomNumber, equals(401));

      final updatedRoom = await facade.updateHostelRoom(401, 402, 'Block D');
      expect(updatedRoom.roomNumber, equals(402));

      final asset = await facade.addHostelAsset(402, 'bed', 'SN-BED-999', 'good');
      expect(asset.id, isNotEmpty);

      final updatedAsset = await facade.updateHostelAsset(402, asset.id, condition: 'repaired');
      expect(updatedAsset.condition, equals('repaired'));

      final occ = await facade.assignHostelOccupant(402, 'usr-test-1', 'test_1', 'Test One');
      expect(occ.userId, equals('usr-test-1'));

      await facade.removeHostelOccupant(402, 'usr-test-1');
      await facade.removeHostelAsset(402, asset.id);

      // Mess
      final meals = await facade.getMessTimetable();
      if (meals.isNotEmpty) {
        final mealToUpdate = meals.first.copyWith(menuSummary: 'Updated Special Thali');
        final updatedMeal = await facade.updateMessMeal(mealToUpdate);
        expect(updatedMeal.menuSummary, equals('Updated Special Thali'));
      }
    });

    test('Facade manages institutional Fee and Fine Subsystems', () async {
      const studentId = 'usr-harish_2025_l_btech_1';

      // 1. Fee summary
      final summary = await facade.getFeeSummary(studentId);
      expect(summary.totalDues, greaterThan(0));
      expect(summary.totalPaid, greaterThan(0));

      // 2. Invoices query
      final invoices = await facade.getInvoices(studentId: studentId);
      expect(invoices.isNotEmpty, isTrue);

      final inv = await facade.getInvoiceById(invoices.first.id);
      expect(inv, isNotNull);

      // Find an invoice with due amount
      final dueInvoice = invoices.firstWhere((i) => i.dueAmount > 0);
      final payResult = await facade.payInvoice(
        invoiceId: dueInvoice.id,
        studentId: studentId,
        amount: 500.0,
        paymentMethod: 'upi',
      );
      expect(payResult['payment'], isA<FeePaymentModel>());
      expect(payResult['receipt'], isA<FeeReceiptModel>());

      // 3. Fines query & pay
      final fines = await facade.getFines(studentId: studentId);
      expect(fines.isNotEmpty, isTrue);

      final appealed = await facade.appealFine(
        fineId: fines.first.id,
        reason: 'Authorized absence for robotics symposium',
      );
      expect(appealed.status, equals(FineStatus.appealed));

      final waived = await facade.waiveFine(
        fineId: fines.first.id,
        waivedBy: 'Campus Dean',
      );
      expect(waived.status, equals(FineStatus.waived));

      // Pay an unpaid fine
      final currentFines = await facade.getFines(studentId: studentId);
      final unpaidFines = currentFines.where((f) => f.status == FineStatus.unpaid).toList();
      if (unpaidFines.isNotEmpty) {
        final finePayResult = await facade.payFine(
          fineId: unpaidFines.first.id,
          studentId: studentId,
          paymentMethod: 'netbanking',
        );
        expect(finePayResult['payment'], isA<FeePaymentModel>());
        expect(finePayResult['receipt'], isA<FeeReceiptModel>());
      }

      // 4. Historical payments and receipt lookup
      final payments = await facade.getFeePayments(studentId);
      expect(payments.isNotEmpty, isTrue);

      final receipt = await facade.getFeeReceipt(payments.first.receiptNumber);
      expect(receipt.receiptNumber, equals(payments.first.receiptNumber));

      // 5. Download Invoice PDF
      final pdfBytes = await facade.downloadInvoicePdf(dueInvoice.id);
      expect(pdfBytes.isNotEmpty, isTrue);

      // 6. Library Subsystem via Facade
      final libSummary = await facade.getLibrarySummary(studentId);
      expect(libSummary.maxBorrowQuota, equals(4));

      final books = await facade.getPhysicalBooks();
      expect(books.isNotEmpty, isTrue);

      final singleBook = await facade.getBookById(books.first.id);
      expect(singleBook, isNotNull);

      final borrows = await facade.getBorrowRecords(studentId: studentId);
      expect(borrows.isNotEmpty, isTrue);

      // Return overdue loan first so Harish can borrow
      final overdueLoan = borrows.firstWhere((b) => b.isOverdue);
      final pendingReturnOverdue = await facade.returnBook(
        borrowId: overdueLoan.id,
        studentId: studentId,
      );
      expect(pendingReturnOverdue.isPendingReturn, isTrue);

      final returnedOverdue = await facade.approveReturnRequest(
        borrowId: overdueLoan.id,
        approvedBy: 'usr-incharge-lib',
        approvedByName: 'Dr. Library Incharge',
      );
      expect(returnedOverdue.isReturned, isTrue);

      // Now borrow an available book (creates loan pending library in-charge approval)
      final availableBook = books.firstWhere((b) => b.isAvailable);
      final newBorrow = await facade.borrowBook(
        studentId: studentId,
        bookId: availableBook.id,
      );
      expect(newBorrow.isPendingApproval, isTrue);

      // Library In-Charge approves the physical book loan
      final approvedLoan = await facade.approveBorrowRequest(
        borrowId: newBorrow.id,
        approvedBy: 'usr-incharge-lib',
        approvedByName: 'Dr. Library Incharge',
      );
      expect(approvedLoan.isActive, isTrue);
      expect(approvedLoan.approvedBy, equals('usr-incharge-lib'));

      // Student requests renewal -> pending renewal
      final pendingRenewal = await facade.renewBook(
        borrowId: newBorrow.id,
        studentId: studentId,
      );
      expect(pendingRenewal.isPendingRenewal, isTrue);

      // Library In-charge approves renewal
      final renewed = await facade.approveRenewalRequest(
        borrowId: newBorrow.id,
        approvedBy: 'usr-incharge-lib',
        approvedByName: 'Dr. Library Incharge',
      );
      expect(renewed.renewalCount, equals(1));
      expect(renewed.isActive, isTrue);
      expect(renewed.renewalApprovedBy, equals('usr-incharge-lib'));

      // Direct in-charge authorization for return
      final returnedNew = await facade.returnBook(
        borrowId: newBorrow.id,
        studentId: studentId,
        approvedBy: 'usr-incharge-lib',
        approvedByName: 'Dr. Library Incharge',
      );
      expect(returnedNew.isReturned, isTrue);

      // Rejection workflow: borrow another book and reject
      final bookToReject = books.firstWhere((b) => b.isAvailable && b.id != availableBook.id);
      final currentBook = await facade.getBookById(bookToReject.id);
      final initialCopies = currentBook!.availableCopies;
      final rejectedReq = await facade.borrowBook(
        studentId: studentId,
        bookId: bookToReject.id,
      );
      expect(rejectedReq.isPendingApproval, isTrue);

      final rejectedRecord = await facade.rejectBorrowRequest(
        borrowId: rejectedReq.id,
        rejectedBy: 'usr-incharge-lib',
        rejectionReason: 'Book reserved for post-graduate laboratory reference',
      );
      expect(rejectedRecord.isRejected, isTrue);
      expect(rejectedRecord.rejectionReason, contains('post-graduate laboratory'));

      final restoredBook = await facade.getBookById(bookToReject.id);
      expect(restoredBook?.availableCopies, equals(initialCopies));

      final ebooks = await facade.getEBooks();
      expect(ebooks.isNotEmpty, isTrue);
      expect(ebooks.first.isInfiniteBorrow, isTrue);
      expect(String.fromCharCodes(pdfBytes).startsWith('%PDF-1.4'), isTrue);
    });
  });
}
