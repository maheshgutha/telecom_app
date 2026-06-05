import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';
import '../widgets/status_badge.dart';

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});
  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<FollowUp> _all = [], _today = [], _overdue = [];
  bool _loading = true;
  String _dueFilter = 'all';
  String _statusFilter = 'pending,late';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getFollowUps(auth, forMe: true, status: _statusFilter);
    final all = (data['followups'] as List? ?? []).map((e) => FollowUp.fromJson(e)).toList();
    setState(() {
      _all = all;
      _today = all.where((f) => f.isToday).toList();
      _overdue = all.where((f) => f.isOverdue).toList();
      _loading = false;
    });
  }

  Future<void> _markDone(FollowUp f) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    await api.updateFollowUp(auth, f.id, {'status': 'done'});
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as done ✓'), backgroundColor: kGreen),
    );
  }

  Future<void> _deleteFollowUp(FollowUp f) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Delete this follow-up?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await api.deleteFollowUp(auth, f.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'All (${_all.length})'),
            Tab(text: 'Today (${_today.length})'),
            Tab(text: 'Overdue (${_overdue.length})'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _showCreateModal),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _FollowUpList(items: _all, onDone: _markDone, onDelete: _deleteFollowUp),
                _FollowUpList(items: _today, onDone: _markDone, onDelete: _deleteFollowUp),
                _FollowUpList(items: _overdue, onDone: _markDone, onDelete: _deleteFollowUp),
              ],
            ),
    );
  }

  void _showCreateModal() {
    final noteCtrl = TextEditingController();
    DateTime? scheduledAt;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Schedule Callback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: noteCtrl, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Note / Instructions')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(scheduledAt != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(scheduledAt!)
                    : 'Pick Date & Time'),
                onPressed: () async {
                  final date = await showDatePicker(context: ctx,
                      initialDate: DateTime.now().add(const Duration(hours: 1)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date == null) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (time == null) return;
                  setS(() => scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: scheduledAt == null ? null : () async {
                  final auth = context.read<AuthService>();
                  final api = context.read<ApiService>();
                  await api.createFollowUp(auth, {
                    'scheduledAt': scheduledAt!.toIso8601String(),
                    'note': noteCtrl.text,
                  });
                  if (mounted) Navigator.pop(context);
                  _load();
                },
                child: const Text('Create Callback'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpList extends StatelessWidget {
  final List<FollowUp> items;
  final Function(FollowUp) onDone;
  final Function(FollowUp) onDelete;
  const _FollowUpList({required this.items, required this.onDone, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_rounded, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No tasks here', style: TextStyle(color: Colors.grey)),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _FollowUpCard(item: items[i], onDone: () => onDone(items[i]), onDelete: () => onDelete(items[i])),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final FollowUp item;
  final VoidCallback onDone, onDelete;
  const _FollowUpCard({required this.item, required this.onDone, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = item.isOverdue ? kRed : item.isToday ? kAmber : kPurple;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(
                  item.leadName ?? 'Follow-up',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain),
                )),
                if (item.status == 'pending' || item.status == 'late')
                  TextButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Done', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: kGreen, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), onPressed: onDelete),
              ],
            ),
            if (item.leadPhone != null)
              Text(item.leadPhone!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy · hh:mm a').format(item.scheduledAt),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.isOverdue ? kRed.withOpacity(0.1) : kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(color: item.isOverdue ? kRed : kGreen, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.note!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}