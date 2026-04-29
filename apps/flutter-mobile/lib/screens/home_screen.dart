import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/api_services.dart';
import 'checkin_history_screen.dart';
import 'checkin_screen.dart';
import 'my_memberships_screen.dart';
import 'stripe_checkout_screen.dart';
import 'trainer_application_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserMembership? _activeMembership;
  bool _hasActiveGroupTrainingAccess = false;
  bool _loadingMembership = true;
  bool _loadingCatalog = true;
  bool _loadingTrainingData = false;
  bool _trainingDataLoaded = false;
  int _selectedIndex = 1;
  String _profileSection = 'Historija';
  int _membersInGym = 12;
  bool _isCheckedIn = false;
  int? _activeCheckInId;
  bool _checkInBusy = false;
  final TextEditingController _gymSearchCtrl = TextEditingController();
  final TextEditingController _shopSearchCtrl = TextEditingController();
  bool _showTrainers = false;
  String _selectedCity = 'Svi gradovi';
  String? _selectedTrainingType;
  String _selectedShopCategory = 'Sve';
  int? _selectedShopGymId;
  List<GymModel> _gyms = [];
  List<MembershipPlanModel> _plans = [];
  List<TrainingSessionModel> _sessions = [];
  List<String> _cities = ['Svi gradovi'];
  List<TrainingTypeModel> _trainingTypeCatalog = [];
  List<String> _trainingTypes = [];
  final List<_ShopCartItem> _shopCart = [];
  final List<_ShopProduct> _shopProducts = const [
    _ShopProduct(
      title: 'Whey Protein',
      price: 89,
      emoji: '🥤',
      category: 'Suplementi',
      gymIds: [1],
    ),
    _ShopProduct(
      title: 'Creatine Monohydrate',
      price: 49,
      emoji: '⚗️',
      category: 'Suplementi',
      gymIds: [1, 2],
    ),
    _ShopProduct(
      title: 'FitZone Majica',
      price: 35,
      emoji: '👕',
      category: 'Odjeća',
      gymIds: [1],
    ),
    _ShopProduct(
      title: 'Power Resistance Band',
      price: 24,
      emoji: '🧵',
      category: 'Oprema',
      gymIds: [2],
    ),
    _ShopProduct(
      title: 'BCAA Recovery',
      price: 39,
      emoji: '💧',
      category: 'Suplementi',
      gymIds: [2, 3],
    ),
    _ShopProduct(
      title: 'Gym Shorts',
      price: 42,
      emoji: '🩳',
      category: 'Odjeća',
      gymIds: [2, 3],
    ),
    _ShopProduct(
      title: 'Muške Rukavice',
      price: 29,
      emoji: '🧤',
      category: 'Oprema',
      gymIds: [1, 3],
    ),
    _ShopProduct(
      title: 'Shaker 700ml',
      price: 15,
      emoji: '🧋',
      category: 'Oprema',
      gymIds: [1, 2, 3],
    ),
    _ShopProduct(
      title: 'Yoga Prostirka',
      price: 55,
      emoji: '🧘',
      category: 'Oprema',
      gymIds: [3],
    ),
    _ShopProduct(
      title: 'IronGym Pojas',
      price: 47,
      emoji: '🦾',
      category: 'Oprema',
      gymIds: [3],
    ),
  ];
  List<Map<String, dynamic>> _recentPayments = [];
  bool _loadingPayments = true;
  int _pendingPaymentsCount = 0;
  Timer? _pendingPaymentsTimer;
  final Set<int> _reservedSessionIds = <int>{};
  final Set<int> _reservationBusyIds = <int>{};
  bool _loadingProgressData = false;
  bool _progressDataLoaded = false;
  int? _reservationStateOwnerUserId;
  bool _loadingPaidGroupSchedule = true;
  List<TrainingSessionModel> _paidGroupSchedule = [];
  List<ProgressMeasurementModel> _measurements = [];
  List<UserBadgeModel> _badges = [];
  List<CheckInModel> _checkInHistory = [];
  List<TrainerProfileModel> _trainerProfiles = [];
  List<RecommendedGymModel> _recommendedGyms = [];
  bool _loadingDiscoveryData = false;
  String? _lastDiscoveryCacheKey;
  Timer? _discoveryDebounce;
  final PageStorageBucket _tabScrollBucket = PageStorageBucket();
  final List<_CustomTrainingEntry> _customTrainings = [];
  int? _customTrainingsOwnerUserId;
  String _billingTypeFilter = 'Sve';
  bool _billingSortNewestFirst = true;
  static const List<int> _sessionDurationOptions = [30, 90, 180, 365];
  Future<void>? _membershipRefreshTask;
  Future<void>? _catalogLoadTask;

  bool get _hasGymAccess =>
      _activeMembership != null || _hasActiveGroupTrainingAccess;

  int? get _membershipGymId {
    final gymName = _activeMembership?.gymName;
    if (gymName == null || gymName.isEmpty) return null;
    for (final gym in _gyms) {
      if (gym.name == gymName) return gym.id;
    }
    return null;
  }

  int? get _effectiveShopGymId {
    if (_selectedShopGymId != null &&
        _gyms.any((g) => g.id == _selectedShopGymId)) {
      return _selectedShopGymId;
    }

    final membershipGymId = _membershipGymId;
    if (membershipGymId != null) return membershipGymId;
    if (_reservedSessions.isNotEmpty) return _reservedSessions.first.gymId;
    if (_gyms.isNotEmpty) return _gyms.first.id;
    return null;
  }

  String get _effectiveShopGymName {
    final gymId = _effectiveShopGymId;
    if (gymId == null) return 'Odabrana teretana';
    final found = _gyms.where((gym) => gym.id == gymId);
    if (found.isNotEmpty) return found.first.name;
    return 'Odabrana teretana';
  }

  List<_CustomTrainingEntry> get _activeCustomTrainings =>
      _customTrainings.where((t) => !t.completed).toList();

  List<_CustomTrainingEntry> get _completedCustomTrainings {
    final items = _customTrainings.where((t) => t.completed).toList();
    items.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );
    return items;
  }

  String _customTrainingsStorageKey(int userId) =>
      'custom_trainings_v1_user_$userId';

  int? get _selectedTrainingTypeId {
    final selected = _selectedTrainingType?.trim().toLowerCase();
    if (selected == null || selected.isEmpty) return null;
    for (final item in _trainingTypeCatalog) {
      if (item.name.trim().toLowerCase() == selected) {
        return item.id;
      }
    }
    return null;
  }

  Map<String, dynamic> _customExerciseToJson(_CustomExerciseEntry exercise) => {
    'exerciseName': exercise.exerciseName,
    'weightKg': exercise.weightKg,
    'reps': exercise.reps,
  };

  _CustomExerciseEntry? _customExerciseFromJson(Map<String, dynamic> map) {
    final name = map['exerciseName']?.toString().trim() ?? '';
    final reps = map['reps']?.toString().trim() ?? '';
    final weightRaw = map['weightKg'];
    final weight = weightRaw is num
        ? weightRaw.toDouble()
        : double.tryParse(weightRaw?.toString() ?? '');

    if (name.isEmpty || reps.isEmpty || weight == null) return null;

    return _CustomExerciseEntry(
      exerciseName: name,
      weightKg: weight,
      reps: reps,
    );
  }

  Map<String, dynamic> _customTrainingToJson(_CustomTrainingEntry training) => {
    'id': training.id,
    'name': training.name,
    'details': training.details,
    'createdAt': training.createdAt.toIso8601String(),
    'completed': training.completed,
    'completedAt': training.completedAt?.toIso8601String(),
    'exercises': training.exercises
        .map((exercise) => _customExerciseToJson(exercise))
        .toList(),
  };

  _CustomTrainingEntry? _customTrainingFromJson(Map<String, dynamic> map) {
    final idRaw = map['id'];
    final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
    final name = map['name']?.toString().trim() ?? '';
    final details = map['details']?.toString().trim() ?? '';
    final createdAtRaw = map['createdAt']?.toString();
    final createdAt = createdAtRaw == null
        ? null
        : DateTime.tryParse(createdAtRaw);

    final exercisesRaw = map['exercises'];
    if (id == null || name.isEmpty || details.isEmpty || createdAt == null) {
      return null;
    }

    final exercises = <_CustomExerciseEntry>[];
    if (exercisesRaw is List) {
      for (final item in exercisesRaw) {
        if (item is! Map) continue;
        final parsedExercise = _customExerciseFromJson(
          Map<String, dynamic>.from(item),
        );
        if (parsedExercise != null) {
          exercises.add(parsedExercise);
        }
      }
    }

    if (exercises.isEmpty) {
      final legacyWeightRaw = map['weightKg'];
      final legacyWeight = legacyWeightRaw is num
          ? legacyWeightRaw.toDouble()
          : double.tryParse(legacyWeightRaw?.toString() ?? '');
      final legacyReps = map['reps']?.toString().trim() ?? '';

      if (legacyWeight != null && legacyReps.isNotEmpty) {
        exercises.add(
          _CustomExerciseEntry(
            exerciseName: name,
            weightKg: legacyWeight,
            reps: legacyReps,
          ),
        );
      }
    }

    if (exercises.isEmpty) return null;

    final completed = map['completed'] == true;
    final completedAtRaw = map['completedAt']?.toString();
    final completedAt = completedAtRaw == null
        ? null
        : DateTime.tryParse(completedAtRaw);

    return _CustomTrainingEntry(
      id: id,
      name: name,
      details: details,
      createdAt: createdAt,
      completed: completed,
      completedAt: completedAt,
      exercises: exercises,
    );
  }

  Future<void> _loadCustomTrainingsForCurrentUser() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _customTrainings.clear();
        _customTrainingsOwnerUserId = null;
      });
      return;
    }
    if (_customTrainingsOwnerUserId == user.id) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_customTrainingsStorageKey(user.id));

    final loaded = <_CustomTrainingEntry>[];
    if (payload != null && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) continue;
            final parsed = _customTrainingFromJson(
              Map<String, dynamic>.from(entry),
            );
            if (parsed != null) {
              loaded.add(parsed);
            }
          }
        }
      } catch (_) {
        // If persisted payload is corrupt, we ignore it and continue with empty state.
      }
    }

    if (!mounted) return;
    setState(() {
      _customTrainings
        ..clear()
        ..addAll(loaded);
      _customTrainingsOwnerUserId = user.id;
    });
  }

  Future<void> _saveCustomTrainingsForCurrentUser() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _customTrainings
          .map((training) => _customTrainingToJson(training))
          .toList(),
    );
    await prefs.setString(_customTrainingsStorageKey(user.id), encoded);

    _customTrainingsOwnerUserId = user.id;
  }

  Future<void> _loadReservationStateForCurrentUser({
    bool forceReload = false,
  }) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _reservedSessionIds.clear();
        _reservationStateOwnerUserId = null;
      });
      return;
    }

    if (!forceReload && _reservationStateOwnerUserId == user.id) return;

    try {
      final reservationIds =
          await TrainingSessionService.getMyReservationSessionIds();
      if (!mounted) return;
      setState(() {
        _reservedSessionIds
          ..clear()
          ..addAll(reservationIds);
        _reservationStateOwnerUserId = user.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reservedSessionIds.clear();
        _reservationStateOwnerUserId = user.id;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembership());
    unawaited(_loadCatalog());
    _syncCheckInState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 2) {
        _ensureTrainingDataLoaded();
      }
      if (_selectedIndex == 2 || _selectedIndex == 3) {
        _ensureProgressDataLoaded();
      }
      if (_selectedIndex == 3) {
        _ensureProfileDataLoaded();
      }
      unawaited(_refreshPendingPaymentsCount());
      unawaited(_resumePendingPayments());
      _pendingPaymentsTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_pendingPaymentsCount <= 0) return;
        unawaited(_refreshPendingPaymentsCount());
        unawaited(_resumePendingPayments());
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userId = Provider.of<AuthProvider>(context).user?.id;
    if (_customTrainingsOwnerUserId == userId &&
        _reservationStateOwnerUserId == userId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (userId == null) {
        setState(() {
          _customTrainings.clear();
          _customTrainingsOwnerUserId = null;
          _reservedSessionIds.clear();
          _reservationStateOwnerUserId = null;
        });
        return;
      }

      unawaited(_loadCustomTrainingsForCurrentUser());
      if (_trainingDataLoaded) {
        unawaited(_loadReservationStateForCurrentUser(forceReload: true));
      }
    });
  }

  Future<void> _refreshPendingPaymentsCount() async {
    final pendingIds = await PaymentService.getPendingPaymentIds();
    if (!mounted) return;
    final nextCount = pendingIds.length;
    if (_pendingPaymentsCount == nextCount) return;
    setState(() => _pendingPaymentsCount = nextCount);
  }

  @override
  void dispose() {
    _pendingPaymentsTimer?.cancel();
    _discoveryDebounce?.cancel();
    _gymSearchCtrl.dispose();
    _shopSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembership({bool silent = false}) {
    final activeTask = _membershipRefreshTask;
    if (activeTask != null) return activeTask;

    final task = _performMembershipLoad(silent: silent);
    _membershipRefreshTask = task;
    return task.whenComplete(() => _membershipRefreshTask = null);
  }

  Future<void> _performMembershipLoad({bool silent = false}) async {
    if (!silent && mounted && !_loadingMembership) {
      setState(() => _loadingMembership = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        MembershipService.getMyActiveMembership(),
        MembershipService.getMyMemberships(),
        MembershipService.getMyAccessStatus(),
      ]);
      final membership = results[0] as UserMembership?;
      final memberships = results[1] as List<UserMembership>;
      final accessStatus = results[2] as Map<String, dynamic>;
      final activeFromList = memberships.where((m) => m.status == 0).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      final resolvedMembership =
          membership ??
          (activeFromList.isNotEmpty ? activeFromList.first : null);
      final hasGroupTrainingAccess =
          accessStatus['hasActiveGroupTrainingAccess'] == true;

      if (!mounted) return;
      final fallbackCount = ((resolvedMembership?.daysRemaining ?? 0) ~/ 2) + 6;
      final nextHasGymAccess =
          resolvedMembership != null || hasGroupTrainingAccess;
      final nextSelectedIndex =
          !nextHasGymAccess && (_selectedIndex == 0 || _selectedIndex == 2)
          ? 1
          : nextHasGymAccess && _selectedIndex == 1
          ? 0
          : _selectedIndex;
      final membershipChanged =
          _activeMembership?.id != resolvedMembership?.id ||
          _activeMembership?.status != resolvedMembership?.status ||
          _activeMembership?.daysRemaining !=
              resolvedMembership?.daysRemaining ||
          _hasActiveGroupTrainingAccess != hasGroupTrainingAccess ||
          _selectedIndex != nextSelectedIndex ||
          (!_isCheckedIn && _membersInGym != fallbackCount);

      if (membershipChanged) {
        setState(() {
          _activeMembership = resolvedMembership;
          _hasActiveGroupTrainingAccess = hasGroupTrainingAccess;
          _selectedIndex = nextSelectedIndex;
          if (!_isCheckedIn) {
            _membersInGym = fallbackCount;
          }
        });
      }

      if (hasGroupTrainingAccess) {
        await _loadPaidGroupSchedule();
      } else {
        if (!mounted) return;
        if (_paidGroupSchedule.isNotEmpty) {
          setState(() => _paidGroupSchedule = []);
        }
        await NotificationService.syncSessionReminders(const []);
      }
    } catch (_) {
      if (!mounted) return;
      final hadMembershipState =
          _activeMembership != null ||
          _hasActiveGroupTrainingAccess ||
          _paidGroupSchedule.isNotEmpty;
      if (hadMembershipState) {
        setState(() {
          _activeMembership = null;
          _hasActiveGroupTrainingAccess = false;
          _paidGroupSchedule = [];
        });
      }
      await NotificationService.syncSessionReminders(const []);
    } finally {
      if (!silent && mounted && _loadingMembership) {
        setState(() => _loadingMembership = false);
      }
    }
  }

  Future<void> _loadCatalog() {
    final activeTask = _catalogLoadTask;
    if (activeTask != null) return activeTask;

    final task = _performCatalogLoad();
    _catalogLoadTask = task;
    return task.whenComplete(() => _catalogLoadTask = null);
  }

  Future<void> _performCatalogLoad() async {
    if (mounted && !_loadingCatalog) {
      setState(() => _loadingCatalog = true);
    }
    try {
      final results = await Future.wait([
        GymService.getAll(),
        MembershipService.getPlans(),
      ]);

      final gyms = results[0] as List<GymModel>;
      final plans = results[1] as List<MembershipPlanModel>;

      if (!mounted) return;
      final nextMembershipGymId = (() {
        final gymName = _activeMembership?.gymName;
        if (gymName == null || gymName.isEmpty) return null;
        for (final gym in gyms) {
          if (gym.name == gymName) return gym.id;
        }
        return null;
      })();
      final nextShopGymId = _selectedShopGymId == null
          ? nextMembershipGymId ?? (gyms.isNotEmpty ? gyms.first.id : null)
          : gyms.any((g) => g.id == _selectedShopGymId)
          ? _selectedShopGymId
          : (gyms.isNotEmpty ? gyms.first.id : null);

      final catalogChanged =
          _gyms.length != gyms.length ||
          _plans.length != plans.length ||
          _selectedShopGymId != nextShopGymId;

      if (catalogChanged) {
        setState(() {
          _gyms = gyms;
          _plans = plans;
          _selectedShopGymId = nextShopGymId;
        });
      } else {
        _gyms = gyms;
        _plans = plans;
      }
    } catch (_) {
      if (!mounted) return;
      if (_gyms.isNotEmpty || _plans.isNotEmpty) {
        setState(() {
          _gyms = [];
          _plans = [];
        });
      }
    } finally {
      if (mounted && _loadingCatalog) {
        setState(() => _loadingCatalog = false);
      }
    }
  }

  Future<void> _loadTrainingData() async {
    if (_loadingTrainingData || _trainingDataLoaded) return;

    setState(() => _loadingTrainingData = true);
    try {
      final results = await Future.wait([
        TrainingSessionService.getAll(),
        ReferenceService.getCities(),
        ReferenceService.getTrainingTypes(),
      ]);

      final sessions = results[0] as List<TrainingSessionModel>;
      final cities = results[1] as List<CityModel>;
      final trainingTypes = results[2] as List<TrainingTypeModel>;

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _trainingTypeCatalog = trainingTypes;
        _cities = ['Svi gradovi', ...cities.map((c) => c.name).toSet()];
        _trainingTypes = trainingTypes.map((t) => t.name).toList();
        if (!_cities.contains(_selectedCity)) {
          _selectedCity = 'Svi gradovi';
        }
        _trainingDataLoaded = true;
      });
      await _loadReservationStateForCurrentUser(forceReload: true);
      await _loadDiscoveryData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessions = [];
        _trainingTypeCatalog = [];
        _cities = ['Svi gradovi'];
        _trainingTypes = [];
        _trainerProfiles = [];
        _recommendedGyms = [];
        _trainingDataLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _loadingTrainingData = false);
    }
  }

  Future<void> _ensureTrainingDataLoaded({bool forceReload = false}) async {
    if (forceReload) {
      _trainingDataLoaded = false;
    }

    await _loadTrainingData();
  }

  void _scheduleDiscoveryRefresh() {
    _discoveryDebounce?.cancel();
    _discoveryDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadDiscoveryData());
    });
  }

  Future<void> _loadDiscoveryData({bool forceReload = false}) async {
    final requestKey =
        '${_selectedCity.trim()}|${_selectedTrainingTypeId ?? ''}|${_gymSearchCtrl.text.trim().toLowerCase()}';
    if (!forceReload && _lastDiscoveryCacheKey == requestKey) return;
    if (_loadingDiscoveryData) return;

    setState(() => _loadingDiscoveryData = true);
    try {
      final results = await Future.wait([
        TrainingSessionService.getRecommendedGyms(
          city: _selectedCity,
          trainingTypeId: _selectedTrainingTypeId,
        ),
        TrainingSessionService.getTrainerProfiles(
          city: _selectedCity,
          trainingTypeId: _selectedTrainingTypeId,
          search: _gymSearchCtrl.text.trim(),
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _recommendedGyms = results[0] as List<RecommendedGymModel>;
        _trainerProfiles = results[1] as List<TrainerProfileModel>;
        _lastDiscoveryCacheKey = requestKey;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendedGyms = [];
        _trainerProfiles = [];
        _lastDiscoveryCacheKey = requestKey;
      });
    } finally {
      if (mounted) setState(() => _loadingDiscoveryData = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadMembership(), _loadCatalog(), _syncCheckInState()]);

    if (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 2) {
      await _ensureTrainingDataLoaded(forceReload: true);
      await _loadPaidGroupSchedule();
      await _loadDiscoveryData(forceReload: true);
    }

    if (_selectedIndex == 2 || _selectedIndex == 3) {
      await _ensureProgressDataLoaded(forceReload: true);
    }

    if (_selectedIndex == 3) {
      await _ensureProfileDataLoaded(forceReload: true);
    }
  }

  Future<void> _ensureProfileDataLoaded({bool forceReload = false}) async {
    if (forceReload || _recentPayments.isEmpty) {
      await _loadPayments();
    }

    if (forceReload || _paidGroupSchedule.isEmpty) {
      await _loadPaidGroupSchedule();
    }

    if (forceReload || !_progressDataLoaded) {
      await _ensureProgressDataLoaded(forceReload: forceReload);
    }
  }

  Future<void> _loadPaidGroupSchedule() async {
    setState(() => _loadingPaidGroupSchedule = true);
    try {
      final schedule = await TrainingSessionService.getMyPaidGroupSchedule();
      if (!mounted) return;
      setState(() => _paidGroupSchedule = schedule);
      await NotificationService.syncSessionReminders(schedule);
    } catch (_) {
      if (!mounted) return;
      setState(() => _paidGroupSchedule = []);
      await NotificationService.syncSessionReminders(const []);
    } finally {
      if (mounted) setState(() => _loadingPaidGroupSchedule = false);
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _loadingPayments = true);
    try {
      final payments = await PaymentService.getMyPayments(take: 20);
      if (!mounted) return;
      setState(() => _recentPayments = payments);
    } catch (_) {
      if (!mounted) return;
      setState(() => _recentPayments = []);
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  Future<void> _ensureProgressDataLoaded({bool forceReload = false}) async {
    if (forceReload) {
      _progressDataLoaded = false;
    }

    if (_loadingProgressData || _progressDataLoaded) return;
    await _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() => _loadingProgressData = true);
    try {
      final results = await Future.wait([
        ProgressService.getMyMeasurements(),
        ProgressService.getMyBadges(),
        CheckInService.getMyHistory(),
      ]);

      final measurements = results[0] as List<ProgressMeasurementModel>;
      final badges = results[1] as List<UserBadgeModel>;
      final history = results[2] as List<CheckInModel>;

      measurements.sort((a, b) => a.date.compareTo(b.date));
      badges.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
      history.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

      if (!mounted) return;
      setState(() {
        _measurements = measurements;
        _badges = badges;
        _checkInHistory = history;
        _progressDataLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _measurements = [];
        _badges = [];
        _checkInHistory = [];
        _progressDataLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _loadingProgressData = false);
    }
  }

  Future<void> _resumePendingPayments() async {
    final pendingIds = await PaymentService.getPendingPaymentIds();
    if (!mounted) return;
    if (pendingIds.isEmpty) {
      if (_pendingPaymentsCount != 0) {
        setState(() => _pendingPaymentsCount = 0);
      }
      return;
    }

    var confirmed = 0;
    var failed = 0;

    for (final paymentId in pendingIds.take(5)) {
      try {
        final result = await PaymentService.getPaymentStatus(paymentId);
        final status = PaymentService.parseFinalStatus(result['status']);
        if (status == PaymentFinalStatus.succeeded) {
          confirmed++;
          await PaymentService.clearPendingPayment(paymentId);
        } else if (status == PaymentFinalStatus.failed) {
          failed++;
          await PaymentService.clearPendingPayment(paymentId);
        }
      } catch (_) {
        // Keep payment pending if temporary status check fails.
      }
    }

    if (!mounted) return;
    await _refreshPendingPaymentsCount();
    if (!mounted) return;
    if (confirmed > 0 || failed > 0) {
      final message =
          'Ažurirano stanje uplata: uspješno $confirmed, neuspješno $failed.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadPayments();
    }
  }

  DateTime _sessionStartAt(TrainingSessionModel session) {
    final merged = DateTime.tryParse('${session.date}T${session.startTime}');
    if (merged != null) return merged;

    final dateOnly = DateTime.tryParse(session.date);
    if (dateOnly != null) return dateOnly;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<TrainingSessionModel> get _reservedSessions {
    final items = _sessions
        .where((s) => _reservedSessionIds.contains(s.id))
        .toList();
    items.sort((a, b) => _sessionStartAt(a).compareTo(_sessionStartAt(b)));
    return items;
  }

  Future<void> _toggleSessionReservation(TrainingSessionModel session) async {
    if (_reservationBusyIds.contains(session.id)) return;

    setState(() => _reservationBusyIds.add(session.id));

    try {
      if (_reservedSessionIds.contains(session.id)) {
        await TrainingSessionService.cancelReservation(session.id);
        if (!mounted) return;
        setState(() {
          _reservedSessionIds.remove(session.id);
          _sessions = _sessions
              .map(
                (s) => s.id == session.id
                    ? TrainingSessionModel(
                        id: s.id,
                        title: s.title,
                        description: s.description,
                        type: s.type,
                        date: s.date,
                        startTime: s.startTime,
                        endTime: s.endTime,
                        maxParticipants: s.maxParticipants,
                        currentParticipants: (s.currentParticipants - 1).clamp(
                          0,
                          s.maxParticipants,
                        ),
                        price: s.price,
                        isActive: s.isActive,
                        trainerId: s.trainerId,
                        trainerFullName: s.trainerFullName,
                        gymId: s.gymId,
                        gymName: s.gymName,
                        trainingTypeId: s.trainingTypeId,
                        trainingTypeName: s.trainingTypeName,
                      )
                    : s,
              )
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rezervacija za "${session.title}" je otkazana.'),
          ),
        );
      } else {
        final reserved = await TrainingSessionService.reserve(session.id);
        if (!mounted) return;
        setState(() {
          _reservedSessionIds.add(session.id);
          _sessions = _sessions
              .map((s) => s.id == session.id ? reserved : s)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uspješno ste rezervisali "${session.title}".'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rezervacija nije uspjela: ${_friendlyError(e)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _reservationBusyIds.remove(session.id));
      }
    }
  }

  String _paymentTypeLabel(dynamic rawType) {
    final t = '$rawType'.toLowerCase();
    if (rawType == 0 || t == 'membership') return 'Članarina';
    if (rawType == 1 || t == 'session') return 'Trening';
    if (rawType == 2 || t == 'shop') return 'Shop';
    return 'Uplata';
  }

  String _paymentStatusLabel(dynamic rawStatus) {
    final s = '$rawStatus'.toLowerCase();
    if (rawStatus == 0 || s == 'pending') return 'U obradi';
    if (rawStatus == 1 || s == 'succeeded') return 'Uspješno';
    if (rawStatus == 2 || s == 'failed') return 'Neuspješno';
    return 'Nepoznato';
  }

  String _formatIsoDate(dynamic rawDate) {
    if (rawDate == null) return '-';
    final parsed = DateTime.tryParse('$rawDate');
    if (parsed == null) return '$rawDate';
    final d = parsed.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd.$mm.$yyyy';
  }

  String _friendlyError(
    Object error, {
    String fallback = 'Došlo je do greške. Pokušajte ponovo.',
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    var cleaned = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('ApiException: ', '')
        .trim();

    if (cleaned.isEmpty) return fallback;
    if (cleaned.length > 220) cleaned = cleaned.substring(0, 220);
    return cleaned;
  }

  double? _parseWeightInput(String value) {
    final normalized = value.trim().replaceAll(',', '.').replaceAll(' ', '');
    return double.tryParse(normalized);
  }

  Widget _skeletonBox({
    double height = 16,
    double width = double.infinity,
    double radius = 12,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _TopCard(
          title: 'Učitavanje...',
          subtitle: 'Pripremamo sadržaj za prikaz',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBox(height: 18, width: 160),
              const SizedBox(height: 10),
              _skeletonBox(height: 14, width: 220),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _skeletonBox(height: 72)),
                  const SizedBox(width: 10),
                  Expanded(child: _skeletonBox(height: 72)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _skeletonBox(height: 72)),
                  const SizedBox(width: 10),
                  Expanded(child: _skeletonBox(height: 72)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _TopCard(
          title: 'Predlozi',
          subtitle: 'Katalog i članarine se učitavaju',
          child: Column(
            children: [
              _skeletonBox(height: 18, width: 180),
              const SizedBox(height: 12),
              _skeletonBox(height: 68),
              const SizedBox(height: 10),
              _skeletonBox(height: 68),
              const SizedBox(height: 10),
              _skeletonBox(height: 68),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyStateCard({
    required String title,
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECF6)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF657BE6)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  String _paymentReference(Map<String, dynamic> payment) {
    final id = payment['paymentId'] ?? payment['id'];
    return '#$id';
  }

  int _paymentId(Map<String, dynamic> payment) {
    final raw = payment['paymentId'] ?? payment['id'];
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? 0;
  }

  bool _isFailedPayment(Map<String, dynamic> payment) {
    final rawStatus = payment['status'];
    final status = '$rawStatus'.toLowerCase();
    return rawStatus == 2 || status == 'failed';
  }

  Future<void> _retryFailedPayment(Map<String, dynamic> payment) async {
    final originalPaymentId = _paymentId(payment);
    if (originalPaymentId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID uplate nije validan za ponovni pokušaj.'),
        ),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final result = await PaymentService.retryFailedPayment(originalPaymentId);
      final paymentId = result['paymentId'];
      final sessionUrl = result['sessionUrl'];
      final amount = result['amount'];
      final parsedPaymentId = paymentId is int
          ? paymentId
          : int.tryParse('$paymentId') ?? 0;

      if (sessionUrl == null || sessionUrl.toString().isEmpty) {
        throw 'Stripe checkout nije dostupan.';
      }

      final launched = await _launchStripeCheckoutForPayment(
        paymentId: parsedPaymentId,
        sessionUrl: sessionUrl.toString(),
      );
      if (!launched) {
        throw 'Ne mogu otvoriti checkout URL.';
      }

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ponovni checkout za uplatu #$originalPaymentId je pokrenut (${(amount as num).toStringAsFixed(0)} KM).',
          ),
        ),
      );

      await _trackPaymentStatus(parsedPaymentId, scaffoldMessenger);
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ponovni pokušaj uplate nije uspio: ${_friendlyError(e)}',
          ),
        ),
      );
    }
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final amount = ((payment['amount'] as num?) ?? 0).toDouble();
    final currency = (payment['currency'] ?? 'KM').toString();
    final type = _paymentTypeLabel(payment['type']);
    final status = _paymentStatusLabel(payment['status']);
    final createdAt = _formatIsoDate(payment['createdAt']);
    final completedAt = _formatIsoDate(payment['completedAt']);
    final sessionAccessDays = int.tryParse(
      '${payment['sessionAccessDays'] ?? ''}',
    );
    final sessionAccessUntil = _formatIsoDate(payment['sessionAccessUntil']);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detalji ${_paymentReference(payment)}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Vrsta', type),
              _detailLine('Status', status),
              _detailLine('Iznos', '${amount.toStringAsFixed(0)} $currency'),
              _detailLine('Kreirano', createdAt),
              _detailLine('Završeno', completedAt),
              if (sessionAccessDays != null && sessionAccessDays > 0)
                _detailLine('Trajanje pristupa', '$sessionAccessDays dana'),
              if (sessionAccessDays != null && sessionAccessDays > 0)
                _detailLine('Pristup do', sessionAccessUntil),
              _detailLine('ID', _paymentReference(payment)),
            ],
          ),
        ),
        actions: [
          if (_isFailedPayment(payment))
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _retryFailedPayment(payment);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  void _showAllPaymentsDialog(List<Map<String, dynamic>> payments) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sve transakcije'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: payments.isEmpty
              ? const Center(child: Text('Nema transakcija za prikaz.'))
              : ListView.separated(
                  itemCount: payments.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return InkWell(
                      onTap: () => _showPaymentDetails(payment),
                      borderRadius: BorderRadius.circular(16),
                      child: _HistoryCard(
                        title:
                            '${_paymentReference(payment)} ${_paymentTypeLabel(payment['type'])}',
                        value:
                            '${((payment['amount'] as num?) ?? 0).toStringAsFixed(0)} ${payment['currency'] ?? 'KM'}',
                        date:
                            '${_formatIsoDate(payment['createdAt'])} · ${_paymentStatusLabel(payment['status'])}',
                      ),
                    );
                  },
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

  Widget _paymentHistoryRow(Map<String, dynamic> payment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showPaymentDetails(payment),
          borderRadius: BorderRadius.circular(16),
          child: _HistoryCard(
            title:
                '${_paymentReference(payment)} ${_paymentTypeLabel(payment['type'])}',
            value:
                '${((payment['amount'] as num?) ?? 0).toStringAsFixed(0)} ${payment['currency'] ?? 'KM'}',
            date:
                '${_formatIsoDate(payment['createdAt'])} · ${_paymentStatusLabel(payment['status'])}',
          ),
        ),
        if (_isFailedPayment(payment))
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: TextButton.icon(
              onPressed: () => _retryFailedPayment(payment),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Pokušaj uplatu ponovo'),
            ),
          ),
      ],
    );
  }

  Future<void> _syncCheckInState() async {
    try {
      final history = await CheckInService.getMyHistory();
      final active = history.where((h) => h.isActive).toList();
      if (!mounted) return;
      if (active.isNotEmpty) {
        final activeCheckIn = active.first;
        setState(() {
          _isCheckedIn = true;
          _activeCheckInId = activeCheckIn.id;
          if (_membersInGym <= 0) {
            _membersInGym = 1;
          }
        });
      } else if (_isCheckedIn || _activeCheckInId != null) {
        setState(() {
          _isCheckedIn = false;
          _activeCheckInId = null;
        });
      }
    } catch (_) {
      // Ignore startup sync errors to keep home screen responsive.
    }
  }

  Future<int> _resolveGymId() async {
    final membershipGymId = _membershipGymId;
    if (membershipGymId != null) {
      return membershipGymId;
    }

    if (_gyms.isNotEmpty) {
      return _gyms.first.id;
    }

    final gymName = _activeMembership?.gymName;
    if (gymName == null || gymName.trim().isEmpty) {
      return 1;
    }

    try {
      final gyms = await GymService.getAll();
      final matched = gyms
          .where((g) => g.name.toLowerCase() == gymName.toLowerCase())
          .toList();
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
          const SnackBar(
            content: Text('Uspješno ste se odjavili iz teretane.'),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Greška: ${_friendlyError(e)}')));
    } finally {
      if (mounted) {
        setState(() => _checkInBusy = false);
      }
    }
  }

  double get _shopTotal =>
      _shopCart.fold(0, (sum, item) => sum + (item.price * item.quantity));

  int get _shopItemsCount =>
      _shopCart.fold(0, (sum, item) => sum + item.quantity);

  DateTime _paymentCreatedAt(Map<String, dynamic> payment) {
    final raw = payment['createdAt'];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse('$raw') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _matchesBillingType(Map<String, dynamic> payment) {
    if (_billingTypeFilter == 'Sve') return true;

    final typeLabel = _paymentTypeLabel(payment['type']);
    if (_billingTypeFilter == 'Članarine') {
      return typeLabel == 'Članarina';
    }

    return typeLabel == _billingTypeFilter;
  }

  List<Map<String, dynamic>> get _billingPayments {
    final filtered = _recentPayments
        .where(_matchesBillingType)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    filtered.sort((a, b) {
      final aDate = _paymentCreatedAt(a);
      final bDate = _paymentCreatedAt(b);
      if (_billingSortNewestFirst) {
        return bDate.compareTo(aDate);
      }
      return aDate.compareTo(bDate);
    });

    return filtered;
  }

  List<String> get _shopCategories {
    final categories =
        _filteredProductsByGym.map((p) => p.category).toSet().toList()..sort();
    return ['Sve', ...categories];
  }

  List<_ShopProduct> get _filteredProductsByGym {
    final gymId = _effectiveShopGymId;
    if (gymId == null) return _shopProducts;
    return _shopProducts
        .where((product) => product.gymIds.contains(gymId))
        .toList();
  }

  List<_ShopProduct> get _filteredShopProducts {
    final query = _shopSearchCtrl.text.trim().toLowerCase();
    return _filteredProductsByGym.where((product) {
      final categoryMatches =
          _selectedShopCategory == 'Sve' ||
          product.category == _selectedShopCategory;
      final queryMatches =
          query.isEmpty ||
          product.title.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList();
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

  Future<bool> _launchStripeCheckoutForPayment({
    required int paymentId,
    required String sessionUrl,
  }) async {
    if (paymentId > 0) {
      unawaited(() async {
        await PaymentService.markPendingPayment(paymentId);
        await _refreshPendingPaymentsCount();
      }());
    }

    final launched = await _launchStripeCheckout(sessionUrl);

    if (!launched && paymentId > 0) {
      await PaymentService.clearPendingPayment(paymentId);
      await _refreshPendingPaymentsCount();
    }

    return launched;
  }

  Future<void> _addShopItemToCart(String title, double price) async {
    setState(() {
      final index = _shopCart.indexWhere(
        (item) => item.title == title && item.price == price,
      );

      if (index >= 0) {
        final existing = _shopCart[index];
        _shopCart[index] = _ShopCartItem(
          title: existing.title,
          price: existing.price,
          quantity: existing.quantity + 1,
        );
      } else {
        _shopCart.add(_ShopCartItem(title: title, price: price, quantity: 1));
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title je dodan u korpu.'),
          duration: const Duration(milliseconds: 1200),
          action: SnackBarAction(label: 'Korpa', onPressed: _openShopCheckout),
        ),
      );
  }

  void _changeCartItemQuantity(_ShopCartItem item, int delta) {
    setState(() {
      final index = _shopCart.indexWhere(
        (x) => x.title == item.title && x.price == item.price,
      );
      if (index < 0) return;

      final current = _shopCart[index];
      final nextQty = current.quantity + delta;
      if (nextQty <= 0) {
        _shopCart.removeAt(index);
      } else {
        _shopCart[index] = _ShopCartItem(
          title: current.title,
          price: current.price,
          quantity: nextQty,
        );
      }
    });
  }

  void _removeCartItem(_ShopCartItem item) {
    setState(() {
      _shopCart.removeWhere(
        (x) => x.title == item.title && x.price == item.price,
      );
    });
  }

  void _clearCart() {
    setState(() => _shopCart.clear());
  }

  Future<void> _openShopCheckout() async {
    if (_shopCart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Korpa je prazna.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Shop korpa'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_shopCart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Korpa je prazna.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _shopCart
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.title} x${item.quantity} - ${(item.price * item.quantity).toStringAsFixed(0)} KM',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Smanji količinu',
                                      onPressed: () {
                                        _changeCartItemQuantity(item, -1);
                                        setLocal(() {});
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      tooltip: 'Povećaj količinu',
                                      onPressed: () {
                                        _changeCartItemQuantity(item, 1);
                                        setLocal(() {});
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      tooltip: 'Ukloni artikal',
                                      onPressed: () {
                                        _removeCartItem(item);
                                        setLocal(() {});
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                const Divider(height: 18),
                Text(
                  'Ukupno: ${_shopTotal.toStringAsFixed(0)} KM',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Napomena: plaćanje se obrađuje preko Stripe-a. Bit ćete preusmjereni na bezbedan checkout.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _shopCart.isEmpty
                  ? null
                  : () {
                      _clearCart();
                      setLocal(() {});
                    },
              child: const Text('Isprazni korpu'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zatvori'),
            ),
            FilledButton(
              onPressed: _shopCart.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Potvrdi narudžbu'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (confirmed != true) return;
    if (_shopCart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Korpa je prazna.')));
      return;
    }

    final payload = _shopCart
        .map(
          (item) => {
            'name': item.title,
            'unitPrice': item.price,
            'quantity': item.quantity,
          },
        )
        .toList();

    try {
      final result = await PaymentService.createShopOrder(items: payload);
      final paymentId = result['paymentId'];
      final sessionUrl = result['sessionUrl'];
      final amount = result['amount'];

      if (!mounted) return;

      // Save scaffold messenger reference before async operations
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Clear the cart immediately
      setState(() {
        _shopCart.clear();
      });

      // Open Stripe checkout URL
      if (sessionUrl != null && sessionUrl.isNotEmpty) {
        try {
          final parsedPaymentId = paymentId is int
              ? paymentId
              : int.tryParse('$paymentId') ?? 0;
          final launched = await _launchStripeCheckoutForPayment(
            paymentId: parsedPaymentId,
            sessionUrl: sessionUrl,
          );
          if (launched) {
            if (!mounted) return;
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Narudžba #$paymentId kreirana. Otvoren je Stripe checkout (${(amount as num).toStringAsFixed(0)} KM).',
                ),
              ),
            );

            // Webhook can take a few seconds; poll status so the user gets feedback in-app.
            await _trackPaymentStatus(parsedPaymentId, scaffoldMessenger);
          } else {
            throw 'Ne mogu otvoriti checkout URL.';
          }
        } catch (e) {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Greška pri otvaranju checkouta: ${_friendlyError(e)}',
              ),
            ),
          );
        }
      } else {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Narudžba #$paymentId je kreirana.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout nije uspio: ${_friendlyError(e)}')),
      );
    }
  }

  Future<void> _trackPaymentStatus(
    int paymentId,
    ScaffoldMessengerState scaffoldMessenger,
  ) async {
    if (paymentId <= 0) return;

    final finalStatus = await PaymentService.waitForFinalStatus(paymentId);
    if (!mounted) return;

    if (finalStatus == PaymentFinalStatus.succeeded) {
      await PaymentService.clearPendingPayment(paymentId);
      await _loadMembership();
      await _loadPayments();
      await _loadPaidGroupSchedule();
      await _refreshPendingPaymentsCount();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Uplata #$paymentId je uspješno potvrđena.')),
      );
      return;
    }

    if (finalStatus == PaymentFinalStatus.failed) {
      await PaymentService.clearPendingPayment(paymentId);
      await _refreshPendingPaymentsCount();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Uplata #$paymentId nije uspjela.')),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Uplata #$paymentId je još uvijek u obradi.')),
    );
  }

  Future<void> _purchaseMembershipPlan(MembershipPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kupi članarinu: ${plan.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teretana: ${plan.gymName}'),
              const SizedBox(height: 6),
              Text('Trajanje: ${plan.durationDays} dana'),
              const SizedBox(height: 6),
              Text(
                'Cijena: ${plan.price.toStringAsFixed(0)} KM',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if ((plan.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(plan.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kupi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final result = await PaymentService.createMembershipCheckout(
        membershipPlanId: plan.id,
      );
      final paymentId = result['paymentId'];
      final sessionUrl = result['sessionUrl'];
      final amount = result['amount'];

      if (sessionUrl != null && sessionUrl.toString().isNotEmpty) {
        final parsedPaymentId = paymentId is int
            ? paymentId
            : int.tryParse('$paymentId') ?? 0;

        final launched = await _launchStripeCheckoutForPayment(
          paymentId: parsedPaymentId,
          sessionUrl: sessionUrl.toString(),
        );
        if (!launched) {
          throw 'Ne mogu otvoriti checkout URL.';
        }

        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Članarina "${plan.name}" je poslana na Stripe checkout (${(amount as num).toStringAsFixed(0)} KM).',
            ),
          ),
        );

        await _trackPaymentStatus(parsedPaymentId, scaffoldMessenger);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Stripe checkout nije dostupan za članarinu "${plan.name}".',
            ),
          ),
        );
      }

      await _loadMembership();
      await _loadPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Proces kupovine članarine "${plan.name}" je pokrenut.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri plaćanju članarine: ${_friendlyError(e)}'),
        ),
      );
    }
  }

  Future<void> _purchaseGroupTraining(
    TrainingSessionModel session, {
    List<String> weekdays = const [],
  }) async {
    int selectedDurationDays = 30;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final selectedPrice = _sessionPriceForDuration(
            session.price,
            selectedDurationDays,
          );
          return AlertDialog(
            title: Text('Uplati grupni trening: ${session.title}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teretana: ${session.gymName}'),
                  const SizedBox(height: 6),
                  Text(
                    'Termin: ${session.startTime.substring(0, 5)} - ${session.endTime.substring(0, 5)}',
                  ),
                  if (weekdays.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Raspored: ${weekdays.join(' / ')}'),
                  ],
                  const SizedBox(height: 12),
                  const Text('Odaberi trajanje grupne članarine:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sessionDurationOptions
                        .map(
                          (days) => ChoiceChip(
                            label: Text(_durationLabel(days)),
                            selected: selectedDurationDays == days,
                            onSelected: (_) =>
                                setLocal(() => selectedDurationDays = days),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cijena: ${selectedPrice.toStringAsFixed(0)} KM',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Nakon uspješne uplate, grupni trening vrijedi kao članarina za odabrani period.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Otkaži'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Plati'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final result = await PaymentService.createSessionCheckout(
        trainingSessionId: session.id,
        sessionDurationDays: selectedDurationDays,
      );
      final paymentId = result['paymentId'];
      final sessionUrl = result['sessionUrl'];
      final amount = result['amount'];

      if (sessionUrl != null && sessionUrl.toString().isNotEmpty) {
        final parsedPaymentId = paymentId is int
            ? paymentId
            : int.tryParse('$paymentId') ?? 0;
        final launched = await _launchStripeCheckoutForPayment(
          paymentId: parsedPaymentId,
          sessionUrl: sessionUrl.toString(),
        );
        if (!launched) {
          throw 'Ne mogu otvoriti checkout URL.';
        }

        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Grupni trening "${session.title}" (${_durationLabel(selectedDurationDays)}) poslan je na Stripe checkout (${(amount as num).toStringAsFixed(0)} KM).',
            ),
          ),
        );

        await _trackPaymentStatus(parsedPaymentId, scaffoldMessenger);
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Stripe checkout nije dostupan za grupni trening.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri plaćanju grupnog treninga: ${_friendlyError(e)}',
          ),
        ),
      );
    }
  }

  Future<void> _openGymOffers(GymModel gym) async {
    final gymPlans =
        _plans.where((plan) => plan.gymId == gym.id && plan.isActive).toList()
          ..sort((a, b) => a.durationDays.compareTo(b.durationDays));

    final gymGroupOffers = _buildSessionOffers(
      _sessions.where((session) => session.gymId == gym.id).toList(),
    );

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.82;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DDEA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  gym.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${gym.cityName}, ${gym.countryName}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Članarine',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (gymPlans.isEmpty)
                  const Text(
                    'Ova teretana trenutno nema aktivnih planova članarine.',
                    style: TextStyle(color: Color(0xFF8A94A8)),
                  )
                else
                  ...gymPlans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${plan.durationDays} dana',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${plan.price.toStringAsFixed(0)} KM',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _purchaseMembershipPlan(plan);
                              },
                              child: const Text('Kupi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Grupni treninzi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (gymGroupOffers.isEmpty)
                  const Text(
                    'Ova teretana trenutno nema grupnih treninga za uplatu.',
                    style: TextStyle(color: Color(0xFF8A94A8)),
                  )
                else
                  ...gymGroupOffers.map(
                    (offer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.representative.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${offer.representative.startTime.substring(0, 5)} - ${offer.representative.endTime.substring(0, 5)}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  if (offer.weekdays.isNotEmpty)
                                    Text(
                                      'Raspored: ${offer.weekdays.join(' / ')}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              'od ${offer.representative.price.toStringAsFixed(0)} KM/mj',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _purchaseGroupTraining(
                                  offer.representative,
                                  weekdays: offer.weekdays,
                                );
                              },
                              child: const Text('Plati'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Napomena: Uplata grupnog treninga omogućava pristup aplikaciji i bez klasične članarine.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditProfileDialog(AuthProvider auth) async {
    final user = auth.user;
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final firstNameCtrl = TextEditingController(text: user.firstName);
    final lastNameCtrl = TextEditingController(text: user.lastName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phoneNumber ?? '');
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Uredi profil'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'Ime'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ime je obavezno'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Prezime'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Prezime je obavezno'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Email je obavezan';
                      if (!value.contains('@')) return 'Email nije validan';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (opcionalno)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => saving = true);
                      try {
                        await auth.updateProfile(
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profil je uspješno ažuriran.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        if (mounted) setLocal(() => saving = false);
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChangePasswordDialog(AuthProvider auth) async {
    final formKey = GlobalKey<FormState>();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Promjena lozinke'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Trenutna lozinka',
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Unesite trenutnu lozinku'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nova lozinka',
                    ),
                      validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Unesite novu lozinku';
                      }
                      if (v.length < 6) {
                        return 'Lozinka mora imati najmanje 6 znakova';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Potvrdite novu lozinku',
                    ),
                    validator: (v) =>
                        v != newCtrl.text ? 'Lozinke se ne podudaraju' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => saving = true);
                      try {
                        await auth.changePassword(
                          oldPassword: oldCtrl.text,
                          newPassword: newCtrl.text,
                          confirmPassword: confirmCtrl.text,
                        );
                        if (!mounted || !ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lozinka je uspješno promijenjena.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        if (mounted) setLocal(() => saving = false);
                      }
                    },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Promijeni'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda odjave'),
        content: const Text('Da li ste sigurni da se želite odjaviti?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da, odjavi me'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _saveCustomTrainingsForCurrentUser();
    await auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  DateTime? _tryParseDate(String raw) => DateTime.tryParse(raw)?.toLocal();

  String _formatMeasurementValue(double? value, {String suffix = ''}) {
    if (value == null) return '-';
    final normalized = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$normalized$suffix';
  }

  String _monthLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Maj',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  Future<void> _openAddMeasurementDialog() async {
    final dateCtrl = TextEditingController(
      text: _formatDate(DateTime.now().toIso8601String()),
    );
    final weightCtrl = TextEditingController();
    final bodyFatCtrl = TextEditingController();
    final chestCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    final hipsCtrl = TextEditingController();
    final armCtrl = TextEditingController();
    final legCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

    InputDecoration decoration(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());

    Future<void> saveMeasurement() async {
      if (formKey.currentState?.validate() != true) return;

      double? parseOptional(TextEditingController controller) {
        final text = controller.text.trim();
        if (text.isEmpty) return null;
        return _parseWeightInput(text);
      }

      try {
        await ProgressService.addMeasurement(
          date: selectedDate,
          weightKg: parseOptional(weightCtrl),
          bodyFatPercent: parseOptional(bodyFatCtrl),
          chestCm: parseOptional(chestCtrl),
          waistCm: parseOptional(waistCtrl),
          hipsCm: parseOptional(hipsCtrl),
          armCm: parseOptional(armCtrl),
          legCm: parseOptional(legCtrl),
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        await _ensureProgressDataLoaded(forceReload: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mjerenje je uspješno sačuvano.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mjerenje nije sačuvano: ${_friendlyError(e)}'),
          ),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj mjerenje'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: decoration('Datum').copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month_outlined),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked == null) return;
                          selectedDate = picked;
                          dateCtrl.text = _formatDate(picked.toIso8601String());
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration('Težina (kg)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: bodyFatCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration('Masno tkivo (%)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: chestCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration('Prsa (cm)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: waistCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration('Struk (cm)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: hipsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration('Bokovi (cm)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: armCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration('Ruka (cm)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: legCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: decoration('Noga (cm)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: decoration('Bilješke'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Odustani'),
          ),
          FilledButton.icon(
            onPressed: saveMeasurement,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  String _weekdayShortFromDate(String dateValue) {
    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) return '';
    const labels = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
    return labels[parsed.weekday - 1];
  }

  String _durationLabel(int days) {
    switch (days) {
      case 30:
        return '1 mjesec';
      case 90:
        return '3 mjeseca';
      case 180:
        return '6 mjeseci';
      case 365:
        return '12 mjeseci';
      default:
        return '$days dana';
    }
  }

  double _sessionPriceForDuration(double monthlyPrice, int durationDays) {
    switch (durationDays) {
      case 30:
        return monthlyPrice;
      case 90:
        return monthlyPrice * 3 * 0.93;
      case 180:
        return monthlyPrice * 6 * 0.88;
      case 365:
        return monthlyPrice * 12 * 0.80;
      default:
        return monthlyPrice;
    }
  }

  List<_SessionOffer> _buildSessionOffers(List<TrainingSessionModel> sessions) {
    final grouped = <String, List<TrainingSessionModel>>{};
    for (final session in sessions.where((s) => s.isGroup && s.isActive)) {
      final key =
          '${session.gymId}|${session.title}|${session.trainerId}|${session.startTime}|${session.endTime}';
      grouped.putIfAbsent(key, () => <TrainingSessionModel>[]).add(session);
    }

    final offers = grouped.values.map((items) {
      items.sort((a, b) => _sessionStartAt(a).compareTo(_sessionStartAt(b)));
      final primary = items.first;
      final weekdays = items
          .map((s) => _weekdayShortFromDate(s.date))
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      const weekdayOrder = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
      weekdays.sort(
        (a, b) => weekdayOrder.indexOf(a).compareTo(weekdayOrder.indexOf(b)),
      );

      return _SessionOffer(representative: primary, weekdays: weekdays);
    }).toList();

    offers.sort((a, b) {
      final byTitle = a.representative.title.compareTo(b.representative.title);
      if (byTitle != 0) return byTitle;
      return a.representative.startTime.compareTo(b.representative.startTime);
    });

    return offers;
  }

  Future<void> _openAddTrainingDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    var exerciseCount = 1;
    final exerciseNameCtrls = <TextEditingController>[TextEditingController()];
    final weightCtrls = <TextEditingController>[TextEditingController()];
    final repsCtrls = <TextEditingController>[TextEditingController()];

    void syncExerciseControllers(int count) {
      while (exerciseNameCtrls.length < count) {
        exerciseNameCtrls.add(TextEditingController());
        weightCtrls.add(TextEditingController());
        repsCtrls.add(TextEditingController());
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFFF1F2F6),
          title: const Text('Dodaj novi trening'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Naziv treninga',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Unesite naziv treninga.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: exerciseCount,
                      decoration: const InputDecoration(
                        labelText: 'Broj vježbi',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocal(() {
                          exerciseCount = value;
                          syncExerciseControllers(exerciseCount);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(exerciseCount, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4DCE8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vježba ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: exerciseNameCtrls[index],
                                decoration: const InputDecoration(
                                  labelText: 'Naziv vježbe',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    (value == null || value.trim().isEmpty)
                                    ? 'Unesite naziv vježbe.'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: weightCtrls[index],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Kilaža (kg)',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Unesite kilažu.';
                                        }
                                        return _parseWeightInput(value) == null
                                            ? 'Neispravan broj.'
                                            : null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: repsCtrls[index],
                                      keyboardType: TextInputType.text,
                                      decoration: const InputDecoration(
                                        labelText: 'Ponavljanja',
                                        hintText: 'npr. 10x3, 10-3 ili 10 3',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Unesite ponavljanja.';
                                        }
                                        final normalized = value
                                            .trim()
                                            .replaceAll(RegExp(r'\s+'), ' ');
                                        final valid = RegExp(
                                          r'^\d+(?:\s*[xX\-]\s*\d+|\s+\d+)?$',
                                        ).hasMatch(normalized);
                                        return valid
                                            ? null
                                            : 'Format: 10x3, 10-3 ili 10 3';
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: detailsCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Detalji treninga',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Dodajte detalje treninga.'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Otkaži'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Sačuvaj trening'),
            ),
          ],
        ),
      ),
    );

    try {
      if (saved == true) {
        final exercises = <_CustomExerciseEntry>[];
        for (var index = 0; index < exerciseCount; index++) {
          final parsedWeight = _parseWeightInput(weightCtrls[index].text);
          if (parsedWeight == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Neispravna kilaža za vježbu ${index + 1}.'),
                ),
              );
            }
            return;
          }

          exercises.add(
            _CustomExerciseEntry(
              exerciseName: exerciseNameCtrls[index].text.trim(),
              weightKg: parsedWeight,
              reps: repsCtrls[index].text.trim(),
            ),
          );
        }

        setState(() {
          _customTrainings.add(
            _CustomTrainingEntry(
              id: DateTime.now().microsecondsSinceEpoch,
              name: nameCtrl.text.trim(),
              exercises: exercises,
              details: detailsCtrl.text.trim(),
              createdAt: DateTime.now(),
            ),
          );
        });
        await _saveCustomTrainingsForCurrentUser();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Novi trening je dodan u Napredak.')),
        );
      }
    } finally {
      // Delay dispose to avoid disposing controllers while dialog widgets are still unmounting.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        detailsCtrl.dispose();
        for (final controller in exerciseNameCtrls) {
          controller.dispose();
        }
        for (final controller in weightCtrls) {
          controller.dispose();
        }
        for (final controller in repsCtrls) {
          controller.dispose();
        }
      });
    }
  }

  Future<void> _completeCustomTraining(_CustomTrainingEntry entry) async {
    setState(() {
      final idx = _customTrainings.indexWhere((t) => t.id == entry.id);
      if (idx == -1) return;
      _customTrainings[idx] = _customTrainings[idx].copyWith(
        completed: true,
        completedAt: DateTime.now(),
      );
    });
    await _saveCustomTrainingsForCurrentUser();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trening "${entry.name}" je prebačen u historiju.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AuthResponse?>(
      (auth) => auth.user,
    );

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
              child: PageStorage(
                bucket: _tabScrollBucket,
                child: RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: _buildTabContent(context, user),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        onDestinationSelected: (index) {
          final requiresMembership = index == 0 || index == 2;
          if (requiresMembership && !_hasGymAccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Za Početnu i Napredak prvo odaberite teretanu i aktivirajte članarinu ili grupni trening.',
                ),
              ),
            );
            setState(() => _selectedIndex = 1);
            return;
          }

          setState(() => _selectedIndex = index);
          if (index == 0 || index == 1 || index == 2) {
            _ensureTrainingDataLoaded();
            if (index == 2) {
              _loadPaidGroupSchedule();
            }
          }
          if (index == 3) {
            _ensureProfileDataLoaded();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Početna',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Teretane',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Napredak',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, AuthResponse? user) {
    if ((_loadingMembership || _loadingCatalog) && _selectedIndex != 3) {
      return _buildLoadingSkeleton();
    }

    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab(context, user);
      case 1:
        return _buildGymsTab();
      case 2:
        return _buildProgressTabV2();
      default:
        return _profileSection == 'Badges'
            ? _buildBadgesTab(context, user)
            : _buildProfileTab(context, user);
    }
  }

  Widget _buildHomeTab(BuildContext context, AuthResponse? user) {
    if (!_hasGymAccess) {
      return ListView(
        key: const PageStorageKey('home-tab-empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _emptyStateCard(
            title: 'Početna je dostupna nakon učlanjenja',
            message:
                'Odaberite teretanu i kupite članarinu ili grupni trening da otključate početnu stranicu vaše teretane.',
            icon: Icons.lock_outline,
            actionLabel: 'Idi na teretane',
            onAction: () => setState(() => _selectedIndex = 1),
          ),
        ],
      );
    }

    final gymName = _activeMembership?.gymName ?? 'Iron Gym Sarajevo';
    final planName = _activeMembership?.planName ?? 'Bez aktivne članarine';
    final daysLeft = _activeMembership?.daysRemaining ?? 0;
    final currentGymName = _activeMembership?.gymName;
    final scopedPlans = _plans.where((plan) {
      if (!plan.isActive) return false;
      if (currentGymName == null || currentGymName.isEmpty) return true;
      return plan.gymName == currentGymName;
    }).toList();

    scopedPlans.sort((a, b) {
      final byDuration = a.durationDays.compareTo(b.durationDays);
      if (byDuration != 0) return byDuration;
      return a.price.compareTo(b.price);
    });

    final byDuration = <int, MembershipPlanModel>{};
    for (final plan in scopedPlans) {
      byDuration.putIfAbsent(plan.durationDays, () => plan);
    }
    final activePlans = byDuration.values.take(4).toList();
    final groupSessionOffers = _buildSessionOffers(_sessions).take(3).toList();
    final now = DateTime.now();
    final upcomingPaidGroupSessions =
        _paidGroupSchedule
            .where(
              (session) => _sessionStartAt(
                session,
              ).isAfter(now.subtract(const Duration(minutes: 1))),
            )
            .toList()
          ..sort((a, b) => _sessionStartAt(a).compareTo(_sessionStartAt(b)));
    final nextPaidGroupSession = upcomingPaidGroupSessions.isNotEmpty
        ? upcomingPaidGroupSessions.first
        : null;

    String prettyTime(String value) =>
        value.length >= 5 ? value.substring(0, 5) : value;
    String countdownText(DateTime sessionStart) {
      final diff = sessionStart.difference(now);
      if (diff.isNegative) return 'u toku';
      final days = diff.inDays;
      final hours = diff.inHours.remainder(24);
      final minutes = diff.inMinutes.remainder(60);
      if (days > 0) return 'za $days dana';
      if (hours > 0) return 'za $hours h';
      return 'za $minutes min';
    }

    return ListView(
      key: const PageStorageKey('home-tab'),
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
                                color: const Color(
                                  0xFF2DBB72,
                                ).withValues(alpha: 0.3),
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

                    if (nextPaidGroupSession != null) ...[
                      _TopCard(
                        title: 'Najbliži plaćeni grupni trening',
                        subtitle:
                            '${nextPaidGroupSession.gymName} · ${countdownText(_sessionStartAt(nextPaidGroupSession))}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextPaidGroupSession.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatDate(nextPaidGroupSession.date)} · ${prettyTime(nextPaidGroupSession.startTime)} - ${prettyTime(nextPaidGroupSession.endTime)}',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Trener: ${nextPaidGroupSession.trainerFullName}',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

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
                          color: const Color(
                            0xFF5D72E6,
                          ).withValues(alpha: 0.15),
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
                        label: Text(
                          _isCheckedIn
                              ? 'Izađi iz teretane'
                              : 'Ušao sam u teretanu',
                        ),
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
                  MaterialPageRoute(
                    builder: (ctx) => const MyMembershipsScreen(),
                  ),
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
                  MaterialPageRoute(
                    builder: (ctx) => const CheckInHistoryScreen(),
                  ),
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
                  MaterialPageRoute(
                    builder: (ctx) => const TrainerApplicationScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const _SectionTitle(icon: '🛒', title: 'Shop'),
        const SizedBox(height: 10),
        if (_gyms.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.store_mall_directory_outlined,
                color: Color(0xFF64748B),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ponuda za teretanu: $_effectiveShopGymName',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _gyms.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final gym = _gyms[index];
                final selected = _effectiveShopGymId == gym.id;
                return ChoiceChip(
                  label: Text(gym.name),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedShopGymId = gym.id;
                      _selectedShopCategory = 'Sve';
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _shopSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Pretraži artikle (npr. protein, oprema, majica)...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _shopSearchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _shopSearchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _shopCategories
              .map(
                (category) => ChoiceChip(
                  label: Text(category),
                  selected: _selectedShopCategory == category,
                  onSelected: (_) =>
                      setState(() => _selectedShopCategory = category),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        if (_filteredShopProducts.isEmpty)
          _emptyStateCard(
            title: 'Nema artikala',
            message:
                'Nismo pronašli artikle za odabranu kategoriju ili upit pretrage.',
            icon: Icons.inventory_2_outlined,
            actionLabel: 'Resetuj filtere',
            onAction: () {
              setState(() {
                _selectedShopCategory = 'Sve';
                _shopSearchCtrl.clear();
              });
            },
          )
        else
          GridView.builder(
            itemCount: _filteredShopProducts.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.74,
            ),
            itemBuilder: (context, index) {
              final product = _filteredShopProducts[index];
              return _OfferCard(
                emoji: product.emoji,
                title: product.title,
                price: '${product.price.toStringAsFixed(0)} KM',
                subtitle: product.category,
                onBuy: () => _addShopItemToCart(product.title, product.price),
              );
            },
          ),
        if (_shopCart.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openShopCheckout,
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text(
                'Korpa ($_shopItemsCount) · ${_shopTotal.toStringAsFixed(0)} KM',
              ),
            ),
          ),
        ],

        const SizedBox(height: 18),
        const _SectionTitle(icon: '💳', title: 'Članarine'),
        const SizedBox(height: 10),
        if (activePlans.isEmpty)
          const Text(
            'Nema dostupnih članarina.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: activePlans
                .map(
                  (plan) => _MembershipOfferCard(
                    emoji: plan.durationDays >= 300
                        ? '🎯'
                        : plan.durationDays >= 180
                        ? '📋'
                        : '🗓️',
                    title: plan.name,
                    price: '${plan.price.toStringAsFixed(0)} KM',
                    onBuy: () => _purchaseMembershipPlan(plan),
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 18),
        const _SectionTitle(icon: '🏋️', title: 'Grupni treninzi'),
        const SizedBox(height: 10),
        if (_loadingTrainingData && !_trainingDataLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (groupSessionOffers.isEmpty)
          const Text(
            'Trenutno nema grupnih treninga.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ...groupSessionOffers.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GroupTrainingTile(
                title: offer.representative.title,
                schedule:
                    '${offer.weekdays.isEmpty ? 'Sedmično' : offer.weekdays.join(' / ')} · ${prettyTime(offer.representative.startTime)} - ${prettyTime(offer.representative.endTime)}',
                spotsLabel:
                    'Slobodno ${((offer.representative.maxParticipants - offer.representative.currentParticipants).clamp(0, offer.representative.maxParticipants))}/${offer.representative.maxParticipants}',
                isReserved: _reservedSessionIds.contains(
                  offer.representative.id,
                ),
                isBusy: _reservationBusyIds.contains(offer.representative.id),
                onReserveToggle: () =>
                    _toggleSessionReservation(offer.representative),
              ),
            ),
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
              colors: [Color(0xFF6B78E5), Color(0xFF7B52D7)],
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
                  Text('🔥', style: TextStyle(fontSize: 20)),
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
    if (_loadingTrainingData && !_trainingDataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = context.read<AuthProvider>().user;
    final search = _gymSearchCtrl.text.trim().toLowerCase();
    final selectedCity = _selectedCity;
    final selectedType = _selectedTrainingType?.trim().toLowerCase();
    final gymById = {for (final gym in _gyms) gym.id: gym};

    final sessionsByGym = <int, List<TrainingSessionModel>>{};
    for (final session in _sessions.where(
      (session) => session.isGroup && session.isActive,
    )) {
      sessionsByGym.putIfAbsent(session.gymId, () => []).add(session);
    }

    final trainerSessionMap = <int, List<TrainingSessionModel>>{};
    for (final session in _sessions.where((session) => session.isActive)) {
      trainerSessionMap
          .putIfAbsent(session.trainerId, () => <TrainingSessionModel>[])
          .add(session);
    }

    bool trainerMatches(_TrainerDirectoryData trainer) {
      final cityMatches =
          selectedCity == 'Svi gradovi' ||
          trainer.cityNames.any(
            (city) => city.toLowerCase().contains(selectedCity.toLowerCase()),
          );
      final typeMatches =
          selectedType == null ||
          trainer.specializations.any(
            (type) => type.toLowerCase() == selectedType,
          );
      final searchMatches =
          search.isEmpty ||
          trainer.name.toLowerCase().contains(search) ||
          trainer.headline.toLowerCase().contains(search) ||
          trainer.specializations.any(
            (type) => type.toLowerCase().contains(search),
          ) ||
          trainer.gymNames.any(
            (gymName) => gymName.toLowerCase().contains(search),
          );
      return cityMatches && typeMatches && searchMatches;
    }

    final trainerCards =
        trainerSessionMap.entries
            .map((entry) {
              final sessions = entry.value;
              final firstSession = sessions.first;
              final name = firstSession.trainerFullName.trim().isEmpty
                  ? 'Trener #${firstSession.trainerId}'
                  : firstSession.trainerFullName;
              final specializations = <String>{
                ...sessions
                    .map((session) => session.trainingTypeName.trim())
                    .where((name) => name.isNotEmpty),
              }.toList()..sort();
              final gymNames = <String>{
                ...sessions
                    .map((session) => session.gymName.trim())
                    .where((name) => name.isNotEmpty),
              }.toList()..sort();
              final cityNames = <String>{
                for (final session in sessions)
                  if (gymById[session.gymId] != null)
                    gymById[session.gymId]!.cityName,
              }.toList()..sort();
              final nextSessionAt = sessions
                  .map(_sessionStartAt)
                  .where((date) => date.isAfter(DateTime.now()))
                  .fold<DateTime?>(null, (current, value) {
                    if (current == null) return value;
                    return value.isBefore(current) ? value : current;
                  });
              final averageLoad = sessions.isEmpty
                  ? 0.0
                  : sessions.fold<double>(
                          0,
                          (sum, session) =>
                              sum +
                              (session.maxParticipants == 0
                                  ? 0
                                  : session.currentParticipants /
                                        session.maxParticipants),
                        ) /
                        sessions.length;
              final rating =
                  (4.0 + (averageLoad * 0.9) + (sessions.length >= 5 ? 0.1 : 0))
                      .clamp(4.0, 5.0)
                      .toStringAsFixed(1);

              return _TrainerDirectoryData(
                trainerId: firstSession.trainerId,
                name: name,
                headline: specializations.isEmpty
                    ? 'Personalni trener'
                    : '${specializations.take(2).join(' • ')} trener',
                rating: rating,
                sessionCount: sessions.length,
                groupSessionCount: sessions
                    .where((session) => session.isGroup)
                    .length,
                specializations: specializations,
                gymNames: gymNames,
                cityNames: cityNames,
                nextAvailableLabel: nextSessionAt == null
                    ? 'Nema buducih termina'
                    : '${nextSessionAt.day.toString().padLeft(2, '0')}.${nextSessionAt.month.toString().padLeft(2, '0')}.${nextSessionAt.year} u ${nextSessionAt.hour.toString().padLeft(2, '0')}:${nextSessionAt.minute.toString().padLeft(2, '0')}',
              );
            })
            .where(trainerMatches)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final backendTrainerCards =
        _trainerProfiles
            .map(
              (trainer) => _TrainerDirectoryData(
                trainerId: trainer.trainerId,
                name: trainer.fullName,
                headline: trainer.trainingTypes.isEmpty
                    ? 'Personalni trener'
                    : '${trainer.trainingTypes.take(2).join(' • ')} trener',
                rating: trainer.rating.toStringAsFixed(1),
                sessionCount: trainer.sessionCount,
                groupSessionCount: trainer.groupSessionCount,
                specializations: trainer.trainingTypes,
                gymNames: trainer.gymNames,
                cityNames: trainer.cityNames,
                nextAvailableLabel: _formatTrainerNextAvailable(
                  trainer.nextAvailableAt,
                ),
                biography: trainer.biography,
                experience: trainer.experience,
                certifications: trainer.certifications,
                availability: trainer.availability,
                email: trainer.email,
                phoneNumber: trainer.phoneNumber,
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final displayedTrainerCards = backendTrainerCards.isNotEmpty
        ? backendTrainerCards
        : trainerCards;

    List<String> tagsForGym(GymModel gym) {
      final tags = <String>{
        ...?sessionsByGym[gym.id]
            ?.map((session) => session.trainingTypeName)
            .where((name) => name.isNotEmpty),
      };
      if (tags.isEmpty) {
        tags.add(gym.isOpen ? 'Otvoreno' : 'Zatvoreno');
      }
      return tags.take(4).toList();
    }

    bool matchesGym(GymModel gym) {
      final cityMatches =
          selectedCity == 'Svi gradovi' ||
          gym.cityName.toLowerCase().contains(selectedCity.toLowerCase());
      final typeMatches =
          selectedType == null ||
          (sessionsByGym[gym.id]?.any(
                (session) =>
                    session.trainingTypeName.toLowerCase() == selectedType,
              ) ??
              false);
      final searchMatches =
          search.isEmpty ||
          gym.name.toLowerCase().contains(search) ||
          gym.address.toLowerCase().contains(search) ||
          gym.cityName.toLowerCase().contains(search) ||
          (sessionsByGym[gym.id]?.any(
                (session) =>
                    session.title.toLowerCase().contains(search) ||
                    session.trainingTypeName.toLowerCase().contains(search),
              ) ??
              false);
      return cityMatches && typeMatches && searchMatches;
    }

    final reservedAndPaidSessions = [
      ..._reservedSessions,
      ..._paidGroupSchedule,
    ];
    final preferredTypeWeights = <String, int>{};
    final visitedGymNames = <String, int>{};

    for (final session in reservedAndPaidSessions) {
      final typeName = session.trainingTypeName.trim().toLowerCase();
      if (typeName.isNotEmpty) {
        preferredTypeWeights[typeName] =
            (preferredTypeWeights[typeName] ?? 0) + 3;
      }
    }

    for (final history in _checkInHistory) {
      final gymName = history.gymName.trim().toLowerCase();
      if (gymName.isNotEmpty) {
        visitedGymNames[gymName] = (visitedGymNames[gymName] ?? 0) + 2;
      }
    }

    if (_selectedTrainingType != null &&
        _selectedTrainingType!.trim().isNotEmpty) {
      final selected = _selectedTrainingType!.trim().toLowerCase();
      preferredTypeWeights[selected] =
          (preferredTypeWeights[selected] ?? 0) + 5;
    }

    for (final training in _completedCustomTrainings) {
      for (final exercise in training.exercises) {
        final exerciseName = exercise.exerciseName.toLowerCase();
        if (exerciseName.contains('cardio') || exerciseName.contains('traka')) {
          preferredTypeWeights['kardio'] =
              (preferredTypeWeights['kardio'] ?? 0) + 1;
        }
        if (exerciseName.contains('bench') ||
            exerciseName.contains('squat') ||
            exerciseName.contains('deadlift') ||
            exerciseName.contains('teg')) {
          preferredTypeWeights['utezi'] =
              (preferredTypeWeights['utezi'] ?? 0) + 1;
        }
      }
    }

    double recommendationScore(GymModel gym) {
      double score = 0;
      final sessions = sessionsByGym[gym.id] ?? const <TrainingSessionModel>[];

      if (gym.isOpen) score += 2;
      if (_activeMembership?.gymName.toLowerCase() == gym.name.toLowerCase()) {
        score += 4;
      }
      if ((user?.cityName ?? '').trim().isNotEmpty &&
          gym.cityName.toLowerCase() == user!.cityName!.toLowerCase()) {
        score += 1.5;
      }
      if (visitedGymNames.containsKey(gym.name.toLowerCase())) {
        score += visitedGymNames[gym.name.toLowerCase()]!.toDouble();
      }

      for (final session in sessions) {
        final typeName = session.trainingTypeName.trim().toLowerCase();
        score += (preferredTypeWeights[typeName] ?? 0) * 1.25;
        if (typeName == selectedType) {
          score += 2;
        }
      }

      final occupancyRatio = gym.capacity == 0
          ? 0.0
          : gym.currentOccupancy / gym.capacity;
      if (occupancyRatio >= 0.35 && occupancyRatio <= 0.85) {
        score += 1.2;
      } else if (occupancyRatio < 0.2) {
        score += 0.5;
      }

      score += sessions.length * 0.15;
      return score;
    }

    final visibleGyms = _gyms.where(matchesGym).toList();
    final rankedGyms = [
      ...visibleGyms,
    ]..sort((a, b) => recommendationScore(b).compareTo(recommendationScore(a)));

    final highlyRecommended = rankedGyms.take(2).toList();

    final recommendedSource = rankedGyms.where(
      (gym) => !highlyRecommended.any((featured) => featured.id == gym.id),
    );
    final recommendedForYou = recommendedSource.isNotEmpty
        ? recommendedSource.take(2).toList()
        : rankedGyms
              .where(
                (gym) =>
                    !highlyRecommended.any((featured) => featured.id == gym.id),
              )
              .take(2)
              .toList();

    final otherGyms = visibleGyms
        .where(
          (gym) =>
              !highlyRecommended.any((featured) => featured.id == gym.id) &&
              !recommendedForYou.any((recommended) => recommended.id == gym.id),
        )
        .toList();

    final preferenceLabels = preferredTypeWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recommendationReason = selectedType != null
        ? 'Na osnovu odabranog tipa treninga: $_selectedTrainingType'
        : preferenceLabels.isNotEmpty
        ? 'Na osnovu vase aktivnosti: ${preferenceLabels.take(2).map((entry) => entry.key).join(', ')}'
        : _activeMembership != null
        ? 'Na osnovu vase aktivne clanarine i posjecenosti'
        : 'Na osnovu dostupnih termina i aktivnosti clanova';

    final recommendationByGymId = {
      for (final item in _recommendedGyms) item.gymId: item,
    };
    final backendRankedGyms =
        visibleGyms
            .where((gym) => recommendationByGymId.containsKey(gym.id))
            .toList()
          ..sort((a, b) {
            final left = recommendationByGymId[a.id]!.score;
            final right = recommendationByGymId[b.id]!.score;
            return right.compareTo(left);
          });
    final displayedHighlyRecommended = backendRankedGyms.isNotEmpty
        ? backendRankedGyms.take(2).toList()
        : highlyRecommended;
    final displayedRecommendedForYou = backendRankedGyms.length > 2
        ? backendRankedGyms.skip(2).take(2).toList()
        : recommendedForYou;

    String ratingFromGym(GymModel gym) {
      final ratio = gym.capacity == 0
          ? 0.0
          : (gym.currentOccupancy / gym.capacity);
      final rating = 3.5 + (ratio * 1.5);
      return rating.clamp(3.5, 5.0).toStringAsFixed(1);
    }

    String reviewsFromGym(GymModel gym) {
      return '${gym.currentOccupancy} trenutno u teretani';
    }

    Widget buildGymCard(GymModel gym) {
      return _GymCard(
        name: gym.name,
        city: '${gym.cityName}, ${gym.countryName}',
        rating: ratingFromGym(gym),
        reviews: reviewsFromGym(gym),
        status: gym.statusLabel,
        tags: tagsForGym(gym),
        accent: gym.isOpen ? const Color(0xFF3BB76A) : const Color(0xFFE76F6F),
        onDetails: () => _openGymOffers(gym),
        onJoin: () => _openGymOffers(gym),
      );
    }

    return ListView(
      key: const PageStorageKey('gyms-tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        TextField(
          controller: _gymSearchCtrl,
          onChanged: (_) {
            setState(() {});
            _scheduleDiscoveryRefresh();
          },
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
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showTrainers = false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_showTrainers
                      ? const Color(0xFF657BE6)
                      : Colors.white,
                  foregroundColor: !_showTrainers
                      ? Colors.white
                      : const Color(0xFF657BE6),
                  side: BorderSide(
                    color: !_showTrainers
                        ? const Color(0xFF657BE6)
                        : const Color(0xFFD9E2F2),
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
                  backgroundColor: _showTrainers
                      ? const Color(0xFF657BE6)
                      : Colors.white,
                  foregroundColor: _showTrainers
                      ? Colors.white
                      : const Color(0xFF657BE6),
                  side: BorderSide(
                    color: _showTrainers
                        ? const Color(0xFF657BE6)
                        : const Color(0xFFD9E2F2),
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
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
          ),
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
              items: _cities
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCity = value);
                _scheduleDiscoveryRefresh();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'TIP TRENINGA',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              (_trainingTypes.isNotEmpty
                      ? _trainingTypes
                      : const [
                          'Yoga',
                          'Pilates',
                          'Utezi',
                          'Kardio',
                          'CrossFit',
                          'HIIT',
                        ])
                  .map(
                    (type) => ChoiceChip(
                      label: Text(type),
                      selected: _selectedTrainingType == type,
                      onSelected: (_) {
                        setState(() {
                          _selectedTrainingType = _selectedTrainingType == type
                              ? null
                              : type;
                        });
                        _scheduleDiscoveryRefresh();
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
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => const TrainerApplicationScreen(),
                  ),
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
          Text(
            '${displayedTrainerCards.length} trenera',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingDiscoveryData && displayedTrainerCards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (displayedTrainerCards.isEmpty)
            const Text(
              'Nema trenera za odabrane filtere.',
              style: TextStyle(color: Color(0xFF8A94A8)),
            )
          else
            ...displayedTrainerCards.map(
              (trainer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TrainerDirectoryCard(
                  trainer: trainer,
                  onProfile: () => _openTrainerProfile(trainer),
                ),
              ),
            ),
        ] else ...[
          const _SectionTitle(icon: '⭐', title: 'Highly Recommended'),
          const SizedBox(height: 6),
          const Text(
            'Najbolje ocijenjene teretane sa 4.5+ zvjezdica',
            style: TextStyle(color: Color(0xFF8A94A8)),
          ),
          const SizedBox(height: 12),
          if (_loadingDiscoveryData && displayedHighlyRecommended.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (displayedHighlyRecommended.isEmpty)
            const Text(
              'Nema rezultata za odabrane filtere.',
              style: TextStyle(color: Color(0xFF8A94A8)),
            )
          else
            ...displayedHighlyRecommended.map(
              (gym) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildGymCard(gym),
              ),
            ),
          const SizedBox(height: 18),
          const _SectionTitle(icon: '✨', title: 'Recommended For You'),
          const SizedBox(height: 6),
          const Text(
            'Na osnovu vaših preferencija: Yoga, Pilates',
            style: TextStyle(color: Color(0xFF8A94A8)),
          ),
          const SizedBox(height: 12),
          Text(
            recommendationReason,
            style: const TextStyle(color: Color(0xFF8A94A8)),
          ),
          const SizedBox(height: 4),
          if (_loadingDiscoveryData && displayedRecommendedForYou.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (displayedRecommendedForYou.isEmpty)
            const Text(
              'Nema preporuka za trenutni filter.',
              style: TextStyle(color: Color(0xFF8A94A8)),
            )
          else
            ...displayedRecommendedForYou.map(
              (gym) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildGymCard(gym),
              ),
            ),
          const SizedBox(height: 18),
          const _SectionTitle(icon: '🏙️', title: 'Ostale teretane'),
          const SizedBox(height: 6),
          const Text(
            'Sve dostupne teretane u vašem gradu',
            style: TextStyle(color: Color(0xFF8A94A8)),
          ),
          const SizedBox(height: 12),
          if (otherGyms.isEmpty)
            const Text(
              'Nema dodatnih teretana za ovaj izbor.',
              style: TextStyle(color: Color(0xFF8A94A8)),
            )
          else
            ...otherGyms.map(
              (gym) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildGymCard(gym),
              ),
            ),
        ],
      ],
    );
  }

  String _formatTrainerNextAvailable(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return 'Nema buducih termina';
    }

    final parsed = DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) return rawValue;

    return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year} u ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openTrainerProfile(_TrainerDirectoryData trainer) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.9;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6DDEA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFF657BE6),
                          child: Icon(
                            Icons.fitness_center,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trainer.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trainer.headline,
                                style: const TextStyle(
                                  color: Color(0xFF657BE6),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '★ ${trainer.rating}',
                            style: const TextStyle(
                              color: Color(0xFF9A6700),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ProfileMetricGrid(
                      items: [
                        _MetricItem(
                          label: 'Ukupno sesija',
                          value: '${trainer.sessionCount}',
                        ),
                        _MetricItem(
                          label: 'Grupni treninzi',
                          value: '${trainer.groupSessionCount}',
                        ),
                        _MetricItem(
                          label: 'Teretane',
                          value: '${trainer.gymNames.length}',
                        ),
                        _MetricItem(
                          label: 'Gradovi',
                          value: '${trainer.cityNames.length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _TopCard(
                      title: 'Dostupnost',
                      subtitle: 'Sljedeci termin',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          trainer.nextAvailableLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TopCard(
                      title: 'Specijalizacije',
                      subtitle: 'Tipovi treninga koje trener vodi',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: trainer.specializations
                            .map(
                              (item) => Chip(
                                label: Text(item),
                                backgroundColor: const Color(0xFFE8EEFF),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF4F63D2),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TopCard(
                      title: 'Lokacije',
                      subtitle: 'Teretane i gradovi',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainer.gymNames.join(', '),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            trainer.cityNames.join(', '),
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if ((trainer.biography ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _TopCard(
                        title: 'Biografija',
                        subtitle: 'Predstavljenje trenera',
                        child: Text(
                          trainer.biography!,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    if ((trainer.experience ?? '').trim().isNotEmpty ||
                        (trainer.certifications ?? '').trim().isNotEmpty ||
                        (trainer.availability ?? '').trim().isNotEmpty ||
                        (trainer.email ?? '').trim().isNotEmpty ||
                        (trainer.phoneNumber ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _TopCard(
                        title: 'Dodatne informacije',
                        subtitle: 'Iskustvo i kontakt',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((trainer.experience ?? '').trim().isNotEmpty)
                              Text(
                                'Iskustvo: ${trainer.experience}',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  height: 1.5,
                                ),
                              ),
                            if ((trainer.certifications ?? '')
                                .trim()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Certifikati: ${trainer.certifications}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            if ((trainer.availability ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Dostupnost: ${trainer.availability}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            if ((trainer.email ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Email: ${trainer.email}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            if ((trainer.phoneNumber ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Telefon: ${trainer.phoneNumber}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildProgressTab() {
    if (_loadingTrainingData && !_trainingDataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final daysRemaining = _activeMembership?.daysRemaining ?? 0;
    final mergedGroupSessionsById = <int, TrainingSessionModel>{
      for (final s in _reservedSessions.where((s) => s.isGroup)) s.id: s,
      for (final s in _paidGroupSchedule.where((s) => s.isGroup)) s.id: s,
    };
    final reservedSessions = mergedGroupSessionsById.values.toList()
      ..sort((a, b) => _sessionStartAt(a).compareTo(_sessionStartAt(b)));

    final now = DateTime.now();
    final upcomingGroupSessions = reservedSessions
        .where(
          (session) => _sessionStartAt(
            session,
          ).isAfter(now.subtract(const Duration(minutes: 1))),
        )
        .toList();
    final reminderSessions = upcomingGroupSessions
        .where(
          (session) => _sessionStartAt(session).difference(now).inHours <= 48,
        )
        .take(3)
        .toList();

    String shortDate(String value) =>
        value.length >= 10 ? value.substring(0, 10) : value;
    String shortTime(String value) =>
        value.length >= 5 ? value.substring(0, 5) : value;
    String weekdayLabel(String value) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return 'Dan nije poznat';
      const labels = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
      return labels[parsed.weekday - 1];
    }

    String reminderLabel(DateTime start) {
      final diff = start.difference(now);
      if (diff.inMinutes <= 120) return 'Počinje uskoro';
      if (diff.inHours < 24) return 'Danas';
      return 'Sutra';
    }

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
                  Expanded(
                    child: _SmallMetric(
                      title: 'Planirano',
                      value: '12',
                      subtitle: 'za ovaj mjesec',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallMetric(
                      title: 'Ostvareno',
                      value: '10',
                      subtitle: 'do sada',
                    ),
                  ),
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
                style: const TextStyle(
                  color: Color(0xFF7A8598),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!_loadingPaidGroupSchedule && reminderSessions.isNotEmpty) ...[
          const _SectionTitle(icon: '⏰', title: 'Podsjetnici'),
          const SizedBox(height: 10),
          ...reminderSessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${weekdayLabel(session.date)}, ${shortDate(session.date)} · ${shortTime(session.startTime)} - ${shortTime(session.endTime)}',
                            style: const TextStyle(color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        reminderLabel(_sessionStartAt(session)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        const _SectionTitle(icon: '🏋️', title: 'Moji grupni termini'),
        const SizedBox(height: 10),
        if (_loadingPaidGroupSchedule)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (upcomingGroupSessions.isEmpty)
          const Text(
            'Nemate aktivnih grupnih termina. Uplatite grupni trening i termini će se ovdje automatski prikazati.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ...upcomingGroupSessions
              .take(8)
              .map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScheduleCard(
                    title: session.title,
                    schedule:
                        '${weekdayLabel(session.date)}, ${shortDate(session.date)} · ${shortTime(session.startTime)} - ${shortTime(session.endTime)}',
                    details:
                        '${session.gymName} · Trener: ${session.trainerFullName}',
                    tag: session.isGroup ? 'GRUPNI PLAĆENI' : 'LIČNI',
                  ),
                ),
              ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openAddTrainingDialog,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj novi trening'),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: '🧠', title: 'Planirani treninzi'),
        const SizedBox(height: 10),
        if (_activeCustomTrainings.isEmpty)
          const Text(
            'Nemate ručno dodanih treninga. Kliknite "Dodaj novi trening" da kreirate plan.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ..._activeCustomTrainings.map(
            (training) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CustomTrainingCard(
                title: training.name,
                exercises: training.exercises,
                details: training.details,
                createdAt: _formatDateTime(training.createdAt),
                onComplete: () => _completeCustomTraining(training),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: '🗓️', title: 'Historija treninga'),
        const SizedBox(height: 10),
        if (_completedCustomTrainings.isEmpty)
          const Text(
            'Historija treninga je prazna. Označite trening kao završen da se pojavi ovdje.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ..._completedCustomTrainings.map(
            (training) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TrainingHistoryCard(
                title: training.name,
                exercises: training.exercises,
                details: training.details,
                completedAt: _formatDateTime(
                  training.completedAt ?? training.createdAt,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressTabV2() {
    if ((_loadingTrainingData && !_trainingDataLoaded) ||
        (_loadingProgressData && !_progressDataLoaded)) {
      return const Center(child: CircularProgressIndicator());
    }

    final daysRemaining = _activeMembership?.daysRemaining ?? 0;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final checkInsThisMonth = _checkInHistory.where((item) {
      final date = _tryParseDate(item.checkInTime);
      return date != null && !date.isBefore(startOfMonth);
    }).toList();
    final weeklyVisits = <String, int>{};
    for (final item in _checkInHistory) {
      final date = _tryParseDate(item.checkInTime);
      if (date == null) continue;
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final key = '${monday.year}-${monday.month}-${monday.day}';
      weeklyVisits[key] = (weeklyVisits[key] ?? 0) + 1;
    }

    final monthlyGoal = 12;
    final completedThisMonth = checkInsThisMonth.length;
    final progressRatio = monthlyGoal == 0
        ? 0.0
        : (completedThisMonth / monthlyGoal).clamp(0.0, 1.0);
    final averageWeekly = weeklyVisits.isEmpty
        ? 0
        : (weeklyVisits.values.reduce((a, b) => a + b) / weeklyVisits.length)
              .round();
    final sortedMeasurements = [..._measurements]
      ..sort((a, b) => a.date.compareTo(b.date));
    final latestMeasurement = sortedMeasurements.isEmpty
        ? null
        : sortedMeasurements.last;
    final previousMeasurement = sortedMeasurements.length > 1
        ? sortedMeasurements[sortedMeasurements.length - 2]
        : null;
    final weightDelta =
        latestMeasurement?.weightKg != null &&
            previousMeasurement?.weightKg != null
        ? latestMeasurement!.weightKg! - previousMeasurement!.weightKg!
        : null;
    final latestWeightText = latestMeasurement?.weightKg == null
        ? '-'
        : '${latestMeasurement!.weightKg!.toStringAsFixed(1)} kg';
    final weightChangeText = weightDelta == null
        ? 'Dodajte barem 2 mjerenja'
        : '${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg od zadnjeg unosa';

    final mergedGroupSessionsById = <int, TrainingSessionModel>{
      for (final s in _reservedSessions.where((s) => s.isGroup)) s.id: s,
      for (final s in _paidGroupSchedule.where((s) => s.isGroup)) s.id: s,
    };
    final reservedSessions = mergedGroupSessionsById.values.toList()
      ..sort((a, b) => _sessionStartAt(a).compareTo(_sessionStartAt(b)));
    final upcomingGroupSessions = reservedSessions
        .where(
          (session) => _sessionStartAt(
            session,
          ).isAfter(now.subtract(const Duration(minutes: 1))),
        )
        .toList();
    final reminderSessions = upcomingGroupSessions
        .where(
          (session) => _sessionStartAt(session).difference(now).inHours <= 48,
        )
        .take(3)
        .toList();

    String shortDate(String value) =>
        value.length >= 10 ? value.substring(0, 10) : value;
    String shortTime(String value) =>
        value.length >= 5 ? value.substring(0, 5) : value;
    String weekdayLabel(String value) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return 'Dan nije poznat';
      const labels = ['Pon', 'Uto', 'Sri', 'Cet', 'Pet', 'Sub', 'Ned'];
      return labels[parsed.weekday - 1];
    }

    String reminderLabel(DateTime start) {
      final diff = start.difference(now);
      if (diff.inMinutes <= 120) return 'Pocinje uskoro';
      if (diff.inHours < 24) return 'Danas';
      return 'Sutra';
    }

    return ListView(
      key: const PageStorageKey('progress-tab-v2'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _TopCard(
          title: 'Napredak i treninzi',
          subtitle: 'Mjerite rutinu i pratite ucinak',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SmallMetric(
                      title: 'Planirano',
                      value: '$monthlyGoal',
                      subtitle: 'cilj za ovaj mjesec',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallMetric(
                      title: 'Ostvareno',
                      value: '$completedThisMonth',
                      subtitle: 'check-in ovog mjeseca',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SmallMetric(
                      title: 'Sedmicni prosjek',
                      value: '$averageWeekly',
                      subtitle: 'dolazaka po sedmici',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallMetric(
                      title: 'Tezina',
                      value: latestWeightText,
                      subtitle: weightChangeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progressRatio,
                  backgroundColor: const Color(0xFFD9E2F2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF657BE6)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(progressRatio * 100).round()}% cilj postignut ($completedThisMonth/$monthlyGoal) · $daysRemaining dana aktivne clanarine',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7A8598),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openAddMeasurementDialog,
                      icon: const Icon(Icons.monitor_weight_outlined),
                      label: const Text('Dodaj mjerenje'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const CheckInHistoryScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Dolasci'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _TopCard(
          title: 'Mjerenja',
          subtitle: sortedMeasurements.isEmpty
              ? 'Jos nema sacuvanih mjerenja'
              : 'Zadnji unos: ${_formatIsoDate(sortedMeasurements.last.date)}',
          child: sortedMeasurements.isEmpty
              ? const Text(
                  'Dodajte prvo mjerenje da biste pratili tezinu, obime i promjene kroz vrijeme.',
                  style: TextStyle(color: Color(0xFF64748B)),
                )
              : Column(
                  children: [
                    if (latestMeasurement != null)
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileInfoBox(
                              label: 'TEZINA',
                              value: _formatMeasurementValue(
                                latestMeasurement.weightKg,
                                suffix: ' kg',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfileInfoBox(
                              label: 'MASNO TKIVO',
                              value: _formatMeasurementValue(
                                latestMeasurement.bodyFatPercent,
                                suffix: '%',
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (latestMeasurement != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileInfoBox(
                              label: 'STRUK',
                              value: _formatMeasurementValue(
                                latestMeasurement.waistCm,
                                suffix: ' cm',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfileInfoBox(
                              label: 'PRSA',
                              value: _formatMeasurementValue(
                                latestMeasurement.chestCm,
                                suffix: ' cm',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Historija mjerenja',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...sortedMeasurements.reversed
                        .take(4)
                        .map(
                          (measurement) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HistoryCard(
                              title: _monthLabel(
                                _tryParseDate(measurement.date) ?? now,
                              ),
                              value:
                                  '${_formatMeasurementValue(measurement.weightKg, suffix: ' kg')} · ${_formatMeasurementValue(measurement.bodyFatPercent, suffix: '%')}',
                              date: _formatIsoDate(measurement.date),
                            ),
                          ),
                        ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        if (!_loadingPaidGroupSchedule && reminderSessions.isNotEmpty) ...[
          const _SectionTitle(icon: 'Clock', title: 'Podsjetnici'),
          const SizedBox(height: 10),
          ...reminderSessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${weekdayLabel(session.date)}, ${shortDate(session.date)} · ${shortTime(session.startTime)} - ${shortTime(session.endTime)}',
                            style: const TextStyle(color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        reminderLabel(_sessionStartAt(session)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const _SectionTitle(icon: 'Schedule', title: 'Moji grupni termini'),
        const SizedBox(height: 10),
        if (_loadingPaidGroupSchedule)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (upcomingGroupSessions.isEmpty)
          const Text(
            'Nemate aktivnih grupnih termina. Uplatite grupni trening i termini ce se ovdje automatski prikazati.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ...upcomingGroupSessions
              .take(8)
              .map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScheduleCard(
                    title: session.title,
                    schedule:
                        '${weekdayLabel(session.date)}, ${shortDate(session.date)} · ${shortTime(session.startTime)} - ${shortTime(session.endTime)}',
                    details:
                        '${session.gymName} · Trener: ${session.trainerFullName}',
                    tag: session.isGroup ? 'GRUPNI PLACENI' : 'LICNI',
                  ),
                ),
              ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openAddTrainingDialog,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj novi trening'),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: 'Plan', title: 'Planirani treninzi'),
        const SizedBox(height: 10),
        if (_activeCustomTrainings.isEmpty)
          const Text(
            'Nemate rucno dodanih treninga. Kliknite "Dodaj novi trening" da kreirate plan.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ..._activeCustomTrainings.map(
            (training) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CustomTrainingCard(
                title: training.name,
                exercises: training.exercises,
                details: training.details,
                createdAt: _formatDateTime(training.createdAt),
                onComplete: () => _completeCustomTraining(training),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const _SectionTitle(icon: 'History', title: 'Historija treninga'),
        const SizedBox(height: 10),
        if (_completedCustomTrainings.isEmpty)
          const Text(
            'Historija treninga je prazna. Oznacite trening kao zavrsen da se pojavi ovdje.',
            style: TextStyle(color: Color(0xFF8A94A8)),
          )
        else
          ..._completedCustomTrainings.map(
            (training) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TrainingHistoryCard(
                title: training.name,
                exercises: training.exercises,
                details: training.details,
                completedAt: _formatDateTime(
                  training.completedAt ?? training.createdAt,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context, AuthResponse? user) {
    final gymName = _activeMembership?.gymName ?? 'Iron Gym Sarajevo';
    final membershipRange = _activeMembership == null
        ? 'Nema aktivne članarine'
        : '${_formatDate(_activeMembership!.startDate)} - ${_formatDate(_activeMembership!.endDate)}';
    final billingPayments = _billingPayments;

    return ListView(
      key: const PageStorageKey('profile-tab'),
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
              Text(
                user?.fullName ?? 'Korisnik',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Color(0xFF7A8598)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ProfileInfoBox(label: 'TERETANA', value: gymName),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileInfoBox(
                      label: 'ČLANARINA',
                      value: membershipRange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ProfileInfoBox(
                      label: 'GRAD',
                      value: user?.cityName ?? '-',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileInfoBox(
                      label: 'TELEFON',
                      value: user?.phoneNumber ?? '-',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _openEditProfileDialog(context.read<AuthProvider>()),
                      icon: const Icon(Icons.edit),
                      label: const Text('Uredi profil'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openChangePasswordDialog(
                        context.read<AuthProvider>(),
                      ),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Lozinka'),
                    ),
                  ),
                ],
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
        if (_pendingPaymentsCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 18,
                  color: Color(0xFF8D6E00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'U obradi: $_pendingPaymentsCount uplata. Status će biti automatski ažuriran.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D4C00),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _resumePendingPayments,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6D4C00),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Osvježi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_profileSection == 'Historija') ...[
          if (_loadingPayments)
            const _TopCard(
              title: 'Historija',
              subtitle: 'Učitavanje plaćanja',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_recentPayments.isEmpty)
            _TopCard(
              title: 'Historija',
              subtitle: 'Nema evidentiranih plaćanja',
              child: _emptyStateCard(
                title: 'Još nema plaćanja',
                message:
                    'Kada obavite uplatu ili kupovinu članarine, ovdje će se pojaviti historija.',
                icon: Icons.receipt_long_outlined,
                actionLabel: 'Pregledaj billing',
                onAction: () => setState(() => _profileSection = 'Billing'),
              ),
            )
          else ...[
            for (var i = 0; i < _recentPayments.length && i < 5; i++) ...[
              _HistoryCard(
                title: _paymentTypeLabel(_recentPayments[i]['type']),
                value:
                    '${((_recentPayments[i]['amount'] as num?) ?? 0).toStringAsFixed(0)} ${_recentPayments[i]['currency'] ?? 'KM'}',
                date: _formatIsoDate(_recentPayments[i]['createdAt']),
              ),
              if (i < 4 && i < _recentPayments.length - 1)
                const SizedBox(height: 10),
            ],
          ],
        ] else if (_profileSection == 'Billing') ...[
          _ProfileMetricGrid(
            items: [
              _MetricItem(
                label: 'Ukupno uplata',
                value: '${_billingPayments.length}',
              ),
              _MetricItem(
                label: 'Ukupno plaćeno',
                value:
                    '${_billingPayments.where((p) {
                      final s = '${p['status']}'.toLowerCase();
                      return p['status'] == 1 || s == 'succeeded';
                    }).fold<double>(0, (sum, p) => sum + (((p['amount'] as num?) ?? 0).toDouble())).toStringAsFixed(0)} KM',
              ),
              _MetricItem(
                label: 'Aktivna članarina',
                value: _activeMembership == null ? 'Ne' : 'Da',
              ),
              _MetricItem(
                label: 'U obradi',
                value:
                    '${_billingPayments.where((p) {
                      final s = '${p['status']}'.toLowerCase();
                      return p['status'] == 0 || s == 'pending';
                    }).length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Sve'),
                selected: _billingTypeFilter == 'Sve',
                onSelected: (_) => setState(() => _billingTypeFilter = 'Sve'),
              ),
              ChoiceChip(
                label: const Text('Članarine'),
                selected: _billingTypeFilter == 'Članarine',
                onSelected: (_) =>
                    setState(() => _billingTypeFilter = 'Članarine'),
              ),
              ChoiceChip(
                label: const Text('Shop'),
                selected: _billingTypeFilter == 'Shop',
                onSelected: (_) => setState(() => _billingTypeFilter = 'Shop'),
              ),
              ChoiceChip(
                label: Text(
                  _billingSortNewestFirst
                      ? 'Najnovije prvo'
                      : 'Najstarije prvo',
                ),
                selected: true,
                onSelected: (_) => setState(
                  () => _billingSortNewestFirst = !_billingSortNewestFirst,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TopCard(
            title: 'Zadnje transakcije',
            subtitle: billingPayments.isEmpty
                ? 'Nema transakcija za odabrani filter'
                : 'Posljednjih ${billingPayments.length > 3 ? 3 : billingPayments.length}',
            child: billingPayments.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Još nema završenih transakcija.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _selectedIndex = _hasGymAccess ? 0 : 1,
                            ),
                            icon: const Icon(Icons.storefront_outlined),
                            label: Text(
                              _hasGymAccess
                                  ? 'Idi na Home'
                                  : 'Pregledaj ponude',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loadPayments,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Osvježi uplate'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var i = 0;
                        i < billingPayments.length && i < 3;
                        i++
                      ) ...[
                        _paymentHistoryRow(billingPayments[i]),
                        const SizedBox(height: 8),
                      ],
                      if (billingPayments.length > 3)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                _showAllPaymentsDialog(billingPayments),
                            child: const Text('Prikaži sve transakcije'),
                          ),
                        ),
                      if (billingPayments.length <= 3)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: billingPayments.isEmpty
                                ? null
                                : () => _showAllPaymentsDialog(billingPayments),
                            child: const Text('Prikaži sve transakcije'),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _TopCard(
            title: 'Korpa',
            subtitle: _shopCart.isEmpty
                ? 'Trenutno nema artikala u korpi'
                : '$_shopItemsCount artikala · ${_shopTotal.toStringAsFixed(0)} KM',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_shopCart.isEmpty)
                  const Text(
                    'Dodaj artikle iz Shop sekcije na Home tabu.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                else ...[
                  ..._shopCart
                      .take(4)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${item.title} x${item.quantity} - ${(item.price * item.quantity).toStringAsFixed(0)} KM',
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeCartItem(item),
                                icon: const Icon(Icons.delete_outline),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Ukloni artikal',
                              ),
                              IconButton(
                                onPressed: () =>
                                    _changeCartItemQuantity(item, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () =>
                                    _changeCartItemQuantity(item, 1),
                                icon: const Icon(Icons.add_circle_outline),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_shopCart.length > 4)
                    Text(
                      '+ još ${_shopCart.length - 4} artikala',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearCart,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Isprazni korpu'),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _shopCart.isEmpty ? null : _openShopCheckout,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text('Otvori korpu'),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          _emptyStateCard(
            title: 'Badges uskoro stižu',
            message:
                'Ovaj dio je trenutno rezervisan za bedževe i napredak. Sljedeći korak je dodavanje pravog progress tracking-a.',
            icon: Icons.emoji_events_outlined,
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
          onPressed: () => _confirmLogout(context.read<AuthProvider>()),
          icon: const Icon(Icons.logout),
          label: const Text('Odjava'),
        ),
      ],
    );
  }

  Widget _buildBadgesTab(BuildContext context, AuthResponse? user) {
    final gymName = _activeMembership?.gymName ?? 'Iron Gym Sarajevo';
    final membershipRange = _activeMembership == null
        ? 'Nema aktivne clanarine'
        : '${_formatDate(_activeMembership!.startDate)} - ${_formatDate(_activeMembership!.endDate)}';

    return ListView(
      key: const PageStorageKey('badges-tab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _TopCard(
          title: 'Moj profil',
          subtitle: 'Bedzevi i ostvareni napredak',
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.person, size: 46, color: Color(0xFF5D72E6)),
              ),
              const SizedBox(height: 14),
              Text(
                user?.fullName ?? 'Korisnik',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Color(0xFF7A8598)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ProfileInfoBox(label: 'TERETANA', value: gymName),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileInfoBox(
                      label: 'CLANARINA',
                      value: membershipRange,
                    ),
                  ),
                ],
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
                selected: false,
                onTap: () => setState(() => _profileSection = 'Historija'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                label: 'Billing',
                selected: false,
                onTap: () => setState(() => _profileSection = 'Billing'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                label: 'Badges',
                selected: true,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingProgressData)
          const _TopCard(
            title: 'Badges',
            subtitle: 'Ucitavanje bedzeva',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_badges.isEmpty)
          _emptyStateCard(
            title: 'Jos nema bedzeva',
            message:
                'Bedzevi se automatski dodjeljuju kroz check-in i redovne dolaske.',
            icon: Icons.emoji_events_outlined,
          )
        else ...[
          _ProfileMetricGrid(
            items: [
              _MetricItem(label: 'Ukupno bedzeva', value: '${_badges.length}'),
              _MetricItem(
                label: 'Prvi osvojen',
                value: _formatIsoDate(_badges.last.earnedAt),
              ),
              _MetricItem(
                label: 'Zadnji osvojen',
                value: _formatIsoDate(_badges.first.earnedAt),
              ),
              _MetricItem(
                label: 'Check-in',
                value: '${_checkInHistory.length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._badges.map(
            (badge) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5ECF6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.emoji_events_outlined,
                        color: Color(0xFFB7791F),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            badge.description ??
                                'Bedz osvojen kroz aktivnost u sistemu.',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatIsoDate(badge.earnedAt),
                      style: const TextStyle(
                        color: Color(0xFF8A94A8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          onPressed: () => _confirmLogout(context.read<AuthProvider>()),
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
          Text(icon, style: const TextStyle(fontSize: 20)),
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
                    color: isWarning
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF5D72E6),
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
                child: Icon(widget.icon, color: widget.iconColor, size: 20),
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

class _TrainerDirectoryData {
  final int trainerId;
  final String name;
  final String headline;
  final String rating;
  final int sessionCount;
  final int groupSessionCount;
  final List<String> specializations;
  final List<String> gymNames;
  final List<String> cityNames;
  final String nextAvailableLabel;
  final String? biography;
  final String? experience;
  final String? certifications;
  final String? availability;
  final String? email;
  final String? phoneNumber;

  const _TrainerDirectoryData({
    required this.trainerId,
    required this.name,
    required this.headline,
    required this.rating,
    required this.sessionCount,
    required this.groupSessionCount,
    required this.specializations,
    required this.gymNames,
    required this.cityNames,
    required this.nextAvailableLabel,
    this.biography,
    this.experience,
    this.certifications,
    this.availability,
    this.email,
    this.phoneNumber,
  });
}

class _TrainerDirectoryCard extends StatelessWidget {
  final _TrainerDirectoryData trainer;
  final VoidCallback onProfile;

  const _TrainerDirectoryCard({required this.trainer, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: Color(0xFF657BE6),
                child: Icon(
                  Icons.fitness_center,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A3448),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trainer.headline,
                      style: const TextStyle(
                        color: Color(0xFF657BE6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '* ${trainer.rating}',
                  style: const TextStyle(
                    color: Color(0xFF9A6700),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trainer.specializations
                  .take(3)
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      backgroundColor: const Color(0xFFF3F6FC),
                      labelStyle: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${trainer.gymNames.length} teretane · ${trainer.cityNames.join(', ')}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${trainer.sessionCount} sesija',
                style: const TextStyle(
                  color: Color(0xFF8A94A8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sljedeci termin: ${trainer.nextAvailableLabel}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF657BE6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Profil'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _TrainerPreviewData {
  final String name;
  final String role;

  const _TrainerPreviewData({required this.name, required this.role});
}

// ignore: unused_element
class _TrainerPreviewCard extends StatelessWidget {
  final String name;
  final String role;

  const _TrainerPreviewCard({required this.name, required this.role});

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
  final String? subtitle;
  final VoidCallback onBuy;

  const _OfferCard({
    required this.emoji,
    required this.title,
    required this.price,
    this.subtitle,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 78,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 8),
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
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF8A94A8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
          ],
          const Spacer(),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFF5D72E6),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              onPressed: onBuy,
              child: const Text('Dodaj u korpu'),
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
  final VoidCallback onBuy;

  const _MembershipOfferCard({
    required this.emoji,
    required this.title,
    required this.price,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              onPressed: onBuy,
              child: const Text('Kupi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCartItem {
  final String title;
  final double price;
  final int quantity;

  const _ShopCartItem({
    required this.title,
    required this.price,
    this.quantity = 1,
  });
}

class _ShopProduct {
  final String title;
  final double price;
  final String emoji;
  final String category;
  final List<int> gymIds;

  const _ShopProduct({
    required this.title,
    required this.price,
    required this.emoji,
    required this.category,
    required this.gymIds,
  });
}

class _GroupTrainingTile extends StatelessWidget {
  final String title;
  final String schedule;
  final String spotsLabel;
  final bool isReserved;
  final bool isBusy;
  final VoidCallback onReserveToggle;

  const _GroupTrainingTile({
    required this.title,
    required this.schedule,
    required this.spotsLabel,
    required this.isReserved,
    required this.isBusy,
    required this.onReserveToggle,
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
                const SizedBox(height: 2),
                Text(
                  spotsLabel,
                  style: TextStyle(
                    color: isReserved
                        ? const Color(0xFF2DBB72)
                        : const Color(0xFF8A94A8),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isBusy ? null : onReserveToggle,
            style: FilledButton.styleFrom(
              backgroundColor: isReserved
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF5D72E6),
              foregroundColor: Colors.white,
            ),
            child: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isReserved ? 'Otkaži' : 'Rezerviši'),
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
  final VoidCallback onDetails;
  final VoidCallback onJoin;

  const _GymCard({
    required this.name,
    required this.city,
    required this.rating,
    required this.reviews,
    required this.status,
    required this.tags,
    required this.accent,
    required this.onDetails,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'ONLINE'
                      ? const Color(0xFF3BB76A)
                      : const Color(0xFFE76F6F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
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
              Text(
                '($reviews)',
                style: const TextStyle(color: Color(0xFF8A94A8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF75819A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  child: const Text('Detalji'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF657BE6),
                  ),
                  onPressed: onJoin,
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

  const _TopCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A3448),
            ),
          ),
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

  const _SmallMetric({
    required this.title,
    required this.value,
    required this.subtitle,
  });

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
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9AA4B2),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF657BE6),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF7A8598), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String title;
  final String schedule;
  final String? details;
  final String tag;

  const _ScheduleCard({
    required this.title,
    required this.schedule,
    required this.tag,
    this.details,
  });

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
            decoration: BoxDecoration(
              color: const Color(0xFF657BE6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule,
                  style: const TextStyle(color: Color(0xFF7A8598)),
                ),
                if (details != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    details!,
                    style: const TextStyle(
                      color: Color(0xFF51607A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Color(0xFF657BE6),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomTrainingCard extends StatelessWidget {
  final String title;
  final List<_CustomExerciseEntry> exercises;
  final String details;
  final String createdAt;
  final VoidCallback onComplete;

  const _CustomTrainingCard({
    required this.title,
    required this.exercises,
    required this.details,
    required this.createdAt,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${exercises.length} vježbi',
            style: const TextStyle(
              color: Color(0xFF51607A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• ${exercise.exerciseName} · ${exercise.weightKg.toStringAsFixed(1)} kg · ${exercise.reps} pon.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(details, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dodano: $createdAt',
                  style: const TextStyle(
                    color: Color(0xFF8A94A8),
                    fontSize: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Završi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingHistoryCard extends StatelessWidget {
  final String title;
  final List<_CustomExerciseEntry> exercises;
  final String details;
  final String completedAt;

  const _TrainingHistoryCard({
    required this.title,
    required this.exercises,
    required this.details,
    required this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${exercises.length} vježbi',
            style: const TextStyle(
              color: Color(0xFF51607A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• ${exercise.exerciseName} · ${exercise.weightKg.toStringAsFixed(1)} kg · ${exercise.reps} pon.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(details, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text(
            'Završeno: $completedAt',
            style: const TextStyle(color: Color(0xFF8A94A8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CustomTrainingEntry {
  final int id;
  final String name;
  final List<_CustomExerciseEntry> exercises;
  final String details;
  final DateTime createdAt;
  final bool completed;
  final DateTime? completedAt;

  const _CustomTrainingEntry({
    required this.id,
    required this.name,
    required this.exercises,
    required this.details,
    required this.createdAt,
    this.completed = false,
    this.completedAt,
  });

  _CustomTrainingEntry copyWith({bool? completed, DateTime? completedAt}) {
    return _CustomTrainingEntry(
      id: id,
      name: name,
      exercises: exercises,
      details: details,
      createdAt: createdAt,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class _CustomExerciseEntry {
  final String exerciseName;
  final double weightKg;
  final String reps;

  const _CustomExerciseEntry({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });
}

class _SessionOffer {
  final TrainingSessionModel representative;
  final List<String> weekdays;

  const _SessionOffer({required this.representative, required this.weekdays});
}

class _ProfileInfoBox extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileInfoBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A94A8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
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

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF657BE6) : Colors.white,
        foregroundColor: selected ? Colors.white : const Color(0xFF657BE6),
        side: BorderSide(
          color: selected ? const Color(0xFF657BE6) : const Color(0xFFD9E2F2),
        ),
      ),
      child: Text(label),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final String value;
  final String date;

  const _HistoryCard({
    required this.title,
    required this.value,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Color(0xFF8A94A8))),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF657BE6),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8A94A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
