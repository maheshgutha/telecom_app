import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';

class MyCallsScreen extends StatefulWidget {
  const MyCallsScreen({super.key});
  @override
  State<MyCallsScreen> createState() => _MyCallsScreenState();
}

class _MyCallsScreenState extends State<MyCallsScreen> {
  List<Lead> _leads = [];
  bool _loading = true;
  Map<String, dynamic>? _summaryData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getMyCalls(auth);
    final list = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(e)).toList();
    setState(() {
      _leads = list;
      _summaryData = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final won = _leads.where((l) => l.status == 'Won').length;
    final interested = _leads.where((l) => l.status == 'Demo Scheduled' || l.status == 'Demo Done').length;
    final notInt = _leads.where((l) => l.status == 'Not interested').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calls'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat('Total', _leads.length, Icons.phone_rounded, kPurple),
                      _Stat('Won', won, Icons.emoji_events_rounded, kGreen),
                      _Stat('Interested', interested, Icons.thumb_up_rounded, kAmber),
                      _Stat('Not Int.', notInt, Icons.thumb_down_rounded, kRed),
                    ],
                  ),
                ),
                Expanded(
                  child: _leads.isEmpty
                      ? const Center(child: Text('No calls logged yet.', style: TextStyle(color: Colors.grey)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _leads.length,
                            itemBuilder: (_, i) {
                              final lead = _leads[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: lead.statusColor.withOpacity(0.15),
                                      child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                                          style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextMain)),
                                          Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          const SizedBox(height: 5),
                                          StatusBadge(status: lead.status),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
                                        child: const Icon(Icons.phone_rounded, color: kGreen, size: 17),
                                      ),
                                      onPressed: () async {
                                        final uri = Uri(scheme: 'tel', path: lead.phone);
                                        if (await canLaunchUrl(uri)) launchUrl(uri);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}