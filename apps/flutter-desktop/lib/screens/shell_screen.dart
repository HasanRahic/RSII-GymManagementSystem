import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import 'dashboard_screen.dart';
import 'gyms_screen.dart';
import 'members_screen.dart';
import 'memberships_screen.dart';
import 'checkins_screen.dart';
import 'trainer_apps_screen.dart';
import 'reports_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selected = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.fitness_center_outlined, Icons.fitness_center, 'Teretane'),
    _NavItem(Icons.people_outline, Icons.people, 'Članovi'),
    _NavItem(Icons.credit_card_outlined, Icons.credit_card, 'Članarine'),
    _NavItem(Icons.check_circle_outline, Icons.check_circle, 'Check-in'),
    _NavItem(Icons.assignment_outlined, Icons.assignment, 'Zahtjevi trenera'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Izvještaji'),
  ];

  List<Widget> get _screens => [
    DashboardScreen(onOpenTrainerApps: () => setState(() => _selected = 5)),
    GymsScreen(),
    MembersScreen(),
    MembershipsScreen(),
    CheckInsScreen(),
    TrainerAppsScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: _selected,
            items: _navItems,
            user: auth.user!,
            onSelect: (i) => setState(() => _selected = i),
            onLogout: () async {
              await auth.logout();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _navItems[_selected].label),
                Expanded(
                  child: IndexedStack(
                    index: _selected,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selected;
  final List<_NavItem> items;
  final dynamic user;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selected,
    required this.items,
    required this.user,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: kSidebar,
      child: Column(
        children: [
          // Logo area
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GymAdmin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final isSelected = i == selected;
                return _SidebarItem(
                  icon: isSelected ? item.activeIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // User info + logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kPrimary,
                  child: Text(
                    _initialFor(user.firstName),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      const Text('Admin',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                  onPressed: onLogout,
                  tooltip: 'Odjava',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialFor(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '?';
    return text[0].toUpperCase();
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? kSidebarSel : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: isSelected ? kPrimary : Colors.white54, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
