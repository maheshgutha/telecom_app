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
import 'call_log_detail_screen.dart';
import 'caller_analysis_screen.dart';
import 'campaign_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  Map<String, dynamic>? _adminStats;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    try {
      final statsData = await api.getLeadStats(auth);
      if (statsData['error'] != null) throw Exception(statsData['error']);
      _stats = DashboardStats.fromJson(statsData);
      if (auth.user?.isAdmin == true) {
        final adminData = await api.getAdminAnalysis(auth);
        if (adminData['error'] == null) _adminStats = adminData;
      }
    } catch (e) { _error = e.toString(); }
    setState(() => _loading = false);
  }

  String _fmtDuration(int sec) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 120, pinned: true, backgroundColor: kTextMain,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [kTextMain, kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(_greeting(user?.name ?? ''), style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(user?.isSuperAdmin == true ? '⚡ Super Admin Center' : user?.isAdmin == true ? '🎯 Admin Desk' : '📞 Caller Desk',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text((user?.role ?? '').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                  ]),
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
        else if (_error != null) SliverFillRemaining(child: _ErrorWidget(error: _error!, onRetry: _load))
        else SliverPadding(
          padding: const EdgeInsets.all(14),
          sliver: SliverList(delegate: SliverChildListDelegate([
            if ((_stats?.overdueFollowupsCount ?? 0) > 0) ...[
              _OverdueAlert(count: _stats!.overdueFollowupsCount), const SizedBox(height: 12),
            ],
            _KpiGrid(stats: _stats, fmtDuration: _fmtDuration, adminStats: _adminStats),
            const SizedBox(height: 14),
            if (_stats?.statusCounts.isNotEmpty ?? false) ...[
              _StatusChart(statusCounts: _stats!.statusCounts), const SizedBox(height: 14),
            ],
            if (!(auth.user?.isAdmin ?? false)) ...[
              if (_stats?.startMyDayQueue.isNotEmpty ?? false) ...[
                _PriorityQueue(queue: _stats!.startMyDayQueue), const SizedBox(height: 14),
              ],
              if (_stats?.upcomingDemos.isNotEmpty ?? false) ...[
                _UpcomingDemos(demos: _stats!.upcomingDemos), const SizedBox(height: 14),
              ],
              _WeeklyTrend(thisWeek: _stats?.trendThisWeek ?? [], lastWeek: _stats?.trendLastWeek ?? []),
              const SizedBox(height: 14),
            ],
            if ((auth.user?.isAdmin ?? false) && _adminStats != null) ...[
              _AdminCallerPanel(adminStats: _adminStats!), const SizedBox(height: 14),
              _AdminCampaignPanel(adminStats: _adminStats!), const SizedBox(height: 14),
              _DailyVolumeChart(adminStats: _adminStats!), const SizedBox(height: 14),
              _OutcomesChart(adminStats: _adminStats!), const SizedBox(height: 14),
            ],
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    return 'Good ${h < 12 ? 'Morning' : h < 17 ? 'Afternoon' : 'Evening'}, $name!';
  }
}

// ─── KPI GRID (clickable) ────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final DashboardStats? stats;
  final Map<String, dynamic>? adminStats;
  final String Function(int) fmtDuration;
  const _KpiGrid({this.stats, this.adminStats, required this.fmtDuration});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthService>().user?.isAdmin ?? false;
    final todayCalls = stats?.todayCallsCount ?? 0;
    final talkTime = fmtDuration(stats?.todayCallsDuration ?? 0);
    final overdue = stats?.overdueFollowupsCount ?? 0;
    final wins = stats?.weeklyWins ?? 0;

    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55,
      children: [
        _KpiTile("Today's Calls", '$todayCalls', Icons.phone_rounded, kPurple, onTap: () => _showCallsModal(context, isAdmin)),
        _KpiTile('Talk Time', talkTime, Icons.timer_rounded, kGreen, onTap: () => _showTalkTimeModal(context, isAdmin)),
        _KpiTile('Overdue F/U', '$overdue', Icons.warning_rounded, kRed),
        _KpiTile(isAdmin ? 'Unassigned' : 'Weekly Wins', isAdmin ? '${adminStats?['unassignedCount'] ?? 0}' : '$wins', Icons.emoji_events_rounded, kAmber),
      ],
    );
  }

  void _showCallsModal(BuildContext context, bool isAdmin) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7,
        builder: (_, ctrl) => _CallsDetailSheet(api: api, auth: auth, scrollCtrl: ctrl),
      ),
    );
  }

  void _showTalkTimeModal(BuildContext context, bool isAdmin) {
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7,
        builder: (_, ctrl) => _TalkTimeSheet(api: api, auth: auth, scrollCtrl: ctrl),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _KpiTile(this.label, this.value, this.icon, this.color, {this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18)),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 16),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }
}

// ─── CALLS DETAIL SHEET ──────────────────────────────────────────────────────
class _CallsDetailSheet extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  final ScrollController scrollCtrl;
  const _CallsDetailSheet({required this.api, required this.auth, required this.scrollCtrl});
  @override
  State<_CallsDetailSheet> createState() => _CallsDetailSheetState();
}

class _CallsDetailSheetState extends State<_CallsDetailSheet> {
  List<dynamic> _calls = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await widget.api.getMyCalls(widget.auth);
    setState(() { _calls = data['leads'] ?? []; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          const Expanded(child: Text("Today's Calls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Text('${_calls.length} total', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
          controller: widget.scrollCtrl, padding: const EdgeInsets.all(12),
          itemCount: _calls.length,
          itemBuilder: (_, i) {
            final l = _calls[i] as Map;
            final lead = Lead.fromJson(Map<String, dynamic>.from(l));
            return ListTile(
              leading: CircleAvatar(backgroundColor: lead.statusColor.withOpacity(0.15),
                  child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?', style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.bold))),
              title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(lead.phone, style: const TextStyle(fontSize: 11)),
              trailing: StatusBadge(status: lead.status),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id))); },
            );
          },
        )),
    ]);
  }
}

// ─── TALK TIME SHEET ─────────────────────────────────────────────────────────
class _TalkTimeSheet extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  final ScrollController scrollCtrl;
  const _TalkTimeSheet({required this.api, required this.auth, required this.scrollCtrl});
  @override
  State<_TalkTimeSheet> createState() => _TalkTimeSheetState();
}

class _TalkTimeSheetState extends State<_TalkTimeSheet> {
  List<dynamic> _calls = [];
  bool _loading = true;
  int _totalSecs = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await widget.api.getMyCalls(widget.auth);
    final leads = data['leads'] as List? ?? [];
    // Build call activities list from leads
    final allActivities = <Map<String, dynamic>>[];
    for (final l in leads) {
      final activities = (l['activities'] as List? ?? []);
      for (final a in activities) {
        if (a['type'] == 'call') {
          allActivities.add({...Map<String, dynamic>.from(a), 'leadName': l['name'], 'leadPhone': l['phone']});
          _totalSecs += (a['callDuration'] as int? ?? 0);
        }
      }
    }
    setState(() { _calls = allActivities; _loading = false; });
  }

  String _fmt(int sec) {
    final m = sec ~/ 60; final s = sec % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          const Expanded(child: Text('Talk Time Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Text('Total: ${_fmt(_totalSecs)}', style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
        ])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : _calls.isEmpty ? const Center(child: Text('No calls logged today', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
          controller: widget.scrollCtrl, padding: const EdgeInsets.all(12),
          itemCount: _calls.length,
          itemBuilder: (_, i) {
            final c = _calls[i] as Map;
            final dur = c['callDuration'] as int? ?? 0;
            final status = c['callStatus'] as String? ?? 'connected';
            return ListTile(
              leading: CircleAvatar(backgroundColor: status == 'connected' ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1),
                  child: Icon(Icons.phone_rounded, color: status == 'connected' ? kGreen : kRed, size: 18)),
              title: Text(c['leadName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text('${status.toUpperCase()} • ${_fmt(dur)}', style: TextStyle(fontSize: 11, color: status == 'connected' ? kGreen : kRed)),
              trailing: Text(c['leadPhone'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            );
          },
        )),
    ]);
  }
}

// ─── STATUS CHART ────────────────────────────────────────────────────────────
class _StatusChart extends StatelessWidget {
  final List<Map<String, dynamic>> statusCounts;
  const _StatusChart({required this.statusCounts});
  static const _colors = [Color(0xFF5B3FC7), Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFF22C55E), Color(0xFFDC2626)];
  @override
  Widget build(BuildContext context) {
    final total = statusCounts.fold<int>(0, (s, e) => s + ((e['count'] as num?)?.toInt() ?? 0));
    if (total == 0) return const SizedBox();
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Leads by Stage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(height: 120, width: 120,
            child: PieChart(PieChartData(sections: List.generate(statusCounts.length, (i) {
              final v = (statusCounts[i]['count'] as num?)?.toDouble() ?? 0;
              return PieChartSectionData(value: v, color: _colors[i % _colors.length], radius: 40,
                  title: v > 0 ? '${((v / total) * 100).toInt()}%' : '',
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold));
            }), centerSpaceRadius: 20))),
          const SizedBox(width: 16),
          Expanded(child: Column(children: List.generate(statusCounts.take(6).length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(statusCounts[i]['_id'] ?? '', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
              Text('${statusCounts[i]['count'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          )))),
        ]),
      ]),
    );
  }
}

// ─── PRIORITY QUEUE ──────────────────────────────────────────────────────────
class _PriorityQueue extends StatelessWidget {
  final List<Map<String, dynamic>> queue;
  const _PriorityQueue({required this.queue});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.format_list_bulleted_rounded, color: kPurple, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Priority Call Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(20)),
              child: Text('${queue.length}', style: const TextStyle(color: kPurple, fontSize: 11, fontWeight: FontWeight.w600))),
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
                if (lead?['_id'] != null)
                  IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: kPurple, size: 16),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead!['_id'])))),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─── UPCOMING DEMOS ──────────────────────────────────────────────────────────
class _UpcomingDemos extends StatelessWidget {
  final List<Map<String, dynamic>> demos;
  const _UpcomingDemos({required this.demos});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.calendar_month_rounded, color: kGreen, size: 18),
          SizedBox(width: 8),
          Text('Upcoming Demos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        ]),
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
                  decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(10)),
                  child: const Text('TODAY', style: TextStyle(color: kRed, fontSize: 9, fontWeight: FontWeight.bold))),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─── WEEKLY TREND ────────────────────────────────────────────────────────────
class _WeeklyTrend extends StatelessWidget {
  final List<int> thisWeek, lastWeek;
  const _WeeklyTrend({required this.thisWeek, required this.lastWeek});
  @override
  Widget build(BuildContext context) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final thisW = List.generate(7, (i) => i < thisWeek.length ? thisWeek[i].toDouble() : 0.0);
    final lastW = List.generate(7, (i) => i < lastWeek.length ? lastWeek[i].toDouble() : 0.0);
    final maxVal = [...thisW, ...lastW].fold(0.0, (a, b) => a > b ? a : b);
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Weekly Dial Trend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 14),
        SizedBox(height: 110, child: BarChart(BarChartData(
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxVal > 0 ? (maxVal / 3).ceilToDouble() : 5),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
              getTitlesWidget: (val, _) { final i = val.toInt(); if (i < 0 || i >= 7) return const SizedBox(); return Text(days[i], style: const TextStyle(fontSize: 9, color: Colors.grey)); },
            )),
          ),
          barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barsSpace: 2, barRods: [
            BarChartRodData(toY: thisW[i], color: kPurple, width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
            BarChartRodData(toY: lastW[i], color: const Color(0xFFCBD5E1), width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
          ])),
        ))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Legend(kPurple, 'This Week'),
          const SizedBox(width: 16),
          _Legend(const Color(0xFFCBD5E1), 'Last Week'),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color; final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

// ─── ADMIN CALLER PANEL (clickable) ──────────────────────────────────────────
class _AdminCallerPanel extends StatelessWidget {
  final Map<String, dynamic> adminStats;
  const _AdminCallerPanel({required this.adminStats});
  @override
  Widget build(BuildContext context) {
    final callers = adminStats['teamStatus'] as List? ?? [];
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.people_rounded, color: kPurple, size: 18),
          SizedBox(width: 8),
          Text('Callers Activity (tap to view)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        ]),
        const SizedBox(height: 12),
        if (callers.isEmpty) const Center(child: Text('No callers set up yet.', style: TextStyle(color: Colors.grey, fontSize: 12)))
        else ...callers.take(8).map((c) {
          final u = c['user'] as Map? ?? {};
          final calls = c['callsToday'] as int? ?? 0;
          final pct = (calls / 30).clamp(0.0, 1.0);
          final isActive = c['isActive'] as bool? ?? false;
          final color = calls >= 25 ? kGreen : calls >= 10 ? kAmber : kRed;
          final userId = u['_id'] as String?;
          return GestureDetector(
            onTap: userId != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CallerAnalysisScreen(userId: userId, userName: u['name'] ?? ''))) : null,
            child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFAF9FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: kPurpleLight,
                      child: Text((u['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ])),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? kGreen : Colors.grey.shade300, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$calls/30', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
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
}

// ─── ADMIN CAMPAIGN PANEL (clickable) ────────────────────────────────────────
class _AdminCampaignPanel extends StatelessWidget {
  final Map<String, dynamic> adminStats;
  const _AdminCampaignPanel({required this.adminStats});
  @override
  Widget build(BuildContext context) {
    final campaigns = adminStats['campaignPerformance'] as List? ?? [];
    if (campaigns.isEmpty) return const SizedBox();
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.campaign_rounded, color: kGreen, size: 18),
          SizedBox(width: 8),
          Text('Campaign Performance (tap to view)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        ]),
        const SizedBox(height: 12),
        ...campaigns.take(5).map((c) {
          final total = (c['totalLeads'] as int? ?? 0);
          final won = (c['won'] as int? ?? 0);
          final called = (c['called'] as int? ?? 0);
          final pct = total > 0 ? called / total : 0.0;
          final convPct = total > 0 ? (won / total * 100).toInt() : 0;
          final cid = c['_id'] as String?;
          return GestureDetector(
            onTap: cid != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: cid, campaignName: c['name'] ?? ''))) : null,
            child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFAF9FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kPurple))),
                  Text('$convPct% conv.', style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 16),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Text('$total leads • $won won • $called called', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(kPurple))),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ─── DAILY VOLUME CHART ───────────────────────────────────────────────────────
class _DailyVolumeChart extends StatelessWidget {
  final Map<String, dynamic> adminStats;
  const _DailyVolumeChart({required this.adminStats});
  @override
  Widget build(BuildContext context) {
    final vol = adminStats['dailyVolume'] as List? ?? [];
    if (vol.isEmpty) return const SizedBox();
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily Call Volume (Last 7 Days)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 14),
        SizedBox(height: 130, child: BarChart(BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              getTitlesWidget: (val, _) { final i = val.toInt(); if (i < 0 || i >= vol.length) return const SizedBox();
                final d = (vol[i]['_id'] as String? ?? '').split('-').last; return Text(d, style: const TextStyle(fontSize: 9, color: Colors.grey)); },
            )),
          ),
          barGroups: List.generate(vol.length, (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (vol[i]['count'] as num?)?.toDouble() ?? 0, color: kPurple, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ])),
        ))),
      ]),
    );
  }
}

// ─── OUTCOMES CHART ───────────────────────────────────────────────────────────
class _OutcomesChart extends StatelessWidget {
  final Map<String, dynamic> adminStats;
  const _OutcomesChart({required this.adminStats});
  static const _colors = [Color(0xFF5B3FC7), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4)];
  @override
  Widget build(BuildContext context) {
    final outcomes = adminStats['outcomes'] as List? ?? [];
    if (outcomes.isEmpty) return const SizedBox();
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Call Outcomes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 14),
        Row(children: [
          SizedBox(height: 120, width: 120, child: PieChart(PieChartData(
            sections: List.generate(outcomes.length, (i) => PieChartSectionData(
              value: (outcomes[i]['count'] as num?)?.toDouble() ?? 0,
              color: _colors[i % _colors.length], radius: 40, title: '',
            )),
            centerSpaceRadius: 20,
          ))),
          const SizedBox(width: 16),
          Expanded(child: Column(children: List.generate(outcomes.length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text((outcomes[i]['_id'] ?? 'No Answer').toString().toLowerCase().replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
              Text('${outcomes[i]['count'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          )))),
        ]),
      ]),
    );
  }
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
class _OverdueAlert extends StatelessWidget {
  final int count;
  const _OverdueAlert({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), border: Border.all(color: const Color(0xFFFECACA)), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Text('⚠️', style: TextStyle(fontSize: 20)),
      const SizedBox(width: 10),
      Expanded(child: Text('$count overdue follow-up callbacks pending!',
          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _ErrorWidget extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, color: kRed, size: 48),
    const SizedBox(height: 12),
    const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text(error, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
  ]));
}