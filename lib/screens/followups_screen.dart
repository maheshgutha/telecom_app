import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import 'leads_screen.dart';

class FollowUpsScreen extends StatefulWidget {
  final int initialTab;
  const FollowUpsScreen({super.key, this.initialTab = 0});
  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<FollowUp> _all = [], _today = [], _overdue = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    _load();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final isAdmin = auth.user?.isAdmin ?? false;
    final data = await api.getFollowUps(auth, forMe: !isAdmin, status: 'upcoming');
    final all = (data['followups'] as List? ?? []).map((e) => FollowUp.fromJson(e)).toList();
    setState(() {
      _all = all;
      _today = all.where((f) => f.isToday).toList();
      _overdue = all.where((f) => f.isOverdue).toList();
      _loading = false;
    });
  }

  Future<void> _markDone(FollowUp f) async {
    await context.read<ApiService>().updateFollowUp(context.read<AuthService>(), f.id, {'status': 'done'});
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as done ✓'), backgroundColor: kGreen),
    );
  }

  Future<void> _delete(FollowUp f) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Task'),
      content: const Text('Delete this follow-up?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: kRed))),
      ],
    ));
    if (ok == true) {
      await context.read<ApiService>().deleteFollowUp(context.read<AuthService>(), f.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tasks & Follow-ups'),
      bottom: TabBar(
        controller: _tabs,
        labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white,
        tabs: [Tab(text: 'All (${_all.length})'), Tab(text: 'Today (${_today.length})'), Tab(text: 'Overdue (${_overdue.length})')],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        IconButton(icon: const Icon(Icons.add_rounded), onPressed: _showCreateOptions),
      ],
    ),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : TabBarView(controller: _tabs, children: [
          _FUList(items: _all, onDone: _markDone, onDelete: _delete),
          _FUList(items: _today, onDone: _markDone, onDelete: _delete),
          _FUList(items: _overdue, onDone: _markDone, onDelete: _delete),
        ]),
  );

  // Show options: schedule callback OR create new task with lead
  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Padding(padding: EdgeInsets.all(16), child: Text('Create New Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.phone_callback_rounded, color: kPurple)),
            title: const Text('Schedule Callback', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Set a reminder to call a lead'),
            onTap: () { Navigator.pop(context); _showScheduleCallback(); },
          ),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.note_add_rounded, color: kGreen)),
            title: const Text('Create Task for Lead', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Assign a follow-up to a specific lead'),
            onTap: () { Navigator.pop(context); _showCreateWithLead(); },
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // Fixed callback modal - no keyboard overlap
  void _showScheduleCallback() {
    final noteCtrl = TextEditingController();
    DateTime? scheduledAt;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          // Use viewInsets to push above keyboard
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Schedule Callback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Note / Instructions',
                  hintText: 'e.g. Follow up on demo interest...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  scheduledAt != null
                    ? DateFormat('dd MMM yyyy  •  hh:mm a').format(scheduledAt!)
                    : 'Pick Date & Time',
                  style: TextStyle(color: scheduledAt != null ? kPurple : Colors.grey.shade600),
                ),
                onPressed: () async {
                  FocusScope.of(ctx).unfocus();
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (!ctx.mounted) return;
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(hours: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (time == null) return;
                  setS(() => scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('Create Callback'),
                onPressed: scheduledAt == null ? null : () async {
                  final auth = context.read<AuthService>();
                  final api = context.read<ApiService>();
                  await api.createFollowUp(auth, {
                    'scheduledAt': scheduledAt!.toIso8601String(),
                    'note': noteCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Callback scheduled ✓'), backgroundColor: kGreen),
                  );
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // Create task with lead selection
  void _showCreateWithLead() {
    final noteCtrl = TextEditingController();
    DateTime? scheduledAt;
    Map<String, dynamic>? selectedLead;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, ctrl) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(children: [
                // Handle
                Container(margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    const Expanded(child: Text('Create Task for Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SizedBox(height: 12),
                      // Lead search/select
                      if (selectedLead == null) ...[
                        const Text('Search Lead', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                        const SizedBox(height: 6),
                        _LeadSearchField(
                          controller: searchCtrl,
                          onLeadSelected: (lead) => setS(() { selectedLead = lead; searchCtrl.clear(); }),
                        ),
                      ] else ...[
                        const Text('Selected Lead', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: kPurple.withOpacity(0.3))),
                          child: Row(children: [
                            CircleAvatar(backgroundColor: kPurple, child: Text((selectedLead!['name'] as String? ?? 'L')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(selectedLead!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: kPurple)),
                              Text(selectedLead!['phone'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ])),
                            IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: kPurple), onPressed: () => setS(() => selectedLead = null)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Task Note', hintText: 'What to do...', alignLabelWithHint: true),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          scheduledAt != null ? DateFormat('dd MMM yyyy  •  hh:mm a').format(scheduledAt!) : 'Pick Date & Time',
                          style: TextStyle(color: scheduledAt != null ? kPurple : Colors.grey.shade600),
                        ),
                        onPressed: () async {
                          FocusScope.of(ctx).unfocus();
                          await Future.delayed(const Duration(milliseconds: 200));
                          if (!ctx.mounted) return;
                          final date = await showDatePicker(context: ctx,
                              initialDate: DateTime.now().add(const Duration(hours: 1)),
                              firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (date == null || !ctx.mounted) return;
                          final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                          if (time == null) return;
                          setS(() => scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text('Create Task'),
                        onPressed: (selectedLead == null || scheduledAt == null) ? null : () async {
                          final auth = context.read<AuthService>();
                          final api = context.read<ApiService>();
                          await api.createFollowUp(auth, {
                            'lead': selectedLead!['_id'],
                            'scheduledAt': scheduledAt!.toIso8601String(),
                            'note': noteCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task created ✓'), backgroundColor: kGreen),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// Lead search widget
class _LeadSearchField extends StatefulWidget {
  final TextEditingController controller;
  final Function(Map<String, dynamic>) onLeadSelected;
  const _LeadSearchField({required this.controller, required this.onLeadSelected});
  @override State<_LeadSearchField> createState() => _LeadSearchFieldState();
}
class _LeadSearchFieldState extends State<_LeadSearchField> {
  List<dynamic> _results = [];
  bool _searching = false;

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getLeads(auth, search: q, limit: 8);
    setState(() { _results = data['leads'] as List? ?? []; _searching = false; });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        hintText: 'Search by name or phone...',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
        isDense: true,
      ),
      onChanged: _search,
    ),
    if (_results.isNotEmpty) Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(children: _results.take(6).map((l) {
        final lead = l as Map;
        return ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, backgroundColor: kPurpleLight,
              child: Text((lead['name'] as String? ?? 'L')[0].toUpperCase(), style: const TextStyle(color: kPurple, fontSize: 11, fontWeight: FontWeight.bold))),
          title: Text(lead['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(lead['phone'] ?? '', style: const TextStyle(fontSize: 11)),
          onTap: () { widget.onLeadSelected(Map<String, dynamic>.from(lead)); setState(() => _results = []); },
        );
      }).toList()),
    ),
  ]);
}

class _FUList extends StatelessWidget {
  final List<FollowUp> items;
  final Function(FollowUp) onDone, onDelete;
  const _FUList({required this.items, required this.onDone, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_available_rounded, size: 56, color: Colors.grey),
      SizedBox(height: 12),
      Text('No tasks here', style: TextStyle(color: Colors.grey)),
    ]));
    return ListView.builder(
      padding: const EdgeInsets.all(14), itemCount: items.length,
      itemBuilder: (_, i) => _FUCard(item: items[i], onDone: () => onDone(items[i]), onDelete: () => onDelete(items[i])),
    );
  }
}

class _FUCard extends StatelessWidget {
  final FollowUp item; final VoidCallback onDone, onDelete;
  const _FUCard({required this.item, required this.onDone, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final color = item.isOverdue ? kRed : item.isToday ? kAmber : kPurple;
    return Container(margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.leadName ?? 'Follow-up',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain))),
          TextButton.icon(onPressed: onDone, icon: const Icon(Icons.check_circle_outline, size: 14),
              label: const Text('Done', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kGreen, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4))),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), onPressed: onDelete),
        ]),
        if (item.leadPhone != null) Text(item.leadPhone!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 13, color: color), const SizedBox(width: 4),
          Text(DateFormat('dd MMM yyyy · hh:mm a').format(item.scheduledAt),
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(item.isOverdue ? 'OVERDUE' : item.isToday ? 'TODAY' : 'UPCOMING',
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        if (item.note != null && item.note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(item.note!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ])),
    );
  }
}