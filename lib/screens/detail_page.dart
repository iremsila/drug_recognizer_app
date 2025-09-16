import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/section.dart';
import '../data/favorite_store.dart';

class DetailPage extends StatelessWidget {
  final Map<String, dynamic> drugData;
  const DetailPage({super.key, required this.drugData});

  String _joinList(dynamic v, {String sep = ', '}) =>
      (v is List) ? v.where((e) => e != null).map((e) => e.toString()).join(sep) : (v?.toString() ?? '');

  String _joinLong(dynamic v) =>
      (v is List) ? v.where((e) => e != null).map((e) => e.toString()).join('\n\n') : (v?.toString() ?? '');

  Widget _chipsRow(List<String> items) {
    final chips = items.where((e) => e.trim().isNotEmpty).map((e) => Chip(label: Text(e))).toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: -8, children: chips);
  }

  @override
  Widget build(BuildContext context) {
    final isLabel = drugData.containsKey('openfda') || drugData.containsKey('indications_and_usage');
    final isNdc = drugData.containsKey('brand_name') && (drugData.containsKey('dosage_form') || drugData.containsKey('route'));
    final isDrugsFda = drugData.containsKey('products');

    String id = '';
    String brand = '';
    String generic = '';
    String manufacturer = '';
    List<String> formChips = [];
    List<String> routeChips = [];
    List<String> substanceChips = [];

    String indications = '';
    String dosage = '';
    String warnings = '';
    String warningsAndCautions = '';
    String contraindications = '';
    String adverse = '';
    String interactions = '';
    String overdosage = '';
    String storage = '';
    String patientInfo = '';
    String boxedWarning = '';

    if (isLabel) {
      final openfda = (drugData['openfda'] ?? {}) as Map<String, dynamic>;
      brand = _joinList(openfda['brand_name']);
      generic = _joinList(openfda['generic_name']);
      manufacturer = _joinList(openfda['manufacturer_name']);
      formChips = _joinList(openfda['dosage_form']).split(', ').where((e) => e.isNotEmpty).toList();
      routeChips = _joinList(openfda['route']).split(', ').where((e) => e.isNotEmpty).toList();
      substanceChips = _joinList(openfda['substance_name']).split(', ').where((e) => e.isNotEmpty).toList();

      indications = _joinLong(drugData['indications_and_usage']);
      dosage = _joinLong(drugData['dosage_and_administration']);
      warnings = _joinLong(drugData['warnings']);
      warningsAndCautions = _joinLong(drugData['warnings_and_cautions']);
      contraindications = _joinLong(drugData['contraindications']);
      adverse = _joinLong(drugData['adverse_reactions']);
      interactions = _joinLong(drugData['drug_interactions']);
      overdosage = _joinLong(drugData['overdosage']);
      storage = _joinLong(drugData['storage_and_handling']);
      patientInfo = _joinLong(drugData['patient_information']);
      boxedWarning = _joinLong(drugData['boxed_warning']);

      id = (drugData['id'] ?? drugData['set_id'] ?? (brand + generic)).toString();
    } else if (isNdc) {
      brand = _joinList(drugData['brand_name']);
      generic = _joinList(drugData['generic_name']);
      manufacturer = _joinList(drugData['labeler_name']);
      formChips = _joinList(drugData['dosage_form']).split(', ').where((e) => e.isNotEmpty).toList();
      routeChips = _joinList(drugData['route']).split(', ').where((e) => e.isNotEmpty).toList();

      final ai = (drugData['active_ingredients'] as List?)?.map((e) {
        final m = e as Map<String, dynamic>;
        final n = (m['name'] ?? '').toString();
        final s = (m['strength'] ?? '').toString();
        return s.isNotEmpty ? '$n ($s)' : n;
      }).where((e) => e.trim().isNotEmpty).toList();
      substanceChips = (ai ?? []);

      id = (drugData['product_ndc'] ?? brand + generic).toString();
    } else if (isDrugsFda) {
      final products = (drugData['products'] as List?) ?? [];
      final p = products.isNotEmpty ? products.first as Map<String, dynamic> : <String, dynamic>{};

      brand = _joinList(p['brand_name']);
      generic = _joinList(p['generic_name']);
      manufacturer = _joinList(drugData['sponsor_name']);
      formChips = _joinList(p['dosage_form']).split(', ').where((e) => e.isNotEmpty).toList();
      routeChips = _joinList(p['route']).split(', ').where((e) => e.isNotEmpty).toList();

      final ai = (p['active_ingredients'] as List?)?.map((e) {
        final m = e as Map<String, dynamic>;
        final n = (m['name'] ?? '').toString();
        final s = (m['strength'] ?? '').toString();
        return s.isNotEmpty ? '$n ($s)' : n;
      }).where((e) => e.trim().isNotEmpty).toList();
      substanceChips = (ai ?? []);

      id = (drugData['application_number'] ?? brand + generic).toString();
    } else {
      brand = (drugData['brand'] ?? '').toString();
      generic = (drugData['generic'] ?? '').toString();
      id = (drugData['id'] ?? brand + generic).toString();
    }

    final titleText = brand.isNotEmpty ? brand : (generic.isNotEmpty ? generic : 'Detail');

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          IconButton(
            tooltip: 'Toggle favorite',
            onPressed: () async {
              await FavoriteStore.toggleFavorite(id: id, brand: brand, generic: generic);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Favorites updated')),
                );
              }
            },
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titleText, style: Theme.of(context).textTheme.titleLarge),
                if (generic.isNotEmpty && brand != generic) ...[
                  const SizedBox(height: 4),
                  Text('Generic: $generic'),
                ],
                if (manufacturer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Manufacturer: $manufacturer'),
                ],
                const SizedBox(height: 12),
                if (formChips.isNotEmpty) _chipsRow(formChips),
                if (routeChips.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _chipsRow(routeChips),
                ),
                if (substanceChips.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _chipsRow(substanceChips),
                ),
              ]),
            ),
          ),

          if (boxedWarning.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Boxed Warning', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.redAccent)),
                const SizedBox(height: 6),
                Text(boxedWarning),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          Section(title: 'Indications', text: indications),
          Section(title: 'Dosage', text: dosage),
          Section(title: 'Warnings', text: warnings),
          Section(title: 'Warnings & Cautions', text: warningsAndCautions),
          Section(title: 'Contraindications', text: contraindications),
          Section(title: 'Adverse Reactions', text: adverse),
          Section(title: 'Drug Interactions', text: interactions),
          Section(title: 'Overdosage', text: overdosage),
          Section(title: 'Storage & Handling', text: storage),
          Section(title: 'Patient Information', text: patientInfo),

          const SizedBox(height: 12),

        ],
      ),
    );
  }
}
