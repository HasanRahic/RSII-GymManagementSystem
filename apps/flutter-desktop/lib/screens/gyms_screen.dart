import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class GymsScreen extends StatefulWidget {
  const GymsScreen({super.key});

  @override
  State<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends State<GymsScreen> {
  List<GymModel> _gyms = [];
  List<CityReferenceModel> _cities = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  static const _cityCoordinatePresets = <String, ({double lat, double lon})>{
    'sarajevo': (lat: 43.8563, lon: 18.4131),
    'mostar': (lat: 43.3438, lon: 17.8078),
    'banja luka': (lat: 44.7722, lon: 17.1910),
    'zagreb': (lat: 45.8150, lon: 15.9819),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        GymService.getAll(search: search),
        ReferenceService.getCityDetails(),
      ]);
      if (!mounted) return;
      setState(() {
        _gyms = results[0] as List<GymModel>;
        _cities = results[1] as List<CityReferenceModel>;
      });
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: kRed));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: kGreen));
  }

  Future<void> _showGymDialog([GymModel? gym]) async {
    final nameCtrl = TextEditingController(text: gym?.name ?? '');
    final addrCtrl = TextEditingController(text: gym?.address ?? '');
    final descCtrl = TextEditingController(text: gym?.description ?? '');
    final phoneCtrl = TextEditingController(text: gym?.phoneNumber ?? '');
    final emailCtrl = TextEditingController(text: gym?.email ?? '');
    final capCtrl = TextEditingController(
      text: gym != null ? gym.capacity.toString() : '',
    );
    final latCtrl = TextEditingController(
      text: gym != null ? gym.latitude.toStringAsFixed(6) : '',
    );
    final lonCtrl = TextEditingController(
      text: gym != null ? gym.longitude.toStringAsFixed(6) : '',
    );
    final openCtrl =
        TextEditingController(text: gym?.openTime.substring(0, 8) ?? '06:00:00');
    final closeCtrl =
        TextEditingController(text: gym?.closeTime.substring(0, 8) ?? '22:00:00');
    final formKey = GlobalKey<FormState>();
    int? selectedCityId = gym?.cityId ?? (_cities.isNotEmpty ? _cities.first.id : null);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(gym == null ? 'Nova teretana' : 'Uredi teretanu'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(
                      nameCtrl,
                      'Naziv',
                      validator: (value) => (value == null || value.trim().length < 2)
                          ? 'Naziv teretane mora imati najmanje 2 slova.'
                          : null,
                    ),
                    _field(
                      addrCtrl,
                      'Adresa',
                      validator: (value) => (value == null || value.trim().length < 5)
                          ? 'Adresa mora imati najmanje 5 karaktera.'
                          : null,
                    ),
                    _field(descCtrl, 'Opis', maxLines: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            phoneCtrl,
                            'Telefon',
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Telefon je obavezan.';
                              if (text.length < 6) return 'Telefon nije u ispravnom formatu.';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            emailCtrl,
                            'Email',
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Email je obavezan.';
                              if (!text.contains('@') || !text.contains('.')) {
                                return 'Email nije u ispravnom formatu.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            capCtrl,
                            'Kapacitet',
                            numeric: true,
                            validator: (value) {
                              final capacity = int.tryParse((value ?? '').trim());
                              if (capacity == null || capacity <= 0) {
                                return 'Kapacitet mora biti veci od 0.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedCityId,
                            decoration: const InputDecoration(
                              labelText: 'Grad',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _cities
                                .map(
                                  (city) => DropdownMenuItem<int>(
                                    value: city.id,
                                    child: Text('${city.name}, ${city.countryName}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => selectedCityId = value),
                            validator: (value) => value == null ? 'Odaberi grad.' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            openCtrl,
                            'Radno vrijeme od',
                            validator: _validateTime,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            closeCtrl,
                            'Radno vrijeme do',
                            validator: (value) {
                              final baseError = _validateTime(value);
                              if (baseError != null) return baseError;
                              if ((value ?? '').trim().compareTo(openCtrl.text.trim()) <= 0) {
                                return 'Vrijeme zatvaranja mora biti nakon otvaranja.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: selectedCityId == null
                                ? null
                                : () {
                                    final city = _cities.firstWhere(
                                      (item) => item.id == selectedCityId,
                                    );
                                    final preset = _cityCoordinatePresets[
                                        city.name.toLowerCase()];
                                    if (preset == null) {
                                      _showError(
                                        'Za ovaj grad nema predlozenih koordinata. Unesi ih rucno.',
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      latCtrl.text = preset.lat.toStringAsFixed(6);
                                      lonCtrl.text = preset.lon.toStringAsFixed(6);
                                    });
                                  },
                            icon: const Icon(Icons.my_location_outlined),
                            label: const Text('Postavi centar grada'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() {
                              _stepCoordinate(latCtrl, 0.001);
                            }),
                            icon: const Icon(Icons.north_outlined),
                            label: const Text('Lat +'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() {
                              _stepCoordinate(latCtrl, -0.001);
                            }),
                            icon: const Icon(Icons.south_outlined),
                            label: const Text('Lat -'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() {
                              _stepCoordinate(lonCtrl, 0.001);
                            }),
                            icon: const Icon(Icons.east_outlined),
                            label: const Text('Lon +'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setDialogState(() {
                              _stepCoordinate(lonCtrl, -0.001);
                            }),
                            icon: const Icon(Icons.west_outlined),
                            label: const Text('Lon -'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            latCtrl,
                            'Latitude',
                            numeric: true,
                            validator: (value) {
                              final parsed = double.tryParse((value ?? '').trim());
                              if (parsed == null) {
                                return 'Latitude mora biti broj.';
                              }
                              if (parsed < -90 || parsed > 90) {
                                return 'Latitude mora biti izmedju -90 i 90.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            lonCtrl,
                            'Longitude',
                            numeric: true,
                            validator: (value) {
                              final parsed = double.tryParse((value ?? '').trim());
                              if (parsed == null) {
                                return 'Longitude mora biti broj.';
                              }
                              if (parsed < -180 || parsed > 180) {
                                return 'Longitude mora biti izmedju -180 i 180.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dto = {
                  'name': nameCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  'phoneNumber': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'capacity': int.parse(capCtrl.text.trim()),
                  'cityId': selectedCityId,
                  'openTime': openCtrl.text.trim(),
                  'closeTime': closeCtrl.text.trim(),
                  'latitude': double.parse(latCtrl.text.trim()),
                  'longitude': double.parse(lonCtrl.text.trim()),
                };
                try {
                  if (gym == null) {
                    await GymService.create(dto);
                  } else {
                    await GymService.update(gym.id, dto);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                    );
                  }
                }
              },
              child: const Text('Spremi'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _load();
      _showSuccess(gym == null ? 'Teretana dodana!' : 'Teretana azurirana!');
    }
  }

  String? _validateTime(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Radno vrijeme je obavezno.';
    final parts = text.split(':');
    if (parts.length != 3) return 'Vrijeme mora biti u formatu HH:mm:ss.';
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) {
      return 'Vrijeme mora biti validan broj.';
    }
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59 || seconds < 0 || seconds > 59) {
      return 'Vrijeme nije u ispravnom rasponu.';
    }
    return null;
  }

  void _stepCoordinate(TextEditingController controller, double delta) {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    controller.text = (current + delta).toStringAsFixed(6);
  }

  Future<void> _toggleStatus(GymModel gym) async {
    final newStatus = gym.isActive ? 1 : 0;
    try {
      await GymService.updateStatus(gym.id, newStatus);
      await _load();
      _showSuccess('Status azuriran!');
    } catch (e) {
      _showError(e.toString());
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool numeric = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pretrazi teretane...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  onSubmitted: (v) => _load(search: v),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _load(search: _searchCtrl.text.trim()),
                icon: const Icon(Icons.search),
                label: const Text('Pretrazi'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  _load();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Resetuj'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showGymDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nova teretana'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _gyms.isEmpty
                    ? const Center(child: Text('Nema teretana'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: _gyms.length,
                        itemBuilder: (ctx, i) => _GymCard(
                          gym: _gyms[i],
                          onEdit: () => _showGymDialog(_gyms[i]),
                          onToggle: () => _toggleStatus(_gyms[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  final GymModel gym;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _GymCard({
    required this.gym,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: gym.isActive
                        ? kPrimary.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fitness_center,
                      color: gym.isActive ? kPrimary : Colors.grey, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    gym.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gym.isActive
                        ? kGreen.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    gym.isActive ? 'Aktivan' : 'Zatvoreno',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: gym.isActive ? kGreen : Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.location_on_outlined,
                '${gym.cityName}, ${gym.countryName}'),
            const SizedBox(height: 6),
            _infoRow(Icons.access_time_outlined,
                '${gym.openTime.substring(0, 5)} - ${gym.closeTime.substring(0, 5)}'),
            const SizedBox(height: 6),
            _infoRow(Icons.pin_drop_outlined,
                '${gym.latitude.toStringAsFixed(4)}, ${gym.longitude.toStringAsFixed(4)}'),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.people_outline,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text('${gym.currentOccupancy} / ${gym.capacity}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: gym.capacity > 0
                        ? gym.currentOccupancy / gym.capacity
                        : 0,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: gym.occupancyPct > 80 ? kRed : kGreen,
                    minHeight: 6,
                  ),
                ),
              ),
            ]),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    gym.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 16,
                  ),
                  label: Text(gym.isActive ? 'Zatvori' : 'Otvori',
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Uredi', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
