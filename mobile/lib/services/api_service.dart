import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password, String deviceHash) async {
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_hash': deviceHash,
        }),
      );
    } catch (e) {
      throw Exception('Network Error: Make sure the backend server is running and reachable.');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _storage.write(key: 'access_token', value: data['access_token']);
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> startSession({required int classroomId, required int subjectId, int durationMins = 60, double? lat, double? long}) async {
    final token = await getToken();
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(ApiConstants.startSession),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'classroom_id': classroomId,
          'subject_id': subjectId,
          'duration_mins': durationMins,
          if (lat != null) 'lat': lat,
          if (long != null) 'long': long,
        }),
      );
    } catch (e) {
      throw Exception('Network Error: Make sure the server is reachable.');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Failed to start session');
    }
  }

  Future<Map<String, dynamic>> verifyAttendance({
    required String sessionToken,
    required String qrToken,
    required double lat,
    required double long,
    required int rssi,
    required String teacherUuid,
  }) async {
    final token = await getToken();
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(ApiConstants.verifyAttendance),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'session_token': sessionToken,
          'qr_token': qrToken,
          'gps_data': {'lat': lat, 'long': long},
          'ble_data': {'rssi': rssi, 'teacher_uuid': teacherUuid},
        }),
      );
    } catch (e) {
      throw Exception('Network Error: Make sure the server is reachable.');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Attendance verification failed');
    }
  }

  // --- Academic & Student Dashboard ---

  Future<Map<String, dynamic>> getStudentStats() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/student-stats'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load student stats');
    }
  }

  Future<List<dynamic>> getTimetable() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/timetable'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load timetable');
    }
  }

  Future<void> applyLeave(Map<String, dynamic> leaveData) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/attendance/leave-request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(leaveData),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to apply for leave');
    }
  }

  Future<List<dynamic>> getMyLeaves() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/my-leaves'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load my leave requests');
    }
  }

  Future<String> uploadProofBytes(List<int> bytes, String fileName) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}/attendance/upload-proof'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['document_url'];
    } else {
      throw Exception('Failed to upload proof');
    }
  }

  Future<String> uploadProof(String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}/attendance/upload-proof'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['document_url'];
    } else {
      throw Exception('Failed to upload proof');
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load profile');
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/auth/me'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to update profile');
    }
  }

  // --- Faculty Methods ---

  Future<List<dynamic>> getFacultyTimetable() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/faculty-timetable'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load faculty timetable');
  }

  Future<Map<String, dynamic>?> getCurrentClass() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/current-class'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>?> getActiveSession() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/active-session'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') return null;
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<dynamic>> getSessionRoster(int sessionId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/session/$sessionId/roster'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load roster');
  }

  Future<void> markStudentPresent(int sessionId, int studentId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/attendance/session/$sessionId/mark-present/$studentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Failed to mark student present');
  }

  Future<void> endSession(int sessionId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/attendance/end-session/$sessionId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Failed to end session');
  }

  Future<List<dynamic>> getFacultySessionHistory() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/attendance/faculty-session-history'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load session history');
  }

  // --- HOD Leave Management ---

  Future<List<dynamic>> getHodLeaveRequests({String? status}) async {
    final token = await getToken();
    var url = '${ApiConstants.baseUrl}/attendance/leave-requests';
    if (status != null) url += '?status=$status';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load leave requests');
  }

  Future<void> approveLeave(int requestId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/attendance/leave-requests/$requestId/approve'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Failed to approve leave');
  }

  Future<void> rejectLeave(int requestId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/attendance/leave-requests/$requestId/reject'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Failed to reject leave');
  }

  Future<void> postAnnouncement(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/announcements/'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to post announcement');
  }

  Future<List<dynamic>> getAnnouncements() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/announcements/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load announcements');
  }

  Future<String> uploadAnnouncementImage(String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}/announcements/upload-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['image_url'];
    } else {
      throw Exception('Failed to upload image');
    }
  }

  Future<void> deleteAnnouncement(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/announcements/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Failed to delete announcement');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }
}
