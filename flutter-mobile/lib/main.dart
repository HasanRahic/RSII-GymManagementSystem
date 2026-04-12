import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const GymMobileApp(),
    ),
  );
}

class GymMobileApp extends StatelessWidget {
  const GymMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const _AuthGate(),
        '/login': (ctx) => const LoginScreen(),
        '/register': (ctx) => const RegisterScreen(),
        '/home': (ctx) => const HomeScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final auth = context.read<AuthProvider>();
    final hasToken = await auth.tryAutoLogin();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, hasToken ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
