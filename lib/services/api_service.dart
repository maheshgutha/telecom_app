import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'https://telecommunication-hmkv.onrender.com/api';

  Future<Map<String, dynamic>> _get(String ep, AuthService auth) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$ep'), headers: auth.authHeaders)
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 401) { auth.logout(); return {'error': 'Session expired. Please login again.'}; }
      if (res.statusCode >= 400) return {'error': 'Server error ${res.statusCode}'};
      return jsonDecode(res.body);
    } catch (e) { return {'error': 'Network error: ${e.toString().split(':').first}'}; }
  }

  Future<Map<String, dynamic>> _post(String ep, AuthService auth, Map body) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl$ep'), headers: auth.authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 401) { auth.logout(); return {'error': 'Unauthorized'}; }
      return jsonDecode(res.body);
    } catch (e) { return {'error': e.toString()}; }
  }

  Future<Map<String, dynamic>> _put(String ep, AuthService auth, Map body) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl$ep'), headers: auth.authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 401) { auth.logout(); return {'error': 'Unauthorized'}; }
      return jsonDecode(res.body);
    } catch (e) { return {'error': e.toString()}; }
  }

  Future<Map<String, dynamic>> _delete(String ep, AuthService auth) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl$ep'), headers: auth.authHeaders)
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 401) { auth.logout(); return {'error': 'Unauthorized'}; }
      return jsonDecode(res.body);
    } catch (e) { return {'error': e.toString()}; }
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe(AuthService auth) => _get('/auth/me', auth);
  Future<Map<String, dynamic>> updateProfile(AuthService auth, Map data) => _put('/auth/profile', auth, data);

  // ─── LEADS ───────────────────────────────────────────────────────────────
  // Returns: { leads, total, page, pages }
  Future<Map<String, dynamic>> getLeads(AuthService auth, {
    String? search, String? status, String? source,
    String? filter, String? assignedTo, String? campaign,
    int page = 1, int limit = 20,
  }) async {
    final q = StringBuffer('?page=$page&limit=$limit');
    if (search != null && search.isNotEmpty) q.write('&search=$search');
    if (status != null && status != 'All') q.write('&status=$status');
    if (source != null && source != 'All') q.write('&source=$source');
    if (filter != null && filter.isNotEmpty) q.write('&filter=$filter');
    if (assignedTo != null && assignedTo.isNotEmpty) q.write('&assignedTo=$assignedTo');
    if (campaign != null && campaign.isNotEmpty) q.write('&campaign=$campaign');
    return _get('/leads$q', auth);
  }

  Future<Map<String, dynamic>> getLeadById(AuthService auth, String id) =>
      _get('/leads/$id', auth);

  // Returns: { statusCounts, total, todayCalls:{count,duration}, weeklyWins,
  //           trendThisWeek, trendLastWeek, startMyDayQueue, upcomingDemos,
  //           overdueFollowupsCount, streak, myRank }
  Future<Map<String, dynamic>> getLeadStats(AuthService auth) =>
      _get('/leads/stats', auth);

  // Returns all leads assigned to me (not filtered by date)
  Future<Map<String, dynamic>> getMyCalls(AuthService auth) =>
      _get('/leads/my-calls', auth);

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

  // ─── FOLLOW-UPS ──────────────────────────────────────────────────────────
  // NOTE: Backend status field = 'upcoming' (not 'pending')
  // Overdue = status:'upcoming' AND scheduledAt < now
  Future<Map<String, dynamic>> getFollowUps(AuthService auth, {
    bool? forMe, String? status,
  }) async {
    final q = StringBuffer('?');
    if (forMe == true) q.write('forMe=true&');
    if (status != null) q.write('status=$status');
    return _get('/followups$q', auth);
  }

  // Get overdue followups (upcoming status + scheduledAt < now)
  Future<Map<String, dynamic>> getOverdueFollowUps(AuthService auth) =>
      _get('/followups?status=upcoming&due=overdue', auth);

  Future<Map<String, dynamic>> createFollowUp(AuthService auth, Map<String, dynamic> data) =>
      _post('/followups', auth, data);
  Future<Map<String, dynamic>> updateFollowUp(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/followups/$id', auth, data);
  Future<Map<String, dynamic>> deleteFollowUp(AuthService auth, String id) =>
      _delete('/followups/$id', auth);

  // ─── CAMPAIGNS ───────────────────────────────────────────────────────────
  // Returns: { campaigns: [{...campaign, totalLeads, statusBreakdown}] }
  Future<Map<String, dynamic>> getCampaigns(AuthService auth) =>
      _get('/campaigns', auth);

  // Returns: { campaign, statusBreakdown, lostReasons, callStats }
  Future<Map<String, dynamic>> getCampaignById(AuthService auth, String id) =>
      _get('/campaigns/$id', auth);

  // Get all leads for a campaign (no role filter)
  Future<Map<String, dynamic>> getCampaignLeads(AuthService auth, String campaignId, {String? status}) async {
    final q = StringBuffer('?campaign=$campaignId&limit=200&filter=all');
    if (status != null && status != 'All') q.write('&status=$status');
    return _get('/leads$q', auth);
  }

  Future<Map<String, dynamic>> createCampaign(AuthService auth, Map<String, dynamic> data) =>
      _post('/campaigns', auth, data);
  Future<Map<String, dynamic>> updateCampaign(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/campaigns/$id', auth, data);

  // ─── REPORTS ─────────────────────────────────────────────────────────────
  // Returns: { leaderboard: [{user, totalCalls, totalDuration, sales, connectedCalls}] }
  Future<Map<String, dynamic>> getLeaderboard(AuthService auth, {String period = 'today'}) =>
      _get('/reports/leaderboard?period=$period', auth);

  // Returns: { outcomes, teamStatus, dailyVolume, unassignedCount,
  //            overdueFollowupsCount, campaignPerformance, callers, ... }
  Future<Map<String, dynamic>> getAdminAnalysis(AuthService auth) =>
      _get('/reports/admin-analysis', auth);

  // Returns: { user, stats, outcomes, dailyVolume, recentActivities }
  Future<Map<String, dynamic>> getUserAnalysis(AuthService auth, String userId) =>
      _get('/reports/user-analysis/$userId', auth);

  // Returns: { today, week, statusBreakdown }
  Future<Map<String, dynamic>> getCallsSummary(AuthService auth) =>
      _get('/reports/calls-summary', auth);

  // ─── USERS ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUsers(AuthService auth) => _get('/users', auth);
  Future<Map<String, dynamic>> createUser(AuthService auth, Map<String, dynamic> data) =>
      _post('/users', auth, data);
  Future<Map<String, dynamic>> updateUser(AuthService auth, String id, Map<String, dynamic> data) =>
      _put('/users/$id', auth, data);
  Future<Map<String, dynamic>> deleteUser(AuthService auth, String id) =>
      _delete('/users/$id', auth);

  // ─── COURSES ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCourses(AuthService auth) => _get('/courses', auth);
}