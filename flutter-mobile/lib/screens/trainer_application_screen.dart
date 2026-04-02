import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_services.dart';

class TrainerApplicationScreen extends StatefulWidget {
  const TrainerApplicationScreen({super.key});

  @override
  State<TrainerApplicationScreen> createState() => _TrainerApplicationScreenState();
}

class _TrainerApplicationScreenState extends State<TrainerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _biographyCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _certificationsCtrl = TextEditingController();
  final _availabilityCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _biographyCtrl.dispose();
    _experienceCtrl.dispose();
    _certificationsCtrl.dispose();
    _availabilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final result = await TrainerApplicationService.apply(
        biography: _biographyCtrl.text.trim(),
        experience: _experienceCtrl.text.trim(),
        certifications: _certificationsCtrl.text.trim().isEmpty
            ? null
            : _certificationsCtrl.text.trim(),
        availability: _availabilityCtrl.text.trim().isEmpty
            ? null
            : _availabilityCtrl.text.trim(),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Prijava poslana'),
          content: Text(
            'Vaša prijava je uspješno poslana i trenutno je ${result.statusLabel.toLowerCase()}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('U redu'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trenerska prijava'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Postani trener',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Popuni kratak profil i pošalji prijavu administraciji.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _biographyCtrl,
                        maxLines: 4,
                        decoration: _decoration('Biografija',
                            hint: 'Kratko opiši svoj stručni profil i pristup radu.'),
                        validator: (value) {
                          if (value == null || value.trim().length < 20) {
                            return 'Unesite barem 20 znakova.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _experienceCtrl,
                        maxLines: 4,
                        decoration: _decoration('Iskustvo',
                            hint: 'Navedi relevantno iskustvo, certifikate ili rad s klijentima.'),
                        validator: (value) {
                          if (value == null || value.trim().length < 20) {
                            return 'Unesite barem 20 znakova.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _certificationsCtrl,
                        maxLines: 2,
                        decoration: _decoration('Certifikati (opcionalno)'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _availabilityCtrl,
                        maxLines: 2,
                        decoration: _decoration('Dostupnost (opcionalno)',
                            hint: 'Npr. pon-pet poslije 17h, vikendom po dogovoru.'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_submitting ? 'Šaljem...' : 'Pošalji prijavu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}