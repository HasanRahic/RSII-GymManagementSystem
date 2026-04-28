import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenTrainerApps;

  const DashboardScreen({super.key, this.onOpenTrainerApps});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  List<CheckInModel> _recentCheckIns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final stats = await ReportService.getDashboard();
      final checkIns = await ReportService.getCheckInReport(
        from.toIso8601String(),
        now.toIso8601String(),
      );
      if (mounted) {
        setState(() {
          _stats = stats;
          _recentCheckIns = checkIns.take(20).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stats == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Učitaj ponovo'),
        ),
      );
    }

    final fmt = NumberFormat('#,##0.00', 'bs');
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(fmt),
            const SizedBox(height: 32),
            _buildRecentCheckIns(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(NumberFormat fmt) {
    final s = _stats!;
    final cards = [
      _StatData(
        'Ukupno članova',
        s.totalMembers.toString(),
        Icons.people,
        kPrimary,
      ),
      _StatData(
        'Aktivne članarine',
        s.activeMemberships.toString(),
        Icons.credit_card,
        kGreen,
      ),
      _StatData(
        'Check-in danas',
        s.totalCheckInsToday.toString(),
        Icons.check_circle,
        kOrange,
      ),
      _StatData(
        'Trenutna gužva',
        s.currentOccupancy.toString(),
        Icons.people_outline,
        kPurple,
      ),
      _StatData(
        'Prihod ovaj mj.',
        '${fmt.format(s.revenueThisMonth)} KM',
        Icons.attach_money,
        kTeal,
      ),
      _StatData(
        'Zahtjevi trenera',
        s.pendingTrainerApplications.toString(),
        Icons.assignment_outlined,
        kRed,
        onTap: widget.onOpenTrainerApps,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.4,
      ),
      itemCount: cards.length,
      itemBuilder: (ctx, i) => _StatCard(data: cards[i]),
    );
  }

  Widget _buildRecentCheckIns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nedavni check-ini (ovaj mjesec)',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _recentCheckIns.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Nema check-ina')),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Član')),
                              DataColumn(label: Text('Teretana')),
                              DataColumn(label: Text('Dolazak')),
                              DataColumn(label: Text('Odlazak')),
                              DataColumn(label: Text('Trajanje')),
                            ],
                            rows: _recentCheckIns.map((c) {
                              final checkIn = _fmtDt(c.checkInTime);
                              final checkOut =
                                  c.checkOutTime != null ? _fmtDt(c.checkOutTime!) : '-';
                              final dur = c.durationMinutes != null
                                  ? '${c.durationMinutes} min'
                                  : 'Aktivan';
                              return DataRow(cells: [
                                DataCell(Text(c.userFullName)),
                                DataCell(Text(c.gymName)),
                                DataCell(Text(checkIn)),
                                DataCell(Text(checkOut)),
                                DataCell(Text(dur,
                                    style: TextStyle(
                                        color: c.durationMinutes == null
                                            ? kGreen
                                            : null))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _fmtDt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatData(this.label, this.value, this.icon, this.color, {this.onTap});
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data.label,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(data.value,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
