import 'package:flutter/material.dart';
import '../data/favorite_store.dart';
import 'results_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _sortByRecent = true; // true = recent first, false = A–Z
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _view = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _all = FavoriteStore.all();
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(_all);

    if (q.isNotEmpty) {
      list = list.where((it) {
        final brand = (it['brand'] ?? '').toString().toLowerCase();
        final generic = (it['generic'] ?? '').toString().toLowerCase();
        final id = (it['id'] ?? '').toString().toLowerCase();
        return brand.contains(q) || generic.contains(q) || id.contains(q);
      }).toList();
    }

    if (_sortByRecent) {
      list.sort((a, b) {
        final sa = DateTime.tryParse((a['savedAt'] ?? '') as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final sb = DateTime.tryParse((b['savedAt'] ?? '') as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return sb.compareTo(sa);
      });
    } else {
      list.sort((a, b) {
        final ta = ((a['brand'] ?? '') as String).isNotEmpty ? a['brand'] as String : (a['generic'] ?? '') as String;
        final tb = ((b['brand'] ?? '') as String).isNotEmpty ? b['brand'] as String : (b['generic'] ?? '') as String;
        return ta.toLowerCase().compareTo(tb.toLowerCase());
      });
    }

    setState(() => _view = list);
  }

  String _relativeSince(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    final w = (d.inDays / 7).floor();
    if (w < 5) return '${w}w ago';
    final mo = (d.inDays / 30).floor();
    return '${mo}mo ago';
  }

  Future<void> _remove(String id, String brand, String generic) async {
    await FavoriteStore.toggleFavorite(id: id, brand: brand, generic: generic);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from favorites'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await FavoriteStore.toggleFavorite(id: id, brand: brand, generic: generic);
            _load();
          },
        ),
      ),
    );
  }

  void _openResult(String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ResultsPage(queryText: name)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // AppBar: düz arka plan, altına arama alanı gömülü
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          scrolledUnderElevation: 0,
          titleSpacing: 12,
          title: Row(
            children: [
              const Icon(Icons.favorite_outline),
              const SizedBox(width: 8),
              Text('Favorites', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                onSelected: (v) {
                  setState(() => _sortByRecent = (v == 'recent'));
                  _applyFilters();
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(value: 'recent', checked: _sortByRecent, child: const Text('Sort by recent')),
                  CheckedPopupMenuItem(value: 'alpha', checked: !_sortByRecent, child: const Text('Sort A–Z')),
                ],
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Material(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Search in favorites...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilters();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        body: _view.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_added_outlined, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('No favorites yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Scan a label or search a medicine, then tap the heart icon to save it here.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
            : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _view.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final it = _view[i];
            final id = (it['id'] ?? '').toString();
            final brand = (it['brand'] ?? '').toString();
            final generic = (it['generic'] ?? '').toString();
            final title = brand.isNotEmpty ? brand : generic;
            final savedAt = (it['savedAt'] ?? '').toString();

            return Dismissible(
              key: ValueKey(id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              onDismissed: (_) => _remove(id, brand, generic),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openResult(title),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                          child: Icon(Icons.medication_outlined, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (generic.isNotEmpty && brand != generic)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Generic: $generic',
                                        style: theme.textTheme.labelSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (savedAt.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule, size: 14, color: theme.hintColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          _relativeSince(savedAt),
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(id, brand, generic),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.north_east, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: _all.isEmpty
            ? null
            : Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_all.length} ${_all.length == 1 ? "item" : "items"}',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _sortByRecent = !_sortByRecent;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.swap_vert),
                label: Text(_sortByRecent ? 'Recent' : 'A–Z'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
