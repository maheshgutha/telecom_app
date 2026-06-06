import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'caller_analysis_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _leaderboard;
  Map<String, dynamic>? _adminData;
  bool _loading = true;
  // Default to 'all' (maps to 'year' / all-time) so leaderboard always has data on load
  String _period = 'all';

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();

    // Backend supports: day, week, month, year
    // 'all' is not supported → use 'year' for all-time
    final period = _period == 'all' ? 'year' : _period;

    final results = await Future.wait([
      api.getLeaderboard(auth, period: period),
      if (auth.user?.isAdmin == true) api.getAdminAnalysis(auth) else Future.value(<String, dynamic>{}),
    ]);

    setState(() {
      _leaderboard = results[0];
      if (auth.user?.isAdmin == true && results.length > 1) {
        if ((results[1] as Map)['error'] == null) _adminData = results[1];
      }
      _loading = false;
    });
  }

  static const _colors = [
    Color(0xFF5B3FC7), Color(0xFF8B5CF6), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444),
  ];

  String get _periodLabel {
    switch (_period) {
      case 'day': return 'Today';
      case 'week': return 'This Week';
      case 'month': return 'This Month';
      case 'all': return 'All Time';
      default: return 'This Week';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(controller: _tabs, labelColor: Colors.white,
            unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Leaderboard'), Tab(text: 'Analytics')]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
            tooltip: _periodLabel,
            onSelected: (v) { setState(() => _period = v); _load(); },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'day', child: Row(children: [
                if (_period == 'day') const Icon(Icons.check, size: 16, color: kPurple), const SizedBox(width: 8), const Text('Today'),
              ])),
              PopupMenuItem(value: 'week', child: Row(children: [
                if (_period == 'week') const Icon(Icons.check, size: 16, color: kPurple), const SizedBox(width: 8), const Text('This Week'),
              ])),
              PopupMenuItem(value: 'month', child: Row(children: [
                if (_period == 'month') const Icon(Icons.check, size: 16, color: kPurple), const SizedBox(width: 8), const Text('This Month'),
              ])),
              PopupMenuItem(value: 'all', child: Row(children: [
                if (_period == 'all') const Icon(Icons.check, size: 16, color: kPurple), const SizedBox(width: 8), const Text('All Time'),
              ])),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _LeaderboardTab(data: _leaderboard, period: _periodLabel),
            _AnalyticsTab(data: _adminData, colors: _colors),
          ]),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final String period;
  const _LeaderboardTab({this.data, required this.period});

  @override
  Widget build(BuildContext context) {
    final callers = (data?['leaderboard'] as List?) ?? [];

    if (data?['error'] != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: kRed, size: 48),
        const SizedBox(height: 12),
        Text('${data!['error']}', style: const TextStyle(color: Colors.grey)),
      ]));
    }

    if (callers.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.leaderboard_rounded, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text('No calls recorded — $period', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        const Text('Try a different time period', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]));
    }

    return Column(children: [
      // Period indicator
      Container(color: kPurpleLight, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: kPurple),
          const SizedBox(width: 8),
          Text('Showing: $period', style: const TextStyle(color: kPurple, fontWeight: FontWeight.w600, fontSize: 12)),
          const Spacer(),
          Text('${callers.length} callers', style: const TextStyle(color: kPurple, fontSize: 12)),
        ])),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(14), itemCount: callers.length,
        itemBuilder: (_, i) {
          final c = callers[i] as Map;
          final user = c['user'] as Map? ?? {};
          final rank = i + 1;
          final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
          final calls = (c['totalCalls'] as num?)?.toInt() ?? 0;
          final wins = (c['sales'] as num?)?.toInt() ?? 0;
          final dur = (c['totalDuration'] as num?)?.toInt() ?? 0;
          final mins = dur ~/ 60;
          final userId = user['_id'] as String?;

          return GestureDetector(
            onTap: userId != null ? () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CallerAnalysisScreen(userId: userId, userName: user['name'] ?? ''))) : null,
            child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rank == 1 ? const Color(0xFFFFFBEB) : rank == 2 ? const Color(0xFFF8F8FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rank == 1 ? kAmber : rank == 2 ? Colors.grey.shade300 : kBorder),
              ),
              child: Row(children: [
                Text(medal, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                CircleAvatar(backgroundColor: kPurpleLight,
                    child: Text((user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)),
                  Text(user['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$calls calls', style: const TextStyle(fontWeight: FontWeight.bold, color: kPurple, fontSize: 13)),
                  if (wins > 0) Text('$wins won 🏆', style: const TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                  if (mins > 0) Text('${mins}m talk', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ]),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
              ]),
            ),
          );
        },
      )),
    ]);
  }
}

class _AnalyticsTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final List<Color> colors;
  const _AnalyticsTab({this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Center(child: Text('Analytics available for admins only.', style: TextStyle(color: Colors.grey)));

    final dailyVol = data!['dailyVolume'] as List? ?? [];
    final outcomes = data!['outcomes'] as List? ?? [];
    final callers = data!['teamStatus'] as List? ?? [];
    final totalCalls = callers.fold<int>(0, (s, c) => s + ((c['callsToday'] as int?) ?? 0));
    final unassigned = data!['unassignedCount'] ?? 0;
    final overdueCount = data!['overdueFollowupsCount'] ?? 0;
    final revenueWon = (data!['revenueWon'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [
        Expanded(child: _MiniCard('Team Calls Today', '$totalCalls', kPurple)),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard('Unassigned', '$unassigned', kAmber)),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard('Overdue F/U', '$overdueCount', kRed)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MiniCard('Revenue Won\n(This Month)', '₹${revenueWon.toStringAsFixed(0)}', kGreen)),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard('Stale Leads', '${data!['staleLeadsCount'] ?? 0}', Colors.grey.shade600)),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard('Demos This Month', '${data!['demosScheduledThisMonth'] ?? 0}', const Color(0xFF06B6D4))),
      ]),
      const SizedBox(height: 14),

      // Caller performance
      if (callers.isNotEmpty) Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Caller Performance (tap for analysis)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 12),
          ...callers.map((c) {
            final u = c['user'] as Map? ?? {};
            final calls = c['callsToday'] as int? ?? 0;
            final pct = (calls / 30).clamp(0.0, 1.0);
            final color = calls >= 25 ? kGreen : calls >= 10 ? kAmber : kRed;
            final userId = u['_id'] as String?;
            return GestureDetector(
              onTap: userId != null ? () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CallerAnalysisScreen(userId: userId, userName: u['name'] ?? ''))) : null,
              child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(children: [
                Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: kPurpleLight,
                      child: Text((u['name'] as String? ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 11))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(u['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ])),
                  Text('$calls/30', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 14),
                ]),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 5,
                        backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(color))),
              ])),
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),

      // Daily volume
      if (dailyVol.isNotEmpty) Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Call Volume', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 12),
          SizedBox(height: 120, child: BarChart(BarChartData(
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (val, _) { final i = val.toInt(); if (i < 0 || i >= dailyVol.length) return const SizedBox();
                  return Text((dailyVol[i]['_id'] as String? ?? '').split('-').last, style: const TextStyle(fontSize: 9, color: Colors.grey)); },
              )),
            ),
            barGroups: List.generate(dailyVol.length, (i) => BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: (dailyVol[i]['count'] as num?)?.toDouble() ?? 0, color: kPurple, width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ])),
          ))),
        ]),
      ),
      const SizedBox(height: 14),

      // Outcomes
      if (outcomes.isNotEmpty) Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Call Outcomes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(height: 110, width: 110, child: PieChart(PieChartData(
              sections: List.generate(outcomes.length, (i) => PieChartSectionData(
                value: (outcomes[i]['count'] as num?)?.toDouble() ?? 0,
                color: colors[i % colors.length], radius: 36, title: '')),
              centerSpaceRadius: 18,
            ))),
            const SizedBox(width: 14),
            Expanded(child: Column(children: List.generate(outcomes.length, (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(child: Text((outcomes[i]['_id'] ?? '').toString().toLowerCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                Text('${outcomes[i]['count'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            )))),
          ]),
        ]),
      ),
      const SizedBox(height: 80),
    ]));
  }
}

class _MiniCard extends StatelessWidget {
  final String label, value; final Color color;
  const _MiniCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ]),
  );
}