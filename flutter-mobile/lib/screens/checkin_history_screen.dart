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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await CheckInService.getMyHistory();
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

  String _formatDateTime(String dt) {
    try {
      final d = DateTime.parse(dt);
      return DateFormat('dd.MM.yyyy HH:mm').format(d);
    } catch (_) {
      return dt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Istorija dolazaka'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('Nema dolazaka'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (ctx, i) {
                      final c = _history[i];
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
                              // Gym name + status
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.isActive
                                          ? kGreen.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: c.isActive ? kGreen : Colors.grey,
                                      ),
                                    ),
                                    child: Text(
                                      c.isActive ? 'Aktivno' : 'Završeno',
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
                              // Check-in time
                              Row(
                                children: [
                                  const Icon(Icons.login,
                                      color: Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ulazak: ${_formatDateTime(c.checkInTime)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Check-out time
                              if (c.checkOutTime != null)
                                Row(
                                  children: [
                                    const Icon(Icons.logout,
                                        color: Color(0xFF64748B), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Izlazak: ${_formatDateTime(c.checkOutTime!)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              // Duration
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
                                      const Icon(Icons.timer,
                                          color: Colors.orange, size: 18),
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
                    },
                  ),
                ),
    );
  }
}
