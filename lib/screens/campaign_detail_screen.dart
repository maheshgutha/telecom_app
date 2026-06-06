import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';
import 'lead_detail_screen.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId, campaignName;
  const CampaignDetailScreen({super.key, required this.campaignId, required this.campaignName});
  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _campaign;
  List<Lead> _allLeads = [];   // all leads in this campaign (no filter)
  List<Lead> _filtered = [];   // filtered by status
  bool _loading = true;
  String _statusFilter = 'All';

  static const _statuses = ['All','Fresh','Connected','Call Not Responding','Call Back Later','Not interested','Demo Scheduled','Demo Done','Won','Lost'];

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();

    // Load campaign info and ALL leads in parallel
    final results = await Future.wait([
      api.getCampaignById(auth, widget.campaignId),
      api.getCampaignLeads(auth, widget.campaignId), // no status filter - get ALL
    ]);

    final campData = results[0];
    final leadsData = results[1];

    final allLeads = (leadsData['leads'] as List? ?? [])
        .map((e) => Lead.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    setState(() {
      if (campData['campaign'] != null) _campaign = Map<String, dynamic>.from(campData['campaign']);
      _allLeads = allLeads;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    if (_statusFilter == 'All') {
      _filtered = List.from(_allLeads);
    } else {
      _filtered = _allLeads.where((l) => l.status == _statusFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always compute from _allLeads — single source of truth
    final total = _allLeads.length;
    final called = _allLeads.where((l) => l.status != 'Fresh').length;
    final won = _allLeads.where((l) => l.status == 'Won').length;
    final interested = _allLeads.where((l) =>
        l.status == 'Demo Scheduled' || l.status == 'Demo Done' || l.status == 'Connected').length;
    final calledPct = total > 0 ? called / total : 0.0;
    final convPct = total > 0 ? (won / total * 100).toInt() : 0;
    final camp = _campaign;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaignName),
        bottom: TabBar(controller: _tabs, labelColor: Colors.white,
            unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Overview'),
              Tab(text: 'Leads (${_allLeads.length})'),
            ]),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [

          // ── OVERVIEW TAB ──────────────────────────────────────────────────
          SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            // Stats row — same numbers shown in list
            Row(children: [
              _StatBox('$total', 'Total', kPurple),
              const SizedBox(width: 8),
              _StatBox('$called', 'Called', kAmber),
              const SizedBox(width: 8),
              _StatBox('$interested', 'Interested', const Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              _StatBox('$won', 'Won 🏆', kGreen),
            ]),
            const SizedBox(height: 14),

            // Progress — same calculation as list view
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Call Progress', style: TextStyle(fontWeight: FontWeight.w700, color: kTextMain, fontSize: 14)),
                  Text('${(calledPct * 100).toInt()}% called', style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: calledPct, minHeight: 10,
                        backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(kPurple))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Conversion Rate', style: TextStyle(fontWeight: FontWeight.w700, color: kTextMain, fontSize: 14)),
                  Text('$convPct% won', style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: total > 0 ? won / total : 0, minHeight: 10,
                        backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(kGreen))),
              ]),
            ),
            const SizedBox(height: 14),

            // Status breakdown
            if (_allLeads.isNotEmpty) _StatusBreakdown(leads: _allLeads),
            const SizedBox(height: 14),

            // Campaign info
            if (camp != null) Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Campaign Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                const SizedBox(height: 10),
                if (camp['description'] != null && camp['description'].toString().isNotEmpty) ...[
                  Text(camp['description'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 6),
                ],
                if (camp['priority'] != null) _InfoRow('Priority', (camp['priority'] as String).toUpperCase()),
                if (camp['createdAt'] != null) _InfoRow('Created', DateFormat('dd MMM yyyy').format(DateTime.tryParse(camp['createdAt']) ?? DateTime.now())),
              ]),
            ),
            const SizedBox(height: 14),

            // Assigned callers
            if (camp != null && (camp['assignedCallers'] as List? ?? []).isNotEmpty)
              Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Assigned Callers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                    const Spacer(),
                    _Badge('${(camp['assignedCallers'] as List).length}', kPurple),
                  ]),
                  const SizedBox(height: 12),
                  ...(camp['assignedCallers'] as List).map((c) {
                    final caller = c as Map? ?? {};
                    // Show per-caller stats
                    final callerLeads = _allLeads.where((l) => l.assignedToId == caller['_id']).toList();
                    final callerCalled = callerLeads.where((l) => l.status != 'Fresh').length;
                    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                      CircleAvatar(radius: 16, backgroundColor: kPurpleLight,
                          child: Text((caller['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 12))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(caller['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(caller['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ])),
                      if (callerLeads.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${callerLeads.length} leads', style: const TextStyle(fontSize: 11, color: kPurple, fontWeight: FontWeight.bold)),
                        Text('$callerCalled called', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ]),
                    ]));
                  }),
                ]),
              ),
            const SizedBox(height: 80),
          ])),

          // ── LEADS TAB ─────────────────────────────────────────────────────
          Column(children: [
            // Status filter chips
            Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                children: _statuses.map((s) {
                  final count = s == 'All' ? _allLeads.length : _allLeads.where((l) => l.status == s).length;
                  final selected = _statusFilter == s;
                  return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                    onTap: () { setState(() { _statusFilter = s; _applyFilter(); }); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? kPurple : Colors.white,
                        border: Border.all(color: selected ? kPurple : kBorder),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$s ($count)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey.shade600)),
                    ),
                  ));
                }).toList(),
              ))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Text('${_filtered.length} leads', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  Text('Total in campaign: ${_allLeads.length}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ])),
            Expanded(child: _filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_statusFilter == 'All' ? 'No leads in this campaign' : 'No "$_statusFilter" leads', style: const TextStyle(color: Colors.grey)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final lead = _filtered[i];
                    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: lead.statusColor.withOpacity(0.15),
                            child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                                style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kPurple)),
                          Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          if (lead.assignedToName != null) Text('👤 ${lead.assignedToName}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 4),
                          StatusBadge(status: lead.status),
                        ])),
                        Row(children: [
                          IconButton(
                            icon: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
                                child: const Icon(Icons.phone_rounded, color: kGreen, size: 16)),
                            onPressed: () async { final uri = Uri(scheme: 'tel', path: lead.phone); if (await canLaunchUrl(uri)) launchUrl(uri); }),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: kPurple, size: 18),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id))).then((_) => _load())),
                        ]),
                      ]),
                    );
                  }),
            ),
          ]),
        ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label; final Color color;
  const _StatBox(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9), textAlign: TextAlign.center),
    ]),
  ));
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
    Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMain)),
  ]));
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

class _StatusBreakdown extends StatelessWidget {
  final List<Lead> leads;
  const _StatusBreakdown({required this.leads});
  @override
  Widget build(BuildContext context) {
    final statusMap = <String, int>{};
    for (final l in leads) { statusMap[l.status] = (statusMap[l.status] ?? 0) + 1; }
    final sorted = statusMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Status Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        ...sorted.map((e) {
          final pct = leads.isNotEmpty ? e.value / leads.length : 0.0;
          final color = Lead(id: '', name: '', phone: '', status: e.key).statusColor;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              Text(' (${(pct * 100).toInt()}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(color))),
          ]));
        }),
      ]),
    );
  }
}