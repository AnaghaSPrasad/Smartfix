import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../models/complaint.dart';

class ApiService {

  // ─── Backend URL configuration ─────────────────────────────────────────────
  // • Web / Desktop         → http://localhost:8000/api
  // • Android emulator      → http://10.0.2.2:8000/api
  // • Physical Android/iOS  → http://192.168.29.158:8000/api  (your PC's Wi-Fi IP)
  //
  // To override at runtime (e.g. for testing) set ApiService.customBaseUrl.
  static String? customBaseUrl;

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) return customBaseUrl!;
    if (kIsWeb) return 'http://localhost:8000/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return 'http://127.0.0.1:8000/api';
      default:
        // Physical Android / iOS device – use the PC's actual Wi-Fi IP.
        // Update this if your PC's IP changes.
        return 'http://192.168.29.158:8000/api';
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  String _parseErrorMessage(String responseBody, String defaultMessage) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final List<String> messages = [];
        decoded.forEach((key, value) {
          if (value is List) {
            messages.add(value.map((e) => e.toString()).join(' '));
          } else if (value is String) {
            messages.add(value);
          } else if (value is Map) {
            value.forEach((k, v) => messages.add('$v'));
          }
        });
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        return decoded.map((e) => e.toString()).join(' ');
      }
    } catch (_) {}
    return defaultMessage;
  }

  // ---------- AUTH ----------

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
      await prefs.setString('role', data['role'] ?? 'customer');
      return data;
    } else {
      throw Exception(_parseErrorMessage(res.body, 'Invalid username or password.'));
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String role, // 'customer' or 'worker'
    String phone = '',
    String category = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'role': role,
        'phone': phone,
        'category': category,
      }),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception(_parseErrorMessage(res.body, 'Registration failed. Please try again.'));
    }
  }


  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('role');
  }

  Future<AppUser> getProfile() async {
    final res = await http.get(Uri.parse('$baseUrl/auth/profile/'), headers: await _authHeaders());
    if (res.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load profile: ${res.statusCode}');
  }

  Future<List<AppUser>> getAvailableWorkers({String? category}) async {
    final uri = category != null
        ? Uri.parse('$baseUrl/auth/available-workers/?category=$category')
        : Uri.parse('$baseUrl/auth/available-workers/');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => AppUser.fromJson(e)).toList();
    }
    throw Exception('Failed to load available workers: ${res.statusCode}');
  }

  Future<AppUser> updateAvailability(bool isAvailable) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/auth/profile/'),
      headers: await _authHeaders(),
      body: jsonEncode({'is_available': isAvailable}),
    );
    if (res.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update availability: ${res.body}');
  }

  // ---------- SERVICES ----------

  Future<List<ServiceItem>> getServices({String? category}) async {
    final uri = category != null
        ? Uri.parse('$baseUrl/services/?category=$category')
        : Uri.parse('$baseUrl/services/');

    final res = await http.get(uri, headers: await _authHeaders());

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => ServiceItem.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load services: ${res.statusCode}');
    }
  }

  // ---------- CUSTOMER BOOKINGS ----------

  Future<Booking> createBooking(Booking booking) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/'),
      headers: await _authHeaders(),
      body: jsonEncode(booking.toJson()),
    );

    if (res.statusCode == 201) {
      return Booking.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to create booking: ${res.body}');
    }
  }

  Future<List<Booking>> getMyBookings() async {
    final res = await http.get(Uri.parse('$baseUrl/bookings/'), headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Booking.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load bookings: ${res.statusCode}');
    }
  }

  // ---------- WORKER JOBS ----------

  Future<List<Booking>> getOpenJobs() async {
    final res = await http.get(Uri.parse('$baseUrl/bookings/open/'), headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Booking.fromJson(e)).toList();
    }
    throw Exception('Failed to load open jobs: ${res.statusCode}');
  }

  Future<List<Booking>> getMyJobs() async {
    final res = await http.get(Uri.parse('$baseUrl/bookings/mine/'), headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Booking.fromJson(e)).toList();
    }
    throw Exception('Failed to load your jobs: ${res.statusCode}');
  }

  Future<Booking> acceptJob(int bookingId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/accept/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return Booking.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to accept job');
  }

  Future<Booking> updateJobStatus(int bookingId, String status) async {
    final res = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/update_status/'),
      headers: await _authHeaders(),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode == 200) {
      return Booking.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to update job status');
  }

  // ---------- ADMIN ----------

  Future<List<AppUser>> getWorkers({bool? verified}) async {
    final uri = verified != null
        ? Uri.parse('$baseUrl/auth/workers/?verified=$verified')
        : Uri.parse('$baseUrl/auth/workers/');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => AppUser.fromJson(e)).toList();
    }
    throw Exception('Failed to load workers: ${res.statusCode}');
  }

  Future<AppUser> verifyWorker(int profileId, bool verify) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/workers/$profileId/verify/'),
      headers: await _authHeaders(),
      body: jsonEncode({'verify': verify}),
    );
    if (res.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update worker verification: ${res.body}');
  }

  Future<List<Booking>> getAllBookings({String? status}) async {
    final uri = status != null
        ? Uri.parse('$baseUrl/bookings/admin/all/?status=$status')
        : Uri.parse('$baseUrl/bookings/admin/all/');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Booking.fromJson(e)).toList();
    }
    throw Exception('Failed to load bookings: ${res.statusCode}');
  }

  Future<Booking> getBooking(int bookingId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/bookings/$bookingId/'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return Booking.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load booking details: ${res.statusCode}');
  }

  // ---------- COMPLAINTS ----------

  Future<List<Complaint>> getComplaints() async {
    final res = await http.get(Uri.parse('$baseUrl/complaints/'), headers: await _authHeaders());
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Complaint.fromJson(e)).toList();
    }
    throw Exception('Failed to load complaints: ${res.statusCode}');
  }

  Future<Complaint> fileComplaint(int bookingId, String description) async {
    final res = await http.post(
      Uri.parse('$baseUrl/complaints/'),
      headers: await _authHeaders(),
      body: jsonEncode({'booking': bookingId, 'description': description}),
    );
    if (res.statusCode == 201) {
      return Complaint.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to file complaint: ${res.body}');
  }

  Future<Complaint> createComplaint(int bookingId, String description) => fileComplaint(bookingId, description);

  Future<Complaint> resolveComplaint(int complaintId, String adminNote, {String status = 'resolved'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/complaints/$complaintId/resolve/'),
      headers: await _authHeaders(),
      body: jsonEncode({'admin_note': adminNote, 'status': status}),
    );
    if (res.statusCode == 200) {
      return Complaint.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to resolve complaint: ${res.body}');
  }
}


