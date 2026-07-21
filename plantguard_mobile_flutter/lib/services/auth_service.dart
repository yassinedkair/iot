import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

/// Service qui gère l'inscription, la connexion et le stockage du token JWT.
///
/// Le token est stocké avec flutter_secure_storage (Keychain sur iOS,
/// Keystore chiffré sur Android) — bien plus sûr que SharedPreferences
/// pour des données sensibles comme un token d'authentification.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "auth_token";
  static const _usernameKey = "auth_username";

  /// Inscription d'un nouvel utilisateur.
  /// Retourne un Map avec "success" (bool) et "message" (String).
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _saveSession(data['token'], data['username']);
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['error'] ?? 'Erreur inconnue'};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  /// Connexion d'un utilisateur existant.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveSession(data['token'], data['username']);
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['error'] ?? 'Erreur inconnue'};
    } catch (e) {
      return {'success': false, 'message': 'Impossible de contacter le serveur.'};
    }
  }

  Future<void> _saveSession(String token, String username) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _usernameKey, value: username);
  }

  /// Récupère le token stocké (null si aucun utilisateur connecté).
  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Récupère le nom d'utilisateur connecté.
  Future<String?> getUsername() async {
    return _storage.read(key: _usernameKey);
  }

  /// Vérifie si un utilisateur est actuellement connecté.
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Déconnexion : supprime le token stocké localement.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
  }
}