import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

class OpenFdaService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.fda.gov'))
    ..interceptors.add(LogInterceptor(
      request: true, responseBody: true, error: true, logPrint: (o) => debugPrint(o.toString()),
    ));

  // TR: "Parol 500 mg tablet" gibi kirlilikleri temizle
  String _sanitize(String s) {
    var t = s.toUpperCase();
    t = t.replaceAll(RegExp(r'\b(\d+(\.\d+)?)(MG|ML|MCG|G)\b'), ' ');
    t = t.replaceAll(RegExp(r'\b(TAB|TABLET|CAPSULE|CAP|SYRUP|SOLUTION|ORAL|COATED|FILM|DRAGEE)\b'), ' ');
    t = t.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  // TR markalari -> ABD jenerik adlari (OpenFDA dili)
  static const Map<String, String> _aliases = {
    'PARACETAMOL': 'ACETAMINOPHEN',
    'IBUPROFEN': 'IBUPROFEN', // örnek
    // 'NOVALGIN': 'METAMIZOLE', // Not: ABD’de onaylı değil; sonuç çıkmayabilir
  };

  Future<Map<String, dynamic>?> fetchDrugSmart(String raw) async {
    String q = _sanitize(raw);
    if (_aliases.containsKey(q)) q = _aliases[q]!;

    // 1) EXACT (dizine uygun alanlar)
    final exact = 'openfda.brand_name.exact:"$q"+OR+openfda.generic_name.exact:"$q"+OR+openfda.substance_name.exact:"$q"';
    final r1 = await _tryLabel(exact);
    if (r1 != null) return r1;

    // 2) WILDCARD (başa/sona yıldız)
    final w = q.replaceAll(' ', '+');
    final wild = 'openfda.brand_name:$w*+OR+openfda.generic_name:$w*+OR+openfda.substance_name:$w*';
    final r2 = await _tryLabel(wild);
    if (r2 != null) return r2;

    // 3) Diğer endpoint fallback (NDC veya drugsfda)
    final r3 = await _tryNdc('brand_name:"$q"+OR+generic_name:"$q"');
    if (r3 != null) return r3;

    final r4 = await _tryDrugsFda('products.brand_name:"$q"+OR+products.active_ingredients.name:"$q"');
    if (r4 != null) return r4;

    return null;
  }
  Future<List<String>> fetchSuggestions(String prefix) async {
    final out = <String>[];
    final seen = <String>{};

    String q = prefix.trim().toUpperCase();
    if (q.isEmpty) return out;

    final endpoints = [
      '/drug/label.json?search=openfda.brand_name:$q*&count=openfda.brand_name.exact',
      '/drug/label.json?search=openfda.generic_name:$q*&count=openfda.generic_name.exact',
      '/drug/label.json?search=openfda.substance_name:$q*&count=openfda.substance_name.exact',
    ];

    for (final url in endpoints) {
      try {
        final res = await _dio.get(url);
        final List results = (res.data is Map && res.data['results'] is List)
            ? res.data['results'] as List
            : const [];
        for (final item in results) {
          final term = (item is Map && item['term'] != null) ? item['term'].toString() : '';
          if (term.isEmpty) continue;
          if (seen.add(term)) {
            out.add(term);
            if (out.length >= 6) return out;
          }
        }
      } on DioException catch (_) {
      }
    }
    return out;
  }

  Future<Map<String, dynamic>?> _tryLabel(String search) async {
    final url = '/drug/label.json?search=$search&limit=1';
    try {
      final res = await _dio.get(url);
      final list = (res.data['results'] as List?) ?? [];
      return list.isNotEmpty ? list.first as Map<String, dynamic> : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // No matches
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _tryNdc(String search) async {
    final url = '/drug/ndc.json?search=$search&limit=1';
    try {
      final res = await _dio.get(url);
      final list = (res.data['results'] as List?) ?? [];
      return list.isNotEmpty ? list.first as Map<String, dynamic> : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _tryDrugsFda(String search) async {
    final url = '/drug/drugsfda.json?search=$search&limit=1';
    try {
      final res = await _dio.get(url);
      final list = (res.data['results'] as List?) ?? [];
      return list.isNotEmpty ? list.first as Map<String, dynamic> : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
