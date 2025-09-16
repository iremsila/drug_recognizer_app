import 'package:flutter/material.dart';
import '../services/openfda_service.dart';
import '../widgets/section.dart';
import 'detail_page.dart';

class ResultsPage extends StatefulWidget {
  final String queryText;
  const ResultsPage({super.key, required this.queryText});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  Map<String, dynamic>? _drug;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = OpenFdaService();
    final result = await svc.fetchDrugSmart(widget.queryText);
    setState(() { _drug = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_drug == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No results found for "${widget.queryText}".\n'
                '- The Turkish brand name may not exist in the US OpenFDA dataset.\n'
                '- OCR text may include extra tokens (e.g., mg, tablet, syrup).\n'
                '- Name differences: PARACETAMOL = ACETAMINOPHEN.\n'
                'Try editing and searching again.',
          ),
        ),
      );
    }

    final openfda = (_drug!['openfda'] ?? {}) as Map<String, dynamic>;
    String joinList(dynamic v) => (v is List) ? v.join(', ') : (v?.toString() ?? '');

    final brand = joinList(openfda['brand_name']);
    final generic = joinList(openfda['generic_name']);
    final substance = joinList(openfda['substance_name']);

    String joinLong(dynamic v) => (v is List) ? v.join('\n\n') : (v?.toString() ?? '');
    final indications = joinLong(_drug!['indications_and_usage']);
    final dosage = joinLong(_drug!['dosage_and_administration']);
    final adverse = joinLong(_drug!['adverse_reactions']);

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            brand.isNotEmpty ? brand : (generic.isNotEmpty ? generic : widget.queryText),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (generic.isNotEmpty) Text('Generic: $generic'),
          if (substance.isNotEmpty) Text('Substance: $substance'),
          const Divider(height: 24),
          Section(title: 'Indications', text: indications),
          Section(title: 'Dosage', text: dosage),
          Section(title: 'Adverse Reactions', text: adverse),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => DetailPage(drugData: _drug!),
              ));
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('Detail'),
          ),
        ],
      ),
    );
  }
}
