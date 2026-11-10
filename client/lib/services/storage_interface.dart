import '../models/academic.dart';
import '../models/complaint.dart';
import '../models/fee.dart';
import '../models/hostel.dart';
import '../models/library.dart';
import '../models/mess.dart';
import '../models/user.dart';

/// ICampusApi abstracts remote network transport and API communication.
abstract class ICampusApi {
  String get baseUrl;

  Future<UserModel> login(String identifier, String password);
  Future<bool> checkHealth();

  // Academics, Timetable, Notices & Attendance
  Future<List<CourseModel>> fetchCourses();
  Future<List<TimetableSlotModel>> fetchTimetable(String scope);
  Future<TimetableSlotModel> saveTimetableSlot(TimetableSlotModel slot);
  Future<bool> deleteTimetableSlot(String id);
  Future<List<TimetableConflictModel>> checkTimetableConflict(TimetableSlotModel slot);
  Future<bool> declareDayOffBackend({
    required int dayOfWeek,
    required String scopeCode,
    required String reason,
  });
  Future<bool> restoreDayScheduleBackend({
    required int dayOfWeek,
    required String scopeCode,
  });
  Future<List<NoticeModel>> fetchNotices(List<String> scopes);
  Future<List<AttendanceSummaryModel>> fetchAttendanceSummary(String studentId);
  Future<bool> pushAttendanceBatch(
    String markedByUserId,
    List<AttendanceSessionModel> sessions,
  );

  // Optical Attendance
  Future<OpticalSessionModel> startOpticalSession(Map<String, dynamic> data);
  Future<OpticalVerificationResult> verifyOpticalAttendance(Map<String, dynamic> req);
  Future<List<AttendanceRecordModel>> fetchOpticalSessionRoster(String sessionId);
  Future<void> endOpticalSession(String sessionId);

  // User Management
  Future<List<UserModel>> fetchUsers({
    String? archetype,
    String? status,
    String? search,
  });
  Future<UserModel> fetchUserProfile(String idOrHandle);
  Future<UserModel> createStudent(Map<String, dynamic> req);
  Future<UserModel> createEmployee(Map<String, dynamic> req);
  Future<UserModel> createContractor(Map<String, dynamic> req);
  Future<UserModel> discontinueUser({
    required String userId,
    required String status,
    required String reason,
    required String discontinuedBy,
  });
  Future<UserModel> reactivateUser(String userId);

  // Department & Academics
  Future<List<DepartmentModel>> fetchDepartments();
  Future<DepartmentModel> createDepartment(Map<String, dynamic> payload);
  Future<DepartmentDetailModel> fetchDepartmentDetail(String id);
  Future<List<ProgramModel>> fetchPrograms();
  Future<List<SubjectModel>> fetchSubjects();
  Future<SubjectModel> createSubject(Map<String, dynamic> payload);
  Future<List<SyllabusVersionModel>> fetchSyllabusAudit(String subjectId);
  Future<SyllabusVersionModel> reviseSyllabus(Map<String, dynamic> payload);
  Future<List<SemesterModel>> fetchSemesters();
  Future<SemesterDetailModel> fetchSemesterDetail(String id);
  Future<List<UserModel>> fetchTeachers();
  Future<List<SectionModel>> fetchSections();
  Future<SectionModel> createSection(Map<String, dynamic> payload);
  Future<SectionDetailModel> fetchSectionDetail(String id);
  Future<void> assignStudentToSection({
    required String sectionId,
    required String studentId,
    required String programId,
  });
  Future<void> transferStudentSection({
    required String studentId,
    required String targetSectionId,
  });
  Future<int> mergeSectionCohorts({
    required String sourceSectionId,
    required String targetSectionId,
  });
  Future<List<LabBatchModel>> fetchSectionBatches(String sectionId);
  Future<LabBatchModel> createLabBatch(Map<String, dynamic> payload);
  Future<List<LabBatchModel>> autoPartitionBatches(Map<String, dynamic> payload);
  Future<void> assignStudentBatch({
    required String batchId,
    required String studentId,
  });
  Future<List<FacultyAllocationModel>> fetchFacultyAllocations(String sectionId);
  Future<FacultyAllocationModel> assignFacultyAllocation(Map<String, dynamic> payload);
  Future<void> removeFacultyAllocation(String allocationId);
  Future<List<FacultyWorkloadSummaryModel>> fetchFacultyWorkload({String? teacherId});

  // Hostel & Housing
  Future<List<HostelRoomModel>> fetchHostelRooms({int? floor});
  Future<HostelRoomModel> createHostelRoom(int roomNumber, String blockName);
  Future<HostelRoomModel> updateHostelRoom({
    required int originalRoomNumber,
    required int newRoomNumber,
    required String blockName,
  });
  Future<HostelAssetModel> addHostelAsset(
    int roomNumber,
    String assetType,
    String serialNumber,
    String condition,
  );
  Future<void> removeHostelAsset(int roomNumber, String assetId);
  Future<HostelAssetModel> updateHostelAsset({
    required int roomNumber,
    required String assetId,
    required String serialNumber,
    required String condition,
  });
  Future<HostelOccupantModel> assignHostelOccupant(
    int roomNumber,
    String userId,
    String handle,
    String name,
  );
  Future<void> removeHostelOccupant(int roomNumber, String userId);

  // Dining & Mess
  Future<List<MessMealModel>> fetchMessTimetable();
  Future<MessMealModel> updateMessMeal(MessMealModel meal);
  Future<MessReportSummary> fetchMessRatingsReport({String? mealId, String? rating});
  Future<MessRatingModel> submitMessRating({
    required String mealId,
    required String userId,
    required String userName,
    required String campusHandle,
    required String rating,
    required String message,
  });

  // Institutional Complaints & Dispute Redressal
  Future<List<ComplaintModel>> fetchComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
    bool? isDispute,
    String? disputeTargetType,
  });
  Future<ComplaintModel> createComplaint(ComplaintModel complaint);
  Future<ComplaintModel> raiseDispute(ComplaintModel dispute);
  Future<List<ComplaintModel>> getDisputes({
    String? targetType,
    String? status,
    String? submittedBy,
    String? viewerId,
  });
  Future<ComplaintModel> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String remarks,
    required String resolvedBy,
  });

  // Institutional Fees & Fines Subsystem
  Future<FeeSummaryModel> getFeeSummary(String studentId);
  Future<List<FeeInvoiceModel>> getInvoices({String? studentId, String? status});
  Future<FeeInvoiceModel?> getInvoiceById(String id);
  Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required String studentId,
    required double amount,
    required String paymentMethod,
  });
  Future<List<FineRecordModel>> getFines({String? studentId, String? status});
  Future<Map<String, dynamic>> payFine({
    required String fineId,
    required String studentId,
    required String paymentMethod,
  });
  Future<FineRecordModel> appealFine({
    required String fineId,
    required String reason,
  });
  Future<FineRecordModel> waiveFine({
    required String fineId,
    required String waivedBy,
  });
  Future<List<FeePaymentModel>> getFeePayments(String studentId);
  Future<FeeReceiptModel> getFeeReceipt(String receiptNumber);
  Future<List<int>> downloadInvoicePdf(String invoiceId);

  // Institutional Library Subsystem
  Future<LibrarySummaryModel> getLibrarySummary(String studentId);
  Future<List<PhysicalBookModel>> getPhysicalBooks({String? query, String? category});
  Future<PhysicalBookModel?> getBookById(String id);
  Future<List<BorrowRecordModel>> getBorrowRecords({String? studentId, String? status});
  Future<BorrowRecordModel> borrowBook({
    required String studentId,
    required String bookId,
    String? approvedBy,
    String? approvedByName,
  });
  Future<BorrowRecordModel> approveBorrowRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  });
  Future<BorrowRecordModel> rejectBorrowRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  });
  Future<BorrowRecordModel> returnBook({required String borrowId, required String studentId});
  Future<BorrowRecordModel> renewBook({required String borrowId, required String studentId});
  Future<List<EBookModel>> getEBooks({String? query, String? category});
}

/// ICampusStorage abstracts local persistence, offline caching, and outbox synchronization.
abstract class ICampusStorage {
  bool get isOnline;
  OpticalSessionModel? get activeOpticalSession;
  List<AttendanceRecordModel> get opticalRoster;
  List<CourseModel> get cachedCourses;

  Future<bool> checkConnectivity({bool force = false});
  Future<UserModel> authenticate(String identifier, String password);
  void logout();

  // User Management & Lifecycle
  Future<List<UserModel>> getUsers({
    String? status,
    String? archetype,
    String? search,
    bool forceRefresh = false,
  });
  Future<UserModel> getUserProfile(String idOrHandle);
  Future<UserModel> createStudent(Map<String, dynamic> req);
  Future<UserModel> createEmployee(Map<String, dynamic> req);
  Future<UserModel> createContractor(Map<String, dynamic> req);
  Future<UserModel> discontinueUser({
    required String userId,
    required String status,
    required String reason,
    required String discontinuedBy,
  });
  Future<UserModel> reactivateUser(String userId);

  // Outbox & Sync
  Future<void> refreshConnectivityAndSync(String userId);
  void recordOfflineAttendance(AttendanceSessionModel session);
  Future<bool> flushOutbox(String userId);

  // Timetable & Academics
  Future<List<TimetableSlotModel>> getTimetable(String scope);
  Future<TimetableSlotModel> saveTimetableSlot(TimetableSlotModel slot);
  Future<bool> deleteTimetableSlot(String id);
  Future<void> declareDayOff({
    required int dayOfWeek,
    required String reason,
    required String scopeCode,
  });
  Future<void> restoreDaySchedule({
    required int dayOfWeek,
    required String scopeCode,
  });
  Future<List<TimetableConflictModel>> checkTimetableConflicts(TimetableSlotModel candidate);
  Future<List<NoticeModel>> getNotices(List<String> scopes);
  Future<List<AttendanceSummaryModel>> getAttendanceSummary(String studentId);

  // Optical Attendance
  Future<OpticalSessionModel> startOpticalSession({
    required String courseId,
    required String courseCode,
    required String courseName,
    required String roomNumber,
    required String scopeCode,
    required String markedByUserId,
    required String markedByName,
    int refreshIntervalMs = 5000,
  });
  Future<OpticalVerificationResult> verifyOpticalAttendance({
    required OpticalFramePacket packet,
    required UserModel student,
  });
  Future<List<AttendanceRecordModel>> getOpticalRoster(String sessionId);
  Future<void> endOpticalSession(String sessionId);

  // Academic Hierarchy & Department Management
  Future<List<DepartmentModel>> getDepartments({bool forceRefresh = false});
  Future<DepartmentModel> addDepartment(Map<String, dynamic> payload);
  Future<DepartmentDetailModel> getDepartmentDetail(String id);
  Future<List<ProgramModel>> getPrograms();
  Future<List<SubjectModel>> getSubjects();
  Future<SubjectModel> createSubject(Map<String, dynamic> payload);
  Future<List<SyllabusVersionModel>> getSubjectSyllabusAudit(String subjectId);
  Future<SyllabusVersionModel> reviseSubjectSyllabus(Map<String, dynamic> payload);
  Future<List<SemesterModel>> getSemesters();
  Future<SemesterDetailModel> getSemesterDetail(String id);
  Future<List<SectionModel>> getSections({bool forceRefresh = false});
  Future<SectionModel> addSection(Map<String, dynamic> payload);
  Future<SectionDetailModel> getSectionDetail(String id);
  Future<void> assignStudentToSection({
    required String sectionId,
    required String studentId,
    required String programId,
  });
  Future<void> transferStudentSection({
    required String studentId,
    required String targetSectionId,
  });
  Future<int> mergeSectionCohorts({
    required String sourceSectionId,
    required String targetSectionId,
  });
  Future<List<LabBatchModel>> getSectionBatches(String sectionId);
  Future<LabBatchModel> createLabBatch(Map<String, dynamic> payload);
  Future<List<LabBatchModel>> autoPartitionBatches(Map<String, dynamic> payload);
  Future<void> assignStudentBatch({
    required String batchId,
    required String studentId,
  });
  Future<List<FacultyAllocationModel>> getSectionFacultyAllocations(String sectionId);
  Future<FacultyAllocationModel> assignFacultyAllocation(Map<String, dynamic> payload);
  Future<void> removeFacultyAllocation(String sectionId, String allocationId);
  Future<List<FacultyWorkloadSummaryModel>> getFacultyWorkloadSummaries({String? teacherId});

  // Residential & Hostel
  Future<List<HostelRoomModel>> getHostelRooms({int? floor});
  Future<HostelRoomModel> createHostelRoom(int roomNumber, String blockName);
  Future<HostelRoomModel> updateHostelRoom(int originalRoomNumber, int newRoomNumber, String blockName);
  Future<HostelAssetModel> addHostelAsset(int roomNumber, String assetType, String serialNumber, String condition);
  Future<void> removeHostelAsset(int roomNumber, String assetId);
  Future<HostelAssetModel> updateHostelAsset(int roomNumber, String assetId, {String? serialNumber, String? condition});
  Future<HostelOccupantModel> assignHostelOccupant(int roomNumber, String userId, String handle, String name);
  Future<void> removeHostelOccupant(int roomNumber, String userId);

  // Dining & Mess
  Future<List<MessMealModel>> getMessTimetable();
  Future<MessMealModel> updateMessMeal(MessMealModel updatedMeal);
  Future<MessReportSummary> getMessRatingsReport({String? mealId, String? rating});
  Future<MessRatingModel> submitMessRating({
    required String mealId,
    required String userId,
    required String userName,
    required String campusHandle,
    required String rating,
    required String message,
  });

  // Institutional Complaints & Dispute Redressal
  Future<List<ComplaintModel>> getComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
    bool? isDispute,
    String? disputeTargetType,
  });
  Future<ComplaintModel> createComplaint(ComplaintModel complaint);
  Future<ComplaintModel> raiseDispute(ComplaintModel dispute);
  Future<List<ComplaintModel>> getDisputes({
    String? targetType,
    String? status,
    String? submittedBy,
    String? viewerId,
  });
  Future<ComplaintModel> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String remarks,
    required String resolvedBy,
  });

  // Institutional Fees & Fines Subsystem
  Future<FeeSummaryModel> getFeeSummary(String studentId);
  Future<List<FeeInvoiceModel>> getInvoices({String? studentId, String? status});
  Future<FeeInvoiceModel?> getInvoiceById(String id);
  Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required String studentId,
    required double amount,
    required String paymentMethod,
  });
  Future<List<FineRecordModel>> getFines({String? studentId, String? status});
  Future<Map<String, dynamic>> payFine({
    required String fineId,
    required String studentId,
    required String paymentMethod,
  });
  Future<FineRecordModel> appealFine({
    required String fineId,
    required String reason,
  });
  Future<FineRecordModel> waiveFine({
    required String fineId,
    required String waivedBy,
  });
  Future<List<FeePaymentModel>> getFeePayments(String studentId);
  Future<FeeReceiptModel> getFeeReceipt(String receiptNumber);
  Future<List<int>> downloadInvoicePdf(String invoiceId);

  // Institutional Library Subsystem
  Future<LibrarySummaryModel> getLibrarySummary(String studentId);
  Future<List<PhysicalBookModel>> getPhysicalBooks({String? query, String? category});
  Future<PhysicalBookModel?> getBookById(String id);
  Future<List<BorrowRecordModel>> getBorrowRecords({String? studentId, String? status});
  Future<BorrowRecordModel> borrowBook({
    required String studentId,
    required String bookId,
    String? approvedBy,
    String? approvedByName,
  });
  Future<BorrowRecordModel> approveBorrowRequest({
    required String borrowId,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  });
  Future<BorrowRecordModel> rejectBorrowRequest({
    required String borrowId,
    required String rejectedBy,
    required String rejectionReason,
  });
  Future<BorrowRecordModel> returnBook({required String borrowId, required String studentId});
  Future<BorrowRecordModel> renewBook({required String borrowId, required String studentId});
  Future<List<EBookModel>> getEBooks({String? query, String? category});
}
