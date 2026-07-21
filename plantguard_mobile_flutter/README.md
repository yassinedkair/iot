# PlantGuard AI — App Mobile (Flutter)

Version Flutter de l'interface PlantGuard AI Pro. Le **serveur Flask reste inchangé** — l'app appelle simplement ses routes JSON existantes (`/predict_direct`, `/get_history`).

## 1. Prérequis

- Flutter SDK installé ([flutter.dev](https://docs.flutter.dev/get-started/install))
- Un téléphone (mode développeur activé) ou un émulateur Android/iOS
- Ton PC, ton téléphone-caméra (IP Webcam) et l'ESP32-CAM sur le **même réseau Wi-Fi**
- Le serveur Flask (`app.py`) démarré sur ton PC : `python app.py`

## 2. Installation

Comme ce projet contient seulement le code Dart (`lib/`), il te faut d'abord régénérer les dossiers natifs Android/iOS puis appliquer les extraits fournis :

```bash
cd plantguard_mobile_flutter
flutter create . --project-name plantguard_mobile --org com.yassine
flutter pub get
```

Puis :
- Ouvre `android/app/src/main/AndroidManifest.xml` (généré par la commande ci-dessus) et ajoute-y la permission `INTERNET` et `android:usesCleartextTraffic="true"` en te basant sur l'extrait fourni dans ce dossier.
- Ouvre `ios/Runner/Info.plist` (généré) et ajoute-y la clé `NSAppTransportSecurity` en te basant sur l'extrait fourni.

(Ces étapes sont nécessaires une seule fois car ton serveur Flask tourne en HTTP local et non en HTTPS — Android/iOS bloquent le trafic non chiffré par défaut.)

## 3. Configuration des IP

Ouvre `lib/config.dart` et adapte les adresses à ton réseau :

```dart
class AppConfig {
  static const String flaskServer = "http://192.168.137.1:5000"; // IP de ton PC
  static const String phoneIp = "192.168.137.92:8080";           // IP du téléphone-caméra
}
```

⚠️ Utilise l'IP réelle de ta machine sur le réseau local (pas `localhost`, qui pointerait vers le téléphone lui-même). Trouve-la avec `ipconfig` (Windows) ou `ifconfig` (Mac/Linux).

## 4. Lancer l'app

```bash
flutter devices          # vérifier que ton téléphone/émulateur est détecté
flutter run
```

## 5. Structure du projet

```
plantguard_mobile_flutter/
├── lib/
│   ├── main.dart                    # Point d'entrée + navigation (bottom bar)
│   ├── config.dart                  # IP du serveur Flask et de la caméra
│   ├── screens/
│   │   ├── diagnostic_screen.dart   # Flux caméra + bouton scan + résultat + conseils
│   │   └── history_screen.dart      # Historique des 10 dernières analyses
│   └── widgets/
│       └── bold_text.dart           # Rendu des **mots en gras** renvoyés par Flask
├── android/app/src/main/AndroidManifest.xml   # extrait à fusionner
├── ios/Runner/Info.plist                      # extrait à fusionner
└── pubspec.yaml
```

## 6. Fonctionnement

1. **Onglet Diagnostic** : affiche le flux vidéo du téléphone-caméra (`/video` de l'app IP Webcam) via `webview_flutter`.
2. Le bouton **"Scanner la plante"** appelle `POST /predict_direct` sur ton serveur Flask, qui capture une image, fait l'inférence TFLite, et retourne la classe + les conseils de traitement.
3. **Onglet Historique** : récupère `GET /get_history` et affiche les 10 dernières analyses, avec tirer-pour-rafraîchir.

## 7. Prochaines améliorations possibles

- Notifications locales quand une maladie est détectée
- Écran de paramètres pour changer les IP directement dans l'app
- Cache local (SQLite / Hive) pour l'historique en mode hors-ligne
- Build APK signé (`flutter build apk --release`) ou IPA pour distribution
