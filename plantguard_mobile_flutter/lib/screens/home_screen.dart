import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// ⚠️ Remplace le contenu de cet écran par l'écran principal existant
/// de ton application (celui qui envoie les photos pour analyse, etc.).
/// Ce fichier montre juste comment récupérer l'utilisateur connecté
/// et gérer la déconnexion.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic de plantes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: authService.getUsername(),
        builder: (context, snapshot) {
          final username = snapshot.data ?? '...';
          return Center(
            child: Text('Bienvenue, $username 👋'),
          );
        },
      ),
    );
  }
}
