import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_services.dart';
import 'checkin_history_screen.dart';
import 'checkin_screen.dart';
import 'my_memberships_screen.dart';
import 'trainer_application_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserMembership? _activeMembership;
  bool _loadingMembership = true;
  int _selectedIndex = 0;
  String _profileSection = 'Historija';
  int _membersInGym = 12;
  bool _isCheckedIn = false;
  int? _activeCheckInId;
  bool _checkInBusy = false;
  final TextEditingController _gymSearchCtrl = TextEditingController();
  bool _showTrainers = false;
  String _selectedCity = 'Svi gradovi';
  String? _selectedTrainingType;

  @override
  void initState() {
    super.initState();
    _loadMembership();
    _syncCheckInState();
  }

  @override
  void dispose() {
    _gymSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembership() async {
    setState(() => _loadingMembership = true);
    try {
      final membership = await MembershipService.getMyActiveMembership();
      if (!mounted) return;
      final fallbackCount = ((membership?.daysRemaining ?? 0) ~/ 2) + 6;
      setState(() {
        _activeMembership = membership;
        if (!_isCheckedIn) {
          _membersInGym = fallbackCount;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeMembership = null);
    } finally {
      if (mounted) setState(() => _loadingMembership = false);
    }
  }

  Future<void> _syncCheckInState() async {
    try {
      final history = await CheckInService.getMyHistory();
      final active = history.where((h) => h.isActive).toList();
      if (!mounted) return;
      if (active.isNotEmpty) {
        setState(() {
          _isCheckedIn = true;
          _activeCheckInId = active.first.id;
          _membersInGym += 1;
        });
      }
    } catch (_) {
      // Ignore startup sync errors to keep home screen responsive.
    }
  }

  Future<int> _resolveGymId() async {
    final gymName = _activeMembership?.gymName;
    if (gymName == null || gymName.trim().isEmpty) {
      return 1;
    }

    try {
      final gyms = await GymService.getAll();
      final matched = gyms.where((g) => g.name.toLowerCase() == gymName.toLowerCase()).toList();
      if (matched.isNotEmpty) {
        return matched.first.id;
      }
    } catch (_) {
      // Use fallback when gym lookup fails.
    }

    return 1;
  }

  Future<void> _toggleCheckIn() async {
    if (_checkInBusy) return;
    setState(() => _checkInBusy = true);

    try {
      if (_isCheckedIn && _activeCheckInId != null) {
        await CheckInService.checkOut(_activeCheckInId!);
        if (!mounted) return;
        setState(() {
          _isCheckedIn = false;
          _activeCheckInId = null;
          _membersInGym = (_membersInGym - 1).clamp(0, 10000);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uspješno ste se odjavili iz teretane.')),
        );
      } else {
        final gymId = await _resolveGymId();
        final checkIn = await CheckInService.checkIn(gymId);
        if (!mounted) return;
        setState(() {
          _isCheckedIn = true;
          _activeCheckInId = checkIn.id;
          _membersInGym += 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in uspješan. Dobrodošli!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _checkInBusy = false);
      }
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
      backgroundColor: const Color(0xFFF1F2F6),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4B79E7), Color(0xFF7654D8)],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'FitTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    _selectedIndex == 0
                        ? 'Pretraži teretane i trenere'
                        : _selectedIndex == 1
                            ? 'Najbolje teretane za tebe'
                            : _selectedIndex == 2
                                ? 'Napredak i treninzi'
                                : 'Moj profil',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMembership,
                child: _buildTabContent(context, user),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Početna'),
          NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment), label: 'Teretane'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Napredak'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, AuthResponse? user) {
    if (_loadingMembership && _selectedIndex != 3) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab(context, user);
      case 1:
        return _buildGymsTab();
      case 2:
        return _buildProgressTab();
      default:
        return _buildProfileTab(context, user);
    }
  }

  Widget _buildHomeTab(BuildContext context, AuthResponse? user) {
    final gymName = _activeMembership?.gymName ?? 'Iron Gym Sarajevo';
    final planName = _activeMembership?.planName ?? 'Bez aktivne članarine';
    final daysLeft = _activeMembership?.daysRemaining ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // === PREMIUM GYM CARD ===
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D72E6).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header sa gradijentom
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5D72E6), Color(0xFF7654D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💪', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gymName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Sarajevo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DBB72),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2DBB72).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 6,
                                height: 6,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Body sa stats i info
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _GymStatBox(
                            icon: '👥',
                            title: 'Član. čl. sada',
                            value: '$_membersInGym',
                            subtitle: 'osoba',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GymStatBox(
                            icon: '⏳',
                            title: 'Članarina',
                            value: '$daysLeft',
                            subtitle: 'dana',
                            isWarning: daysLeft < 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Working hours section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF5D72E6).withValues(alpha: 0.08),
                            const Color(0xFF7654D8).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF5D72E6).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⏰ Radno vrijeme',
                                style: TextStyle(
                                  color: Color(0xFF4A5568),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Ponedjeljak',
                                style: TextStyle(
                                  color: Color(0xFF20293C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5D72E6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '06:00 - 22:00',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _isCheckedIn
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF2DBB72),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _checkInBusy ? null : _toggleCheckIn,
                        icon: _checkInBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(_isCheckedIn ? Icons.logout : Icons.login),
                        label: Text(_isCheckedIn ? 'Izađi iz teretane' : 'Ušao sam u teretanu'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCheckedIn
                          ? 'Status: trenutno ste prijavljeni u teretani.'
                          : 'Klikni kada uđeš da se ažurira broj članova.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                planName,
                                style: const TextStyle(
                                  color: Color(0xFF20293C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (_activeMembership != null)
                                Text(
                                  '${_formatDate(_activeMembership!.startDate)} - ${_formatDate(_activeMembership!.endDate)}',
                                  style: const TextStyle(
                                    color: Color(0xFF8A94A8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Aktivna 📌',
                            style: TextStyle(
                              color: Color(0xFF5D72E6),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // === QUICK ACTION SECTION ===
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Brzi pristup',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20293C),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 1),
              child: Row(
                children: const [
                  Icon(Icons.apartment, size: 16, color: Color(0xFF5D72E6)),
                  SizedBox(width: 4),
                  Text(
                    'Sve teretane',
                    style: TextStyle(
                      color: Color(0xFF5D72E6),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Quick tile row 1
        Row(
          children: [
            Expanded(
              child: _PremiumQuickTile(
                icon: Icons.check_circle,
                iconColor: const Color(0xFF2DBB72),
                title: 'Check-in',
                subtitle: 'Brzi ulazak',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const CheckInScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumQuickTile(
                icon: Icons.card_membership,
                iconColor: const Color(0xFFFF6B6B),
                title: 'Članarina',
                subtitle: 'Pregled statusa',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const MyMembershipsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Quick tile row 2
        Row(
          children: [
            Expanded(
              child: _PremiumQuickTile(
                icon: Icons.history,
                iconColor: const Color(0xFF4ECDC4),
                title: 'Istorija',
                subtitle: 'Posjete',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const CheckInHistoryScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumQuickTile(
                icon: Icons.person_add,
                iconColor: const Color(0xFFFFD93D),
                title: 'Trener',
                subtitle: 'Zahtjev',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const TrainerApplicationScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const _SectionTitle(icon: '🛒', title: 'Shop'),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(
              child: _OfferCard(
                emoji: '🥤',
                title: 'Whey Protein',
                price: '89 KM',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _OfferCard(
                emoji: '👕',
                title: 'FitTrack Majica',
                price: '35 KM',
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        const _SectionTitle(icon: '💳', title: 'Članarine'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _MembershipOfferCard(emoji: '🗓️', title: 'Mjesečna', price: '50 KM'),
            _MembershipOfferCard(emoji: '🗓️', title: 'Tromjesečna', price: '135 KM'),
            _MembershipOfferCard(emoji: '📋', title: 'Polugodišnja', price: '250 KM'),
            _MembershipOfferCard(emoji: '🎯', title: 'Godišnja', price: '450 KM'),
          ],
        ),

        const SizedBox(height: 18),
        const _SectionTitle(icon: '🏋️', title: 'Grupni treninzi'),
        const SizedBox(height: 10),
        const _GroupTrainingTile(
          title: 'Pilates',
          schedule: 'Pon, Sri, Pet · 17:00',
        ),
        const SizedBox(height: 10),
        const _GroupTrainingTile(
          title: 'Yoga',
          schedule: 'Uto, Čet · 18:30',
        ),
        const SizedBox(height: 10),
        const _GroupTrainingTile(
          title: 'Mix Workout',
          schedule: 'Sva, Sub · 10:00',
        ),

        // === NEWS SECTION ===
        const Text(
          '📢 Novosti',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20293C),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B78E5),
                Color(0xFF7B52D7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B52D7).withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    '🔥',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Novi grupni treninzi!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Od sljedeće sedmice startujemo sa novim HIIT treninzima svakog utorka i četvrtka u 18h. Uključujemo vam prvi trening besplatno!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '05.12.2025',
                    style: TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Saznaj više',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGymsTab() {
    final search = _gymSearchCtrl.text.trim().toLowerCase();

    final List<_GymCardData> highly = [
      _GymCardData(
        name: 'FitZone Centar',
        city: 'Sarajevo, Centar',
        rating: '4.9',
        reviews: '342 recenzije',
        status: 'ONLINE',
        tags: const ['CrossFit', 'HIIT', 'Kardio', 'Bazen'],
        accent: const Color(0xFFF6A600),
      ),
      _GymCardData(
        name: 'Iron Gym Sarajevo',
        city: 'Sarajevo, Marijin Dvor',
        rating: '4.8',
        reviews: '289 recenzije',
        status: 'ONLINE',
        tags: const ['Yoga', 'Pilates', 'Utezi', 'Sauna'],
        accent: const Color(0xFFF6A600),
      ),
    ];

    final List<_GymCardData> recommended = [
      _GymCardData(
        name: 'Zen Fitness Studio',
        city: 'Sarajevo, Ilidža',
        rating: '4.6',
        reviews: '156 recenzija',
        status: 'OFFLINE',
        tags: const ['Yoga', 'Pilates', 'Meditacija'],
        accent: const Color(0xFF657BE6),
      ),
    ];

    final List<_GymCardData> other = [
      _GymCardData(
        name: 'PowerHouse Gym',
        city: 'Sarajevo, Novo Sarajevo',
        rating: '4.5',
        reviews: '134 recenzije',
        status: 'ONLINE',
        tags: const ['Utezi', 'Kardio', 'Funkcionalni'],
        accent: const Color(0xFF3BB76A),
      ),
      _GymCardData(
        name: 'Titan Fitness',
        city: 'Mostar, Centar',
        rating: '4.4',
        reviews: '98 recenzija',
        status: 'ONLINE',
        tags: const ['Kardio', 'HIIT', 'Utezi'],
        accent: const Color(0xFF3BB76A),
      ),
    ];

    bool matches(_GymCardData gym) {
      final cityMatches = _selectedCity == 'Svi gradovi' || gym.city.toLowerCase().contains(_selectedCity.toLowerCase());
      final typeMatches = _selectedTrainingType == null || gym.tags.any((t) => t.toLowerCase() == _selectedTrainingType!.toLowerCase());
      final searchMatches = search.isEmpty ||
          gym.name.toLowerCase().contains(search) ||
          gym.city.toLowerCase().contains(search) ||
          gym.tags.any((t) => t.toLowerCase().contains(search));
      return cityMatches && typeMatches && searchMatches;
    }

    final filteredHighly = highly.where(matches).toList();
    final filteredRecommended = recommended.where(matches).toList();
    final filteredOther = other.where(matches).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        TextField(
          controller: _gymSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Pretraži teretane i trenere...',
            prefixIcon: const Icon(Icons.search),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD9E2F2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD9E2F2)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'TIP PREGLEDA',
          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showTrainers = false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_showTrainers ? const Color(0xFF657BE6) : Colors.white,
                  foregroundColor: !_showTrainers ? Colors.white : const Color(0xFF657BE6),
                  side: BorderSide(
                    color: !_showTrainers ? const Color(0xFF657BE6) : const Color(0xFFD9E2F2),
                  ),
                ),
                icon: const Icon(Icons.apartment, size: 18),
                label: const Text('Teretane'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showTrainers = true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _showTrainers ? const Color(0xFF657BE6) : Colors.white,
                  foregroundColor: _showTrainers ? Colors.white : const Color(0xFF657BE6),
                  side: BorderSide(
                    color: _showTrainers ? const Color(0xFF657BE6) : const Color(0xFFD9E2F2),
                  ),
                ),
                icon: const Icon(Icons.person, size: 18),
                label: const Text('Treneri'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'GRAD',
          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9E2F2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCity,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Svi gradovi', child: Text('Svi gradovi')),
                DropdownMenuItem(value: 'Sarajevo', child: Text('Sarajevo')),
                DropdownMenuItem(value: 'Mostar', child: Text('Mostar')),
                DropdownMenuItem(value: 'Banja Luka', child: Text('Banja Luka')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCity = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'TIP TRENINGA',
          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Yoga', 'Pilates', 'Utezi', 'Kardio', 'CrossFit', 'HIIT']
              .map(
                (type) => ChoiceChip(
                  label: Text(type),
                  selected: _selectedTrainingType == type,
                  onSelected: (_) {
                    setState(() {
                      _selectedTrainingType = _selectedTrainingType == type ? null : type;
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2DBB72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎉 Postani trener!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Apliciraj i dijeli svoje znanje',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const TrainerApplicationScreen()),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2DBB72),
                ),
                child: const Text('Apliciraj'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_showTrainers) ...[
          const Text(
            '8 trenera',
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const _TrainerPreviewCard(
            name: 'Amir Hodžić',
            role: 'Yoga & Pilates instruktor',
          ),
          const SizedBox(height: 10),
          const _TrainerPreviewCard(
            name: 'Lejla Karić',
            role: 'HIIT i Kardio trener',
          ),
          const SizedBox(height: 10),
          const _TrainerPreviewCard(
            name: 'Haris Mujić',
            role: 'CrossFit trener',
          ),
        ] else ...[
        const _SectionTitle(icon: '⭐', title: 'Highly Recommended'),
        const SizedBox(height: 6),
        const Text('Najbolje ocijenjene teretane sa 4.5+ zvjezdica', style: TextStyle(color: Color(0xFF8A94A8))),
        const SizedBox(height: 12),
        if (filteredHighly.isEmpty)
          const Text('Nema rezultata za odabrane filtere.', style: TextStyle(color: Color(0xFF8A94A8)))
        else
          ...filteredHighly
              .map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GymCard(
                    name: g.name,
                    city: g.city,
                    rating: g.rating,
                    reviews: g.reviews,
                    status: g.status,
                    tags: g.tags,
                    accent: g.accent,
                  ),
                ),
              )
              ,
        const SizedBox(height: 18),
        const _SectionTitle(icon: '✨', title: 'Recommended For You'),
        const SizedBox(height: 6),
        const Text('Na osnovu vaših preferencija: Yoga, Pilates', style: TextStyle(color: Color(0xFF8A94A8))),
        const SizedBox(height: 12),
        if (filteredRecommended.isEmpty)
          const Text('Nema preporuka za trenutni filter.', style: TextStyle(color: Color(0xFF8A94A8)))
        else
          ...filteredRecommended
              .map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GymCard(
                    name: g.name,
                    city: g.city,
                    rating: g.rating,
                    reviews: g.reviews,
                    status: g.status,
                    tags: g.tags,
                    accent: g.accent,
                  ),
                ),
              )
              ,
        const SizedBox(height: 18),
        const _SectionTitle(icon: '🏙️', title: 'Ostale teretane'),
        const SizedBox(height: 6),
        const Text('Sve dostupne teretane u vašem gradu', style: TextStyle(color: Color(0xFF8A94A8))),
        const SizedBox(height: 12),
        if (filteredOther.isEmpty)
          const Text('Nema dodatnih teretana za ovaj izbor.', style: TextStyle(color: Color(0xFF8A94A8)))
        else
          ...filteredOther
              .map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GymCard(
                    name: g.name,
                    city: g.city,
                    rating: g.rating,
                    reviews: g.reviews,
                    status: g.status,
                    tags: g.tags,
                    accent: g.accent,
                  ),
                ),
              )
              ,
        ],
      ],
    );
  }

  Widget _buildProgressTab() {
    final daysRemaining = _activeMembership?.daysRemaining ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _TopCard(
          title: 'Napredak i treninzi',
          subtitle: 'Mjerite rutinu i pratite učinak',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _SmallMetric(title: 'Planirano', value: '12', subtitle: 'za ovaj mjesec')),
                  const SizedBox(width: 12),
                  Expanded(child: _SmallMetric(title: 'Ostvareno', value: '10', subtitle: 'do sada')),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: 10 / 12,
                  backgroundColor: const Color(0xFFD9E2F2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF657BE6)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '83% cilj postignut (10/12) · $daysRemaining dana aktivne članarine',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7A8598), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(icon: '🏋️', title: 'Nadolazeći treninzi'),
        const SizedBox(height: 10),
        const _ScheduleCard(title: 'Grupni trening - HIIT', schedule: 'Pon, Sri, Pet · 18:00 - 19:00', tag: 'GRUPNI'),
        const SizedBox(height: 10),
        const _ScheduleCard(title: 'Trening prsa i tricepsa', schedule: 'Ponedjeljak · 17:00 - 19:00', tag: 'LIČNI'),
        const SizedBox(height: 10),
        const _ScheduleCard(title: 'Leđa i core', schedule: 'Utorak · 19:00 - 20:00', tag: 'LIČNI'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const CheckInScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Dodaj novi trening'),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: '📊', title: 'Statistika dolazaka'),
        const SizedBox(height: 10),
        _TopCard(
          title: 'Decembar 2025',
          subtitle: 'Plan i ostvarenje',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _SmallMetric(title: 'Planirano', value: '12', subtitle: 'za ovaj mjesec')),
                  const SizedBox(width: 12),
                  Expanded(child: _SmallMetric(title: 'Ostvareno', value: '10', subtitle: 'do sada')),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: 10 / 12,
                  backgroundColor: const Color(0xFFD9E2F2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF3BB76A)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Odlično! Ostalo ti je još samo 2 treninga do mjesečnog cilja.'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: '🗓️', title: 'Historija treninga'),
        const SizedBox(height: 10),
        const _HistoryRow(date: '08.12.2025', value: '75 kg', delta: '0.5 kg'),
        const _HistoryRow(date: '01.12.2025', value: '75.5 kg', delta: '0.8 kg'),
        const _HistoryRow(date: '24.11.2025', value: '76.3 kg', delta: '0.3 kg'),
        const _HistoryRow(date: '17.11.2025', value: '76.6 kg', delta: '0.4 kg'),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context, AuthResponse? user) {
    final gymName = _activeMembership?.gymName ?? 'Iron Gym Sarajevo';
    final membershipRange = _activeMembership == null
        ? 'Nema aktivne članarine'
        : '${_formatDate(_activeMembership!.startDate)} - ${_formatDate(_activeMembership!.endDate)}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _TopCard(
          title: 'Moj profil',
          subtitle: 'Korisnički podaci i sažetak računa',
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.person, size: 46, color: Color(0xFF5D72E6)),
              ),
              const SizedBox(height: 14),
              Text(user?.fullName ?? 'Korisnik', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: const TextStyle(color: Color(0xFF7A8598))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _ProfileInfoBox(label: 'TERETANA', value: gymName)),
                  const SizedBox(width: 10),
                  Expanded(child: _ProfileInfoBox(label: 'ČLANARINA', value: membershipRange)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _ProfileInfoBox(label: 'ADRESA', value: 'Zmaja od Bosne 12')),
                  const SizedBox(width: 10),
                  Expanded(child: _ProfileInfoBox(label: 'TELEFON', value: '+387 62 123 456')),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit),
                label: const Text('Uredi profil'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SegmentButton(
                label: 'Historija',
                selected: _profileSection == 'Historija',
                onTap: () => setState(() => _profileSection = 'Historija'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                label: 'Billing',
                selected: _profileSection == 'Billing',
                onTap: () => setState(() => _profileSection = 'Billing'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                label: 'Badges',
                selected: _profileSection == 'Badges',
                onTap: () => setState(() => _profileSection = 'Badges'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_profileSection == 'Historija') ...[
          _HistoryCard(title: 'Mjesečna članarina', value: '50 KM', date: '01.11.2025'),
          const SizedBox(height: 10),
          _HistoryCard(title: 'Whey Protein 1kg', value: '89 KM', date: '28.10.2025'),
          const SizedBox(height: 10),
          _HistoryCard(title: 'FitTrack Majica', value: '35 KM', date: '15.09.2025'),
        ] else if (_profileSection == 'Billing') ...[
          _ProfileMetricGrid(
            items: const [
              _MetricItem(label: 'Ukupno narudžbi', value: '18'),
              _MetricItem(label: 'Ukupno plaćeno', value: '1.245 KM'),
              _MetricItem(label: 'Aktivna članarina', value: 'Da'),
              _MetricItem(label: 'Posjeta ovaj mjesec', value: '10'),
            ],
          ),
        ] else ...[
          _ProfileMetricGrid(
            items: const [
              _MetricItem(label: 'Prvi mjesec', value: 'Dobrodošao!'),
              _MetricItem(label: '3 zaredom', value: 'Streber'),
              _MetricItem(label: '50 treninga', value: 'Odlično!'),
              _MetricItem(label: 'VIP član', value: 'Zaključano'),
            ],
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const CheckInHistoryScreen()),
          ),
          icon: const Icon(Icons.history),
          label: const Text('Pogledaj istoriju dolazaka'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Odjava'),
        ),
      ],
    );
  }
}

class _GymStatBox extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String subtitle;
  final bool isWarning;

  const _GymStatBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFF1F0) : const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? const Color(0xFFFFDDD4) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7A8598),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isWarning ? const Color(0xFFFF6B6B) : const Color(0xFF5D72E6),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A94A8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumQuickTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PremiumQuickTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_PremiumQuickTile> createState() => _PremiumQuickTileState();
}

class _PremiumQuickTileState extends State<_PremiumQuickTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.iconColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF20293C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7A8598),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A3448),
          ),
        ),
      ],
    );
  }
}

class _GymCardData {
  final String name;
  final String city;
  final String rating;
  final String reviews;
  final String status;
  final List<String> tags;
  final Color accent;

  const _GymCardData({
    required this.name,
    required this.city,
    required this.rating,
    required this.reviews,
    required this.status,
    required this.tags,
    required this.accent,
  });
}

class _TrainerPreviewCard extends StatelessWidget {
  final String name;
  final String role;

  const _TrainerPreviewCard({
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Color(0xFF657BE6),
            child: Text('🧑‍🏫', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A3448),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFF657BE6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF657BE6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Profil'),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String price;

  const _OfferCard({
    required this.emoji,
    required this.title,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 92,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A3448),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFF5D72E6),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipOfferCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String price;

  const _MembershipOfferCard({
    required this.emoji,
    required this.title,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFF5D72E6),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTrainingTile extends StatelessWidget {
  final String title;
  final String schedule;

  const _GroupTrainingTile({
    required this.title,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💪 $title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A3448),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  schedule,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5D72E6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rezerviši'),
          ),
        ],
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  final String name;
  final String city;
  final String rating;
  final String reviews;
  final String status;
  final List<String> tags;
  final Color accent;

  const _GymCard({required this.name, required this.city, required this.rating, required this.reviews, required this.status, required this.tags, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x0E000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status == 'ONLINE' ? const Color(0xFF3BB76A) : const Color(0xFFE76F6F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(city, style: const TextStyle(color: Color(0xFF8A94A8))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('⭐ ⭐ ⭐ ⭐ ⭐', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(rating, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('($reviews)', style: const TextStyle(color: Color(0xFF8A94A8))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tag, style: const TextStyle(color: Color(0xFF75819A), fontWeight: FontWeight.w600)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Detalji'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF657BE6)),
                  onPressed: () {},
                  child: const Text('Učlani se'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _TopCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF2A3448))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF8A94A8))),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _SmallMetric({required this.title, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9AA4B2), fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF657BE6))),
          Text(subtitle, style: const TextStyle(color: Color(0xFF7A8598), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String title;
  final String schedule;
  final String tag;

  const _ScheduleCard({required this.title, required this.schedule, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 56,
            decoration: BoxDecoration(color: const Color(0xFF657BE6), borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(schedule, style: const TextStyle(color: Color(0xFF7A8598))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(999)),
            child: Text(tag, style: const TextStyle(color: Color(0xFF657BE6), fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String date;
  final String value;
  final String delta;

  const _HistoryRow({required this.date, required this.value, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Color(0xFF8A94A8))),
              ],
            ),
          ),
          Text(delta, style: const TextStyle(color: Color(0xFFE07D7D), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProfileInfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileInfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8A94A8), fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF657BE6) : Colors.white,
        foregroundColor: selected ? Colors.white : const Color(0xFF657BE6),
        side: BorderSide(color: selected ? const Color(0xFF657BE6) : const Color(0xFFD9E2F2)),
      ),
      child: Text(label),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final String value;
  final String date;

  const _HistoryCard({required this.title, required this.value, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Color(0xFF8A94A8))),
              ],
            ),
          ),
          Text(value, style: const TextStyle(color: Color(0xFF657BE6), fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});
}

class _ProfileMetricGrid extends StatelessWidget {
  final List<_MetricItem> items;

  const _ProfileMetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A94A8), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(item.value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        );
      },
    );
  }
}

