import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class CheckInHistoryScreen extends StatefulWidget {
  const CheckInHistoryScreen({super.key});

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  List<CheckInModel> _history = [];
  bool _loading = true;
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await CheckInService.getMyHistory();
      data.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      if (!mounted) return;
      setState(() => _history = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseLocal(String raw) => DateTime.tryParse(raw)?.toLocal();

  String _formatDateTime(String dt) {
    try {
      final d = DateTime.parse(dt).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(d);
    } catch (_) {
      return dt;
    }
  }

  String _monthLabel(DateTime value) {
    const months = [
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Juni',
      'Juli',
      'August',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  Widget _skeletonRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5ECF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 14,
            width: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                size: 32,
                color: Color(0xFF657BE6),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nema dolazaka',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kada napravite check-in, historija ce se ovdje automatski pojaviti.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5ECF6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final monthStart = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final monthEnd = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final countsByDay = <int, int>{};

    for (final item in _history) {
      final date = _parseLocal(item.checkInTime);
      if (date == null) continue;
      if (date.year == _displayMonth.year && date.month == _displayMonth.month) {
        countsByDay[date.day] = (countsByDay[date.day] ?? 0) + 1;
      }
    }

    final leadingEmpty = monthStart.weekday - 1;
    final totalSlots = leadingEmpty + monthEnd.day;
    final trailingEmpty = (7 - (totalSlots % 7)) % 7;
    const weekdays = ['Pon', 'Uto', 'Sri', 'Cet', 'Pet', 'Sub', 'Ned'];

    Color cellColor(int count) {
      if (count <= 0) return const Color(0xFFF3F6FC);
      if (count == 1) return const Color(0xFFDDF4E5);
      if (count == 2) return const Color(0xFF9FDEB7);
      return const Color(0xFF2DBB72);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _monthLabel(_displayMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekdays
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalSlots + trailingEmpty,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmpty || index >= leadingEmpty + monthEnd.day) {
                return const SizedBox.shrink();
              }

              final day = index - leadingEmpty + 1;
              final count = countsByDay[day] ?? 0;
              final isActive = count > 0;

              return Container(
                decoration: BoxDecoration(
                  color: cellColor(count),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF2DBB72)
                        : const Color(0xFFE5ECF6),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: count >= 2 ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    if (isActive)
                      Text(
                        '${count}x',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: count >= 2 ? Colors.white : const Color(0xFF2DBB72),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _historyCard(CheckInModel c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c.gymName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.isActive
                        ? kGreen.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.isActive ? kGreen : Colors.grey),
                  ),
                  child: Text(
                    c.isActive ? 'Aktivno' : 'Zavrseno',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: c.isActive ? kGreen : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.login, color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Ulazak: ${_formatDateTime(c.checkInTime)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (c.checkOutTime != null)
              Row(
                children: [
                  const Icon(Icons.logout, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Izlazak: ${_formatDateTime(c.checkOutTime!)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            if (c.durationMinutes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Trajanje: ${c.durationMinutes} minuta',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finishedVisits = _history.where((item) => item.durationMinutes != null).toList();
    final totalMinutes = finishedVisits.fold<int>(
      0,
      (sum, item) => sum + (item.durationMinutes ?? 0),
    );
    final weeklyAverage = _history.isEmpty ? 0 : (_history.length / 4).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Istorija dolazaka'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _skeletonRow(),
                _skeletonRow(),
                _skeletonRow(),
              ],
            )
          : _history.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _summaryCard(
                            'Ukupno dolazaka',
                            '${_history.length}',
                            'svi evidentirani check-in',
                          ),
                          const SizedBox(width: 10),
                          _summaryCard(
                            'Sedmicni prosjek',
                            '$weeklyAverage',
                            'gruba procjena',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _summaryCard(
                            'Ukupno minuta',
                            '$totalMinutes',
                            'zavrsene posjete',
                          ),
                          const SizedBox(width: 10),
                          _summaryCard(
                            'Aktivan check-in',
                            _history.any((e) => e.isActive) ? 'Da' : 'Ne',
                            'trenutni status',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildCalendarCard(),
                      const SizedBox(height: 14),
                      ..._history.map(_historyCard),
                    ],
                  ),
                ),
    );
  }
}
