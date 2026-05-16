import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  List<GymModel> _gyms = [];
  List<CountryModel> _countries = [];
  List<CityReferenceModel> _cities = [];
  List<TrainingTypeReferenceModel> _trainingTypes = [];
  List<ShopProductReferenceModel> _shopProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        GymService.getAll(),
        ReferenceService.getCountries(),
        ReferenceService.getCityDetails(),
        ReferenceService.getTrainingTypes(),
        ReferenceService.getShopProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _gyms = results[0] as List<GymModel>;
        _countries = results[1] as List<CountryModel>;
        _cities = results[2] as List<CityReferenceModel>;
        _trainingTypes = results[3] as List<TrainingTypeReferenceModel>;
        _shopProducts = results[4] as List<ShopProductReferenceModel>;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? kRed : kGreen,
      ),
    );
  }

  Future<void> _showCountryDialog([CountryModel? country]) async {
    final nameCtrl = TextEditingController(text: country?.name ?? '');
    final codeCtrl = TextEditingController(text: country?.code ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(country == null ? 'Nova drzava' : 'Uredi drzavu'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Naziv drzave'),
                  validator: (value) => (value == null || value.trim().length < 2)
                      ? 'Naziv mora imati najmanje 2 slova.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Kod drzave'),
                  validator: (value) => (value == null || value.trim().length < 2)
                      ? 'Kod mora imati najmanje 2 znaka.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final dto = {
                'name': nameCtrl.text.trim(),
                'code': codeCtrl.text.trim().toUpperCase(),
              };
              try {
                if (country == null) {
                  await ReferenceService.createCountry(dto);
                } else {
                  await ReferenceService.updateCountry(country.id, dto);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                );
              }
            },
            child: const Text('Sacuvaj'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      _showMessage(country == null ? 'Drzava dodana.' : 'Drzava azurirana.');
    }
  }

  Future<void> _showCityDialog([CityReferenceModel? city]) async {
    final nameCtrl = TextEditingController(text: city?.name ?? '');
    final postalCtrl = TextEditingController(text: city?.postalCode ?? '');
    int? selectedCountryId =
        city?.countryId ?? (_countries.isNotEmpty ? _countries.first.id : null);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(city == null ? 'Novi grad' : 'Uredi grad'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Naziv grada'),
                    validator: (value) => (value == null || value.trim().length < 2)
                        ? 'Naziv mora imati najmanje 2 slova.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCountryId,
                    decoration: const InputDecoration(labelText: 'Drzava'),
                    items: _countries
                        .map(
                          (country) => DropdownMenuItem<int>(
                            value: country.id,
                            child: Text('${country.name} (${country.code})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedCountryId = value),
                    validator: (value) => value == null ? 'Odaberi drzavu.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: postalCtrl,
                    decoration: const InputDecoration(labelText: 'Postanski broj'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dto = {
                  'name': nameCtrl.text.trim(),
                  'postalCode':
                      postalCtrl.text.trim().isEmpty ? null : postalCtrl.text.trim(),
                  'countryId': selectedCountryId,
                };
                try {
                  if (city == null) {
                    await ReferenceService.createCity(dto);
                  } else {
                    await ReferenceService.updateCity(city.id, dto);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                  );
                }
              },
              child: const Text('Sacuvaj'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      _showMessage(city == null ? 'Grad dodan.' : 'Grad azuriran.');
    }
  }

  Future<void> _showTrainingTypeDialog(
      [TrainingTypeReferenceModel? item]) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descriptionCtrl = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Novi tip treninga' : 'Uredi tip treninga'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Naziv'),
                  validator: (value) => (value == null || value.trim().length < 2)
                      ? 'Naziv mora imati najmanje 2 slova.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Opis'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final dto = {
                'name': nameCtrl.text.trim(),
                'description': descriptionCtrl.text.trim().isEmpty
                    ? null
                    : descriptionCtrl.text.trim(),
              };
              try {
                if (item == null) {
                  await ReferenceService.createTrainingType(dto);
                } else {
                  await ReferenceService.updateTrainingType(item.id, dto);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                );
              }
            },
            child: const Text('Sacuvaj'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      _showMessage(
          item == null ? 'Tip treninga dodan.' : 'Tip treninga azuriran.');
    }
  }

  Future<void> _showShopProductDialog([ShopProductReferenceModel? item]) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    final descriptionCtrl = TextEditingController(text: item?.description ?? '');
    final priceCtrl = TextEditingController(
      text: item == null ? '' : item.price.toStringAsFixed(2),
    );
    final stockCtrl = TextEditingController(
      text: item?.stockQuantity.toString() ?? '0',
    );
    final emojiCtrl = TextEditingController(text: item?.emoji ?? '');
    var isActive = item?.isActive ?? true;
    int? selectedGymId = item?.gymId ?? (_gyms.isNotEmpty ? _gyms.first.id : null);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Novi shop proizvod' : 'Uredi shop proizvod'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Naziv proizvoda'),
                      validator: (value) => (value == null || value.trim().length < 2)
                          ? 'Naziv mora imati najmanje 2 slova.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedGymId,
                      decoration: const InputDecoration(labelText: 'Teretana'),
                      items: _gyms
                          .map((gym) => DropdownMenuItem<int>(
                                value: gym.id,
                                child: Text(gym.name),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() => selectedGymId = value),
                      validator: (value) => value == null ? 'Odaberi teretanu.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Kategorija'),
                      validator: (value) => (value == null || value.trim().length < 2)
                          ? 'Kategorija mora imati najmanje 2 slova.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Cijena'),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
                        return parsed == null || parsed <= 0 ? 'Unesi ispravnu cijenu.' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(labelText: 'Stanje zaliha'),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        return parsed == null || parsed < 0 ? 'Unesi ispravnu zalihu.' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emojiCtrl,
                      decoration: const InputDecoration(labelText: 'Emoji (opcionalno)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionCtrl,
                      decoration: const InputDecoration(labelText: 'Opis'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktivan proizvod'),
                      value: isActive,
                      onChanged: (value) => setDialogState(() => isActive = value),
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
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dto = {
                  'name': nameCtrl.text.trim(),
                  'category': categoryCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim().isEmpty
                      ? null
                      : descriptionCtrl.text.trim(),
                  'price': double.parse(priceCtrl.text.trim().replaceAll(',', '.')),
                  'stockQuantity': int.parse(stockCtrl.text.trim()),
                  'emoji': emojiCtrl.text.trim().isEmpty ? null : emojiCtrl.text.trim(),
                  'gymId': selectedGymId,
                  'isActive': isActive,
                };
                try {
                  if (item == null) {
                    await ReferenceService.createShopProduct(dto);
                  } else {
                    await ReferenceService.updateShopProduct(item.id, dto);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: kRed),
                  );
                }
              },
              child: const Text('Sacuvaj'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      _showMessage(item == null ? 'Shop proizvod dodan.' : 'Shop proizvod azuriran.');
    }
  }

  Future<void> _deleteItem({
    required String label,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Potvrda brisanja'),
            content: Text('Obrisati "$label"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ne'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Da'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await action();
      await _load();
      if (!mounted) return;
      _showMessage('Stavka je obrisana.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: kPrimary,
            indicatorColor: kPrimary,
            tabs: const [
              Tab(text: 'Drzave'),
              Tab(text: 'Gradovi'),
              Tab(text: 'Tipovi treninga'),
              Tab(text: 'Shop proizvodi'),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _ReferenceList<CountryModel>(
                        title: 'Drzave',
                        buttonLabel: 'Nova drzava',
                        items: _countries,
                        onCreate: () => _showCountryDialog(),
                        onEdit: _showCountryDialog,
                        onDelete: (country) => _deleteItem(
                          label: country.name,
                          action: () => ReferenceService.deleteCountry(country.id),
                        ),
                        itemBuilder: (country) => ListTile(
                          title: Text(country.name),
                          subtitle: Text('Kod: ${country.code}'),
                        ),
                      ),
                      _ReferenceList<CityReferenceModel>(
                        title: 'Gradovi',
                        buttonLabel: 'Novi grad',
                        items: _cities,
                        onCreate: () => _showCityDialog(),
                        onEdit: _showCityDialog,
                        onDelete: (city) => _deleteItem(
                          label: city.name,
                          action: () => ReferenceService.deleteCity(city.id),
                        ),
                        itemBuilder: (city) => ListTile(
                          title: Text(city.name),
                          subtitle: Text(
                            '${city.countryName}${city.postalCode == null ? '' : ' • ${city.postalCode}'}',
                          ),
                        ),
                      ),
                      _ReferenceList<TrainingTypeReferenceModel>(
                        title: 'Tipovi treninga',
                        buttonLabel: 'Novi tip',
                        items: _trainingTypes,
                        onCreate: () => _showTrainingTypeDialog(),
                        onEdit: _showTrainingTypeDialog,
                        onDelete: (item) => _deleteItem(
                          label: item.name,
                          action: () =>
                              ReferenceService.deleteTrainingType(item.id),
                        ),
                        itemBuilder: (item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.description ?? 'Bez opisa'),
                        ),
                      ),
                      _ReferenceList<ShopProductReferenceModel>(
                        title: 'Shop proizvodi',
                        buttonLabel: 'Novi proizvod',
                        items: _shopProducts,
                        onCreate: () => _showShopProductDialog(),
                        onEdit: _showShopProductDialog,
                        onDelete: (item) => _deleteItem(
                          label: item.name,
                          action: () => ReferenceService.deleteShopProduct(item.id),
                        ),
                        itemBuilder: (item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.gymName} • ${item.category} • ${item.price.toStringAsFixed(0)} KM • Zaliha ${item.stockQuantity}${item.isActive ? '' : ' • Neaktivan'}',
                          ),
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

class _ReferenceList<T> extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final List<T> items;
  final VoidCallback onCreate;
  final Future<void> Function(T item) onEdit;
  final Future<void> Function(T item) onDelete;
  final Widget Function(T item) itemBuilder;

  const _ReferenceList({
    required this.title,
    required this.buttonLabel,
    required this.items,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Nema podataka.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: itemBuilder(item)),
                          IconButton(
                            onPressed: () => onEdit(item),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Uredi',
                          ),
                          IconButton(
                            onPressed: () => onDelete(item),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Obrisi',
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
