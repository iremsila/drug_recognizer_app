import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Reminder {
  final int baseId;
  String name;
  int hour;
  int minute;
  Set<int> weekdays; // 1..7
  String notes;
  bool enabled;
  String createdAtIso;

  Reminder({
    required this.baseId,
    required this.name,
    required this.hour,
    required this.minute,
    required this.weekdays,
    this.notes = '',
    this.enabled = true,
    String? createdAtIso,
  }) : createdAtIso = createdAtIso ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
    'baseId': baseId,
    'name': name,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList(),
    'notes': notes,
    'enabled': enabled,
    'createdAtIso': createdAtIso,
  };

  static Reminder fromJson(Map<String, dynamic> j) => Reminder(
    baseId: j['baseId'] as int,
    name: j['name'] as String,
    hour: j['hour'] as int,
    minute: j['minute'] as int,
    weekdays: Set<int>.from((j['weekdays'] as List).map((e) => e as int)),
    notes: (j['notes'] ?? '') as String,
    enabled: (j['enabled'] ?? true) as bool,
    createdAtIso: (j['createdAtIso'] ?? DateTime.now().toIso8601String()) as String,
  );
}

class ReminderStore {
  static const _key = 'reminders_v1';

  static Future<List<Reminder>> all() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
        .cast<Reminder>();
  }

  static Future<void> saveAll(List<Reminder> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, raw);
  }

  static Future<void> upsert(Reminder r) async {
    final list = await all();
    final idx = list.indexWhere((e) => e.baseId == r.baseId);
    if (idx >= 0) {
      list[idx] = r;
    } else {
      list.add(r);
    }
    await saveAll(list);
  }

  static Future<void> remove(int baseId) async {
    final list = await all();
    list.removeWhere((e) => e.baseId == baseId);
    await saveAll(list);
  }
}
