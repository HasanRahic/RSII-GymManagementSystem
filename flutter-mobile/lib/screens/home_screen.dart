import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_services.dart';
import 'checkin_history_screen.dart';
import 'checkin_screen.dart';
import 'my_memberships_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserMembership? _activeMembership;
  bool _loadingMembership = true;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    setState(() => _loadingMembership = true);
    try {
      final membership = await MembershipService.getMyActiveMembership();
      if (!mounted) return;
      setState(() => _activeMembership = membership);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeMembership = null);
    } finally {
      if (mounted) setState(() => _loadingMembership = false);
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Mobile'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Odjava',
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMembership,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dobrodošli',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullName ?? 'Korisnik',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user != null ? 'Uloga: ${user.roleLabel}' : '',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingMembership
                    ? const SizedBox(
                        height: 72,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _activeMembership == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aktivna članarina',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Trenutno nema aktivne članarine.',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => const MyMembershipsScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.credit_card),
                                label: const Text('Otvori članarine'),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: kGreen),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Aktivna članarina',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _activeMembership!.planName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _activeMembership!.gymName,
                                style: const TextStyle(color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatDate(_activeMembership!.startDate)} - ${_formatDate(_activeMembership!.endDate)}',
                                style: const TextStyle(color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_activeMembership!.daysRemaining} dana preostalo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: kGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_activeMembership!.price.toStringAsFixed(2)} KM',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),
            _QuickTile(
              icon: Icons.login,
              title: 'Check-in',
              subtitle: 'Brzi ulazak u teretanu',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const CheckInScreen(),
                ),
              ),
            ),
            _QuickTile(
              icon: Icons.credit_card,
              title: 'Moja članarina',
              subtitle: 'Pregled statusa i trajanja',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const MyMembershipsScreen(),
                ),
              ),
            ),
            _QuickTile(
              icon: Icons.history,
              title: 'Istorija dolazaka',
              subtitle: 'Pregled prethodnih posjeta',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const CheckInHistoryScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: kPrimary.withValues(alpha: 0.12),
            child: Icon(icon, color: kPrimary),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
