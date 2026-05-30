import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api_services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _pageSize = 20;

  bool _loading = true;
  bool _unreadOnly = false;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  final List<NotificationModel> _items = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _loadingMore) return;
      unawaited(_load(reset: true, silent: true));
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool reset, bool silent = false}) async {
    if (_loadingMore) return;

    if (reset) {
      if (!silent) {
        setState(() {
          _loading = true;
          _page = 1;
          _hasMore = true;
        });
      } else {
        _page = 1;
        _hasMore = true;
      }
    } else {
      if (!_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = reset ? 1 : _page + 1;
      final result = await NotificationApiService.getMyNotifications(
        unreadOnly: _unreadOnly,
        page: page,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result);
          _page = 1;
        } else {
          _items.addAll(result);
          _page = page;
        }
        _hasMore = result.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ucitavanje notifikacija nije uspjelo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (!silent) {
            _loading = false;
          }
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleUnreadOnly(bool value) async {
    if (_unreadOnly == value) return;
    setState(() => _unreadOnly = value);
    await _load(reset: true);
  }

  Future<void> _markAsRead(NotificationModel item) async {
    if (item.isRead) return;

    try {
      final updated = await NotificationApiService.markAsRead(item.id);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((n) => n.id == item.id);
        if (index != -1) {
          _items[index] = updated;
        }
        if (_unreadOnly) {
          _items.removeWhere((n) => n.id == updated.id && n.isRead);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oznacavanje notifikacije nije uspjelo: $e')),
      );
    }
  }

  String _formatWhen(String iso) {
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm').format(parsed);
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.payments_outlined;
      case 'refund':
        return Icons.undo_outlined;
      case 'reservation':
        return Icons.event_available_outlined;
      case 'trainerapplication':
        return Icons.badge_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _iconColorFor(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return const Color(0xFF0F766E);
      case 'refund':
        return const Color(0xFFB45309);
      case 'reservation':
        return const Color(0xFF1D4ED8);
      case 'trainerapplication':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikacije'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Osvjezi',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Sve'),
                  selected: !_unreadOnly,
                  onSelected: (_) => _toggleUnreadOnly(false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Neprocitane'),
                  selected: _unreadOnly,
                  onSelected: (_) => _toggleUnreadOnly(true),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 52,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'Nema notifikacija za prikaz.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: _loadingMore
                                        ? null
                                        : () => _load(reset: false),
                                    icon: _loadingMore
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more),
                                    label: Text(
                                      _loadingMore
                                          ? 'Ucitavanje...'
                                          : 'Ucitaj jos',
                                    ),
                                  ),
                                ),
                              );
                            }

                            final item = _items[index];
                            final accent = _iconColorFor(item.type);
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: item.isRead ? null : () => _markAsRead(item),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: item.isRead
                                          ? const Color(0xFFE2E8F0)
                                          : accent.withValues(alpha: 0.4),
                                    ),
                                    gradient: item.isRead
                                        ? null
                                        : LinearGradient(
                                            colors: [
                                              accent.withValues(alpha: 0.10),
                                              Colors.white,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color:
                                                accent.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            _iconFor(item.type),
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.title,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: item.isRead
                                                            ? FontWeight.w600
                                                            : FontWeight.w800,
                                                        color: const Color(
                                                          0xFF0F172A,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (!item.isRead)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: accent,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          999,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Novo',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                item.message,
                                                style: const TextStyle(
                                                  height: 1.35,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _formatWhen(item.createdAt),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (!item.isRead)
                                                    TextButton(
                                                      onPressed: () =>
                                                          _markAsRead(item),
                                                      child: const Text(
                                                        'Oznaci kao procitano',
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
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
