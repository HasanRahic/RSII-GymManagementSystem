import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  List<GymModel> _gyms = [];
  List<CheckInModel> _rows = [];
  double _revenue = 0;

  int? _gymId;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final gyms = await GymService.getAll();
      final revenue = await ReportService.getRevenue(
        _from.toIso8601String(),
        _to.toIso8601String(),
        gymId: _gymId,
      );
      final rows = await ReportService.getCheckInReport(
        _from.toIso8601String(),
        _to.toIso8601String(),
        gymId: _gymId,
      );
      if (!mounted) return;
      setState(() {
        _gyms = gyms;
        _revenue = revenue;
        _rows = rows;
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

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final activeNow = _rows.where((r) => r.checkOutTime == null).length;
    final finished = _rows.where((r) => r.durationMinutes != null).toList();
    final avgDuration = finished.isEmpty
        ? 0
        : (finished.map((e) => e.durationMinutes!).reduce((a, b) => a + b) /
                finished.length)
            .round();
    final groupedByDay = _buildDailySummary();
    final topGyms = _buildGymSummary();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          Row(
            children: [
              _KpiCard(
                label: 'Prihod',
                value: '${NumberFormat('#,##0.00', 'bs').format(_revenue)} KM',
                color: kTeal,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'Ukupno check-in',
                value: _rows.length.toString(),
                color: kPrimary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'Aktivni trenutno',
                value: activeNow.toString(),
                color: kGreen,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'Prosj. trajanje',
                value: '$avgDuration min',
                color: kOrange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(
                        child: Text('Nema podataka za odabrani period.'),
                      )
                    : ListView(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _ChartCard(
                                  title: 'Dnevni trend dolazaka',
                                  subtitle: 'Broj check-inova po danu u odabranom periodu',
                                  child: _buildCheckInChart(groupedByDay),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _ChartCard(
                                  title: 'Najaktivnije teretane',
                                  subtitle: 'Top lokacije po broju dolazaka',
                                  child: _buildTopGyms(topGyms),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ChartCard(
                                  title: 'Prosjecno trajanje',
                                  subtitle: 'Trajanje zavrsenih posjeta po danu',
                                  child: _buildDurationChart(groupedByDay),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _ChartCard(
                                  title: 'Sažetak perioda',
                                  subtitle: 'Brzi pregled aktivnosti i kapaciteta',
                                  child: _buildSummaryList(
                                    activeNow: activeNow,
                                    avgDuration: avgDuration,
                                    groupedByDay: groupedByDay,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTable(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<int?>(
            initialValue: _gymId,
            decoration: InputDecoration(
              labelText: 'Teretana',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sve teretane'),
              ),
              ..._gyms.map(
                (g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name)),
              ),
            ],
            onChanged: (v) => setState(() => _gymId = v),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickFrom,
          icon: const Icon(Icons.date_range_outlined, size: 18),
          label: Text('Od: ${DateFormat('dd.MM.yyyy').format(_from)}'),
        ),
        OutlinedButton.icon(
          onPressed: _pickTo,
          icon: const Icon(Icons.date_range_outlined, size: 18),
          label: Text('Do: ${DateFormat('dd.MM.yyyy').format(_to)}'),
        ),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.filter_alt_outlined),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
          ),
          label: const Text('Primijeni'),
        ),
      ],
    );
  }

  Map<DateTime, _DailyReportSummary> _buildDailySummary() {
    final daily = <DateTime, _DailyReportSummary>{};
    for (final row in _rows) {
      final parsed = DateTime.tryParse(row.checkInTime)?.toLocal();
      if (parsed == null) continue;
      final key = DateTime(parsed.year, parsed.month, parsed.day);
      final current = daily[key] ?? const _DailyReportSummary();
      daily[key] = current.copyWith(
        checkInCount: current.checkInCount + 1,
        totalDurationMinutes:
            current.totalDurationMinutes + (row.durationMinutes ?? 0),
        finishedVisits:
            current.finishedVisits + (row.durationMinutes == null ? 0 : 1),
      );
    }
    return Map.fromEntries(
      daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  List<_GymReportSummary> _buildGymSummary() {
    final gyms = <String, _GymReportSummary>{};
    for (final row in _rows) {
      final current = gyms[row.gymName] ??
          _GymReportSummary(gymName: row.gymName, checkInCount: 0, activeCount: 0);
      gyms[row.gymName] = _GymReportSummary(
        gymName: row.gymName,
        checkInCount: current.checkInCount + 1,
        activeCount: current.activeCount + (row.checkOutTime == null ? 1 : 0),
      );
    }
    final result = gyms.values.toList()
      ..sort((a, b) => b.checkInCount.compareTo(a.checkInCount));
    return result.take(5).toList();
  }

  Widget _buildCheckInChart(Map<DateTime, _DailyReportSummary> groupedByDay) {
    final entries = groupedByDay.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('Nema dovoljno podataka za grafikon.'));
    }

    final maxY = entries
        .map((entry) => entry.value.checkInCount.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 4 ? 4 : maxY + 1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Color(0xFFE2E8F0),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: entries.length > 8 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('dd.MM').format(entries[index].key),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < entries.length; i++)
                  FlSpot(i.toDouble(), entries[i].value.checkInCount.toDouble()),
              ],
              isCurved: true,
              color: kPrimary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: kPrimary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChart(Map<DateTime, _DailyReportSummary> groupedByDay) {
    final entries = groupedByDay.entries
        .where((entry) => entry.value.finishedVisits > 0)
        .toList();
    if (entries.isEmpty) {
      return const Center(
        child: Text('Trajanje ce biti dostupno nakon zavrsenih check-out zapisa.'),
      );
    }

    final barGroups = <BarChartGroupData>[];
    double maxY = 0;

    for (var i = 0; i < entries.length; i++) {
      final averageMinutes =
          entries[i].value.totalDurationMinutes / entries[i].value.finishedVisits;
      if (averageMinutes > maxY) {
        maxY = averageMinutes;
      }
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: averageMinutes,
              color: kOrange,
              width: 18,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          maxY: maxY < 30 ? 30 : maxY + 10,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Color(0xFFE2E8F0),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('dd.MM').format(entries[index].key),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildTopGyms(List<_GymReportSummary> gyms) {
    if (gyms.isEmpty) {
      return const Center(child: Text('Nema podataka za poredenje teretana.'));
    }

    return Column(
      children: [
        for (final gym in gyms) ...[
          _SummaryRow(
            label: gym.gymName,
            value: '${gym.checkInCount} dolazaka',
            caption: '${gym.activeCount} trenutno aktivno',
          ),
          if (gym != gyms.last) const Divider(height: 20),
        ],
      ],
    );
  }

  Widget _buildSummaryList({
    required int activeNow,
    required int avgDuration,
    required Map<DateTime, _DailyReportSummary> groupedByDay,
  }) {
    final dailyValues = groupedByDay.values.toList();
    final peak = dailyValues.isEmpty
        ? 0
        : dailyValues
            .map((value) => value.checkInCount)
            .reduce((a, b) => a > b ? a : b);
    final bestDay = groupedByDay.entries.isEmpty
        ? null
        : groupedByDay.entries.reduce(
            (a, b) =>
                a.value.checkInCount >= b.value.checkInCount ? a : b,
          );

    return Column(
      children: [
        _SummaryRow(
          label: 'Najprometniji dan',
          value: bestDay == null
              ? '-'
              : DateFormat('dd.MM.yyyy').format(bestDay.key),
          caption: bestDay == null
              ? 'Nema aktivnosti'
              : '${bestDay.value.checkInCount} check-inova',
        ),
        const Divider(height: 20),
        _SummaryRow(
          label: 'Maksimalni dnevni promet',
          value: '$peak',
          caption: 'najveci broj dolazaka u jednom danu',
        ),
        const Divider(height: 20),
        _SummaryRow(
          label: 'Aktivni clanovi sada',
          value: '$activeNow',
          caption: 'bez evidentiranog check-out-a',
        ),
        const Divider(height: 20),
        _SummaryRow(
          label: 'Prosjecno trajanje',
          value: '$avgDuration min',
          caption: 'samo zavrsene posjete',
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Clan')),
                    DataColumn(label: Text('Teretana')),
                    DataColumn(label: Text('Dolazak')),
                    DataColumn(label: Text('Odlazak')),
                    DataColumn(label: Text('Trajanje')),
                  ],
                  rows: _rows
                      .map(
                        (c) => DataRow(cells: [
                          DataCell(Text(c.userFullName)),
                          DataCell(Text(c.gymName)),
                          DataCell(Text(_fmtDt(c.checkInTime))),
                          DataCell(
                            Text(c.checkOutTime == null ? '-' : _fmtDt(c.checkOutTime!)),
                          ),
                          DataCell(
                            Text(
                              c.durationMinutes == null
                                  ? 'Aktivan'
                                  : '${c.durationMinutes} min',
                            ),
                          ),
                        ]),
                      )
                      .toList(),
                ),
              ),
            );
          },
        ),
      ),
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }
}

class _DailyReportSummary {
  final int checkInCount;
  final int totalDurationMinutes;
  final int finishedVisits;

  const _DailyReportSummary({
    this.checkInCount = 0,
    this.totalDurationMinutes = 0,
    this.finishedVisits = 0,
  });

  _DailyReportSummary copyWith({
    int? checkInCount,
    int? totalDurationMinutes,
    int? finishedVisits,
  }) {
    return _DailyReportSummary(
      checkInCount: checkInCount ?? this.checkInCount,
      totalDurationMinutes:
          totalDurationMinutes ?? this.totalDurationMinutes,
      finishedVisits: finishedVisits ?? this.finishedVisits,
    );
  }
}

class _GymReportSummary {
  final String gymName;
  final int checkInCount;
  final int activeCount;

  const _GymReportSummary({
    required this.gymName,
    required this.checkInCount,
    required this.activeCount,
  });
}
