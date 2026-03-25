import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class TrainerAppsScreen extends StatefulWidget {
  const TrainerAppsScreen({super.key});

  @override
  State<TrainerAppsScreen> createState() => _TrainerAppsScreenState();
}

class _TrainerAppsScreenState extends State<TrainerAppsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  List<TrainerApplication> _apps = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await TrainerService.getAll();
      if (!mounted) return;
      setState(() => _apps = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TrainerApplication> _forStatus(AppStatus status) {
    return _apps.where((a) => a.appStatus == status).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: kPrimary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: kPrimary,
                  tabs: [
                    Tab(text: 'Na čekanju (${_forStatus(AppStatus.pending).length})'),
                    Tab(text: 'Odobreni (${_forStatus(AppStatus.approved).length})'),
                    Tab(text: 'Odbijeni (${_forStatus(AppStatus.rejected).length})'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _load,
                tooltip: 'Osvježi',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildTable(_forStatus(AppStatus.pending), true),
                      _buildTable(_forStatus(AppStatus.approved), false),
                      _buildTable(_forStatus(AppStatus.rejected), false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<TrainerApplication> rows, bool actionable) {
    if (rows.isEmpty) {
      return const Center(child: Text('Nema zahtjeva za prikaz.'));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Korisnik')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Predano')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Napomena')),
            DataColumn(label: Text('Akcije')),
          ],
          rows: rows
              .map(
                (a) => DataRow(cells: [
                  DataCell(Text(a.userFullName)),
                  DataCell(Text(a.userEmail)),
                  DataCell(Text(_fmtDt(a.submittedAt))),
                  DataCell(_statusBadge(a.appStatus)),
                  DataCell(Text(a.adminNote?.isNotEmpty == true ? a.adminNote! : '-')),
                  DataCell(
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _showDetails(a),
                          child: const Text('Detalji'),
                        ),
                        if (actionable)
                          ElevatedButton(
                            onPressed: () => _reviewDialog(a),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Obradi'),
                          ),
                      ],
                    ),
                  ),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _showDetails(TrainerApplication app) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Zahtjev: ${app.userFullName}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Email', app.userEmail),
                _detail('Predano', _fmtDt(app.submittedAt)),
                _detail('Biografija', app.biography ?? '-'),
                _detail('Iskustvo', app.experience ?? '-'),
                _detail('Certifikati', app.certifications ?? '-'),
                _detail('Dostupnost', app.availability ?? '-'),
                _detail('Admin napomena', app.adminNote ?? '-'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          )
        ],
      ),
    );
  }

  Future<void> _reviewDialog(TrainerApplication app) async {
    final noteCtrl = TextEditingController();
    var submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
            title: Text('Obrada zahtjeva: ${app.userFullName}'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unesite opcionalnu napomenu prije odluke.'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Napomena admina',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Otkaži'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        setLocal(() => submitting = true);
                        try {
                          await TrainerService.review(app.id, 2, noteCtrl.text.trim());
                          if (mounted) {
                            navigator.pop();
                            await _load();
                          }
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                          );
                        } finally {
                          if (mounted) setLocal(() => submitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Odbij'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        setLocal(() => submitting = true);
                        try {
                          await TrainerService.review(app.id, 1, noteCtrl.text.trim());
                          if (mounted) {
                            navigator.pop();
                            await _load();
                          }
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                          );
                        } finally {
                          if (mounted) setLocal(() => submitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Odobri'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(AppStatus status) {
    late final String label;
    late final Color fg;
    late final Color bg;

    switch (status) {
      case AppStatus.pending:
        label = 'Na čekanju';
        fg = kOrange;
        bg = kOrange.withValues(alpha: 0.12);
        break;
      case AppStatus.approved:
        label = 'Odobreno';
        fg = kGreen;
        bg = kGreen.withValues(alpha: 0.12);
        break;
      case AppStatus.rejected:
        label = 'Odbijeno';
        fg = kRed;
        bg = kRed.withValues(alpha: 0.12);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  String _fmtDt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
