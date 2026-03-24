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
      final plans = await MembershipService.getPlans();
      final memberships = await MembershipService.getAllMemberships();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _memberships = memberships;
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: kPrimary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimary,
            tabs: const [
              Tab(text: 'Planovi'),
              Tab(text: 'Članarine'),
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

    // Group plans by gym
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              child: Text(
                gymName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
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
              itemBuilder: (ctx, j) => _PlanCard(plan: plansForGym[j]),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildMembershipsTab() {
    if (_memberships.isEmpty) {
      return const Center(child: Text('Nema aktivnih članarina.'));
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
              DataColumn(label: Text('Član')),
              DataColumn(label: Text('Teretana')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Početak')),
              DataColumn(label: Text('Istiek')),
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

// ─── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'bs');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: plan.isActive ? kGreen.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
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
              ],
            ),
            const SizedBox(height: 8),
            if (plan.description != null && plan.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  plan.description!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${plan.durationDays}d',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${fmt.format(plan.price)} KM',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

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
