import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = '';
  bool _loading = true;
  List<UserModel> _users = [];

  static const _roles = [
    {'label': 'Sve uloge', 'value': ''},
    {'label': 'Admin', 'value': 'Admin'},
    {'label': 'Član', 'value': 'Member'},
    {'label': 'Trener', 'value': 'Trainer'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await UserService.getAll(
        search: _searchCtrl.text.trim(),
        role: _roleFilter.isEmpty ? null : _roleFilter,
      );
      if (!mounted) return;
      setState(() => _users = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(UserModel user, bool value) async {
    try {
      await UserService.setActive(user.id, value);
      if (!mounted) return;
      setState(() {
        _users = _users
            .map((u) => u.id == user.id
                ? UserModel(
                    id: u.id,
                    firstName: u.firstName,
                    lastName: u.lastName,
                    username: u.username,
                    email: u.email,
                    phoneNumber: u.phoneNumber,
                    dateOfBirth: u.dateOfBirth,
                    role: u.role,
                    isActive: value,
                    profileImageUrl: u.profileImageUrl,
                    cityId: u.cityId,
                    cityName: u.cityName,
                    primaryGymId: u.primaryGymId,
                    primaryGymName: u.primaryGymName,
                  )
                : u)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Korisnik aktiviran.' : 'Korisnik deaktiviran.'),
          backgroundColor: kGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    }
  }

  void _showDetails(UserModel u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Korisnik #${u.id}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Ime i prezime', u.fullName),
              _detailRow('Username', u.username),
              _detailRow('Email', u.email),
              _detailRow('Telefon', u.phoneNumber ?? '-'),
              _detailRow('Uloga', u.roleLabel),
              _detailRow('Grad', u.cityName ?? '-'),
              _detailRow('Primarna teretana', u.primaryGymName ?? '-'),
              _detailRow('Datum rođenja', u.dateOfBirth ?? '-'),
              _detailRow('Status', u.isActive ? 'Aktivan' : 'Neaktivan'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditDialog(u);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Uredi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(UserModel user) async {
    try {
      final results = await Future.wait([
        ReferenceService.getCities(),
        GymService.getAll(),
      ]);
      if (!mounted) return;

      final cities = results[0] as List<ReferenceItem>;
      final gyms = results[1] as List<GymModel>;

      final firstNameCtrl = TextEditingController(text: user.firstName);
      final lastNameCtrl = TextEditingController(text: user.lastName);
      final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');
      final imageCtrl = TextEditingController(text: user.profileImageUrl ?? '');
      final dobCtrl = TextEditingController(
        text: user.dateOfBirth != null ? user.dateOfBirth!.substring(0, 10) : '',
      );
      final formKey = GlobalKey<FormState>();
      int? selectedCityId = user.cityId;
      int? selectedGymId = user.primaryGymId;
      DateTime? selectedDob = user.dateOfBirth != null
          ? DateTime.tryParse(user.dateOfBirth!)
          : null;

      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('Uredi korisnika #${user.id}'),
            content: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'Ime'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obavezno polje'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Prezime'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obavezno polje'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Telefon'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dobCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Datum rođenja',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDob ?? DateTime.now(),
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now(),
                              );
                              if (picked == null) return;
                              setDialogState(() {
                                selectedDob = picked;
                                dobCtrl.text =
                                    '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedCityId,
                        decoration: const InputDecoration(labelText: 'Grad'),
                        items: cities
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedCityId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedGymId,
                        decoration: const InputDecoration(labelText: 'Primarna teretana'),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Nije postavljeno'),
                          ),
                          ...gyms.map(
                            (g) => DropdownMenuItem<int>(
                              value: g.id,
                              child: Text(g.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setDialogState(() => selectedGymId = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imageCtrl,
                        decoration: const InputDecoration(labelText: 'URL slike profila'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Korisničko ime i email se ne mijenjaju iz ovog ekrana.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Otkaži'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await UserService.update(
                      user.id,
                      {
                        'firstName': firstNameCtrl.text.trim(),
                        'lastName': lastNameCtrl.text.trim(),
                        'phoneNumber': phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                        'dateOfBirth': selectedDob?.toIso8601String(),
                        'cityId': selectedCityId,
                        'primaryGymId': selectedGymId,
                        'profileImageUrl': imageCtrl.text.trim().isEmpty
                            ? null
                            : imageCtrl.text.trim(),
                      },
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, true);
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                    );
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Sačuvaj'),
              ),
            ],
          ),
        ),
      );

      if (saved == true) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Korisnik je ažuriran.'),
            backgroundColor: kGreen,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pretraži članove...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _roleFilter,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: _roles
                      .map((r) => DropdownMenuItem<String>(
                            value: r['value'],
                            child: Text(r['label']!),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _roleFilter = v ?? '');
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search),
                label: const Text('Traži'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _roleFilter = '');
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(child: Text('Nema korisnika za prikaz.'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: DataTable(
                                    headingRowColor: const WidgetStatePropertyAll(
                                      Color(0xFFF8FAFC),
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Korisnik')),
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Uloga')),
                                      DataColumn(label: Text('Grad')),
                                      DataColumn(label: Text('Aktivan')),
                                      DataColumn(label: Text('Akcije')),
                                    ],
                                    rows: _users
                                        .map(
                                          (u) => DataRow(cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 15,
                                                    backgroundColor:
                                                        kPrimary.withValues(alpha: 0.12),
                                                    child: Text(
                                                      (u.firstName.isNotEmpty
                                                              ? u.firstName[0]
                                                              : '?')
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        color: kPrimary,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(u.fullName),
                                                ],
                                              ),
                                            ),
                                            DataCell(Text(u.email)),
                                            DataCell(_RoleChip(role: u.roleLabel)),
                                            DataCell(Text(u.cityName ?? '-')),
                                            DataCell(
                                              Switch(
                                                value: u.isActive,
                                                activeThumbColor: kGreen,
                                                onChanged: (v) => _toggleActive(u, v),
                                              ),
                                            ),
                                            DataCell(
                                              TextButton.icon(
                                                onPressed: () => _showDetails(u),
                                                icon: const Icon(Icons.visibility_outlined,
                                                    size: 17),
                                                label: const Text('Pregled'),
                                              ),
                                            ),
                                          ]),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (role.toLowerCase()) {
      case 'admin':
        bg = kPurple.withValues(alpha: 0.12);
        fg = kPurple;
        break;
      case 'trener':
        bg = kTeal.withValues(alpha: 0.12);
        fg = kTeal;
        break;
      default:
        bg = kPrimary.withValues(alpha: 0.12);
        fg = kPrimary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
