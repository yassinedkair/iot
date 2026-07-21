import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

/// Service qui appelle les routes protégées de l'API (prédiction + historique).
/// Toutes les requêtes ajoutent automatiquement le header
/// "Authorization: Bearer <token>".
class ApiService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Envoie une image pour analyse. Retourne le résultat du diagnostic.
  /// Lève une exception contenant "SESSION_EXPIREE" si le token est
  /// expiré/absent (statusCode 401) — à intercepter pour rediriger
  /// vers l'écran de login.
  Future<Map<String, dynamic>> predictUpload(File imageFile) async {
    final headers = await _authHeaders();
    final request = http.MultipartRequest('POST', Uri.parse(AppConfig.predictUploadUrl));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401) {
      throw Exception('SESSION_EXPIREE');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Récupère l'historique propre à l'utilisateur connecté.
  Future<List<dynamic>> getHistory() async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse(AppConfig.historyUrl), headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw Exception('SESSION_EXPIREE');
    }

    return jsonDecode(response.body) as List<dynamic>;
  }
}