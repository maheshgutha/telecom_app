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
  List<Lead> _leads = [];
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
    final data = await api.getCampaignById(auth, widget.campaignId);
    final leadsData = await api.getLeads(auth, filter: 'all', status: _statusFilter == 'All' ? null : _statusFilter);
    // Filter leads by campaign
    final allLeads = (leadsData['leads'] as List? ?? []).map((e) => Lead.fromJson(e)).where((l) => l.campaignId == widget.campaignId).toList();
    setState(() { _campaign = data['campaign'] as Map<String, dynamic>?; _leads = allLeads; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final camp = _campaign;
    final totalLeads = _leads.length;
    final won = _leads.where((l) => l.status == 'Won').length;
    final called = _leads.where((l) => l.status != 'Fresh').length;
    final convPct = totalLeads > 0 ? (won / totalLeads * 100).toInt() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaignName),
        bottom: TabBar(controller: _tabs, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Leads')]),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
          // ── Overview tab
          SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            // Summary cards
            Row(children: [
              _CampStat('Total Leads', '$totalLeads', kPurple),
              const SizedBox(width: 10),
              _CampStat('Called', '$called', kAmber),
              const SizedBox(width: 10),
              _CampStat('Won', '$won', kGreen),
              const SizedBox(width: 10),
              _CampStat('Conv.', '$convPct%', kTextMain),
            ]),
            const SizedBox(height: 14),

            // Progress
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Progress', style: TextStyle(fontWeight: FontWeight.w700, color: kTextMain)),
                  Text('${totalLeads > 0 ? (called / totalLeads * 100).toInt() : 0}% called', style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: totalLeads > 0 ? called / totalLeads : 0, minHeight: 10,
                        backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(kPurple))),
              ]),
            ),
            const SizedBox(height: 14),

            // Callers assigned
            if (camp != null && (camp['assignedCallers'] as List? ?? []).isNotEmpty)
              Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Assigned Callers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                  const SizedBox(height: 12),
                  ...(camp['assignedCallers'] as List? ?? []).map((caller) {
                    final c = caller as Map? ?? {};
                    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                      CircleAvatar(radius: 16, backgroundColor: kPurpleLight,
                          child: Text((c['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 12))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(c['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ])),
                    ]));
                  }),
                ]),
              ),

            // Campaign info
            if (camp != null) ...[
              const SizedBox(height: 14),
              Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Campaign Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
                  const SizedBox(height: 10),
                  if (camp['description'] != null) Text(camp['description'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (camp['priority'] != null) Row(children: [
                    const Text('Priority: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text((camp['priority'] as String).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: kPurple, fontSize: 12)),
                  ]),
                  if (camp['createdAt'] != null) Row(children: [
                    const Text('Created: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(DateFormat('dd MMM yyyy').format(DateTime.tryParse(camp['createdAt']) ?? DateTime.now()),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 80),
          ])),

          // ── Leads tab
          Column(children: [
            Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _statuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() => _statusFilter = s); _load(); },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusFilter == s ? kPurple : Colors.white,
                      border: Border.all(color: _statusFilter == s ? kPurple : kBorder),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusFilter == s ? Colors.white : Colors.grey.shade600)),
                  ),
                ),
              )).toList())),
            ),
            Expanded(child: _leads.isEmpty
              ? const Center(child: Text('No leads in this campaign', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _leads.length,
                  itemBuilder: (_, i) {
                    final lead = _leads[i];
                    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: lead.statusColor.withOpacity(0.15),
                            child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?', style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kPurple)),
                          Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          StatusBadge(status: lead.status),
                        ])),
                        Row(children: [
                          IconButton(icon: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
                              child: const Icon(Icons.phone_rounded, color: kGreen, size: 16)),
                            onPressed: () async { final uri = Uri(scheme: 'tel', path: lead.phone); if (await canLaunchUrl(uri)) launchUrl(uri); }),
                          IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: kPurple, size: 18),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: lead.id)))),
                        ]),
                      ]),
                    );
                  },
                )),
          ]),
        ]),
    );
  }
}

class _CampStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CampStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ]),
  ));
}