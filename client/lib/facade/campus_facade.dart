import '../models/academic.dart';
import '../models/complaint.dart';
import '../models/fee.dart';
import '../models/hostel.dart';
import '../models/mess.dart';
import '../models/user.dart';
import '../services/storage_interface.dart';

/// ICampusFacade defines the unified boundary for all frontend domain interactions.
abstract class ICampusFacade {
  ICampusStorage get storage;
  ICampusApi get api;

  bool get isOnline;
  OpticalSessionModel? get activeOpticalSession;
  List<AttendanceRecordModel> get opticalRoster;

  // Lifecycle & Connectivity
  Future<bool> checkConnectivity({bool force = false});
  Future<void> refreshAndSync(String userId);

  // Authentication & User Identity
  Future<UserModel> login(String identifier, String password);
  void logout();
  Future<UserModel> getUserProfile(String idOrHandle);
  Future<List<UserModel>> getUsers({
    String? status,
    String? archetype,
    String? search,
    bool forceRefresh = false,
  });
  Future<UserModel> createStudent(Map<String, dynamic> data);
  Future<UserModel> createEmployee(Map<String, dynamic> data);
  Future<UserModel> createContractor(Map<String, dynamic> data);
  Future<UserModel> discontinueUser({
    required String userId,
    required String status,
    required String reason,
    required String discontinuedBy,
  });
  Future<UserModel> reactivateUser(String userId);

  // Academics & Timetable
  List<CourseModel> getCachedCourses();
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

  // Optical Attendance Session
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

  // Departments, Programs, Subjects & Sections
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

  // Residence & Hostel
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

  // Grievances & Complaints
  Future<List<ComplaintModel>> getComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
  });
  Future<ComplaintModel> createComplaint(ComplaintModel complaint);
  Future<ComplaintModel> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String remarks,
    required String resolvedBy,
  });

  // Institutional Fees & Fines
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
}

/// CampusFacade is the production implementation of ICampusFacade.
class CampusFacade implements ICampusFacade {
  @override
  final ICampusStorage storage;

  @override
  final ICampusApi api;

  CampusFacade({
    required this.storage,
    required this.api,
  });

  @override
  bool get isOnline => storage.isOnline;

  @override
  OpticalSessionModel? get activeOpticalSession => storage.activeOpticalSession;

  @override
  List<AttendanceRecordModel> get opticalRoster => storage.opticalRoster;

  @override
  Future<bool> checkConnectivity({bool force = false}) =>
      storage.checkConnectivity(force: force);

  @override
  Future<void> refreshAndSync(String userId) =>
      storage.refreshConnectivityAndSync(userId);

  @override
  Future<UserModel> login(String identifier, String password) =>
      storage.authenticate(identifier, password);

  @override
  void logout() => storage.logout();

  @override
  Future<UserModel> getUserProfile(String idOrHandle) =>
      storage.getUserProfile(idOrHandle);

  @override
  Future<List<UserModel>> getUsers({
    String? status,
    String? archetype,
    String? search,
    bool forceRefresh = false,
  }) =>
      storage.getUsers(
        status: status,
        archetype: archetype,
        search: search,
        forceRefresh: forceRefresh,
      );

  @override
  Future<UserModel> createStudent(Map<String, dynamic> data) =>
      storage.createStudent(data);

  @override
  Future<UserModel> createEmployee(Map<String, dynamic> data) =>
      storage.createEmployee(data);

  @override
  Future<UserModel> createContractor(Map<String, dynamic> data) =>
      storage.createContractor(data);

  @override
  Future<UserModel> discontinueUser({
    required String userId,
    required String status,
    required String reason,
    required String discontinuedBy,
  }) =>
      storage.discontinueUser(
        userId: userId,
        status: status,
        reason: reason,
        discontinuedBy: discontinuedBy,
      );

  @override
  Future<UserModel> reactivateUser(String userId) =>
      storage.reactivateUser(userId);

  @override
  List<CourseModel> getCachedCourses() => storage.cachedCourses;

  @override
  Future<List<TimetableSlotModel>> getTimetable(String scope) =>
      storage.getTimetable(scope);

  @override
  Future<TimetableSlotModel> saveTimetableSlot(TimetableSlotModel slot) =>
      storage.saveTimetableSlot(slot);

  @override
  Future<bool> deleteTimetableSlot(String id) =>
      storage.deleteTimetableSlot(id);

  @override
  Future<void> declareDayOff({
    required int dayOfWeek,
    required String reason,
    required String scopeCode,
  }) =>
      storage.declareDayOff(
        dayOfWeek: dayOfWeek,
        reason: reason,
        scopeCode: scopeCode,
      );

  @override
  Future<void> restoreDaySchedule({
    required int dayOfWeek,
    required String scopeCode,
  }) =>
      storage.restoreDaySchedule(
        dayOfWeek: dayOfWeek,
        scopeCode: scopeCode,
      );

  @override
  Future<List<TimetableConflictModel>> checkTimetableConflicts(
          TimetableSlotModel candidate) =>
      storage.checkTimetableConflicts(candidate);

  @override
  Future<List<NoticeModel>> getNotices(List<String> scopes) =>
      storage.getNotices(scopes);

  @override
  Future<List<AttendanceSummaryModel>> getAttendanceSummary(String studentId) =>
      storage.getAttendanceSummary(studentId);

  @override
  Future<OpticalSessionModel> startOpticalSession({
    required String courseId,
    required String courseCode,
    required String courseName,
    required String roomNumber,
    required String scopeCode,
    required String markedByUserId,
    required String markedByName,
    int refreshIntervalMs = 5000,
  }) =>
      storage.startOpticalSession(
        courseId: courseId,
        courseCode: courseCode,
        courseName: courseName,
        roomNumber: roomNumber,
        scopeCode: scopeCode,
        markedByUserId: markedByUserId,
        markedByName: markedByName,
        refreshIntervalMs: refreshIntervalMs,
      );

  @override
  Future<OpticalVerificationResult> verifyOpticalAttendance({
    required OpticalFramePacket packet,
    required UserModel student,
  }) =>
      storage.verifyOpticalAttendance(packet: packet, student: student);

  @override
  Future<List<AttendanceRecordModel>> getOpticalRoster(String sessionId) =>
      storage.getOpticalRoster(sessionId);

  @override
  Future<void> endOpticalSession(String sessionId) =>
      storage.endOpticalSession(sessionId);

  @override
  Future<List<DepartmentModel>> getDepartments({bool forceRefresh = false}) =>
      storage.getDepartments(forceRefresh: forceRefresh);

  @override
  Future<DepartmentModel> addDepartment(Map<String, dynamic> payload) =>
      storage.addDepartment(payload);

  @override
  Future<DepartmentDetailModel> getDepartmentDetail(String id) =>
      storage.getDepartmentDetail(id);

  @override
  Future<List<ProgramModel>> getPrograms() => storage.getPrograms();

  @override
  Future<List<SubjectModel>> getSubjects() => storage.getSubjects();

  @override
  Future<SubjectModel> createSubject(Map<String, dynamic> payload) =>
      storage.createSubject(payload);

  @override
  Future<List<SyllabusVersionModel>> getSubjectSyllabusAudit(String subjectId) =>
      storage.getSubjectSyllabusAudit(subjectId);

  @override
  Future<SyllabusVersionModel> reviseSubjectSyllabus(Map<String, dynamic> payload) =>
      storage.reviseSubjectSyllabus(payload);

  @override
  Future<List<SemesterModel>> getSemesters() => storage.getSemesters();

  @override
  Future<SemesterDetailModel> getSemesterDetail(String id) =>
      storage.getSemesterDetail(id);

  @override
  Future<List<SectionModel>> getSections({bool forceRefresh = false}) =>
      storage.getSections(forceRefresh: forceRefresh);

  @override
  Future<SectionModel> addSection(Map<String, dynamic> payload) =>
      storage.addSection(payload);

  @override
  Future<SectionDetailModel> getSectionDetail(String id) =>
      storage.getSectionDetail(id);

  @override
  Future<void> assignStudentToSection({
    required String sectionId,
    required String studentId,
    required String programId,
  }) =>
      storage.assignStudentToSection(
        sectionId: sectionId,
        studentId: studentId,
        programId: programId,
      );

  @override
  Future<void> transferStudentSection({
    required String studentId,
    required String targetSectionId,
  }) =>
      storage.transferStudentSection(
        studentId: studentId,
        targetSectionId: targetSectionId,
      );

  @override
  Future<int> mergeSectionCohorts({
    required String sourceSectionId,
    required String targetSectionId,
  }) =>
      storage.mergeSectionCohorts(
        sourceSectionId: sourceSectionId,
        targetSectionId: targetSectionId,
      );

  @override
  Future<List<LabBatchModel>> getSectionBatches(String sectionId) =>
      storage.getSectionBatches(sectionId);

  @override
  Future<LabBatchModel> createLabBatch(Map<String, dynamic> payload) =>
      storage.createLabBatch(payload);

  @override
  Future<List<LabBatchModel>> autoPartitionBatches(Map<String, dynamic> payload) =>
      storage.autoPartitionBatches(payload);

  @override
  Future<void> assignStudentBatch({
    required String batchId,
    required String studentId,
  }) =>
      storage.assignStudentBatch(
        batchId: batchId,
        studentId: studentId,
      );

  @override
  Future<List<FacultyAllocationModel>> getSectionFacultyAllocations(String sectionId) =>
      storage.getSectionFacultyAllocations(sectionId);

  @override
  Future<FacultyAllocationModel> assignFacultyAllocation(Map<String, dynamic> payload) =>
      storage.assignFacultyAllocation(payload);

  @override
  Future<void> removeFacultyAllocation(String sectionId, String allocationId) =>
      storage.removeFacultyAllocation(sectionId, allocationId);

  @override
  Future<List<FacultyWorkloadSummaryModel>> getFacultyWorkloadSummaries({String? teacherId}) =>
      storage.getFacultyWorkloadSummaries(teacherId: teacherId);

  @override
  Future<List<HostelRoomModel>> getHostelRooms({int? floor}) =>
      storage.getHostelRooms(floor: floor);

  @override
  Future<HostelRoomModel> createHostelRoom(int roomNumber, String blockName) =>
      storage.createHostelRoom(roomNumber, blockName);

  @override
  Future<HostelRoomModel> updateHostelRoom(
          int originalRoomNumber, int newRoomNumber, String blockName) =>
      storage.updateHostelRoom(originalRoomNumber, newRoomNumber, blockName);

  @override
  Future<HostelAssetModel> addHostelAsset(
          int roomNumber, String assetType, String serialNumber, String condition) =>
      storage.addHostelAsset(roomNumber, assetType, serialNumber, condition);

  @override
  Future<void> removeHostelAsset(int roomNumber, String assetId) =>
      storage.removeHostelAsset(roomNumber, assetId);

  @override
  Future<HostelAssetModel> updateHostelAsset(
          int roomNumber, String assetId, {String? serialNumber, String? condition}) =>
      storage.updateHostelAsset(roomNumber, assetId,
          serialNumber: serialNumber, condition: condition);

  @override
  Future<HostelOccupantModel> assignHostelOccupant(
          int roomNumber, String userId, String handle, String name) =>
      storage.assignHostelOccupant(roomNumber, userId, handle, name);

  @override
  Future<void> removeHostelOccupant(int roomNumber, String userId) =>
      storage.removeHostelOccupant(roomNumber, userId);

  @override
  Future<List<MessMealModel>> getMessTimetable() =>
      storage.getMessTimetable();

  @override
  Future<MessMealModel> updateMessMeal(MessMealModel updatedMeal) =>
      storage.updateMessMeal(updatedMeal);

  @override
  Future<MessReportSummary> getMessRatingsReport({String? mealId, String? rating}) =>
      storage.getMessRatingsReport(mealId: mealId, rating: rating);

  @override
  Future<MessRatingModel> submitMessRating({
    required String mealId,
    required String userId,
    required String userName,
    required String campusHandle,
    required String rating,
    required String message,
  }) =>
      storage.submitMessRating(
        mealId: mealId,
        userId: userId,
        userName: userName,
        campusHandle: campusHandle,
        rating: rating,
        message: message,
      );

  @override
  Future<List<ComplaintModel>> getComplaints({
    String? category,
    String? status,
    String? submittedBy,
    String? viewerId,
    List<String>? allowedCategories,
  }) =>
      storage.getComplaints(
        category: category,
        status: status,
        submittedBy: submittedBy,
        viewerId: viewerId,
        allowedCategories: allowedCategories,
      );

  @override
  Future<ComplaintModel> createComplaint(ComplaintModel complaint) =>
      storage.createComplaint(complaint);

  @override
  Future<ComplaintModel> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String remarks,
    required String resolvedBy,
  }) =>
      storage.updateComplaintStatus(
        complaintId: complaintId,
        status: status,
        remarks: remarks,
        resolvedBy: resolvedBy,
      );

  // Institutional Fees & Fines
  @override
  Future<FeeSummaryModel> getFeeSummary(String studentId) =>
      storage.getFeeSummary(studentId);

  @override
  Future<List<FeeInvoiceModel>> getInvoices({String? studentId, String? status}) =>
      storage.getInvoices(studentId: studentId, status: status);

  @override
  Future<FeeInvoiceModel?> getInvoiceById(String id) =>
      storage.getInvoiceById(id);

  @override
  Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required String studentId,
    required double amount,
    required String paymentMethod,
  }) =>
      storage.payInvoice(
        invoiceId: invoiceId,
        studentId: studentId,
        amount: amount,
        paymentMethod: paymentMethod,
      );

  @override
  Future<List<FineRecordModel>> getFines({String? studentId, String? status}) =>
      storage.getFines(studentId: studentId, status: status);

  @override
  Future<Map<String, dynamic>> payFine({
    required String fineId,
    required String studentId,
    required String paymentMethod,
  }) =>
      storage.payFine(
        fineId: fineId,
        studentId: studentId,
        paymentMethod: paymentMethod,
      );

  @override
  Future<FineRecordModel> appealFine({
    required String fineId,
    required String reason,
  }) =>
      storage.appealFine(fineId: fineId, reason: reason);

  @override
  Future<FineRecordModel> waiveFine({
    required String fineId,
    required String waivedBy,
  }) =>
      storage.waiveFine(fineId: fineId, waivedBy: waivedBy);

  @override
  Future<List<FeePaymentModel>> getFeePayments(String studentId) =>
      storage.getFeePayments(studentId);

  @override
  Future<FeeReceiptModel> getFeeReceipt(String receiptNumber) =>
      storage.getFeeReceipt(receiptNumber);
}
