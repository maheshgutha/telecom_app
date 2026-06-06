import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';
import 'lead_detail_screen.dart';
import 'caller_analysis_screen.dart';
import 'campaign_detail_screen.dart';
import 'followups_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _adminData;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    try {
      if (auth.user?.isAdmin == true) {
        final r = await api.getAdminAnalysis(auth);
        if (r['error'] != null) throw Exception(r['error']);
        _adminData = r;
      } else {
        final r = await api.getLeadStats(auth);
        if (r['error'] != null) throw Exception(r['error']);
        _statsData = r;

        final myCallsRes = await api.getMyCalls(auth);
        if (myCallsRes['error'] == null) {
          final leads = (myCallsRes['leads'] as List? ?? []).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
          final today = DateTime.now();
          int todayCount = 0;
          int todaySecs = 0;
          for (final l in leads) {
            bool calledToday = false;
            for (final a in l.activities) {
              if (a.type == 'call') {
                final ct = a.createdAt;
                if (ct != null && ct.toLocal().year == today.year && ct.toLocal().month == today.month && ct.toLocal().day == today.day) {
                  calledToday = true;
                  todaySecs += a.callDuration ?? 0;
                }
              }
            }
            if (calledToday) {
              todayCount++;
            }
          }
          _statsData?['todayCalls'] = {
            'count': todayCount,
            'duration': todaySecs,
          };
        }
      }
    } catch (e) { _error = e.toString().replaceAll('Exception: ', ''); }
    setState(() => _loading = false);
  }

  // ── Caller getters from /leads/stats ──────────────────────────────────────
  int get _myCallsCount => (_statsData?['todayCalls'] as Map?)?['count'] ?? 0;
  int get _myTalkSecs => (_statsData?['todayCalls'] as Map?)?['duration'] ?? 0;
  int get _callerOverdue => _statsData?['overdueFollowupsCount'] ?? 0;
  int get _weeklyWins => _statsData?['weeklyWins'] ?? 0;
  List<Map<String, dynamic>> get _statusCounts =>
      List<Map<String, dynamic>>.from(_statsData?['statusCounts'] ?? []);
  List<Map<String, dynamic>> get _priorityQueue =>
      List<Map<String, dynamic>>.from(_statsData?['startMyDayQueue'] ?? []);
  List<Map<String, dynamic>> get _upcomingDemos =>
      List<Map<String, dynamic>>.from(_statsData?['upcomingDemos'] ?? []);
  List<int> get _trendThis => List<int>.from(
      ((_adminData != null ? _adminData : _statsData)?['trendThisWeek'] as List? ?? []).map((e) => (e as num).toInt()));
  List<int> get _trendLast => List<int>.from(
      ((_adminData != null ? _adminData : _statsData)?['trendLastWeek'] as List? ?? []).map((e) => (e as num).toInt()));

  // ── Admin getters from /reports/admin-analysis ────────────────────────────
  int get _teamCalls =>
      (_adminData?['teamStatus'] as List? ?? []).fold<int>(0, (s, c) => s + ((c['callsToday'] as int?) ?? 0));
  int get _adminOverdue => _adminData?['overdueFollowupsCount'] ?? 0;
  int get _unassigned => _adminData?['unassignedCount'] ?? 0;
  double get _revenueWon => (_adminData?['revenueWon'] as num?)?.toDouble() ?? 0;
  List<Map<String, dynamic>> get _teamStatus =>
      List<Map<String, dynamic>>.from(_adminData?['teamStatus'] ?? []);
  List<Map<String, dynamic>> get _campaignPerf =>
      List<Map<String, dynamic>>.from(_adminData?['campaignPerformance'] ?? []);

  String _fmt(int sec) {
    if (sec == 0) return '0s';
    final h = sec ~/ 3600; final m = (sec % 3600) ~/ 60; final s = sec % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final isAdmin = user?.isAdmin ?? false;
    final overdueCount = isAdmin ? _adminOverdue : _callerOverdue;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 120, pinned: true, backgroundColor: kTextMain,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [kTextMain, kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Good ${DateTime.now().hour < 12 ? 'Morning' : DateTime.now().hour < 17 ? 'Afternoon' : 'Evening'}, ${user?.name ?? ''}!',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(user?.isSuperAdmin == true ? '⚡ Super Admin' : isAdmin ? '🎯 Admin Desk' : '📞 My Dashboard',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text((user?.role ?? '').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                  ])),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20), onPressed: _load),
                    CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(user?.initials ?? 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                  ]),
                ]),
              )),
            ),
          ),
        ),
        if (_loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_error != null) SliverFillRemaining(child: _ErrWidget(error: _error!, onRetry: _load))
        else SliverPadding(
          padding: const EdgeInsets.all(14),
          sliver: SliverList(delegate: SliverChildListDelegate([
            if (overdueCount > 0) ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowUpsScreen(initialTab: 2))),
                child: _OverdueBar(count: overdueCount),
              ),
              const SizedBox(height: 12),
            ],

            isAdmin ? _buildAdminKpis(context) : _buildCallerKpis(context),
            const SizedBox(height: 14),

            // Status chart
            if (!isAdmin && _statusCounts.where((e) => (e['count'] as num? ?? 0) > 0).isNotEmpty) ...[
              _StatusChart(statusCounts: _statusCounts), const SizedBox(height: 14),
            ],

            // Admin: use conversionFunnel for status chart
            if (isAdmin) ...[
              _buildAdminStatusChart(), const SizedBox(height: 14),
            ],

            // Caller sections
            if (!isAdmin) ...[
              if (_priorityQueue.isNotEmpty) ...[_PriorityQueue(queue: _priorityQueue), const SizedBox(height: 14)],
              if (_upcomingDemos.isNotEmpty) ...[_UpcomingDemos(demos: _upcomingDemos), const SizedBox(height: 14)],
              _WeeklyTrend(thisWeek: _trendThis, lastWeek: _trendLast),
              const SizedBox(height: 14),
            ],

            // Admin sections
            if (isAdmin && _adminData != null) ...[
              _AdminWeeklyTrend(adminData: _adminData!),
              const SizedBox(height: 14),
              _AdminCallerPanel(teamStatus: _teamStatus, teamCalls: _teamCalls, fmt: _fmt),
              const SizedBox(height: 14),
              _OutcomesChart(adminData: _adminData!),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }

  Widget _buildAdminStatusChart() {
    final funnel = _adminData?['conversionFunnel'] as List? ?? [];
    if (funnel.isEmpty) return const SizedBox();
    final items = funnel.where((f) => (f['count'] as int? ?? 0) > 0)
        .map((f) => {'_id': f['stage'], 'count': f['count']})
        .toList()
        .cast<Map<String, dynamic>>();
    if (items.isEmpty) return const SizedBox();
    return _StatusChart(statusCounts: items);
  }

  Widget _buildAdminKpis(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
      children: [
        _KpiTile('Team Calls Today', '$_teamCalls', Icons.phone_rounded, kPurple,
            sub: 'all callers', onTap: () => _showTeamCallsSheet(context)),
        _KpiTile('Overdue F/U', '$_adminOverdue', Icons.warning_rounded, kRed,
            sub: 'across team',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowUpsScreen(initialTab: 2)))),
        _KpiTile('Unassigned', '$_unassigned', Icons.person_off_rounded, kAmber,
            sub: 'leads', onTap: () => _showUnassignedSheet(context)),
        _KpiTile('Revenue Won', '₹${_revenueWon > 0 ? _fmt2(_revenueWon) : '0'}', Icons.currency_rupee_rounded, kGreen,
            sub: 'this month', onTap: () => _showRevenueBreakdownSheet(context)),
      ],
    );
  }

  String _fmt2(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _buildCallerKpis(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
      children: [
        _KpiTile("Today's Calls", '$_myCallsCount', Icons.phone_rounded, kPurple,
            sub: 'by me', onTap: () => _showMyCallsSheet(context)),
        _KpiTile('Talk Time', _fmt(_myTalkSecs), Icons.timer_rounded, kGreen,
            sub: 'today', onTap: () => _showTalkTimeSheet(context)),
        _KpiTile('Overdue F/U', '$_callerOverdue', Icons.warning_rounded, kRed,
            sub: 'pending',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowUpsScreen(initialTab: 2)))),
        _KpiTile('Weekly Wins 🏆', '$_weeklyWins', Icons.emoji_events_rounded, kAmber,
            sub: 'this week', onTap: () => _showWeeklyWinsSheet(context)),
      ],
    );
  }

  void _showTeamCallsSheet(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          _Handle(), _Header('Team Calls Today', '$_teamCalls calls', kPurple),
          const Divider(height: 1),
          Expanded(child: _teamStatus.isEmpty
            ? const Center(child: Text('No calls today', style: TextStyle(color: Colors.grey)))
            : ListView.builder(controller: ctrl, padding: const EdgeInsets.all(12), itemCount: _teamStatus.length,
                itemBuilder: (_, i) {
                  final c = _teamStatus[i]; final u = c['user'] as Map? ?? {};
                  final calls = c['callsToday'] as int? ?? 0;
                  final userId = u['_id'] as String?;
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: kPurpleLight,
                        child: Text((u['name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold))),
                    title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(u['email'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$calls', style: const TextStyle(fontWeight: FontWeight.bold, color: kPurple, fontSize: 18)),
                      const Text('calls', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ]),
                    onTap: userId != null ? () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => CallerAnalysisScreen(userId: userId, userName: u['name'] ?? ''))); } : null,
                  );
                })),
        ])));
  }

  void _showUnassignedSheet(BuildContext context) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (_, ctrl) => _UnassignedSheet(api: api, auth: auth, ctrl: ctrl, count: _unassigned)));
  }

  void _showMyCallsSheet(BuildContext context) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (_, ctrl) => _MyCallsSheet(api: api, auth: auth, ctrl: ctrl, count: _myCallsCount, secs: _myTalkSecs, fmt: _fmt)));
  }

  void _showTalkTimeSheet(BuildContext context) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (_, ctrl) => _TalkTimeSheet(api: api, auth: auth, ctrl: ctrl, totalSecs: _myTalkSecs, fmt: _fmt)));
  }

  void _showWeeklyWinsSheet(BuildContext context) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (_, ctrl) => _WeeklyWinsSheet(api: api, auth: auth, ctrl: ctrl)));
  }

  void _showRevenueBreakdownSheet(BuildContext context) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (_, ctrl) => _RevenueBreakdownSheet(api: api, auth: auth, ctrl: ctrl, totalRevenue: _revenueWon)));
  }
}

// ── SHEETS ────────────────────────────────────────────────────────────────────
class _UnassignedSheet extends StatefulWidget {
  final ApiService api; final AuthService auth; final ScrollController ctrl; final int count;
  const _UnassignedSheet({required this.api, required this.auth, required this.ctrl, required this.count});
  @override State<_UnassignedSheet> createState() => _UnassignedSheetState();
}
class _UnassignedSheetState extends State<_UnassignedSheet> {
  List<Lead> _leads = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    // Get unassigned leads - filter=all and check for no assignedTo
    final data = await widget.api.getLeads(widget.auth, filter: 'all', limit: 100);
    final all = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
    final unassigned = all.where((l) => l.assignedToId == null || l.assignedToId!.isEmpty).toList();
    if (mounted) setState(() { _leads = unassigned; _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    _Handle(),
    _Header('Unassigned Leads', '${widget.count} leads', kAmber),
    const Divider(height: 1),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
      : _leads.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline_rounded, size: 48, color: kGreen),
              const SizedBox(height: 12),
              const Text('All leads are assigned!', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text('Total checked: ${widget.count} from database', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]))
          : ListView.builder(controller: widget.ctrl, padding: const EdgeInsets.all(12), itemCount: _leads.length,
              itemBuilder: (_, i) {
                final l = _leads[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: kAmber.withOpacity(0.15),
                      child: Text(l.name.isNotEmpty ? l.name[0].toUpperCase() : '?', style: const TextStyle(color: kAmber, fontWeight: FontWeight.bold))),
                  title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l.phone),
                  trailing: StatusBadge(status: l.status),
                  onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id))); },
                );
              })),
  ]);
}

class _MyCallsSheet extends StatefulWidget {
  final ApiService api; final AuthService auth; final ScrollController ctrl;
  final int count, secs; final String Function(int) fmt;
  const _MyCallsSheet({required this.api, required this.auth, required this.ctrl, required this.count, required this.secs, required this.fmt});
  @override State<_MyCallsSheet> createState() => _MyCallsSheetState();
}
class _MyCallsSheetState extends State<_MyCallsSheet> {
  List<Lead> _leads = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await widget.api.getMyCalls(widget.auth);
    final today = DateTime.now();
    final allLeads = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
    final todayLeads = allLeads.where((l) {
      return l.activities.any((a) {
        if (a.type != 'call') return false;
        final ct = a.createdAt;
        return ct != null &&
            ct.toLocal().year == today.year &&
            ct.toLocal().month == today.month &&
            ct.toLocal().day == today.day;
      });
    }).toList();
    if (mounted) setState(() {
      _leads = todayLeads;
      _loading = false;
    });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    _Handle(),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
      const Expanded(child: Text("Today's Calls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      _Chip('${_leads.length} calls', kPurple), const SizedBox(width: 8),
      _Chip(widget.fmt(widget.secs), kGreen),
    ])),
    const Divider(height: 1),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
      : _leads.isEmpty ? const Center(child: Text('No calls logged today', style: TextStyle(color: Colors.grey)))
      : ListView.builder(controller: widget.ctrl, padding: const EdgeInsets.all(12), itemCount: _leads.length,
          itemBuilder: (_, i) {
            final l = _leads[i];
            return ListTile(
              leading: CircleAvatar(backgroundColor: l.statusColor.withOpacity(0.15),
                  child: Text(l.name.isNotEmpty ? l.name[0].toUpperCase() : '?', style: TextStyle(color: l.statusColor, fontWeight: FontWeight.bold))),
              title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(l.phone),
              trailing: StatusBadge(status: l.status),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id))); },
            );
          })),
  ]);
}

class _TalkTimeSheet extends StatefulWidget {
  final ApiService api; final AuthService auth; final ScrollController ctrl;
  final int totalSecs; final String Function(int) fmt;
  const _TalkTimeSheet({required this.api, required this.auth, required this.ctrl, required this.totalSecs, required this.fmt});
  @override State<_TalkTimeSheet> createState() => _TalkTimeSheetState();
}
class _TalkTimeSheetState extends State<_TalkTimeSheet> {
  List<Map<String, dynamic>> _entries = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await widget.api.getMyCalls(widget.auth);
    final leads = data['leads'] as List? ?? [];
    final today = DateTime.now();
    final entries = <Map<String, dynamic>>[];
    for (final l in leads) {
      for (final a in (l['activities'] as List? ?? [])) {
        if (a['type'] == 'call') {
          final ct = DateTime.tryParse(a['createdAt'] ?? '');
          if (ct != null && ct.year == today.year && ct.month == today.month && ct.day == today.day) {
            entries.add({...Map<String, dynamic>.from(a), 'leadName': l['name'], 'leadPhone': l['phone']});
          }
        }
      }
    }
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    _Handle(),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
      const Expanded(child: Text('Talk Time Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      _Chip('Total: ${widget.fmt(widget.totalSecs)}', kGreen),
    ])),
    const Divider(height: 1),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
      : _entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No call logs for today', style: TextStyle(color: Colors.grey)),
              Text('Total: ${widget.fmt(widget.totalSecs)} recorded', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]))
          : ListView.builder(controller: widget.ctrl, padding: const EdgeInsets.all(12), itemCount: _entries.length,
              itemBuilder: (_, i) {
                final c = _entries[i];
                final dur = c['callDuration'] as int? ?? 0;
                final status = c['callStatus'] as String? ?? 'no_answer';
                final conn = status == 'connected';
                return ListTile(
                  leading: CircleAvatar(backgroundColor: conn ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1),
                      child: Icon(Icons.phone_rounded, color: conn ? kGreen : kRed, size: 18)),
                  title: Text(c['leadName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(c['leadPhone'] ?? ''),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(widget.fmt(dur), style: TextStyle(fontWeight: FontWeight.bold, color: conn ? kGreen : Colors.grey, fontSize: 14)),
                    Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 9, color: conn ? kGreen : kRed, fontWeight: FontWeight.bold)),
                  ]),
                );
              })),
  ]);
}

// ── KPI TILE ──────────────────────────────────────────────────────────────────
class _KpiTile extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  final String? sub; final VoidCallback? onTap;
  const _KpiTile(this.label, this.value, this.icon, this.color, {this.sub, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: color.withOpacity(0.07), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18)),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 16),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 9, color: color.withOpacity(0.6))),
        ]),
      ]),
    ),
  );
}

// ── STATUS CHART ──────────────────────────────────────────────────────────────
class _StatusChart extends StatelessWidget {
  final List<Map<String, dynamic>> statusCounts;
  const _StatusChart({required this.statusCounts});
  static const _colors = [Color(0xFF5B3FC7), Color(0xFF8B5CF6), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFF22C55E), Color(0xFFDC2626)];
  @override
  Widget build(BuildContext context) {
    final items = statusCounts.where((e) => (e['count'] as num? ?? 0) > 0).toList();
    if (items.isEmpty) return const SizedBox();
    final total = items.fold<int>(0, (s, e) => s + ((e['count'] as num?)?.toInt() ?? 0));
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Leads by Stage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(height: 110, width: 110, child: PieChart(PieChartData(
            sections: List.generate(items.length, (i) {
              final v = (items[i]['count'] as num?)?.toDouble() ?? 0;
              return PieChartSectionData(value: v, color: _colors[i % _colors.length], radius: 38,
                  title: '${((v / total) * 100).toInt()}%',
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold));
            }), centerSpaceRadius: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(children: List.generate(items.take(7).length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(items[i]['_id'] ?? '', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
              Text('${items[i]['count'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          )))),
        ]),
      ]),
    );
  }
}

// ── PRIORITY QUEUE ────────────────────────────────────────────────────────────
class _PriorityQueue extends StatelessWidget {
  final List<Map<String, dynamic>> queue;
  const _PriorityQueue({required this.queue});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.format_list_bulleted_rounded, color: kPurple, size: 18), const SizedBox(width: 8),
        const Expanded(child: Text('Priority Call Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain))),
        _Chip('${queue.length}', kPurple),
      ]),
      const SizedBox(height: 10),
      ...queue.take(5).map((item) {
        final lead = item['lead'] as Map?;
        final reason = item['queueReason'] as String? ?? '';
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFAF9FF), border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lead?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)),
              Text(lead?['phone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(10)),
                  child: Text(reason, style: const TextStyle(color: kPurple, fontSize: 10, fontWeight: FontWeight.w600))),
            ])),
            Row(children: [
              IconButton(icon: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
                  child: const Icon(Icons.phone_rounded, color: kGreen, size: 16)),
                onPressed: () async { final uri = Uri(scheme: 'tel', path: lead?['phone'] ?? ''); if (await canLaunchUrl(uri)) launchUrl(uri); }),
              if ((lead?['_id'] as String?) != null)
                IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: kPurple, size: 16),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead!['_id'])))),
            ]),
          ]),
        );
      }),
    ]),
  );
}

// ── UPCOMING DEMOS ────────────────────────────────────────────────────────────
class _UpcomingDemos extends StatelessWidget {
  final List<Map<String, dynamic>> demos;
  const _UpcomingDemos({required this.demos});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.calendar_month_rounded, color: kGreen, size: 18), SizedBox(width: 8),
        Text('Upcoming Demos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain))]),
      const SizedBox(height: 10),
      ...demos.take(3).map((d) {
        final date = DateTime.tryParse(d['demoScheduledDate'] ?? '');
        final isToday = date != null && date.toLocal().day == DateTime.now().day;
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFAFDFB), border: Border.all(color: const Color(0xFFE8F8F0)), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (date != null) Text('📅 ${DateFormat('dd MMM, hh:mm a').format(date.toLocal())}',
                  style: const TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
            if (isToday) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text('TODAY', style: TextStyle(color: kRed, fontSize: 9, fontWeight: FontWeight.bold))),
          ]),
        );
      }),
    ]),
  );
}

// ── WEEKLY TREND ──────────────────────────────────────────────────────────────
class _WeeklyTrend extends StatelessWidget {
  final List<int> thisWeek, lastWeek;
  const _WeeklyTrend({required this.thisWeek, required this.lastWeek});
  @override
  Widget build(BuildContext context) {
    const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    final tw = List.generate(7, (i) => i < thisWeek.length ? thisWeek[i].toDouble() : 0.0);
    final lw = List.generate(7, (i) => i < lastWeek.length ? lastWeek[i].toDouble() : 0.0);
    final maxV = [...tw, ...lw, 1.0].reduce((a, b) => a > b ? a : b);
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Weekly Dial Trend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain))),
          GestureDetector(
            onTap: () => _showLastWeek(context, lw, days),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1).withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                child: const Text('Last Week ›', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 110, child: BarChart(BarChartData(
          maxY: maxV * 1.2,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
              getTitlesWidget: (val, _) { final i = val.toInt(); if (i < 0 || i >= 7) return const SizedBox();
                return Text(days[i], style: const TextStyle(fontSize: 9, color: Colors.grey)); },
            )),
          ),
          barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barsSpace: 2, barRods: [
            BarChartRodData(toY: tw[i], color: kPurple, width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
            BarChartRodData(toY: lw[i], color: const Color(0xFFCBD5E1), width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
          ])),
        ))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _DotLegend(kPurple, 'This Week'), const SizedBox(width: 16), _DotLegend(const Color(0xFFCBD5E1), 'Last Week (tap ›)'),
        ]),
      ]),
    );
  }
  void _showLastWeek(BuildContext ctx, List<double> lw, List<String> days) {
    final total = lw.fold(0.0, (a, b) => a + b).toInt();
    showModalBottomSheet(context: ctx, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Last Week Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextMain)),
        Text('Total: $total calls', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        ...List.generate(7, (i) {
          final calls = lw[i].toInt();
          final pct = total > 0 ? lw[i] / total : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            SizedBox(width: 36, child: Text(days[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMain))),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCBD5E1))))),
            const SizedBox(width: 8),
            Text('$calls', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ]));
        }),
        const SizedBox(height: 10),
      ])));
  }
}

class _DotLegend extends StatelessWidget {
  final Color color; final String label;
  const _DotLegend(this.color, this.label);
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

// ── ADMIN CALLER PANEL ────────────────────────────────────────────────────────
class _AdminCallerPanel extends StatelessWidget {
  final List<Map<String, dynamic>> teamStatus; final int teamCalls; final String Function(int) fmt;
  const _AdminCallerPanel({required this.teamStatus, required this.teamCalls, required this.fmt});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.people_rounded, color: kPurple, size: 18), const SizedBox(width: 8),
        const Expanded(child: Text('Team Callers (tap for analysis)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain))),
        _Chip('$teamCalls calls today', kPurple),
      ]),
      const SizedBox(height: 12),
      if (teamStatus.isEmpty) const Center(child: Text('No callers set up yet.', style: TextStyle(color: Colors.grey, fontSize: 12)))
      else ...teamStatus.take(8).map((c) {
        final u = c['user'] as Map? ?? {};
        final calls = c['callsToday'] as int? ?? 0;
        final isActive = c['isActive'] as bool? ?? false;
        final pct = (calls / 30).clamp(0.0, 1.0);
        final color = calls >= 25 ? kGreen : calls >= 10 ? kAmber : kRed;
        final userId = u['_id'] as String?;
        return GestureDetector(
          onTap: userId != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CallerAnalysisScreen(userId: userId, userName: u['name'] ?? ''))) : null,
          child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFAF9FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
            child: Column(children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: kPurpleLight,
                    child: Text((u['name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
                ])),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? kGreen : Colors.grey.shade300, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('$calls/30', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 16),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(color))),
            ]),
          ),
        );
      }),
    ]),
  );
}



// ── ADMIN WEEKLY TREND ────────────────────────────────────────────────────────
class _AdminWeeklyTrend extends StatelessWidget {
  final Map<String, dynamic> adminData;
  const _AdminWeeklyTrend({required this.adminData});

  @override
  Widget build(BuildContext context) {
    final vol = adminData['dailyVolume'] as List? ?? [];
    if (vol.isEmpty) return const SizedBox();

    int totalCalls = 0;
    int maxCalls = 0;
    String peakDayLabel = '';
    
    for (final day in vol) {
      final c = (day['count'] as num?)?.toInt() ?? 0;
      totalCalls += c;
      if (c > maxCalls) {
        maxCalls = c;
        final date = DateTime.tryParse(day['_id'] as String? ?? '');
        peakDayLabel = date != null ? DateFormat('EEEE').format(date) : '';
      }
    }
    
    final avgCalls = vol.isNotEmpty ? (totalCalls / vol.length).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kTextMain.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: kPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Dial Trend',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextMain,
                      ),
                    ),
                    Text(
                      'Team call attempts over the last 7 days',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Total Calls', '$totalCalls', kPurple),
              _buildMiniStat('Daily Avg', avgCalls, kGreen),
              _buildMiniStat('Peak Day', peakDayLabel.isEmpty ? '-' : peakDayLabel, kAmber),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: (maxCalls * 1.25).clamp(5, double.infinity).toDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: kTextMain.withOpacity(0.9),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = vol[groupIndex];
                      final dateStr = day['_id'] as String? ?? '';
                      final date = DateTime.tryParse(dateStr);
                      final formattedDate = date != null ? DateFormat('dd MMM').format(date) : dateStr;
                      return BarTooltipItem(
                        '$formattedDate\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} calls',
                            style: const TextStyle(color: kPurpleLight, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxCalls / 4).clamp(1, double.infinity),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: kBorder.withOpacity(0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= vol.length) return const SizedBox();
                        final dateStr = vol[i]['_id'] as String? ?? '';
                        final date = DateTime.tryParse(dateStr);
                        final label = date != null ? DateFormat('E').format(date) : dateStr.split('-').last;
                        
                        final isToday = date != null &&
                            date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;
                            
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                              color: isToday ? kPurple : Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(vol.length, (i) {
                  final day = vol[i];
                  final count = (day['count'] as num?)?.toDouble() ?? 0.0;
                  final date = DateTime.tryParse(day['_id'] as String? ?? '');
                  final isToday = date != null &&
                      date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        gradient: LinearGradient(
                          colors: isToday
                              ? [kGreen, kGreen.withOpacity(0.7)]
                              : [kPurple, kPurple.withOpacity(0.7)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _OutcomesChart extends StatelessWidget {
  final Map<String, dynamic> adminData;
  const _OutcomesChart({required this.adminData});
  static const _colors = [Color(0xFF5B3FC7), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4)];
  @override
  Widget build(BuildContext context) {
    final outcomes = adminData['outcomes'] as List? ?? [];
    if (outcomes.isEmpty) return const SizedBox();
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Call Outcomes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(height: 100, width: 100, child: PieChart(PieChartData(
            sections: List.generate(outcomes.length, (i) => PieChartSectionData(
              value: (outcomes[i]['count'] as num?)?.toDouble() ?? 0,
              color: _colors[i % _colors.length], radius: 34, title: '')),
            centerSpaceRadius: 16))),
          const SizedBox(width: 12),
          Expanded(child: Column(children: List.generate(outcomes.length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text((outcomes[i]['_id'] ?? '').toString().toLowerCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
              Text('${outcomes[i]['count'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          )))),
        ]),
      ]),
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────
class _Handle extends StatelessWidget {
  @override Widget build(BuildContext context) => Center(child: Container(
    margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))));
}

class _Header extends StatelessWidget {
  final String title, badge; final Color color;
  const _Header(this.title, this.badge, this.color);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      _Chip(badge, color),
    ]));
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip(this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)));
}

class _OverdueBar extends StatelessWidget {
  final int count;
  const _OverdueBar({required this.count});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), border: Border.all(color: const Color(0xFFFECACA)), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Text('⚠️', style: TextStyle(fontSize: 20)), const SizedBox(width: 10),
      Expanded(child: Text('$count overdue follow-up callbacks! Tap to view.',
          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600))),
      const Icon(Icons.chevron_right_rounded, color: Color(0xFF991B1B), size: 20),
    ]));
}

class _ErrWidget extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrWidget({required this.error, required this.onRetry});
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, color: kRed, size: 48), const SizedBox(height: 12),
    const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4),
    Text(error, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
    const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
  ]));
}

// ── WEEKLY WINS SHEET ──────────────────────────────────────────────────────────
class _WeeklyWinsSheet extends StatefulWidget {
  final ApiService api; final AuthService auth; final ScrollController ctrl;
  const _WeeklyWinsSheet({required this.api, required this.auth, required this.ctrl});
  @override State<_WeeklyWinsSheet> createState() => _WeeklyWinsSheetState();
}
class _WeeklyWinsSheetState extends State<_WeeklyWinsSheet> {
  List<Lead> _leads = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await widget.api.getLeads(widget.auth, status: 'Won', limit: 100);
    if (mounted) setState(() {
      _leads = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
      _loading = false;
    });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    _Handle(),
    _Header('Weekly Wins 🏆', '${_leads.length} won', kAmber),
    const Divider(height: 1),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
      : _leads.isEmpty ? const Center(child: Text('No won leads yet', style: TextStyle(color: Colors.grey)))
      : ListView.builder(controller: widget.ctrl, padding: const EdgeInsets.all(12), itemCount: _leads.length,
          itemBuilder: (_, i) {
            final l = _leads[i];
            return ListTile(
              leading: CircleAvatar(backgroundColor: kGreen.withOpacity(0.15),
                  child: Text(l.name.isNotEmpty ? l.name[0].toUpperCase() : '?', style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold))),
              title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(l.phone),
              trailing: StatusBadge(status: l.status),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id))); },
            );
          })),
  ]);
}

// ── REVENUE BREAKDOWN SHEET ────────────────────────────────────────────────────
class _RevenueBreakdownSheet extends StatefulWidget {
  final ApiService api; final AuthService auth; final ScrollController ctrl; final double totalRevenue;
  const _RevenueBreakdownSheet({required this.api, required this.auth, required this.ctrl, required this.totalRevenue});
  @override State<_RevenueBreakdownSheet> createState() => _RevenueBreakdownSheetState();
}
class _RevenueBreakdownSheetState extends State<_RevenueBreakdownSheet> {
  List<Lead> _leads = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final data = await widget.api.getLeads(widget.auth, status: 'Won', filter: 'all', limit: 100);
    if (mounted) setState(() {
      _leads = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
      _loading = false;
    });
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    _Handle(),
    _Header('Revenue Won Breakdown', '₹${widget.totalRevenue > 0 ? _fmt2(widget.totalRevenue) : '0'}', kGreen),
    const Divider(height: 1),
    Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
      : _leads.isEmpty ? const Center(child: Text('No revenue generated this month', style: TextStyle(color: Colors.grey)))
      : ListView.builder(controller: widget.ctrl, padding: const EdgeInsets.all(12), itemCount: _leads.length,
          itemBuilder: (_, i) {
            final l = _leads[i];
            final amt = l.budget ?? 0.0;
            return ListTile(
              leading: CircleAvatar(backgroundColor: kGreen.withOpacity(0.15),
                  child: const Icon(Icons.currency_rupee_rounded, color: kGreen, size: 18)),
              title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Campaign: ${l.campaignName ?? 'None'} • Caller: ${l.assignedToName ?? 'Unassigned'}'),
              trailing: Text('₹${amt > 0 ? _fmt2(amt) : '0'}', style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen, fontSize: 16)),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id))); },
            );
          })),
  ]);
  String _fmt2(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}