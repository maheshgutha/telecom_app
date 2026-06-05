import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../main.dart';

class CallerAnalysisScreen extends StatefulWidget {
  final String userId, userName;
  const CallerAnalysisScreen({super.key, required this.userId, required this.userName});
  @override
  State<CallerAnalysisScreen> createState() => _CallerAnalysisScreenState();
}

class _CallerAnalysisScreenState extends State<CallerAnalysisScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    setState(() => _loading = true);
    final data = await api.getUserAnalysis(auth, widget.userId);
    setState(() { _data = data; _loading = false; });
  }

  String _fmt(int sec) { final m = sec ~/ 60; final s = sec % 60; return m > 0 ? '${m}m ${s}s' : '${s}s'; }

  static const _colors = [Color(0xFF5B3FC7), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4)];

  @override
  Widget build(BuildContext context) {
    final user = _data?['user'] as Map?;
    final stats = _data?['stats'] as Map? ?? {};
    final dailyVol = _data?['dailyVolume'] as List? ?? [];
    final outcomes = _data?['outcomes'] as List? ?? [];
    final activities = _data?['recentActivities'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.userName), actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          // Profile card
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
            child: Column(children: [
              CircleAvatar(radius: 32, backgroundColor: kPurpleLight,
                  child: Text(widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: kPurple, fontSize: 26, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              Text(widget.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
              if (user?['email'] != null) Text(user!['email'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(20)),
                  child: Text((user?['role'] ?? 'caller').toUpperCase(), style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 11))),
            ]),
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(children: [
            Expanded(child: _StatCard('Total Calls', '${stats['totalCalls'] ?? 0}', kPurple)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard('Talk Time', _fmt(stats['totalDuration'] ?? 0), kGreen)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard('Connect %',
                '${stats['totalCalls'] != null && stats['totalCalls'] > 0 ? ((stats['connected'] ?? 0) / stats['totalCalls'] * 100).toInt() : 0}%', kAmber)),
          ]),
          const SizedBox(height: 14),

          // Daily volume chart
          if (dailyVol.isNotEmpty) Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Daily Volume (Last 7 Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
              const SizedBox(height: 14),
              SizedBox(height: 110, child: BarChart(BarChartData(
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
                  BarChartRodData(toY: (dailyVol[i]['count'] as num?)?.toDouble() ?? 0, color: kPurple, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ])),
              ))),
            ]),
          ),
          const SizedBox(height: 14),

          // Outcomes pie
          if (outcomes.isNotEmpty) Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Call Outcomes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
              const SizedBox(height: 14),
              Row(children: [
                SizedBox(height: 100, width: 100, child: PieChart(PieChartData(
                  sections: List.generate(outcomes.length, (i) => PieChartSectionData(
                    value: (outcomes[i]['count'] as num?)?.toDouble() ?? 0,
                    color: _colors[i % _colors.length], radius: 35, title: '',
                  )), centerSpaceRadius: 18,
                ))),
                const SizedBox(width: 16),
                Expanded(child: Column(children: List.generate(outcomes.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text((outcomes[i]['_id'] ?? 'No Answer').toString().toLowerCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 11))),
                    Text('${outcomes[i]['count'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                )))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // Recent activity
          if (activities.isNotEmpty) Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Recent Activities', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
              const SizedBox(height: 12),
              ...activities.take(10).map((a) {
                final act = a['activity'] as Map? ?? {};
                final status = act['callStatus'] as String? ?? 'no_answer';
                return Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 28, height: 28, decoration: BoxDecoration(
                        color: status == 'connected' ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.phone_rounded, color: status == 'connected' ? kGreen : kRed, size: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RichText(text: TextSpan(style: const TextStyle(fontSize: 12, color: Colors.black87), children: [
                        const TextSpan(text: 'Called '),
                        TextSpan(text: a['leadName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: kTextMain)),
                      ])),
                      Text('${status.toUpperCase()} • ${_fmt(act['callDuration'] ?? 0)}', style: TextStyle(fontSize: 11, color: status == 'connected' ? kGreen : kRed)),
                    ])),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 80),
        ])),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ]),
  );
}