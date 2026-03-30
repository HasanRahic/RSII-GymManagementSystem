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
                : _buildTable(),
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
              const DropdownMenuItem<int?>(value: null, child: Text('Sve teretane')),
              ..._gyms.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
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

  Widget _buildTable() {
    if (_rows.isEmpty) {
      return const Center(child: Text('Nema podataka za odabrani period.'));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Član')),
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
                        DataCell(Text(c.checkOutTime == null ? '-' : _fmtDt(c.checkOutTime!))),
                        DataCell(Text(c.durationMinutes == null ? 'Aktivan' : '${c.durationMinutes} min')),
                      ]),
                    )
                    .toList(),
              ),
            ),
          );
        },
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
          border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
