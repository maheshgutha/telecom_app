import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../main.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getUsers(auth);
    setState(() { _users = (data['users'] as List? ?? []).map((u) => User.fromJson(Map<String, dynamic>.from(u))).toList(); _loading = false; });
  }

  Future<void> _showAddModal() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'caller';
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    String? errorMsg;

    await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Add New User'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (errorMsg != null) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(errorMsg!, style: const TextStyle(color: kRed, fontSize: 12))),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
        const SizedBox(height: 8),
        TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *')),
        const SizedBox(height: 8),
        TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 8),
        TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password *')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Role'),
            items: ['caller','admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setS(() => role = v!)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) { setS(() => errorMsg = 'Fill required fields'); return; }
          try {
            await api.createUser(auth, {'name': nameCtrl.text, 'email': emailCtrl.text, 'phone': phoneCtrl.text, 'password': passCtrl.text, 'role': role});
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) { setS(() => errorMsg = 'Failed: $e'); }
        }, child: const Text('Create')),
      ],
    )));
  }

  Future<void> _showEditModal(User user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final passCtrl = TextEditingController();
    String role = user.role;
    bool isActive = user.isActive;
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final isSuperAdmin = auth.user?.isSuperAdmin ?? false;

    await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text('Edit — ${user.name}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 13))),
              const Text('(cannot change)', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ])),
        const SizedBox(height: 8),
        TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 8),
        TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password (leave blank to keep)')),
        const SizedBox(height: 8),
        if (isSuperAdmin && user.role != 'super admin')
          DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Role'),
              items: ['caller','admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setS(() => role = v!)),
        const SizedBox(height: 8),
        Row(children: [
          Checkbox(value: isActive, onChanged: (v) => setS(() => isActive = v!)),
          const Text('Account Active', style: TextStyle(fontSize: 13)),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final payload = <String, dynamic>{'name': nameCtrl.text, 'phone': phoneCtrl.text, 'isActive': isActive};
          if (passCtrl.text.isNotEmpty) payload['password'] = passCtrl.text;
          if (isSuperAdmin) payload['role'] = role;
          await api.updateUser(auth, user.id, payload);
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        }, child: const Text('Save Changes')),
      ],
    )));
  }

  Future<void> _deleteUser(User user) async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete User'),
      content: Text('Delete "${user.name}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: kRed))),
      ],
    ));
    if (ok == true) { await api.deleteUser(auth, user.id); _load(); }
  }

  Color _roleColor(String role) {
    switch (role) { case 'super admin': return kRed; case 'admin': return kPurple; default: return Colors.blue; }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isSuperAdmin = auth.user?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('User Management'), actions: [
        IconButton(icon: const Icon(Icons.person_add_rounded), onPressed: _showAddModal),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _users.isEmpty ? const Center(child: Text('No users yet.', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: _users.length,
          itemBuilder: (_, i) {
            final u = _users[i];
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
              child: Row(children: [
                CircleAvatar(backgroundColor: kPurpleLight,
                    child: Text(u.initials, style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextMain)),
                  Text(u.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (u.phone != null) Text(u.phone!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _roleColor(u.role).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(u.role.toUpperCase(), style: TextStyle(color: _roleColor(u.role), fontSize: 9, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: u.isActive ? kGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(u.isActive ? 'Active' : 'Inactive', style: TextStyle(color: u.isActive ? kGreen : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold))),
                  ]),
                ])),
                Column(children: [
                  // Edit button
                  IconButton(icon: const Icon(Icons.edit_rounded, color: kPurple, size: 20), onPressed: () => _showEditModal(u)),
                  // Delete (super admin only, not self)
                  if (isSuperAdmin && u.role != 'super admin' && u.id != auth.user?.id)
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20), onPressed: () => _deleteUser(u)),
                ]),
              ]),
            );
          },
        ),
    );
  }
}