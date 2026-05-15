import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class MembershipsScreen extends StatefulWidget {
  const MembershipsScreen({super.key});

  @override
  State<MembershipsScreen> createState() => _MembershipsScreenState();
}

class _MembershipsScreenState extends State<MembershipsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  List<MembershipPlan> _plans = [];
  List<UserMembership> _memberships = [];
  List<GymModel> _gyms = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MembershipService.getPlans(),
        MembershipService.getAllMemberships(),
        GymService.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<MembershipPlan>;
        _memberships = results[1] as List<UserMembership>;
        _gyms = results[2] as List<GymModel>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPlanDialog([MembershipPlan? plan, int? initialGymId]) async {
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final descriptionCtrl = TextEditingController(text: plan?.description ?? '');
    final durationCtrl = TextEditingController(
      text: plan != null ? plan.durationDays.toString() : '30',
    );
    final priceCtrl = TextEditingController(
      text: plan != null ? plan.price.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();
    int? selectedGymId =
        plan?.gymId ?? initialGymId ?? (_gyms.isNotEmpty ? _gyms.first.id : null);
    bool isActive = plan?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(plan == null ? 'Novi plan clanarine' : 'Uredi plan'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Naziv plana'),
                      validator: (value) => (value == null || value.trim().length < 2)
                          ? 'Naziv mora imati najmanje 2 slova.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedGymId,
                      decoration: const InputDecoration(labelText: 'Teretana'),
                      items: _gyms
                          .map(
                            (gym) => DropdownMenuItem<int>(
                              value: gym.id,
                              child: Text(gym.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedGymId = value),
                      validator: (value) => value == null ? 'Odaberi teretanu.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionCtrl,
                      decoration: const InputDecoration(labelText: 'Opis'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Trajanje (dani)',
                            ),
                            validator: (value) {
                              final days = int.tryParse((value ?? '').trim());
                              if (days == null || days <= 0) {
                                return 'Trajanje mora biti veci broj od 0.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(labelText: 'Cijena (KM)'),
                            validator: (value) {
                              final price = double.tryParse(
                                (value ?? '').trim().replaceAll(',', '.'),
                              );
                              if (price == null || price <= 0) {
                                return 'Cijena mora biti veca od 0.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isActive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Plan je aktivan'),
                        onChanged: (value) => setDialogState(() => isActive = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dto = {
                  'name': nameCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim().isEmpty
                      ? null
                      : descriptionCtrl.text.trim(),
                  'durationDays': int.parse(durationCtrl.text.trim()),
                  'price': double.parse(priceCtrl.text.trim().replaceAll(',', '.')),
                  'gymId': selectedGymId,
                  if (plan != null) 'isActive': isActive,
                };
                try {
                  if (plan == null) {
                    await MembershipService.createPlan(dto);
                  } else {
                    await MembershipService.updatePlan(plan.id, dto);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                  );
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Sacuvaj'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(plan == null ? 'Plan je dodan.' : 'Plan je azuriran.'),
          backgroundColor: kGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: kPrimary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: kPrimary,
                  tabs: const [
                    Tab(text: 'Planovi'),
                    Tab(text: 'Clanarine'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (_tabCtrl.index == 0)
                FilledButton.icon(
                  onPressed: _gyms.isEmpty ? null : () => _showPlanDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novi plan'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildPlansTab(),
                      _buildMembershipsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansTab() {
    if (_plans.isEmpty) {
      return const Center(child: Text('Nema dostupnih planova.'));
    }

    final Map<int, List<MembershipPlan>> byGym = {};
    for (final plan in _plans) {
      byGym.putIfAbsent(plan.gymId, () => []).add(plan);
    }

    final gyms = byGym.keys.toList();

    return ListView.builder(
      itemCount: gyms.length,
      itemBuilder: (ctx, i) {
        final gymId = gyms[i];
        final plansForGym = byGym[gymId]!;
        final gymName = plansForGym.first.gymName;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      gymName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showPlanDialog(null, gymId),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Dodaj za ovu teretanu'),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: plansForGym.length,
              itemBuilder: (ctx, j) => _PlanCard(
                plan: plansForGym[j],
                onEdit: () => _showPlanDialog(plansForGym[j]),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildMembershipsTab() {
    if (_memberships.isEmpty) {
      return const Center(child: Text('Nema aktivnih clanarina.'));
    }

    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Clan')),
              DataColumn(label: Text('Teretana')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Pocetak')),
              DataColumn(label: Text('Istek')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Dana')),
            ],
            rows: _memberships
                .map(
                  (m) => DataRow(cells: [
                    DataCell(Text(m.fullName)),
                    DataCell(Text(m.gymName)),
                    DataCell(Text(m.planName)),
                    DataCell(Text(_fmtDate(m.startDate))),
                    DataCell(Text(_fmtDate(m.endDate))),
                    DataCell(_StatusBadge(label: m.statusLabel)),
                    DataCell(Text(
                      m.daysRemaining.toString(),
                      style: TextStyle(
                        color: m.daysRemaining < 7 ? kRed : kGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                  ]),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  final VoidCallback onEdit;

  const _PlanCard({
    required this.plan,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'bs');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Uredi plan',
                  ),
                ],
              ),
              if (plan.description != null && plan.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    plan.description!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: plan.isActive
                          ? kGreen.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plan.isActive ? 'Aktivan' : 'Neaktivan',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: plan.isActive ? kGreen : Colors.grey,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${plan.durationDays} dana',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${fmt.format(plan.price)} KM',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (label.toLowerCase()) {
      case 'aktivna':
        bg = kGreen.withValues(alpha: 0.12);
        fg = kGreen;
        break;
      case 'istekla':
        bg = kRed.withValues(alpha: 0.12);
        fg = kRed;
        break;
      default:
        bg = kOrange.withValues(alpha: 0.12);
        fg = kOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
