import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _saving = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _passCtrl = TextEditingController();
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final payload = <String, dynamic>{'name': _nameCtrl.text, 'phone': _phoneCtrl.text};
    if (_passCtrl.text.isNotEmpty) payload['password'] = _passCtrl.text;
    try {
      await api.updateProfile(auth, payload);
      setState(() { _isEditing = false; _saving = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated ✓'), backgroundColor: kGreen),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            TextButton.icon(icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                label: const Text('Edit', style: TextStyle(color: Colors.white)),
                onPressed: () => setState(() => _isEditing = true))
          else
            TextButton.icon(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                label: const Text('Cancel', style: TextStyle(color: Colors.white)),
                onPressed: () => setState(() { _isEditing = false; _nameCtrl.text = user?.name ?? ''; _phoneCtrl.text = user?.phone ?? ''; _passCtrl.clear(); })),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        // Avatar card
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
          child: Column(children: [
            Stack(children: [
              CircleAvatar(radius: 40, backgroundColor: kPurpleLight,
                  child: Text(user?.initials ?? 'U', style: const TextStyle(color: kPurple, fontSize: 30, fontWeight: FontWeight.bold))),
              if (_isEditing) Positioned(right: 0, bottom: 0, child: Container(
                padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              )),
            ]),
            const SizedBox(height: 14),
            if (!_isEditing) ...[
              Text(user?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextMain)),
              const SizedBox(height: 2),
              Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(20)),
                  child: Text((user?.role ?? '').toUpperCase(), style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 12))),
            ] else ...[
              // Edit form
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded, size: 18))),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                  child: Row(children: [
                    const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    const Text('cannot change', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ])),
              const SizedBox(height: 10),
              TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined, size: 18))),
              const SizedBox(height: 10),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password (optional)', prefixIcon: Icon(Icons.lock_outline, size: 18))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes'),
              )),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Info tiles
        if (!_isEditing) Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
          child: Column(children: [
            _Tile(Icons.person_outline_rounded, 'Name', user?.name ?? '—'),
            const Divider(height: 1, indent: 56),
            _Tile(Icons.email_outlined, 'Email', user?.email ?? '—'),
            const Divider(height: 1, indent: 56),
            _Tile(Icons.phone_outlined, 'Phone', user?.phone ?? '—'),
            const Divider(height: 1, indent: 56),
            _Tile(Icons.badge_outlined, 'Role', user?.role ?? '—'),
            const Divider(height: 1, indent: 56),
            _Tile(user?.isActive == true ? Icons.check_circle_outline : Icons.cancel_outlined, 'Status',
                user?.isActive == true ? 'Active' : 'Inactive',
                color: user?.isActive == true ? kGreen : kRed),
          ]),
        ),
        const SizedBox(height: 16),

        // Server info
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
          child: Row(children: [
            Icon(Icons.cloud_outlined, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Server', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w700, fontSize: 12)),
              Text('telecommunication-hmkv.onrender.com', style: TextStyle(color: Colors.blue.shade600, fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // Logout
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: kRed))),
              ],
            ));
            if (ok == true && context.mounted) {
              await context.read<AuthService>().logout();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }
          },
          icon: const Icon(Icons.logout_rounded, color: kRed),
          label: const Text('Sign Out', style: TextStyle(color: kRed)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        )),
        const SizedBox(height: 40),
      ])),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon; final String label, value; final Color? color;
  const _Tile(this.icon, this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? kPurple, size: 20),
    title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    subtitle: Text(value, style: TextStyle(color: color ?? kTextMain, fontWeight: FontWeight.w500, fontSize: 13)),
    dense: true,
  );
}