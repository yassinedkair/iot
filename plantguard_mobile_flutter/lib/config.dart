// --------------------------------------------------
// ⚠️ CONFIGURATION DE L'ADRESSE IP
// À adapter selon ton réseau local (même Wi-Fi que le PC/ESP32)
// --------------------------------------------------
class AppConfig {
  // IP du PC qui exécute ton serveur Flask (plant_model.tflite, etc.)
  static const String flaskServer = "http://192.168.11.106:5000";

  // Nouvel endpoint qui reçoit la photo prise par la caméra du téléphone
  static String get predictUploadUrl => "$flaskServer/predict_upload";
  static String get historyUrl => "$flaskServer/get_history";

  // Endpoints d'authentification
  static String get registerUrl => "$flaskServer/register";
  static String get loginUrl => "$flaskServer/login";
}