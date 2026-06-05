import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../main.dart';

const _statuses = ['Fresh','Connected','Call Not Responding','Call Back Later','Not interested','Demo Scheduled','Demo Done','Won','Lost'];
const _sources = ['Manual','Facebook','WhatsApp','Website','Excel','Referral'];
const _courses = ['MBA','BBA','B.Tech','MCA','B.Sc','M.Tech','B.Com','M.Com'];
const _modes = ['Online','Offline','Hybrid'];

class AddLeadScreen extends StatefulWidget {
  final String? leadId;
  const AddLeadScreen({super.key, this.leadId});
  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  bool _loading = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _altPhone = TextEditingController();
  final _email = TextEditingController();
  final _location = TextEditingController();
  final _qual = TextEditingController();
  final _budget = TextEditingController();

  String _status = 'Fresh';
  String _source = 'Manual';
  String _mode = '';
  List<String> _preferredCourses = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _dbCourses = [];
  String _assignedTo = '';
  String _campaign = '';
  String _courseInterest = '';

  @override
  void initState() {
    super.initState();
    _loadOptions();
    if (widget.leadId != null) _loadLead();
  }

  @override
  void dispose() {
    for (final c in [_name,_phone,_altPhone,_email,_location,_qual,_budget]) c.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final results = await Future.wait([
      api.getCampaigns(auth),
      api.getUsers(auth),
      api.getCourses(auth),
    ]);
    setState(() {
      _campaigns = List<Map<String, dynamic>>.from(results[0]['campaigns'] ?? []);
      _users = List<Map<String, dynamic>>.from(results[1]['users'] ?? []);
      _dbCourses = List<Map<String, dynamic>>.from(results[2]['courses'] ?? []);
    });
  }

  Future<void> _loadLead() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final data = await api.getLeadById(auth, widget.leadId!);
    final l = data['lead'];
    if (l != null) {
      _name.text = l['name'] ?? '';
      _phone.text = l['phone'] ?? '';
      _altPhone.text = l['alternatePhone'] ?? '';
      _email.text = l['email'] ?? '';
      _location.text = l['location'] ?? '';
      _qual.text = l['lastQualification'] ?? '';
      _budget.text = l['budget']?.toString() ?? '';
      setState(() {
        _status = l['status'] ?? 'Fresh';
        _source = l['leadSource'] ?? 'Manual';
        _mode = l['mode'] ?? '';
        _preferredCourses = List<String>.from(l['preferredCourses'] ?? []);
        _assignedTo = (l['assignedTo'] is Map ? l['assignedTo']['_id'] : l['assignedTo']) ?? '';
        _campaign = (l['campaign'] is Map ? l['campaign']['_id'] : l['campaign']) ?? '';
        _courseInterest = (l['courseInterest'] is Map ? l['courseInterest']['_id'] : l['courseInterest']) ?? '';
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final body = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      if (_altPhone.text.isNotEmpty) 'alternatePhone': _altPhone.text.trim(),
      if (_email.text.isNotEmpty) 'email': _email.text.trim(),
      if (_location.text.isNotEmpty) 'location': _location.text.trim(),
      if (_qual.text.isNotEmpty) 'lastQualification': _qual.text.trim(),
      if (_budget.text.isNotEmpty) 'budget': double.tryParse(_budget.text) ?? 0,
      'status': _status,
      'leadSource': _source,
      if (_mode.isNotEmpty) 'mode': _mode,
      if (_preferredCourses.isNotEmpty) 'preferredCourses': _preferredCourses,
      if (_assignedTo.isNotEmpty) 'assignedTo': _assignedTo,
      if (_campaign.isNotEmpty) 'campaign': _campaign,
      if (_courseInterest.isNotEmpty) 'courseInterest': _courseInterest,
    };

    try {
      if (widget.leadId != null) {
        await api.updateLead(auth, widget.leadId!, body);
      } else {
        await api.createLead(auth, body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.leadId != null ? 'Lead updated!' : 'Lead added!'), backgroundColor: kGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: kRed),
      );
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.leadId != null ? 'Edit Lead' : 'Add New Lead')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Info
                    _Section('Basic Information', [
                      _Field('Full Name *', TextFormField(controller: _name, validator: (v) => v?.isEmpty == true ? 'Required' : null, decoration: const InputDecoration(hintText: 'Enter full name'))),
                      Row(children: [
                        Expanded(child: _Field('Phone *', TextFormField(controller: _phone, keyboardType: TextInputType.phone, validator: (v) => v?.isEmpty == true ? 'Required' : null, decoration: const InputDecoration(hintText: 'Phone number')))),
                        const SizedBox(width: 10),
                        Expanded(child: _Field('Alternate Phone', TextFormField(controller: _altPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Alt number')))),
                      ]),
                      _Field('Email', TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email address'))),
                      _Field('Location', TextFormField(controller: _location, decoration: const InputDecoration(hintText: 'City, State'))),
                    ]),
                    const SizedBox(height: 12),

                    // Lead Details
                    _Section('Lead Details', [
                      Row(children: [
                        Expanded(child: _Field('Status', DropdownButtonFormField<String>(
                          value: _status, decoration: const InputDecoration(),
                          items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _status = v!),
                        ))),
                        const SizedBox(width: 10),
                        Expanded(child: _Field('Source', DropdownButtonFormField<String>(
                          value: _source, decoration: const InputDecoration(),
                          items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _source = v!),
                        ))),
                      ]),
                      if (_dbCourses.isNotEmpty)
                        _Field('Course Interest', DropdownButtonFormField<String>(
                          value: _courseInterest.isEmpty ? null : _courseInterest,
                          decoration: const InputDecoration(hintText: 'Select course'),
                          items: [const DropdownMenuItem(value: '', child: Text('None')), ..._dbCourses.map((c) => DropdownMenuItem(value: c['_id'] as String, child: Text('${c['name']} (₹${c['cost']?.toStringAsFixed(0) ?? '0'})')))],
                          onChanged: (v) => setState(() => _courseInterest = v ?? ''),
                        )),
                      _Field('Study Mode', DropdownButtonFormField<String>(
                        value: _mode.isEmpty ? null : _mode,
                        decoration: const InputDecoration(hintText: 'Select mode'),
                        items: [const DropdownMenuItem(value: '', child: Text('None')), ..._modes.map((m) => DropdownMenuItem(value: m, child: Text(m)))],
                        onChanged: (v) => setState(() => _mode = v ?? ''),
                      )),
                      _Field('Preferred Courses', Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _courses.map((c) => GestureDetector(
                          onTap: () => setState(() {
                            if (_preferredCourses.contains(c)) _preferredCourses.remove(c);
                            else _preferredCourses.add(c);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _preferredCourses.contains(c) ? kPurple : Colors.white,
                              border: Border.all(color: _preferredCourses.contains(c) ? kPurple : kBorder),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(c, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: _preferredCourses.contains(c) ? Colors.white : Colors.grey.shade600,
                            )),
                          ),
                        )).toList(),
                      )),
                      _Field('Budget (₹)', TextFormField(controller: _budget, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0', prefixText: '₹'))),
                      _Field('Last Qualification', TextFormField(controller: _qual, decoration: const InputDecoration(hintText: 'Qualification details'))),
                    ]),
                    const SizedBox(height: 12),

                    // Assignment
                    _Section('Assignment', [
                      if (_users.isNotEmpty)
                        _Field('Assign To', DropdownButtonFormField<String>(
                          value: _assignedTo.isEmpty ? null : _assignedTo,
                          decoration: const InputDecoration(hintText: 'Select user'),
                          items: [const DropdownMenuItem(value: '', child: Text('Assign to me')), ..._users.map((u) => DropdownMenuItem(value: u['_id'] as String, child: Text('${u['name']} (${u['role']})')))],
                          onChanged: (v) => setState(() => _assignedTo = v ?? ''),
                        )),
                      if (_campaigns.isNotEmpty)
                        _Field('Campaign', DropdownButtonFormField<String>(
                          value: _campaign.isEmpty ? null : _campaign,
                          decoration: const InputDecoration(hintText: 'Select campaign'),
                          items: [const DropdownMenuItem(value: '', child: Text('No Campaign')), ..._campaigns.map((c) => DropdownMenuItem(value: c['_id'] as String, child: Text(c['name'] as String)))],
                          onChanged: (v) => setState(() => _campaign = v ?? ''),
                        )),
                    ]),
                    const SizedBox(height: 20),

                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(widget.leadId != null ? 'Update Lead' : 'Add Lead'),
                      )),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain)),
          const SizedBox(height: 14),
          ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field(this.label, this.child);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.4)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}