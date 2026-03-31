import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  CheckInModel? _activeCheckIn;
  List<GymModel> _gyms = [];
  int? _selectedGymId;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final gyms = await GymService.getAll();
      if (!mounted) return;
      setState(() {
        _gyms = gyms;
        if (gyms.isNotEmpty) _selectedGymId = gyms.first.id;
      });
      // Provjeravamo da li je korisnik aktivno prijavljen
      _checkActive();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkActive() async {
    try {
      final history = await CheckInService.getMyHistory();
      final active = history.firstWhere(
        (c) => c.isActive,
        orElse: () => throw Exception('Nema aktivnog check-ina'),
      );
      if (!mounted) return;
      setState(() => _activeCheckIn = active);
    } catch (_) {
      // Nema aktivnog check-ina, OK je
    }
  }

  Future<void> _checkIn() async {
    if (_selectedGymId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izaberite teretanu')),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final result = await CheckInService.checkIn(_selectedGymId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uspješan ulazak!'),
          backgroundColor: kGreen,
        ),
      );
      setState(() => _activeCheckIn = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _checkOut() async {
    if (_activeCheckIn == null) return;
    setState(() => _processing = true);
    try {
      await CheckInService.checkOut(_activeCheckIn!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uspješan izlazak!'),
          backgroundColor: kGreen,
        ),
      );
      setState(() => _activeCheckIn = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _formatTime(String dt) {
    try {
      final d = DateTime.parse(dt);
      return DateFormat('HH:mm').format(d);
    } catch (_) {
      return dt;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Aktivni check-in status
            if (_activeCheckIn != null) ...[
              Card(
                color: kGreen.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kGreen),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: kGreen, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Aktivno sada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeCheckIn!.gymName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ulazak: ${_formatTime(_activeCheckIn!.checkInTime)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _processing ? null : _checkOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Izlazak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                color: kPrimary.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kPrimary),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.location_on,
                          color: kPrimary, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Niste prijaviljeni',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Prijavite se u teretanu',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                        value: _selectedGymId,
                        decoration: InputDecoration(
                          labelText: 'Izaberite teretanu',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _gyms
                            .map((g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.name),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGymId = val),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _processing ? null : _checkIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Ulazak'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
