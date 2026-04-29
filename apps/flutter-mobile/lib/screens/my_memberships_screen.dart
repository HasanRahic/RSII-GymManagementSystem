import 'dart:async';

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
  int _pendingPaymentsCount = 0;
  Timer? _pendingPaymentsTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshPendingPaymentsCount();
    _pendingPaymentsTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _refreshPendingPaymentsCount();
    });
  }

  @override
  void dispose() {
    _pendingPaymentsTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPendingPaymentsCount() async {
    final pendingIds = await PaymentService.getPendingPaymentIds();
    if (!mounted) return;
    setState(() => _pendingPaymentsCount = pendingIds.length);
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

  Widget _skeletonMembershipCard() {
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
          Container(height: 18, width: 180, decoration: BoxDecoration(color: const Color(0xFFE9EEF7), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 10),
          Container(height: 12, width: 140, decoration: BoxDecoration(color: const Color(0xFFE9EEF7), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 10),
          Container(height: 12, width: 220, decoration: BoxDecoration(color: const Color(0xFFE9EEF7), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 16),
          Container(height: 42, decoration: BoxDecoration(color: const Color(0xFFE9EEF7), borderRadius: BorderRadius.circular(12))),
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
              child: const Icon(Icons.card_membership_outlined, size: 32, color: Color(0xFF657BE6)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nema članarina',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kupite plan ili obnovite postojeću članarinu da biste je ovdje vidjeli.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _launchStripeCheckout(String sessionUrl) async {
    if (!mounted) return false;
    final launched = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 90),
        reverseTransitionDuration: const Duration(milliseconds: 80),
        pageBuilder: (context, animation, secondaryAnimation) =>
            StripeCheckoutScreen(checkoutUrl: sessionUrl),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
    return launched ?? false;
  }

  Future<void> _trackPaymentStatus(int paymentId) async {
    if (paymentId <= 0) return;

    final finalStatus = await PaymentService.waitForFinalStatus(paymentId);
    if (!mounted) return;

    if (finalStatus == PaymentFinalStatus.succeeded) {
      await PaymentService.clearPendingPayment(paymentId);
      await _refreshPendingPaymentsCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Članarina #$paymentId je uspješno plaćena.'), backgroundColor: kGreen),
      );
      await _load();
      return;
    }

    if (finalStatus == PaymentFinalStatus.failed) {
      await PaymentService.clearPendingPayment(paymentId);
      await _refreshPendingPaymentsCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plaćanje članarine #$paymentId nije uspjelo.'), backgroundColor: kRed),
      );
      return;
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
      final parsedPaymentId = paymentId is int ? paymentId : int.tryParse('$paymentId') ?? 0;

      await PaymentService.markPendingPayment(parsedPaymentId);
      await _refreshPendingPaymentsCount();

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

        await _trackPaymentStatus(parsedPaymentId);
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

  Future<void> _cancelMembership(UserMembership membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Otkaži: ${membership.planName}'),
        content: Text(
          'Ova akcija će označiti članarinu kao otkazanu. Članarina će ostati vidljiva u historiji.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zadrži'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Otkaži članarinu'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await MembershipService.cancel(membership.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Članarina ${membership.planName} je otkazana.'),
          backgroundColor: kGreen,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    }
  }

  void _showMembershipDetails(UserMembership membership) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(membership.planName),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Teretana', membership.gymName),
              _detailLine('Status', membership.statusLabel),
              _detailLine('Početak', _formatDate(membership.startDate)),
              _detailLine('Kraj', _formatDate(membership.endDate)),
              _detailLine('Preostalo dana', '${membership.daysRemaining}'),
              _detailLine('Cijena', '${membership.price.toStringAsFixed(2)} KM'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja članarina'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: _pendingPaymentsCount > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFF8D6E00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'U obradi: $_pendingPaymentsCount uplata. Status će se automatski osvježiti.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D4C00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await _refreshPendingPaymentsCount();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Status uplata je osvježen.')),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6D4C00),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        child: const Text('Osvježi'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _skeletonMembershipCard(),
                _skeletonMembershipCard(),
              ],
            )
          : _memberships.isEmpty
              ? _emptyState()
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
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showMembershipDetails(m),
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('Detalji'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: m.status == 0 ? () => _cancelMembership(m) : null,
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text('Otkaži'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: kRed,
                                        side: const BorderSide(color: kRed),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
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
