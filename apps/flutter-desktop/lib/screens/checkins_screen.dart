import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class CheckInsScreen extends StatefulWidget {
  const CheckInsScreen({super.key});

  @override
  State<CheckInsScreen> createState() => _CheckInsScreenState();
}

class _CheckInsScreenState extends State<CheckInsScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<GymModel> _gyms = [];
  List<CheckInModel> _checkIns = [];

  int? _gymId;
  DateTime _date = DateTime.now();
  String _search = '';

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
      final gyms = await GymService.getAll();
      final rows = await _fetchCheckIns(_gymId, _date);
      if (!mounted) return;
      setState(() {
        _gyms = gyms;
        _checkIns = rows;
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

  Future<List<CheckInModel>> _fetchCheckIns(int? gymId, DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    return ReportService.getCheckInReport(
      from.toIso8601String(),
      to.toIso8601String(),
      gymId: gymId,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  List<CheckInModel> get _filtered {
    if (_search.trim().isEmpty) return _checkIns;
    final q = _search.toLowerCase();
    return _checkIns.where((c) {
      return c.userFullName.toLowerCase().contains(q) ||
          c.gymName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final active = rows.where((r) => r.checkOutTime == null).length;
    final finished = rows.where((r) => r.durationMinutes != null).toList();
    final avgMinutes = finished.isEmpty
        ? 0
        : (finished.map((e) => e.durationMinutes!).reduce((a, b) => a + b) / finished.length).round();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricCard(label: 'Ukupno check-in', value: rows.length.toString(), color: kPrimary),
              const SizedBox(width: 12),
              _MetricCard(label: 'Aktivni sada', value: active.toString(), color: kGreen),
              const SizedBox(width: 12),
              _MetricCard(label: 'Prosj. trajanje', value: '$avgMinutes min', color: kOrange),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildTable(rows),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Pretraga po članu ili teretani...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int?>(
            initialValue: _gymId,
            decoration: InputDecoration(
              labelText: 'Teretana',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Sve teretane')),
              ..._gyms.map(
                (g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name)),
              )
            ],
            onChanged: (v) async {
              setState(() => _gymId = v);
              await _load();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(DateFormat('dd.MM.yyyy').format(_date)),
        ),
        IconButton(
          onPressed: _load,
          tooltip: 'Osvježi',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildTable(List<CheckInModel> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('Nema check-in zapisa za odabrane filtere.'));
    }

    return Card(
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
            DataColumn(label: Text('Dolazak')),
            DataColumn(label: Text('Odlazak')),
            DataColumn(label: Text('Trajanje')),
            DataColumn(label: Text('Status')),
          ],
          rows: rows
              .map(
                (c) => DataRow(cells: [
                  DataCell(Text(c.userFullName)),
                  DataCell(Text(c.gymName)),
                  DataCell(Text(_fmtDt(c.checkInTime))),
                  DataCell(Text(c.checkOutTime != null ? _fmtDt(c.checkOutTime!) : '-')),
                  DataCell(Text(c.durationMinutes != null ? '${c.durationMinutes} min' : '-')),
                  DataCell(_statusBadge(c.checkOutTime == null ? 'Aktivan' : 'Završen')),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _statusBadge(String label) {
    final active = label == 'Aktivan';
    final bg = active ? kGreen.withValues(alpha: 0.12) : kOrange.withValues(alpha: 0.12);
    final fg = active ? kGreen : kOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
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
