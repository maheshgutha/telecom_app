import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';
import 'lead_detail_screen.dart';

class MyCallsScreen extends StatefulWidget {
  const MyCallsScreen({super.key});
  @override
  State<MyCallsScreen> createState() => _MyCallsScreenState();
}

class _MyCallsScreenState extends State<MyCallsScreen> {
  List<Lead> _leads = [];
  List<Map<String, dynamic>> _callLogs = [];
  bool _loading = true;
  int _totalCalls = 0;
  int _totalDuration = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getMyCalls(auth);
    final rawLeads = data['leads'] as List? ?? [];
    final leads = rawLeads.map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();

    // Extract all call activities
    final logs = <Map<String, dynamic>>[];
    int calls = 0;
    int secs = 0;
    final today = DateTime.now();
    for (final raw in rawLeads) {
      for (final a in (raw['activities'] as List? ?? [])) {
        if (a['type'] == 'call') {
          final ct = DateTime.tryParse(a['createdAt'] ?? '');
          if (ct != null && ct.year == today.year && ct.month == today.month && ct.day == today.day) {
            calls++;
            secs += (a['callDuration'] as int? ?? 0);
            logs.add({...Map<String, dynamic>.from(a), 'leadName': raw['name'], 'leadPhone': raw['phone'], 'leadId': raw['_id']});
          }
        }
      }
    }

    setState(() {
      _leads = leads;
      _callLogs = logs;
      _totalCalls = calls > 0 ? calls : leads.length;
      _totalDuration = secs;
      _loading = false;
    });
  }

  String _fmt(int sec) {
    if (sec == 0) return '0s';
    final h = sec ~/ 3600; final m = (sec % 3600) ~/ 60; final s = sec % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final won = _leads.where((l) => l.status == 'Won').length;
    final interested = _leads.where((l) => l.status == 'Demo Scheduled' || l.status == 'Demo Done').length;
    final notInt = _leads.where((l) => l.status == 'Not interested').length;
    final connected = _callLogs.where((c) => c['callStatus'] == 'connected').length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Calls'),
          bottom: const TabBar(
            labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
            tabs: [Tab(text: 'Leads'), Tab(text: 'Call Logs')],
          ),
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
        ),
        body: _loading ? const Center(child: CircularProgressIndicator())
          : Column(children: [
            // Stats
            Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _Stat('Calls', '$_totalCalls', Icons.phone_rounded, kPurple),
                _Stat('Connected', '$connected', Icons.call_rounded, kGreen),
                _Stat('Talk Time', _fmt(_totalDuration), Icons.timer_rounded, kAmber),
                _Stat('Won', '$won', Icons.emoji_events_rounded, const Color(0xFF8B5CF6)),
              ]),
            ),
            Expanded(child: TabBarView(children: [
              // Leads tab
              _leads.isEmpty
                ? const Center(child: Text('No calls logged yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _leads.length,
                    itemBuilder: (_, i) {
                      final lead = _leads[i];
                      return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                        child: Row(children: [
                          CircleAvatar(backgroundColor: lead.statusColor.withOpacity(0.15),
                              child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                                  style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextMain)),
                            Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 5),
                            StatusBadge(status: lead.status),
                          ])),
                          Row(children: [
                            IconButton(
                              icon: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
                                  child: const Icon(Icons.phone_rounded, color: kGreen, size: 17)),
                              onPressed: () async { final uri = Uri(scheme: 'tel', path: lead.phone); if (await canLaunchUrl(uri)) launchUrl(uri); }),
                            IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: kPurple, size: 18),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id)))),
                          ]),
                        ]),
                      );
                    }),

              // Call Logs tab
              _callLogs.isEmpty
                ? const Center(child: Text('No call logs yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _callLogs.length,
                    itemBuilder: (_, i) {
                      final c = _callLogs[i];
                      final dur = c['callDuration'] as int? ?? 0;
                      final status = c['callStatus'] as String? ?? 'no_answer';
                      final isConn = status == 'connected';
                      final createdAt = DateTime.tryParse(c['createdAt'] ?? '');
                      return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                        child: Row(children: [
                          CircleAvatar(backgroundColor: isConn ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1),
                              child: Icon(Icons.phone_rounded, color: isConn ? kGreen : kRed, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['leadName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextMain)),
                            Text(c['leadPhone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (createdAt != null) Text(DateFormat('hh:mm a').format(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_fmt(dur), style: TextStyle(fontWeight: FontWeight.bold, color: isConn ? kGreen : Colors.grey, fontSize: 14)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(color: isConn ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: isConn ? kGreen : kRed, fontSize: 9, fontWeight: FontWeight.bold))),
                          ]),
                        ]),
                      );
                    }),
            ])),
          ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
  ]);
}