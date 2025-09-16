import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'camera_ocr_screen.dart';
import 'results_page.dart';
import '../services/openfda_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _svc = OpenFdaService();

  Timer? _debounce;
  bool _loadingSugs = false;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _handleCameraScan() async {
    final ok = await _ensureCameraPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required. Please enable it from Settings.')),
        );
      }
      return;
    }

    final ocrText = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const CameraOcrScreen()),
    );
    if (ocrText == null || ocrText.trim().isEmpty) return;

    final edited = await _showOcrDialog(ocrText.trim());
    final query = (edited ?? ocrText).trim();
    if (query.isEmpty) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultsPage(queryText: query)),
    );
  }

  Future<String?> _showOcrDialog(String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('OCR text'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Drug name (edit if needed)...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Search')),
        ],
      ),
    );
  }

  void _submitSearch([String? value]) {
    final txt = (value ?? _searchCtrl.text).trim();
    if (txt.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsPage(queryText: txt)));
  }

  // ---------- Suggestions ----------
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (!mounted) return;
      if (q.isEmpty) {
        setState(() {
          _suggestions = [];
          _loadingSugs = false;
        });
        return;
      }
      setState(() => _loadingSugs = true);
      final sugs = await _svc.fetchSuggestions(q);
      if (!mounted) return;
      setState(() {
        _suggestions = sugs;
        _loadingSugs = false;
      });
    });
  }

  Future<void> _onTapSuggestion(String name) async {
    // Close keyboard and hide suggestion list for a cleaner UX
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
    });

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultsPage(queryText: name)),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0EA5A4), Color(0xFF22C1B5)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.medical_services_outlined, color: Colors.white),
                      SizedBox(height: 20,),
                      const SizedBox(width: 8),
                      Text('Medicine Scanner',
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      const Spacer(),

                    ]),
                    const SizedBox(height: 8),
                    Text('Identify medicines and read trusted label info.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.95))),
                    const SizedBox(height: 16),

                    // Search card
                    Material(
                      elevation: 0,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _focusNode,
                                textInputAction: TextInputAction.search,
                                onSubmitted: _submitSearch,
                                onChanged: _onQueryChanged,
                                decoration: const InputDecoration(
                                  hintText: 'e.g., Acetaminophen, Ibuprofen...',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _searchCtrl.clear();
                                _onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Suggestions list (shows live under the search card)
                    if (_loadingSugs || _suggestions.isNotEmpty) const SizedBox(height: 8),
                    if (_loadingSugs || _suggestions.isNotEmpty)
                      Material(
                        elevation: 0,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: _loadingSugs
                              ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('Searching...'),
                              ],
                            ),
                          )
                              : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _suggestions.length.clamp(0, 6),
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                dense: true,
                                title: Text(s),
                                onTap: () => _onTapSuggestion(s),
                                trailing: const Icon(Icons.north_east, size: 18),
                              );
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Primary CTA
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _handleCameraScan,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan label'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick suggestions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Quick suggestions', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: [
                    'Acetaminophen', 'Ibuprofen', 'Amoxicillin', 'Omeprazole', 'Loratadine'
                  ].map((s) {
                    return ActionChip(
                      label: Text(s),
                      onPressed: () => _onTapSuggestion(s),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Tip card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Tip'),
                    subtitle: Text('For Turkish brands, try the generic name (e.g., Paracetamol → Acetaminophen).'),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
