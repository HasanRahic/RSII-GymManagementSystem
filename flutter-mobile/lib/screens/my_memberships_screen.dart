import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';
import 'stripe_checkout_screen.dart';

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

  Future<bool> _launchStripeCheckout(String sessionUrl) async {
    if (!mounted) return false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StripeCheckoutScreen(checkoutUrl: sessionUrl),
      ),
    );
    return true;
  }

  Future<void> _trackPaymentStatus(int paymentId) async {
    if (paymentId <= 0) return;

    for (var i = 0; i < 12; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final result = await PaymentService.getPaymentStatus(paymentId);
        final rawStatus = result['status'];
        final status = '$rawStatus'.toLowerCase();
        final succeeded = rawStatus == 1 || status == 'succeeded';
        final failed = rawStatus == 2 || status == 'failed';

        if (succeeded) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Članarina #$paymentId je uspješno plaćena.'), backgroundColor: kGreen),
          );
          await _load();
          return;
        }

        if (failed) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plaćanje članarine #$paymentId nije uspjelo.'), backgroundColor: kRed),
          );
          return;
        }
      } catch (_) {
        // Ignore transient polling errors.
      }
    }
  }

  Future<void> _renewMembership(UserMembership membership) async {
    final discountCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Obnovi: ${membership.planName}'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Teretana: ${membership.gymName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Popust %',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (value == null) return 'Unesite broj';
                    if (value < 0 || value > 100) return 'Popust mora biti 0-100';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Obnova koristi isti plan i otvara novu aktivnu članarinu.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Obnovi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await PaymentService.createMembershipCheckout(
        membershipPlanId: membership.membershipPlanId,
        discountPercent: double.parse(discountCtrl.text.replaceAll(',', '.')),
      );

      final paymentId = result['paymentId'];
      final sessionUrl = result['sessionUrl'];
      final amount = result['amount'];

      if (sessionUrl != null && sessionUrl.toString().isNotEmpty) {
        final launched = await _launchStripeCheckout(sessionUrl.toString());
        if (!launched) {
          throw 'Ne mogu otvoriti checkout URL.';
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stripe checkout otvoren za ${membership.planName} (${(amount as num).toStringAsFixed(0)} KM).',
            ),
            backgroundColor: kGreen,
          ),
        );

        await _trackPaymentStatus(paymentId is int ? paymentId : int.tryParse('$paymentId') ?? 0);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stripe checkout nije dostupan.'),
            backgroundColor: kRed,
          ),
        );
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
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
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _renewMembership(m),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Obnovi ovu članarinu'),
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
