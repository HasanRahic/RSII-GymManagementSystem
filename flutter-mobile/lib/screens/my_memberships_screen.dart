import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class MyMembershipsScreen extends StatefulWidget {
  const MyMembershipsScreen({super.key});

  @override
  State<MyMembershipsScreen> createState() => _MyMembershipsScreenState();
}

class _MyMembershipsScreenState extends State<MyMembershipsScreen> {
  List<UserMembership> _memberships = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await MembershipService.getMyMemberships();
      if (!mounted) return;
      setState(() => _memberships = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String dt) {
    try {
      final d = DateTime.parse(dt);
      return DateFormat('dd.MM.yyyy').format(d);
    } catch (_) {
      return dt;
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return kGreen;
      case 1:
        return kRed;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja članarina'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _memberships.isEmpty
              ? const Center(child: Text('Nema aktivnih članarina'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _memberships.length,
                    itemBuilder: (ctx, i) {
                      final m = _memberships[i];
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
                              // Status badge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    m.planName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                        color:
                                          _statusColor(m.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _statusColor(m.status),
                                      ),
                                    ),
                                    child: Text(
                                      m.statusLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _statusColor(m.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Gym info
                              Row(
                                children: [
                                  const Icon(Icons.fitness_center,
                                      color: Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      m.gymName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Dates
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_formatDate(m.startDate)} - ${_formatDate(m.endDate)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Days remaining
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Preostalih dana',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      '${m.daysRemaining} dana',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Price
                              Text(
                                'Cijena: ${m.price.toStringAsFixed(2)} KM',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
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
