import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink$path');
    final headers = await _getHeaders();
    return http.get(url, headers: headers);
  }

  static Future<http.Response> post(String path, {Object? body}) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink$path');
    final headers = await _getHeaders();
    return http.post(
      url,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }

  static Future<http.Response> put(String path, {Object? body}) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink$path');
    final headers = await _getHeaders();
    return http.put(
      url,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }

  static Future<http.Response> delete(String path) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink$path');
    final headers = await _getHeaders();
    return http.delete(url, headers: headers);
  }
}
