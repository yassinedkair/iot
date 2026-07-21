import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

const _primary = Color(0xFF2E7D32);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _apiService = ApiService();

  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _apiService.getHistory();
      setState(() => _history = data);
    } catch (e) {
      if (e.toString().contains('SESSION_EXPIREE')) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      debugPrint("Erreur historique: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.history, color: _primary),
                  SizedBox(width: 8),
                  Text(
                    "Historique des analyses",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _primary))
                    : _history.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: Center(
                                  child: Text(
                                    "Aucune analyse enregistrée.",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _history.length,
                            itemBuilder: (context, index) => _HistoryCard(item: _history[index]),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final healthy = item['status'] == 'Sain';
    final severity = item['severity'] as String?;
    final confidence = item['confidence'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['class'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['time'] ?? '',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: healthy ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      healthy ? Icons.check_circle : Icons.warning,
                      size: 14,
                      color: healthy ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['status'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: healthy ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (severity != null || confidence != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (severity != null && severity != "Aucune")
                  _miniTag("Gravité : $severity", Colors.deepOrange),
                if (confidence != null)
                  _miniTag("Confiance : ${confidence.toString()}%", Colors.blueGrey),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}