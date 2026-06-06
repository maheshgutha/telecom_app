import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';
import 'lead_detail_screen.dart';
import 'add_lead_screen.dart';

const _statuses = ['All','Fresh','Connected','Call Not Responding','Call Back Later','Not interested','Demo Scheduled','Demo Done','Won','Lost'];
const _sources = ['All','Manual','Facebook','WhatsApp','Website','Excel','Referral'];

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});
  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  List<Lead> _leads = [];
  bool _loading = true;
  String _search = '';
  String _status = 'All';
  String _source = 'All';
  String _filter = 'mine';
  int _page = 1;
  int _total = 0;
  List<User> _callers = [];
  final _searchCtrl = TextEditingController();
  final _debounce = Stopwatch();

  @override
  void initState() { super.initState(); _loadCallers(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadCallers() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    if (auth.user?.isAdmin == true) {
      final data = await api.getUsers(auth);
      final users = (data['users'] as List? ?? []).map((u) => User.fromJson(Map<String, dynamic>.from(u))).toList();
      if (mounted) setState(() => _callers = users.where((u) => u.role == 'caller').toList());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();

    // Build assignedTo from filter if it's a user ID
    String? assignedTo;
    String? filter;
    if (_filter == 'mine') { filter = 'mine'; }
    else if (_filter == 'all') { filter = 'all'; }
    else { assignedTo = _filter; filter = 'all'; }

    final data = await api.getLeads(auth,
      search: _search.isEmpty ? null : _search,
      status: _status == 'All' ? null : _status,
      source: _source == 'All' ? null : _source,
      filter: filter,
      assignedTo: assignedTo,
      page: _page,
    );
    if (mounted) setState(() {
      _leads = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
      _total = data['total'] ?? 0;
      _loading = false;
    });
  }

  Future<void> _deleteLead(Lead lead) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Lead'),
      content: Text('Delete "${lead.name}"? Cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: kRed))),
      ],
    ));
    if (ok == true) {
      await context.read<ApiService>().deleteLead(context.read<AuthService>(), lead.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAdmin = auth.user?.isAdmin ?? false;
    final isSuperAdmin = auth.user?.isSuperAdmin ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(title: const Text('Leads'), actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        IconButton(icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLeadScreen())).then((_) => _load())),
      ]),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: Column(children: [
          // Search
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search name, phone, email...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 16),
                  onPressed: () { _searchCtrl.clear(); setState(() { _search = ''; _page = 1; }); _load(); }) : null,
              isDense: true,
            ),
            onChanged: (v) {
              setState(() { _search = v; _page = 1; });
              Future.delayed(const Duration(milliseconds: 600), () { if (mounted && _search == v) _load(); });
            },
          ),
          const SizedBox(height: 8),
          // Filters row
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _Chip(_status == 'All' ? 'Status' : _status, _status != 'All',
                () => _showPicker('Status', _statuses, _status, (v) { setState(() { _status = v; _page = 1; }); _load(); })),
            const SizedBox(width: 8),
            _Chip(_source == 'All' ? 'Source' : _source, _source != 'All',
                () => _showPicker('Source', _sources, _source, (v) { setState(() { _source = v; _page = 1; }); _load(); })),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              _Chip(
                _filter == 'mine' ? 'My Leads' : _filter == 'all' ? 'All Leads' : (_callers.any((c) => c.id == _filter) ? _callers.firstWhere((c) => c.id == _filter).name : 'Filter'),
                _filter != 'mine',
                () {
                  final opts = ['mine', 'all', ..._callers.map((c) => c.id)];
                  final labels = ['My Leads', 'All Leads', ..._callers.map((c) => '${c.name} (caller)')];
                  _showPickerLabeled('Filter', opts, labels, _filter, (v) { setState(() { _filter = v; _page = 1; }); _load(); });
                },
              ),
            ],
          ])),
        ])),

        // Count + pagination
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(children: [
          Text('$_total leads', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Spacer(),
          if (_page > 1) TextButton(onPressed: () { setState(() => _page--); _load(); }, child: const Text('← Prev', style: TextStyle(fontSize: 11))),
          Text(' Page $_page ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (_page * 20 < _total) TextButton(onPressed: () { setState(() => _page++); _load(); }, child: const Text('Next →', style: TextStyle(fontSize: 11))),
        ])),

        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _leads.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No leads found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextButton(onPressed: () { setState(() { _status = 'All'; _source = 'All'; _filter = 'mine'; _search = ''; _searchCtrl.clear(); _page = 1; }); _load(); }, child: const Text('Clear Filters')),
            ]))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
              itemCount: _leads.length,
              itemBuilder: (_, i) => _LeadCard(
                lead: _leads[i], isSuperAdmin: isSuperAdmin,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: _leads[i].id))).then((_) => _load()),
                onCall: () async { final uri = Uri(scheme: 'tel', path: _leads[i].phone); if (await canLaunchUrl(uri)) launchUrl(uri); },
                onDelete: isSuperAdmin ? () => _deleteLead(_leads[i]) : null,
              ),
            ))),
      ]),
    );
  }

  void _showPicker(String title, List<String> opts, String current, Function(String) onSel) {
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Flexible(child: ListView(shrinkWrap: true, children: opts.map((o) => ListTile(
          title: Text(o), selected: o == current,
          selectedTileColor: kPurpleLight, selectedColor: kPurple,
          onTap: () { Navigator.pop(context); onSel(o); },
        )).toList())),
        const SizedBox(height: 16),
      ]));
  }

  void _showPickerLabeled(String title, List<String> opts, List<String> labels, String current, Function(String) onSel) {
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Flexible(child: ListView(shrinkWrap: true, children: List.generate(opts.length, (i) => ListTile(
          title: Text(labels[i]), selected: opts[i] == current,
          selectedTileColor: kPurpleLight, selectedColor: kPurple,
          onTap: () { Navigator.pop(context); onSel(opts[i]); },
        )))),
        const SizedBox(height: 16),
      ]));
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _Chip(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: active ? kPurpleLight : Colors.white,
          border: Border.all(color: active ? kPurple : kBorder), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 12, color: active ? kPurple : Colors.grey.shade600, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        const SizedBox(width: 4),
        Icon(Icons.arrow_drop_down, size: 16, color: active ? kPurple : Colors.grey.shade400),
      ]),
    ),
  );
}

class _LeadCard extends StatelessWidget {
  final Lead lead; final bool isSuperAdmin;
  final VoidCallback onTap, onCall; final VoidCallback? onDelete;
  const _LeadCard({required this.lead, required this.isSuperAdmin, required this.onTap, required this.onCall, this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        CircleAvatar(backgroundColor: lead.statusColor.withOpacity(0.15),
            child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?', style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPurple)),
          Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (lead.assignedToName != null) Text('👤 ${lead.assignedToName}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 5),
          StatusBadge(status: lead.status),
        ])),
        Column(children: [
          IconButton(icon: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
              child: const Icon(Icons.phone_rounded, color: kGreen, size: 17)), onPressed: onCall),
          if (isSuperAdmin && onDelete != null)
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18), onPressed: onDelete),
        ]),
      ]),
    )),
  );
}