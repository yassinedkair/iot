import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../widgets/bold_text.dart';
import '../widgets/diagnosis_dashboard.dart';
import 'login_screen.dart';

const _primary = Color(0xFF2E7D32);
const _danger = Color(0xFFD32F2F);

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with WidgetsBindingObserver {
  final _apiService = ApiService();

  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _cameraReady = false;
  String? _cameraError;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _cameraError = "Permission caméra refusée.");
      return;
    }

    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = controller;
      _initializeControllerFuture = controller.initialize().then((_) {
        if (mounted) setState(() => _cameraReady = true);
      });
      setState(() {});
    } catch (e) {
      setState(() => _cameraError = "Erreur caméra : $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final XFile photo = await controller.takePicture();

      final data = await _apiService.predictUpload(File(photo.path));

      if (data['status'] == 'Erreur') {
        setState(() => _error = data['class']?.toString());
      } else {
        setState(() => _result = data);
        if (mounted) _showResultDialog(data);
      }

      try {
        await File(photo.path).delete();
      } catch (_) {}
    } catch (e) {
      if (e.toString().contains('SESSION_EXPIREE')) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResultDialog(Map<String, dynamic> data) {
    final healthy = data['status'] == 'Sain';
    final treatment = data['treatment_info'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête coloré selon le statut (Sain / Malade)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: healthy ? _primary : _danger,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        healthy ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        healthy ? "Plante en bonne santé" : "Problème détecté",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenu scrollable : dashboard + conseils de traitement
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DiagnosisDashboard(result: data),
                        const SizedBox(height: 16),
                        if (treatment != null)
                          _TreatmentBox(
                            healthy: healthy,
                            title: treatment['title'] ?? '',
                            steps: List<String>.from(treatment['steps'] ?? []),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: healthy ? _primary : _danger,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        "Fermer",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Column(
              children: const [
                Icon(Icons.eco, size: 32, color: _primary),
                SizedBox(height: 6),
                Text(
                  "PlantGuard AI Pro",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Analyse en temps réel & Conseils d'experts",
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Aperçu caméra en direct
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: _primary, width: 3),
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black,
                ),
                child: _buildCameraPreview(),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: (_loading || !_cameraReady) ? null : _captureAndScan,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white),
              label: Text(
                _loading ? "Analyse en cours..." : "Prendre la photo & scanner",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(text: "❌ Erreur : $_error"),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _cameraError!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || _initializeControllerFuture == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? 1,
                  height: controller.value.previewSize?.width ?? 1,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        border: Border.all(color: _danger, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _danger),
      ),
    );
  }
}

class _TreatmentBox extends StatelessWidget {
  final bool healthy;
  final String title;
  final List<String> steps;
  const _TreatmentBox({required this.healthy, required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: healthy ? _primary : _danger, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  ", style: TextStyle(fontSize: 16)),
                  Expanded(child: BoldText(step)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}