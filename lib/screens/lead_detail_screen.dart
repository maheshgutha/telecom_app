import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';

const _statuses = ['Fresh','Connected','Call Not Responding','Call Back Later','Not interested','Demo Scheduled','Demo Done','Won','Lost'];

class LeadDetailScreen extends StatefulWidget {
  final String leadId;
  const LeadDetailScreen({super.key, required this.leadId});
  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Lead? _lead;
  bool _loading = true;
  bool _isEditing = false;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _qualCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _altCtrl, _emailCtrl, _locCtrl, _qualCtrl, _budgetCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getLeadById(auth, widget.leadId);
    if (data['lead'] != null) {
      final l = Lead.fromJson(data['lead']);
      setState(() {
        _lead = l;
        _nameCtrl.text = l.name;
        _phoneCtrl.text = l.phone;
        _altCtrl.text = l.alternatePhone ?? '';
        _emailCtrl.text = l.email ?? '';
        _locCtrl.text = l.location ?? '';
        _qualCtrl.text = l.lastQualification ?? '';
        _budgetCtrl.text = l.budget?.toStringAsFixed(0) ?? '';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    setState(() => _saving = true);
    await api.updateLeadStatus(auth, widget.leadId, newStatus);
    setState(() => _saving = false);
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status updated ✓'), backgroundColor: kGreen),
    );
  }

  Future<void> _saveEdit() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    setState(() => _saving = true);
    await api.updateLead(auth, widget.leadId, {
      'name': _nameCtrl.text,
      'phone': _phoneCtrl.text,
      'alternatePhone': _altCtrl.text,
      'email': _emailCtrl.text,
      'location': _locCtrl.text,
      'lastQualification': _qualCtrl.text,
      'budget': double.tryParse(_budgetCtrl.text) ?? 0,
    });
    setState(() { _saving = false; _isEditing = false; });
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lead updated ✓'), backgroundColor: kGreen),
    );
  }

  Future<void> _logCall(String callStatus, int duration, String note) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    await api.logCall(auth, widget.leadId, {'callStatus': callStatus, 'duration': duration, 'note': note});
    _load();
  }

  Future<void> _addNote(String note, String type) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    await api.addNote(auth, widget.leadId, {'note': note, 'type': type});
    _load();
  }

  void _call() async {
    if (_lead == null) return;
    final uri = Uri(scheme: 'tel', path: _lead!.phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _whatsapp() async {
    if (_lead == null) return;
    final phone = _lead!.phone.replaceAll(RegExp(r'\D'), '');
    final p = phone.length == 10 ? '91$phone' : phone;
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ..._statuses.map((s) {
            final color = Lead(id: '', name: '', phone: '', status: s).statusColor;
            return ListTile(
              leading: CircleAvatar(radius: 8, backgroundColor: color),
              title: Text(s),
              selected: _lead?.status == s,
              selectedTileColor: kPurpleLight,
              selectedColor: kPurple,
              onTap: () { Navigator.pop(context); _updateStatus(s); },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showLogCallModal() {
    final statusN = ValueNotifier('connected');
    final durationCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Log Call', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ValueListenableBuilder<String>(
            valueListenable: statusN,
            builder: (_, val, __) => DropdownButtonFormField<String>(
              value: val,
              decoration: const InputDecoration(labelText: 'Call Status'),
              items: ['connected','no_answer','busy','failed'].map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase()))).toList(),
              onChanged: (v) => statusN.value = v!,
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (seconds)')),
          const SizedBox(height: 10),
          TextField(controller: noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Call Note')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logCall(statusN.value, int.tryParse(durationCtrl.text) ?? 0, noteCtrl.text);
            },
            child: const Text('Save Call Log'),
          ),
        ]),
      ),
    );
  }

  void _showAddNoteModal() {
    final noteCtrl = TextEditingController();
    final typeN = ValueNotifier('note');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: typeN,
            builder: (_, val, __) => Row(children: ['note','whatsapp','sms'].map((t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => typeN.value = t,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: val == t ? kPurple : Colors.white, border: Border.all(color: val == t ? kPurple : kBorder), borderRadius: BorderRadius.circular(20)),
                  child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: val == t ? Colors.white : Colors.grey)),
                ),
              ),
            )).toList()),
          ),
          const SizedBox(height: 12),
          TextField(controller: noteCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Note details')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _addNote(noteCtrl.text, typeN.value); },
            child: const Text('Save Note'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(_lead?.name ?? 'Lead Profile'),
        actions: [
          if (!_isEditing)
            IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => setState(() => _isEditing = true))
          else
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _isEditing = false)),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lead == null
              ? const Center(child: Text('Lead not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 16),
                    // Quick actions
                    _buildQuickActions(),
                    const SizedBox(height: 16),
                    // Info / edit form
                    _isEditing ? _buildEditForm() : _buildInfoCard(),
                    const SizedBox(height: 16),
                    // Activity timeline
                    _buildTimeline(),
                    const SizedBox(height: 80),
                  ]),
                ),
    );
  }

  Widget _buildHeader() {
    final lead = _lead!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Column(children: [
        CircleAvatar(
          radius: 32, backgroundColor: lead.statusColor.withOpacity(0.15),
          child: Text(lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
              style: TextStyle(color: lead.statusColor, fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        Text(lead.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kTextMain)),
        const SizedBox(height: 2),
        Text(lead.phone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showStatusPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: lead.statusColor.withOpacity(0.1), border: Border.all(color: lead.statusColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(lead.status, style: TextStyle(color: lead.statusColor, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Icon(Icons.edit_rounded, color: lead.statusColor, size: 14),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ActionBtn(icon: Icons.phone_rounded, label: 'Call', color: kGreen, onTap: _call),
          const SizedBox(width: 24),
          _ActionBtn(icon: Icons.chat_rounded, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: _whatsapp),
        ]),
      ]),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('📞', 'CALL', kGreen, _call),
      ('⏰', 'CALLBACK', kAmber, () => _updateStatus('Call Back Later')),
      ('💬', 'WHATSAPP', const Color(0xFF25D366), _whatsapp),
      ('📝', 'LOG CALL', kPurple, _showLogCallModal),
      ('➕', 'NOTE', kTextMain, _showAddNoteModal),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        Row(children: actions.map((a) => Expanded(child: GestureDetector(
          onTap: a.$4,
          child: Column(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: a.$3.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: a.$3.withOpacity(0.2))),
                child: Center(child: Text(a.$1, style: const TextStyle(fontSize: 20)))),
            const SizedBox(height: 4),
            Text(a.$2, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: a.$3), textAlign: TextAlign.center),
          ]),
        ))).toList()),
      ]),
    );
  }

  Widget _buildInfoCard() {
    final l = _lead!;
    final rows = <(IconData, String, String)>[
      (Icons.phone_rounded, 'Phone', l.phone),
      if (l.alternatePhone != null && l.alternatePhone!.isNotEmpty) (Icons.phone_outlined, 'Alternate', l.alternatePhone!),
      if (l.email != null) (Icons.email_outlined, 'Email', l.email!),
      if (l.location != null) (Icons.location_on_outlined, 'Location', l.location!),
      if (l.lastQualification != null) (Icons.school_outlined, 'Qualification', l.lastQualification!),
      if (l.budget != null) (Icons.currency_rupee_rounded, 'Budget', '₹${l.budget!.toStringAsFixed(0)}'),
      if (l.leadSource != null) (Icons.source_outlined, 'Source', l.leadSource!),
      if (l.campaignName != null) (Icons.campaign_outlined, 'Campaign', l.campaignName!),
      if (l.assignedToName != null) (Icons.person_outline_rounded, 'Assignee', l.assignedToName!),
      if (l.mode != null) (Icons.school_rounded, 'Mode', l.mode!),
      if (l.createdAt != null) (Icons.calendar_today_rounded, 'Added', DateFormat('dd MMM yyyy').format(l.createdAt!)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Contact Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(r.$1, size: 16, color: kPurple),
            const SizedBox(width: 10),
            Text('${r.$2}: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(child: GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: r.$3)),
              child: Text(r.$3, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextMain)),
            )),
          ]),
        )),
      ]),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Edit Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        ...[('Full Name', _nameCtrl, TextInputType.text), ('Phone', _phoneCtrl, TextInputType.phone), ('Alternate Phone', _altCtrl, TextInputType.phone),
            ('Email', _emailCtrl, TextInputType.emailAddress), ('Location', _locCtrl, TextInputType.text),
            ('Qualification', _qualCtrl, TextInputType.text), ('Budget (₹)', _budgetCtrl, TextInputType.number)]
            .map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: f.$2, keyboardType: f.$3, decoration: InputDecoration(labelText: f.$1)),
            )),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditing = false), child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: _saving ? null : _saveEdit,
            child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
          )),
        ]),
      ]),
    );
  }

  Widget _buildTimeline() {
    final activities = _lead!.activities;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Activity & Call History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No activity history yet.', style: TextStyle(color: Colors.grey))))
        else
          ...activities.map((a) {
            Color actColor;
            IconData actIcon;
            switch (a.type) {
              case 'call': actColor = kGreen; actIcon = Icons.phone_rounded; break;
              case 'whatsapp': actColor = const Color(0xFF25D366); actIcon = Icons.chat_rounded; break;
              case 'sms': actColor = Colors.blue; actIcon = Icons.sms_rounded; break;
              case 'status_change': actColor = kAmber; actIcon = Icons.swap_horiz_rounded; break;
              default: actColor = kPurple; actIcon = Icons.notes_rounded;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: actColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(actIcon, size: 14, color: actColor)),
                const SizedBox(width: 10),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFAF9FF), border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(a.type.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: actColor)),
                      const Spacer(),
                      if (a.createdAt != null) Text(DateFormat('dd MMM, hh:mm a').format(a.createdAt!), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ]),
                    if (a.type == 'call') ...[
                      const SizedBox(height: 4),
                      Text('${(a.callStatus ?? 'connected').toUpperCase()} • ${a.durationFormatted}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                    if (a.description != null && a.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(a.description!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                    if (a.performedByName != null) ...[
                      const SizedBox(height: 4),
                      Text('By: ${a.performedByName}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ]),
                )),
              ]),
            );
          }),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}