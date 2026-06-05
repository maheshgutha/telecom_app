import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'https://telecommunication-hmkv.onrender.com/api';

  Future<Map<String, dynamic>> _get(String ep, AuthService auth) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$ep'), headers: auth.authHeaders)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) {
        auth.logout();
        return {'error': 'Unauthorized'};
      }
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _post(String ep, AuthService auth, Map body) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl$ep'),
          headers: auth.authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _put(String ep, AuthService auth, Map body) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl$ep'),
          headers: auth.authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _delete(String ep, AuthService auth) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl$ep'), headers: auth.authHeaders)
          .timeout(const Duration(seconds: 20));
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe(AuthService auth) => _get('/auth/me', auth);
  Future<Map<String, dynamic>> updateProfile(AuthService auth, Map data) => _put('/auth/profile', auth, data);

  // ─── LEADS ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLeads(AuthService auth, {
    String? search, String? status, String? source, String? filter, int page = 1, int limit = 20,
  }) async {
    String q = '?page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) q += '&search=$search';
    if (status != null && status != 'All') q += '&status=$status';
    if (source != null && source != 'All') q += '&source=$source';
    if (filter != null) q += '&filter=$filter';
    return _get('/leads$q', auth);
  }

  Future<Map<String, dynamic>> getLeadById(AuthService auth, String id) => _get('/leads/$id', auth);

  Future<Map<String, dynamic>> getLeadStats(AuthService auth) => _get('/leads/stats', auth);

  Future<Map<String, dynamic>> getMyCalls(AuthService auth) => _get('/leads/my-calls', auth);

  Future<Map<String, dynamic>> createLead(AuthService auth, Map<String, dynamic> data) =>
      _post('/leads', auth, data);

  Future<Map<String, dynamic>> updateLead(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/leads/$id', auth, data);

  Future<Map<String, dynamic>> deleteLead(AuthService auth, String id) =>
      _delete('/leads/$id', auth);

  Future<Map<String, dynamic>> updateLeadStatus(AuthService auth, String id, String status) =>
      _put('/leads/$id/status', auth, {'status': status});

  Future<Map<String, dynamic>> logCall(AuthService auth, String id, Map<String, dynamic> data) =>
      _post('/leads/$id/call', auth, data);

  Future<Map<String, dynamic>> addNote(AuthService auth, String id, Map<String, dynamic> data) =>
      _post('/leads/$id/note', auth, data);

  // ─── FOLLOW-UPS ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFollowUps(AuthService auth, {
    bool? forMe, String? due, String? status, String? type,
  }) async {
    String q = '?';
    if (forMe == true) q += 'forMe=true&';
    if (due != null) q += 'due=${due.toLowerCase()}&';
    if (status != null) q += 'status=$status&';
    if (type != null) q += 'type=$type&';
    return _get('/followups$q', auth);
  }

  Future<Map<String, dynamic>> createFollowUp(AuthService auth, Map<String, dynamic> data) =>
      _post('/followups', auth, data);

  Future<Map<String, dynamic>> updateFollowUp(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/followups/$id', auth, data);

  Future<Map<String, dynamic>> deleteFollowUp(AuthService auth, String id) =>
      _delete('/followups/$id', auth);

  // ─── CAMPAIGNS ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCampaigns(AuthService auth) => _get('/campaigns', auth);

  Future<Map<String, dynamic>> getCampaignById(AuthService auth, String id) =>
      _get('/campaigns/$id', auth);

  Future<Map<String, dynamic>> createCampaign(AuthService auth, Map<String, dynamic> data) =>
      _post('/campaigns', auth, data);

  Future<Map<String, dynamic>> updateCampaign(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/campaigns/$id', auth, data);

  // ─── REPORTS ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLeaderboard(AuthService auth, {String? period}) =>
      _get('/reports/leaderboard${period != null ? '?period=$period' : ''}', auth);

  Future<Map<String, dynamic>> getAdminAnalysis(AuthService auth) =>
      _get('/reports/admin-analysis', auth);

  Future<Map<String, dynamic>> getUserAnalysis(AuthService auth, String userId) =>
      _get('/reports/user-analysis/$userId', auth);

  Future<Map<String, dynamic>> getCallsSummary(AuthService auth) =>
      _get('/reports/calls-summary', auth);

  // ─── USERS ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUsers(AuthService auth) => _get('/users', auth);

  Future<Map<String, dynamic>> createUser(AuthService auth, Map<String, dynamic> data) =>
      _post('/users', auth, data);

  Future<Map<String, dynamic>> updateUser(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/users/$id', auth, data);

  Future<Map<String, dynamic>> deleteUser(AuthService auth, String id) =>
      _delete('/users/$id', auth);

  // ─── COURSES ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCourses(AuthService auth) => _get('/courses', auth);
}