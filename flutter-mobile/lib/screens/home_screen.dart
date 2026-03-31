import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import 'checkin_screen.dart';
import 'my_memberships_screen.dart';
import 'checkin_history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

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
      body: ListView(
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
                  'Dobrodosli',
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
          _QuickTile(
            icon: Icons.credit_card,
            title: 'Moja clanarina',
            subtitle: 'Pregled statusa i trajanja',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => const MyMembershipsScreen(),
              ),
            ),
          ),
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
