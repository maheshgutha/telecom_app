import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import 'campaign_detail_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getCampaigns(auth);
    setState(() {
      _campaigns = (data['campaigns'] as List? ?? []).map((e) => Campaign.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _createCampaign() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('New Campaign'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Campaign Name *')),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
      ],
    ));
    if (ok == true && nameCtrl.text.isNotEmpty) {
      final auth = context.read<AuthService>();
      final api = context.read<ApiService>();
      await api.createCampaign(auth, {'name': nameCtrl.text, 'description': descCtrl.text});
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final filtered = _campaigns.where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns'), actions: [
        if (auth.user?.isAdmin == true) IconButton(icon: const Icon(Icons.add_rounded), onPressed: _createCampaign),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ]),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(12),
            child: TextField(decoration: const InputDecoration(hintText: 'Search campaign...', prefixIcon: Icon(Icons.search, size: 18), isDense: true),
                onChanged: (v) => setState(() => _search = v))),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty ? const Center(child: Text('No campaigns found', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _CampaignCard(campaign: filtered[i], onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: filtered[i].id, campaignName: filtered[i].name)))
                .then((_) => _load())),
          ))),
      ]),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;
  const _CampaignCard({required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (campaign.progress / 100).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('@${campaign.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPurple))),
            if (campaign.priority != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: campaign.priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(campaign.priority!.toUpperCase(), style: TextStyle(color: campaign.priorityColor, fontSize: 10, fontWeight: FontWeight.bold))),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ]),
          if (campaign.description != null && campaign.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(campaign.description!, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Text('${campaign.totalLeads} leads', style: const TextStyle(fontWeight: FontWeight.bold, color: kTextMain, fontSize: 13)),
            const Spacer(),
            if (campaign.assignedCallerNames.isNotEmpty)
              Text('Callers: ${campaign.assignedCallerNames.take(2).join(', ')}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Progress', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('${campaign.progress.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kPurple)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(kPurple))),
          ]),
          if (campaign.createdAt != null) ...[
            const SizedBox(height: 8),
            Text('Created ${DateFormat('dd MMM yyyy').format(campaign.createdAt!)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ]),
      ),
    );
  }
}