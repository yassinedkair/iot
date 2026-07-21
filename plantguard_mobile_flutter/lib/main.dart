import 'package:flutter/material.dart';
import 'screens/diagnostic_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

const _primary = Color(0xFF2E7D32);

void main() {
  runApp(const PlantGuardApp());
}

class PlantGuardApp extends StatelessWidget {
  const PlantGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantGuard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: _primary,
        colorScheme: ColorScheme.fromSeed(seedColor: _primary),
        useMaterial3: true,
      ),
      // Au démarrage : si un token valide est déjà stocké, on va
      // directement sur RootNav, sinon on affiche l'écran de connexion.
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatelessWidget {
  const _StartupRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snapshot.data ?? false;
        return loggedIn ? const RootNav() : const LoginScreen();
      },
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  final _screens = const [
    DiagnosticScreen(),
    HistoryScreen(),
  ];

  Future<void> _handleLogout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlantGuard AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.eco), label: "Diagnostic"),
          NavigationDestination(icon: Icon(Icons.history), label: "Historique"),
        ],
      ),
    );
  }
}