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
  String _period = 'today';

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final results = await Future.wait([
      api.getLeaderboard(auth, period: _period),
      if (auth.user?.isAdmin == true) api.getAdminAnalysis(auth) else Future.value(<String, dynamic>{}),
    ]);
    setState(() {
      _leaderboard = results[0];
      if (auth.user?.isAdmin == true && results.length > 1) _adminData = results[1];
      _loading = false;
    });
  }

  static const _colors = [Color(0xFF5B3FC7), Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(controller: _tabs, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Leaderboard'), Tab(text: 'Analytics')]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
            onSelected: (v) { setState(() => _period = v); _load(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'today', child: Text('Today')),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
          // ── Leaderboard Tab
          _LeaderboardTab(data: _leaderboard),
          // ── Analytics Tab
          _AnalyticsTab(data: _adminData, colors: _colors),
        ]),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _LeaderboardTab({this.data});

  @override
  Widget build(BuildContext context) {
    final callers = data?['leaderboard'] as List? ?? [];
    if (callers.isEmpty) return const Center(child: Text('No leaderboard data yet.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: callers.length,
      itemBuilder: (_, i) {
        final c = callers[i] as Map;
        final user = c['user'] as Map? ?? {};
        final rank = i + 1;
        final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
        final calls = c['totalCalls'] ?? 0;
        final wins = c['sales'] ?? 0;
        final userId = user['_id'] as String?;

        return GestureDetector(
          onTap: userId != null ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CallerAnalysisScreen(userId: userId, userName: user['name'] ?? ''))) : null,
          child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: rank == 1 ? const Color(0xFFFFFBEB) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rank == 1 ? kAmber : kBorder),
            ),
            child: Row(children: [
              Text(medal, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              CircleAvatar(backgroundColor: kPurpleLight,
                  child: Text((user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)),
                Text(user['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$calls calls', style: const TextStyle(fontWeight: FontWeight.bold, color: kPurple, fontSize: 14)),
                Text('$wins wins 🏆', style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
            ]),
          ),
        );
      },
    );
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

    return SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [
        Expanded(child: _MiniCard('Team Calls Today', '$totalCalls', kPurple)),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard('Unassigned Leads', '${data!['unassignedCount'] ?? 0}', kRed)),
        const SizedBox(width: 10),
        Expanded(child: _MiniCard('Overdue F/U', '${data!['overdueFollowupsCount'] ?? 0}', kAmber)),
      ]),
      const SizedBox(height: 14),

      // Caller performance (clickable)
      if (callers.isNotEmpty) Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Caller Performance (tap for details)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
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
                      child: Text((u['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 11))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('$calls/30', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                  Text(' (${(pct * 100).toInt()}%)', style: TextStyle(fontSize: 11, color: color)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 14),
                ]),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(color))),
              ])),
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),

      // Daily volume
      if (dailyVol.isNotEmpty) Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Call Volume', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 14),
          SizedBox(height: 130, child: BarChart(BarChartData(
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
              BarChartRodData(toY: (dailyVol[i]['count'] as num?)?.toDouble() ?? 0, color: kPurple, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ])),
          ))),
        ]),
      ),
      const SizedBox(height: 14),

      // Outcomes pie
      if (outcomes.isNotEmpty) Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Call Outcomes Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(height: 120, width: 120, child: PieChart(PieChartData(
              sections: List.generate(outcomes.length, (i) => PieChartSectionData(
                value: (outcomes[i]['count'] as num?)?.toDouble() ?? 0,
                color: colors[i % colors.length], radius: 40, title: '',
              )), centerSpaceRadius: 20,
            ))),
            const SizedBox(width: 16),
            Expanded(child: Column(children: List.generate(outcomes.length, (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(child: Text((outcomes[i]['_id'] ?? 'No Answer').toString().toLowerCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 11))),
                Text('${outcomes[i]['count'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
  final String label, value;
  final Color color;
  const _MiniCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ]),
  );
}