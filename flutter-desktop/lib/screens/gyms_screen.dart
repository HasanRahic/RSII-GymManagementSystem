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
  bool _loading = true;
  final _searchCtrl = TextEditingController();

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
      _gyms = await GymService.getAll(search: search);
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
        text: gym != null ? gym.capacity.toString() : '');
    final latCtrl = TextEditingController(
        text: gym != null ? gym.latitude.toString() : '');
    final lonCtrl = TextEditingController(
        text: gym != null ? gym.longitude.toString() : '');
    final openCtrl = TextEditingController(text: gym?.openTime ?? '06:00:00');
    final closeCtrl = TextEditingController(text: gym?.closeTime ?? '22:00:00');
    final cityCtrl = TextEditingController(
        text: gym != null ? gym.cityId.toString() : '1');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gym == null ? 'Nova teretana' : 'Uredi teretanu'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(nameCtrl, 'Naziv', required: true),
                  _field(addrCtrl, 'Adresa', required: true),
                  _field(descCtrl, 'Opis'),
                  _field(phoneCtrl, 'Telefon', required: true),
                  _field(emailCtrl, 'Email', required: true),
                  Row(children: [
                    Expanded(child: _field(capCtrl, 'Kapacitet', required: true, numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(cityCtrl, 'Grad ID', required: true, numeric: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _field(openCtrl, 'Radno vr. od', required: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(closeCtrl, 'Radno vr. do', required: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _field(latCtrl, 'Latitude', required: true, numeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(lonCtrl, 'Longitude', required: true, numeric: true)),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final dto = {
                'name': nameCtrl.text.trim(),
                'address': addrCtrl.text.trim(),
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'phoneNumber': phoneCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'capacity': int.parse(capCtrl.text),
                'cityId': int.parse(cityCtrl.text),
                'openTime': openCtrl.text.trim(),
                'closeTime': closeCtrl.text.trim(),
                'latitude': double.parse(latCtrl.text),
                'longitude': double.parse(lonCtrl.text),
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
                      SnackBar(content: Text(e.toString()), backgroundColor: kRed));
                }
              }
            },
            child: const Text('Spremi'),
          ),
        ],
      ),
    );
    if (result == true) {
      _load();
      _showSuccess(gym == null ? 'Teretana dodana!' : 'Teretana ažurirana!');
    }
  }

  Future<void> _toggleStatus(GymModel gym) async {
    final newStatus = gym.isActive ? 1 : 0;
    try {
      await GymService.updateStatus(gym.id, newStatus);
      _load();
      _showSuccess('Status ažuriran!');
    } catch (e) {
      _showError(e.toString());
    }
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Obavezno' : null
            : null,
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
          // Toolbar
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pretraži teretane...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                  onSubmitted: (v) => _load(search: v),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _load(search: _searchCtrl.text.trim()),
                icon: const Icon(Icons.search),
                label: const Text('Pretraži'),
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

          // Grid
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

// ─── Gym Card ─────────────────────────────────────────────────────────────────

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
                        ? kPrimary.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.12),
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
                        ? kGreen.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
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
            _infoRow(Icons.location_on_outlined, '${gym.cityName}, ${gym.countryName}'),
            const SizedBox(height: 6),
            _infoRow(Icons.access_time_outlined, '${gym.openTime.substring(0, 5)} – ${gym.closeTime.substring(0, 5)}'),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.people_outline, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text('${gym.currentOccupancy} / ${gym.capacity}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: gym.capacity > 0 ? gym.currentOccupancy / gym.capacity : 0,
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
                    gym.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
