import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(
            _userCtrl.text.trim(),
            _passCtrl.text,
          );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: kRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 400,
            child: Card(
              elevation: 24,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.fitness_center,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'GymAdmin',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Adminstratorska aplikacija',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 32),

                      // Username
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Korisničko ime',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _login(),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Obavezno polje' : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Lozinka',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _login(),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Obavezno polje' : null,
                      ),
                      const SizedBox(height: 28),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ))
                              : const Text('Prijava',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
