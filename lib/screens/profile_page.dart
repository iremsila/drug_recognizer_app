import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../data/reminder_store.dart';
import '../services/openfda_service.dart'; // for suggestions (optional)
import 'reminders_page.dart'; // path: lib/screens/reminders_page.dart

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Reminder> _items = [];
  final _svc = OpenFdaService();


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await NotificationService.init();
    final items = await ReminderStore.all();
    setState(() => _items = items);
  }

  Future<void> _syncSchedule(Reminder r) async {
    if (r.enabled) {
      await NotificationService.scheduleWeeklyReminders(
        baseId: r.baseId,
        name: r.name,
        // <-- title yerine name
        hour: r.hour,
        minute: r.minute,
        weekdays: r.weekdays,
        notes: r.notes, // <-- body yerine notes
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
      // ← eklendi
      enableDrag: false,
      // ← eklendi
      builder: (_) => _ReminderEditor(initial: existing, svc: _svc),
    );
    if (result == null) {
      // İsteyenler için bilgi vermek isterseniz:
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not saved')));
      return;
    }
    await ReminderStore.upsert(result);
    await _syncSchedule(result);
    await _load();
  }

  Future<void> _delete(Reminder r) async {
    await NotificationService.cancelReminderSeries(r.baseId);
    await ReminderStore.remove(r.baseId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted reminder for ${r.name}')),
    );
  }

  Object _weekdayLabel(Set<int> wds) {
    if (wds.length == 7) return 'Daily';
    const names = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun'
    };
    return wds.toList()
      ..sort()
      ..toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdayShort = const {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun'
    };

    final int totalReminders = _items.length;
    final List<Reminder> previewItems = _items.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Allow notifications',
            onPressed: () => NotificationService.requestPermission(),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Basic profile block (placeholder)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Account'),
              subtitle: Text('Language: English'),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Reminders card ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.alarm_outlined,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medication Reminders',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              totalReminders > 0
                                  ? '• $totalReminders reminder${totalReminders ==
                                  1 ? '' : 's'}'
                                  : '• No reminders yet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Buttons (wrap to avoid overflow)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RemindersPage()),
                              );
                              if (!mounted) return;
                              await _load(); // refresh after returning
                            },
                            icon: const Icon(Icons.list_alt_outlined, size: 20),
                            label: Text(
                              totalReminders > 0
                                  ? 'View all ($totalReminders)'
                                  : 'View all',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await _addOrEdit(); // open add sheet
                              if (!mounted) return;
                              await _load(); // refresh after save
                            },
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),

                // Empty state
                if (totalReminders == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Create alarms for specific medicines and times. Choose weekdays and optional notes.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Preview list (max 3)
                if (totalReminders > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: previewItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = previewItems[i];
                        final time = '${r.hour.toString().padLeft(2, '0')}:${r
                            .minute
                            .toString()
                            .padLeft(2, '0')}';
                        final wnames = r.weekdays.toList()
                          ..sort();
                        final wlabel = r.weekdays.length == 7
                            ? 'Daily'
                            : wnames.map((d) => weekdayShort[d]).join(', ');

                        return Dismissible(
                          key: ValueKey('rem-prev-${r.baseId}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                                Icons.delete_outline, color: Colors.red),
                          ),
                          onDismissed: (_) => _delete(r),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: theme.colorScheme.outlineVariant),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Time pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    time,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Name + meta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        r.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$wlabel${r.notes.isNotEmpty ? ' • ${r
                                            .notes}' : ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.hintColor),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Enable switch
                                Switch(
                                  value: r.enabled,
                                  onChanged: (v) async {
                                    final updated = Reminder(
                                      baseId: r.baseId,
                                      name: r.name,
                                      hour: r.hour,
                                      minute: r.minute,
                                      weekdays: r.weekdays,
                                      notes: r.notes,
                                      enabled: v,
                                      createdAtIso: r.createdAtIso,
                                    );
                                    await ReminderStore.upsert(updated);
                                    await _syncSchedule(updated);
                                    await _load();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                if (totalReminders > previewItems.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RemindersPage()),
                          );
                          if (!mounted) return;
                          await _load();
                        },
                        child: Text('Manage all reminders ($totalReminders)'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ---- /Reminders card ----
        ],
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
  Set<int> _wds = {1,2,3,4,5,6,7};
  bool _enabled = true;

  // suggestions
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
      if (t.isEmpty) { setState(() => _sugs = []); return; }
      final res = await widget.svc.fetchSuggestions(t);
      if (!mounted) return;
      setState(() => _sugs = res);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _toggleDay(int d) {
    setState(() {
      if (_wds.contains(d)) _wds.remove(d);
      else _wds.add(d);
      if (_wds.isEmpty) _wds = {1,2,3,4,5,6,7}; // avoid empty schedule
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a medicine name.')));
      return;
    }
    final baseId = widget.initial?.baseId ?? DateTime.now().millisecondsSinceEpoch.remainder(10000000);
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
    if (!mounted) return;
    Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const days = {1:'Mon', 2:'Tue', 3:'Wed', 4:'Thu', 5:'Fri', 6:'Sat', 7:'Sun'};

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16,
        top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 4, width: 48,
              decoration: BoxDecoration(
                color: theme.dividerColor, borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.initial == null ? 'Add Reminder' : 'Edit Reminder',
                style: theme.textTheme.titleMedium),
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
                  itemCount: _sugs.length.clamp(0, 6),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = _sugs[i];
                    return ListTile(
                      dense: true,
                      title: Text(s),
                      onTap: () { setState(() { _nameCtrl.text = s; _sugs = []; }); },
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Time & enable
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
                      Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
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
            TextField(
              controller: _notesCtrl,
              minLines: 1, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., take with food',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),

            const SizedBox(height: 16),
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
