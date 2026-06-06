import 'package:flutter/material.dart' show Color;

// ─── USER ────────────────────────────────────────────────────────────────────
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final bool isActive;

  User({required this.id, required this.name, required this.email,
        required this.role, this.phone, this.isActive = true});

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['_id'] ?? j['id'] ?? '',
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 'caller',
    phone: j['phone'],
    isActive: j['isActive'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'name': name, 'email': email,
    'role': role, 'phone': phone, 'isActive': isActive,
  };

  bool get isAdmin => role == 'admin' || role == 'super admin';
  bool get isSuperAdmin => role == 'super admin';
  bool get isCaller => role == 'caller';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// ─── LEAD ────────────────────────────────────────────────────────────────────
class Lead {
  final String id;
  final String name;
  final String phone;
  final String? alternatePhone;
  final String? email;
  final String status;
  final String? leadSource;
  final String? location;
  final String? lastQualification;
  final double? budget;
  final String? mode;
  final String? assignedToId;
  final String? assignedToName;
  final String? campaignId;
  final String? campaignName;
  final String? courseInterestId;
  final String? courseInterestName;
  final List<String> preferredCourses;
  final bool isStarred;
  final int rating;
  final DateTime? createdAt;
  final DateTime? nextFollowupDate;
  final DateTime? demoScheduledDate;
  final List<Activity> activities;

  Lead({
    required this.id, required this.name, required this.phone,
    this.alternatePhone, this.email, required this.status,
    this.leadSource, this.location, this.lastQualification,
    this.budget, this.mode, this.assignedToId, this.assignedToName,
    this.campaignId, this.campaignName, this.courseInterestId,
    this.courseInterestName, this.preferredCourses = const [],
    this.isStarred = false, this.rating = 0,
    this.createdAt, this.nextFollowupDate, this.demoScheduledDate,
    this.activities = const [],
  });

  factory Lead.fromJson(Map<String, dynamic> j) {
    final at = j['assignedTo'];
    final camp = j['campaign'];
    final course = j['courseInterest'];
    return Lead(
      id: j['_id'] ?? '',
      name: j['name'] ?? '',
      phone: j['phone'] ?? '',
      alternatePhone: j['alternatePhone'],
      email: j['email'],
      status: j['status'] ?? 'Fresh',
      leadSource: j['leadSource'],
      location: j['location'],
      lastQualification: j['lastQualification'],
      budget: (j['budget'] as num?)?.toDouble(),
      mode: j['mode'],
      assignedToId: at is Map ? at['_id'] : at,
      assignedToName: at is Map ? at['name'] : null,
      campaignId: camp is Map ? camp['_id'] : camp,
      campaignName: camp is Map ? camp['name'] : null,
      courseInterestId: course is Map ? course['_id'] : course,
      courseInterestName: course is Map ? course['name'] : null,
      preferredCourses: List<String>.from(j['preferredCourses'] ?? []),
      isStarred: j['isStarred'] ?? false,
      rating: j['rating'] ?? 0,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      nextFollowupDate: j['nextFollowupDate'] != null ? DateTime.tryParse(j['nextFollowupDate']) : null,
      demoScheduledDate: j['demoScheduledDate'] != null ? DateTime.tryParse(j['demoScheduledDate']) : null,
      activities: (j['activities'] as List? ?? []).map((a) => Activity.fromJson(a)).toList(),
    );
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'fresh': return const Color(0xFF3B82F6);
      case 'connected': return const Color(0xFF10B981);
      case 'call not responding': return const Color(0xFF6B7280);
      case 'call back later': return const Color(0xFFF59E0B);
      case 'not interested': return const Color(0xFFEF4444);
      case 'demo scheduled': return const Color(0xFF8B5CF6);
      case 'demo done': return const Color(0xFF06B6D4);
      case 'won': return const Color(0xFF22C55E);
      case 'lost': return const Color(0xFFDC2626);
      default: return const Color(0xFF6B7280);
    }
  }

  String get statusEmoji {
    switch (status.toLowerCase()) {
      case 'fresh': return '🆕';
      case 'connected': return '📞';
      case 'call not responding': return '📵';
      case 'call back later': return '⏰';
      case 'not interested': return '❌';
      case 'demo scheduled': return '📅';
      case 'demo done': return '✅';
      case 'won': return '🏆';
      case 'lost': return '💔';
      default: return '📋';
    }
  }
}

// ─── ACTIVITY ────────────────────────────────────────────────────────────────
class Activity {
  final String type;
  final String? description;
  final String? callStatus;
  final int? callDuration;
  final String? performedByName;
  final DateTime? createdAt;

  Activity({
    required this.type, this.description, this.callStatus,
    this.callDuration, this.performedByName, this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> j) {
    final pb = j['performedBy'];
    return Activity(
      type: j['type'] ?? 'note',
      description: j['description'],
      callStatus: j['callStatus'],
      callDuration: j['callDuration'],
      performedByName: pb is Map ? pb['name'] : null,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
    );
  }

  String get durationFormatted {
    if (callDuration == null || callDuration == 0) return '0s';
    final m = callDuration! ~/ 60;
    final s = callDuration! % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

// ─── FOLLOW-UP ───────────────────────────────────────────────────────────────
class FollowUp {
  final String id;
  final String? leadId;
  final String? leadName;
  final String? leadPhone;
  final DateTime scheduledAt;
  final String status;
  final String? note;
  final String? assignedToName;
  final String? priority;

  FollowUp({
    required this.id, this.leadId, this.leadName, this.leadPhone,
    required this.scheduledAt, required this.status, this.note,
    this.assignedToName, this.priority,
  });

  factory FollowUp.fromJson(Map<String, dynamic> j) {
    final lead = j['lead'];
    final at = j['assignedTo'];
    return FollowUp(
      id: j['_id'] ?? '',
      leadId: lead is Map ? lead['_id'] : lead,
      leadName: lead is Map ? lead['name'] : null,
      leadPhone: lead is Map ? lead['phone'] : null,
      scheduledAt: DateTime.tryParse(j['scheduledAt'] ?? '') ?? DateTime.now(),
      status: j['status'] ?? 'pending',
      note: j['note'] ?? j['description'],
      assignedToName: at is Map ? at['name'] : null,
      priority: j['priority'],
    );
  }

  bool get isOverdue => scheduledAt.isBefore(DateTime.now()) && (status == 'upcoming' || status == 'pending');
  bool get isToday {
    final now = DateTime.now();
    return scheduledAt.year == now.year &&
           scheduledAt.month == now.month &&
           scheduledAt.day == now.day;
  }

  bool get isPending => status == 'upcoming' || status == 'pending';

  Color get priorityColor {
    switch (priority?.toLowerCase()) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF22A163);
    }
  }
}

// ─── CAMPAIGN ────────────────────────────────────────────────────────────────
class Campaign {
  final String id;
  final String name;
  final String? description;
  final String? priority;
  final int totalLeads;
  final int called;
  final int won;
  final DateTime? createdAt;
  final List<String> assignedCallerNames;

  Campaign({
    required this.id, required this.name, this.description,
    this.priority, required this.totalLeads,
    this.called = 0, this.won = 0,
    this.createdAt, this.assignedCallerNames = const [],
  });

  // Single source of truth: calculated from real lead counts
  double get progress => totalLeads > 0 ? called / totalLeads : 0;
  int get conversionPct => totalLeads > 0 ? (won / totalLeads * 100).toInt() : 0;

  factory Campaign.fromJson(Map<String, dynamic> j) {
    final callers = j['assignedCallers'] as List? ?? [];
    // Compute called/won from statusBreakdown if available (from /api/campaigns)
    final statusBreakdown = j['statusBreakdown'] as List? ?? [];
    int called = 0, won = 0, total = 0;
    if (statusBreakdown.isNotEmpty) {
      for (final s in statusBreakdown) {
        final cnt = (s['count'] as num?)?.toInt() ?? 0;
        total += cnt;
        if (s['_id'] != 'Fresh') called += cnt;
        if (s['_id'] == 'Won') won += cnt;
      }
    } else {
      // Fallback to direct fields
      final stats = j['stats'] as Map? ?? {};
      final rawCalled = j['called'] ?? j['calledCount'] ?? stats['called'] ?? j['contactedCount'] ?? 0;
      final rawWon = j['won'] ?? j['wonCount'] ?? stats['won'] ?? 0;
      called = (rawCalled as num).toInt();
      won = (rawWon as num).toInt();
      total = j['totalLeads'] ?? 0;
    }
    return Campaign(
      id: j['_id'] ?? '',
      name: j['name'] ?? '',
      description: j['description'],
      priority: j['priority'],
      totalLeads: j['totalLeads'] ?? total,
      called: called,
      won: won,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      assignedCallerNames: callers.map((c) => c is Map ? (c['name'] as String? ?? '') : c.toString()).toList(),
    );
  }

  Color get priorityColor {
    switch (priority?.toLowerCase()) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      case 'low': return const Color(0xFF22A163);
      default: return const Color(0xFF6B7280);
    }
  }
}

// ─── DASHBOARD STATS ─────────────────────────────────────────────────────────
class DashboardStats {
  final int total;
  final int todayCallsCount;
  final int todayCallsDuration;
  final int overdueFollowupsCount;
  final int weeklyWins;
  final int myRank;
  final int totalCallers;
  final int streak;
  final List<Map<String, dynamic>> statusCounts;
  final List<Map<String, dynamic>> startMyDayQueue;
  final List<Map<String, dynamic>> upcomingDemos;
  final List<int> trendThisWeek;
  final List<int> trendLastWeek;

  DashboardStats({
    this.total = 0, this.todayCallsCount = 0, this.todayCallsDuration = 0,
    this.overdueFollowupsCount = 0, this.weeklyWins = 0, this.myRank = 1,
    this.totalCallers = 1, this.streak = 0,
    this.statusCounts = const [], this.startMyDayQueue = const [],
    this.upcomingDemos = const [], this.trendThisWeek = const [],
    this.trendLastWeek = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    final todayCalls = j['todayCalls'] as Map? ?? {};
    return DashboardStats(
      total: j['total'] ?? 0,
      todayCallsCount: todayCalls['count'] ?? 0,
      todayCallsDuration: todayCalls['duration'] ?? 0,
      overdueFollowupsCount: j['overdueFollowupsCount'] ?? 0,
      weeklyWins: j['weeklyWins'] ?? 0,
      myRank: j['myRank'] ?? 1,
      totalCallers: j['totalCallers'] ?? 1,
      streak: j['streak'] ?? 0,
      statusCounts: List<Map<String, dynamic>>.from(j['statusCounts'] ?? []),
      startMyDayQueue: List<Map<String, dynamic>>.from(j['startMyDayQueue'] ?? []),
      upcomingDemos: List<Map<String, dynamic>>.from(j['upcomingDemos'] ?? []),
      trendThisWeek: List<int>.from((j['trendThisWeek'] as List? ?? []).map((e) => (e as num).toInt())),
      trendLastWeek: List<int>.from((j['trendLastWeek'] as List? ?? []).map((e) => (e as num).toInt())),
    );
  }
}