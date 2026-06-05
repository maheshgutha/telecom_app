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

  @override
  void initState() {
    super.initState();
    _loadCallers();
    _load();
  }

  Future<void> _loadCallers() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    if (auth.user?.isAdmin == true) {
      final data = await api.getUsers(auth);
      final users = (data['users'] as List? ?? []).map((u) => User.fromJson(u)).toList();
      setState(() => _callers = users.where((u) => u.role == 'caller').toList());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getLeads(auth,
      search: _search, status: _status, source: _source, filter: _filter, page: _page);
    setState(() {
      _leads = (data['leads'] as List? ?? []).map((e) => Lead.fromJson(e)).toList();
      _total = data['total'] ?? 0;
      _loading = false;
    });
  }

  Future<void> _deleteLead(Lead lead) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Delete "${lead.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await api.deleteLead(auth, lead.id);
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
      appBar: AppBar(
        title: const Text('Leads'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddLeadScreen())).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search lead by name, phone...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close, size: 16),
                            onPressed: () { _searchCtrl.clear(); setState(() { _search = ''; _page = 1; }); _load(); })
                        : null,
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setState(() { _search = v; _page = 1; });
                    Future.delayed(const Duration(milliseconds: 600), _load);
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filter
                      _FilterChip(
                        label: _status == 'All' ? 'Status' : _status,
                        active: _status != 'All',
                        onTap: () => _showPicker('Status', _statuses, _status, (v) {
                          setState(() { _status = v; _page = 1; }); _load();
                        }),
                      ),
                      const SizedBox(width: 8),
                      // Source filter
                      _FilterChip(
                        label: _source == 'All' ? 'Source' : _source,
                        active: _source != 'All',
                        onTap: () => _showPicker('Source', _sources, _source, (v) {
                          setState(() { _source = v; _page = 1; }); _load();
                        }),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        // Caller filter
                        _FilterChip(
                          label: _callers.any((c) => c.id == _filter) ? _callers.firstWhere((c) => c.id == _filter).name : 'All Callers',
                          active: _callers.any((c) => c.id == _filter),
                          onTap: () {
                            final options = ['all', 'mine', ..._callers.map((c) => c.id)];
                            final labels = ['All Leads', 'My Leads', ..._callers.map((c) => c.name)];
                            _showPickerWithLabels('Filter', options, labels, _filter, (v) {
                              setState(() { _filter = v; _page = 1; }); _load();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Count bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('$_total leads', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                if (_page > 1)
                  TextButton(onPressed: () { setState(() => _page--); _load(); },
                      child: const Text('← Prev', style: TextStyle(fontSize: 12))),
                Text('Page $_page', style: const TextStyle(fontSize: 12)),
                if (_page * 20 < _total)
                  TextButton(onPressed: () { setState(() => _page++); _load(); },
                      child: const Text('Next →', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _leads.isEmpty
                    ? const Center(child: Text('No leads found', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _leads.length,
                          itemBuilder: (_, i) => _LeadCard(
                            lead: _leads[i],
                            isSuperAdmin: isSuperAdmin,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: _leads[i].id)))
                                .then((_) => _load()),
                            onCall: () async {
                              final uri = Uri(scheme: 'tel', path: _leads[i].phone);
                              if (await canLaunchUrl(uri)) launchUrl(uri);
                            },
                            onDelete: isSuperAdmin ? () => _deleteLead(_leads[i]) : null,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showPicker(String title, List<String> options, String current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ...options.map((o) => ListTile(
            title: Text(o),
            selected: o == current,
            selectedTileColor: kPurpleLight,
            selectedColor: kPurple,
            onTap: () { Navigator.pop(context); onSelect(o); },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPickerWithLabels(String title, List<String> options, List<String> labels, String current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ...List.generate(options.length, (i) => ListTile(
            title: Text(labels[i]),
            selected: options[i] == current,
            selectedTileColor: kPurpleLight,
            selectedColor: kPurple,
            onTap: () { Navigator.pop(context); onSelect(options[i]); },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kPurpleLight : Colors.white,
          border: Border.all(color: active ? kPurple : kBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: active ? kPurple : Colors.grey.shade600, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: active ? kPurple : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final bool isSuperAdmin;
  final VoidCallback onTap, onCall;
  final VoidCallback? onDelete;
  const _LeadCard({required this.lead, required this.isSuperAdmin, required this.onTap, required this.onCall, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                    Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPurple)),
                    Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
                    if (lead.assignedToName != null) ...[
                      const SizedBox(height: 2),
                      Text('👤 ${lead.assignedToName}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                    const SizedBox(height: 6),
                    StatusBadge(status: lead.status),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(color: Color(0xFFE8F8F0), shape: BoxShape.circle),
                      child: const Icon(Icons.phone_rounded, color: kGreen, size: 17),
                    ),
                    onPressed: onCall,
                  ),
                  if (isSuperAdmin && onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}