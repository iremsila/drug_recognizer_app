import 'package:hive_flutter/hive_flutter.dart';

class FavoriteStore {
  static Box get _box => Hive.box('favorites');

  static Future<void> toggleFavorite({required String id, required String brand, required String generic}) async {
    if (id.isEmpty) return;
    if (_box.containsKey(id)) {
      await _box.delete(id);
    } else {
      await _box.put(id, {
        'id': id,
        'brand': brand,
        'generic': generic,
        'savedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  static List<Map<String, dynamic>> all() {
    return _box.keys.map((k) => Map<String, dynamic>.from(_box.get(k))).toList()
      ..sort((a,b) => (b['savedAt'] as String).compareTo(a['savedAt'] as String));
  }
}
