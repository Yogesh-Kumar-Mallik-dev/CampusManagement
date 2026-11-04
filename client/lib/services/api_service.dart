import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/academic.dart';
import '../models/user.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8080'});

  Future<UserModel> login(String identifier, String password) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/v1/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(res.body);
      final userMap = data['user'] as Map<String, dynamic>;
      final scopes = (data['scopes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          ['global'];

      return UserModel(
        id: userMap['id'] ?? 'usr-$identifier',
        campusHandle: userMap['campus_handle'] ?? identifier,
        firstName: userMap['first_name'] ?? 'Campus',
        lastName: userMap['last_name'] ?? 'User',
        email: userMap['email'] ?? '$identifier@campus.edu',
        archetype: userMap['archetype'] ?? 'student',
        activeScopes: scopes,
      );
    }
    throw Exception('Authentication failed (${res.statusCode})');
  }

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<CourseModel>> fetchCourses() async {
    final res = await http.get(Uri.parse('$baseUrl/api/v1/academics/courses'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => CourseModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load courses (${res.statusCode})');
  }

  Future<List<TimetableSlotModel>> fetchTimetable(String scope) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/v1/academics/timetable?scope=$scope'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => TimetableSlotModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load timetable (${res.statusCode})');
  }

  Future<List<NoticeModel>> fetchNotices(List<String> scopes) async {
    final scopeParam = scopes.join(',');
    final res = await http
        .get(Uri.parse('$baseUrl/api/v1/notices?scopes=$scopeParam'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => NoticeModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load notices (${res.statusCode})');
  }

  Future<List<AttendanceSummaryModel>> fetchAttendanceSummary(
      String studentId) async {
    final res = await http.get(
        Uri.parse('$baseUrl/api/v1/attendance/summary?student_id=$studentId'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => AttendanceSummaryModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load attendance summary (${res.statusCode})');
  }

  Future<bool> pushAttendanceBatch(
      String markedByUserId, List<AttendanceSessionModel> sessions) async {
    final body = jsonEncode({
      'sessions': sessions.map((s) => s.toJson()).toList(),
    });
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/sync'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-ID': markedByUserId,
      },
      body: body,
    );
    return res.statusCode == 200;
  }
}
