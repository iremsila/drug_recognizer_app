import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart';
import '../data/reminder_store.dart';
import '../services/openfda_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Reminder> _items = [];
  int _orphanCount = 0; // OS'te var, store'da yok
  final _svc = OpenFdaService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await NotificationService.init();
    final items = await ReminderStore.all();
    final pend = await NotificationService.pending();

    final storeBaseIds = items.map((e) => e.baseId).toSet();
    final osBaseIds = pend.map((p) => p.id ~/ 10).toSet();
    final orphans = osBaseIds.difference(storeBaseIds);

    setState(() {
      _items = items;
      _orphanCount = orphans.length;
    });
  }

  Future<void> _syncSchedule(Reminder r) async {
    if (r.enabled) {
      await NotificationService.scheduleWeeklyReminders(
        baseId: r.baseId,
        name: r.name,
        hour: r.hour,
        minute: r.minute,
        weekdays: r.weekdays,
        notes: r.notes,
      );
    } else {
      await NotificationService.cancelReminderSeries(r.baseId);
    }
  }

  Future<void> _addOrEdit([Reminder? existing]) async {
    final result = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _ReminderEditor(initial: existing, svc: _svc),
    );
    if (result == null) return;

    try {
      await ReminderStore.upsert(result);            // önce diske yaz
      await _syncSchedule(result);                   // sonra planla (hata alabilir)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${result.name}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved locally, scheduling failed: $e')),
      );
    } finally {
      await _load(); // NE OLURSA OLSUN listeyi tazele
    }
  }

  Future<void> _delete(Reminder r) async {
    await NotificationService.cancelReminderSeries(r.baseId);
    await ReminderStore.remove(r.baseId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted reminder for ${r.name}')));
  }

  Future<void> _importFromSystem() async {
    final pend = await NotificationService.pending();
    final Map<int, Reminder> grouped = {};

    for (final p in pend) {
      final baseId = p.id ~/ 10;
      final weekday = p.id % 10; // 1..7
      String name = p.title?.replaceFirst('Time to take ', '') ?? 'Medicine';
      String notes = p.body ?? '';
      int hour = 8, minute = 0;
      Set<int> wds = {weekday};

      try {
        if ((p.payload ?? '').isNotEmpty) {
          final data = jsonDecode(p.payload!);
          name = (data['name'] ?? name).toString();
          notes = (data['notes'] ?? notes).toString();
          hour = (data['hour'] ?? hour) as int;
          minute = (data['minute'] ?? minute) as int;
          final wl = (data['weekdays'] as List?)?.map((e) => e as int).toList() ?? [];
          if (wl.isNotEmpty) wds = wl.toSet();
        }
      } catch (_) {}

      grouped.update(
        baseId,
            (ex) {
          ex.weekdays.add(weekday);
          return ex;
        },
        ifAbsent: () => Reminder(
          baseId: baseId, name: name, hour: hour, minute: minute, weekdays: wds, notes: notes, enabled: true,
        ),
      );
    }

    // Store'a yaz (mevcudu ezme)
    final current = await ReminderStore.all();
    final currentIds = current.map((e) => e.baseId).toSet();
    for (final r in grouped.values) {
      if (!currentIds.contains(r.baseId)) {
        await ReminderStore.upsert(r);
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        actions: [
          IconButton(
            tooltip: 'Request permission',
            onPressed: () => NotificationService.requestPermission(),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'Debug: notify now',
            onPressed: () => NotificationService.showNow(title: 'Test', body: 'This is a test notification'),
            icon: const Icon(Icons.bug_report_outlined),
          ),
          IconButton(
            tooltip: 'Debug: store count',
            onPressed: () async {
              final all = await ReminderStore.all();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Stored reminders: ${all.length}')),
              );
            },
            icon: const Icon(Icons.data_object),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _items.isEmpty
          ? _EmptyState(theme: theme)
          : ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final r = _items[i];
          final time = '${r.hour.toString().padLeft(2,'0')}:${r.minute.toString().padLeft(2,'0')}';
          final label = _weekdayLabel(r.weekdays);

          return Dismissible(
            key: ValueKey(r.baseId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            onDismissed: (_) => _delete(r),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.alarm, color: theme.colorScheme.primary),
                ),
                title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$time • $label${r.notes.isNotEmpty ? ' • ${r.notes}' : ''}'),
                trailing: Switch(
                  value: r.enabled,
                  onChanged: (v) async {
                    final updated = Reminder(
                      baseId: r.baseId, name: r.name, hour: r.hour, minute: r.minute,
                      weekdays: r.weekdays, notes: r.notes, enabled: v, createdAtIso: r.createdAtIso,
                    );
                    await ReminderStore.upsert(updated);
                    await _syncSchedule(updated);
                    await _load();
                  },
                ),
                onTap: () => _addOrEdit(r),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _weekdayLabel(Set<int> wds) {
    if (wds.length == 7) return 'Daily';
    const m = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
    final list = wds.toList()..sort();
    return list.map((d) => m[d]).join(', ');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_add_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No reminders yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Create alarms for specific medicines and times. Choose weekdays and add notes.',
              style: theme.textTheme.bodyMedium, textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


class _ReminderEditor extends StatefulWidget {
  final Reminder? initial;
  final OpenFdaService svc;
  const _ReminderEditor({required this.initial, required this.svc});

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}
class _ReminderEditorState extends State<_ReminderEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  Set<int> _wds = {1, 2, 3, 4, 5, 6, 7};
  bool _enabled = true;

  List<String> _sugs = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    if (r != null) {
      _time = TimeOfDay(hour: r.hour, minute: r.minute);
      _wds = Set<int>.from(r.weekdays);
      _enabled = r.enabled;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final t = v.trim();
      if (t.isEmpty) {
        if (!mounted) return;
        setState(() => _sugs = []);
        return;
      }
      final res = await widget.svc.fetchSuggestions(t);
      if (!mounted) return;
      setState(() => _sugs = res.take(6).toList());
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _toggleDay(int d) {
    setState(() {
      if (_wds.contains(d)) {
        _wds.remove(d);
      } else {
        _wds.add(d);
      }
      if (_wds.isEmpty) {
        // avoid empty schedule: default back to Daily
        _wds = {1, 2, 3, 4, 5, 6, 7};
      }
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medicine name.')),
      );
      return;
    }
    final baseId = widget.initial?.baseId ??
        DateTime.now().millisecondsSinceEpoch.remainder(10000000);
    final r = Reminder(
      baseId: baseId,
      name: name,
      hour: _time.hour,
      minute: _time.minute,
      weekdays: _wds,
      notes: _notesCtrl.text.trim(),
      enabled: _enabled,
      createdAtIso: widget.initial?.createdAtIso,
    );
    Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const days = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 4,
              width: 48,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.initial == null ? 'Add Reminder' : 'Edit Reminder',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Name + suggestions
            TextField(
              controller: _nameCtrl,
              onChanged: _onNameChanged,
              decoration: const InputDecoration(
                labelText: 'Medicine name',
                hintText: 'e.g., Acetaminophen',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
            ),
            if (_sugs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sugs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = _sugs[i];
                    return ListTile(
                      dense: true,
                      title: Text(s),
                      onTap: () {
                        setState(() {
                          _nameCtrl.text = s;
                          _sugs = [];
                        });
                      },
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Time & enabled
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text('Time: ${_time.format(context)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Enabled'),
                      const SizedBox(width: 8),
                      Switch(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Weekdays
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: days.entries.map((e) {
                  final selected = _wds.contains(e.key);
                  return FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => _toggleDay(e.key),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., take with food',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),

            const SizedBox(height: 16),

            // Save
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save reminder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
