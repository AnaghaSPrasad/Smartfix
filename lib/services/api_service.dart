import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service.dart';
import '../models/booking.dart';

class ApiService {
  // TODO: Update this to your Django backend's actual address.
  // Use 10.0.2.2 instead of localhost when testing on the Android emulator.
  static const String baseUrl = 'http://10.0.2.2:8000/api';

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
      return data;
    } else {
      throw Exception('Login failed: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Registration failed: ${res.body}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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

  // ---------- BOOKINGS ----------

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
    final res = await http.get(
      Uri.parse('$baseUrl/bookings/'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Booking.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load bookings: ${res.statusCode}');
    }
  }
}
