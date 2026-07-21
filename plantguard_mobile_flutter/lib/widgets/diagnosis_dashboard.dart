import 'package:flutter/material.dart';

/// Convertit une couleur hex "#c62828" envoyée par le backend en Color Flutter.
Color _colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

/// Carte "dashboard" affichée après un scan : plante détectée, maladie,
/// gravité (badge coloré) et niveau de confiance de l'IA.
class DiagnosisDashboard extends StatelessWidget {
  final Map<String, dynamic> result;

  const DiagnosisDashboard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool healthy = result['status'] == 'Sain';
    final String plant = result['plant'] ?? '';
    final String plantIcon = result['plant_icon'] ?? '🌿';
    final String diseaseLabel = result['disease_label'] ?? result['class'] ?? '';
    final String severity = result['severity'] ?? '';
    final Color severityColor =
        _colorFromHex(result['severity_color'] ?? (healthy ? '#2e7d32' : '#c62828'));
    final double confidence = (result['confidence'] is num)
        ? (result['confidence'] as num).toDouble()
        : 0.0;
    final String timestamp = result['timestamp'] ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : plante + statut
          Row(
            children: [
              Text(plantIcon, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      diseaseLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                healthy ? Icons.check_circle : Icons.warning_rounded,
                color: healthy ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                size: 28,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Badges : gravité + confiance
          Row(
            children: [
              if (!healthy) ...[
                _Badge(
                  label: "Gravité : $severity",
                  color: severityColor,
                ),
                const SizedBox(width: 8),
              ],
              _Badge(
                label: "Confiance IA : ${confidence.toStringAsFixed(0)}%",
                color: Colors.blueGrey,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Barre de confiance
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (confidence / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                healthy ? const Color(0xFF2E7D32) : severityColor,
              ),
            ),
          ),

          if (timestamp.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "Analysé le $timestamp",
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
