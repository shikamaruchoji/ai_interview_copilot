import 'dart:math';

/// Lightweight BM25-like retrieval over resume + job text chunks (on-device).
class RagService {
  static List<String> chunk(String text, {int maxChars = 800}) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return [];
    final out = <String>[];
    for (var i = 0; i < t.length; i += maxChars) {
      final s = t.substring(i, min(i + maxChars, t.length)).trim();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  static List<String> tokenize(String s) =>
      RegExp(r'[a-zA-Z0-9_+#.-]{2,}').allMatches(s.toLowerCase()).map((m) => m.group(0)!).toList();

  final List<String> chunks;
  final List<List<String>> tokens;
  final Map<String, double> idf;
  final List<double> avgDl;

  RagService._(this.chunks, this.tokens, this.idf, this.avgDl);

  factory RagService.fromTexts(String? resume, String? job) {
    final chunks = <String>[];
    if ((resume ?? '').trim().isNotEmpty) {
      for (final c in chunk(resume!.trim())) {
        chunks.add('[RESUME] $c');
      }
    }
    if ((job ?? '').trim().isNotEmpty) {
      for (final c in chunk(job!.trim())) {
        chunks.add('[JOB] $c');
      }
    }
    final tokens = chunks.map(tokenize).toList();
    final df = <String, int>{};
    for (final toks in tokens) {
      final seen = <String>{};
      for (final t in toks) {
        if (seen.add(t)) df[t] = (df[t] ?? 0) + 1;
      }
    }
    final corpusSize = chunks.length;
    final idf = <String, double>{};
    for (final e in df.entries) {
      idf[e.key] = log((corpusSize - e.value + 0.5) / (e.value + 0.5) + 1.0);
    }
    final avgDl = tokens.map((t) => t.length.toDouble()).toList();
    return RagService._(chunks, tokens, idf, avgDl);
  }

  static const _k1 = 1.5;
  static const _b = 0.75;

  List<String> retrieve(String query, {int k = 6}) {
    if (chunks.isEmpty) return [];
    final q = tokenize(query);
    if (q.isEmpty) return chunks.take(k).toList();
    final avgLen = avgDl.isEmpty ? 1.0 : avgDl.reduce((a, b) => a + b) / avgDl.length;
    final scores = List<double>.filled(chunks.length, 0);
    for (var i = 0; i < chunks.length; i++) {
      final dl = tokens[i].length.toDouble();
      final denom = _k1 * (1 - _b + _b * (dl / avgLen));
      for (final term in q) {
        final tf = tokens[i].where((t) => t == term).length;
        if (tf == 0) continue;
        final idfW = idf[term] ?? 0.8;
        scores[i] += idfW * ((_k1 + 1) * tf) / (denom + tf);
      }
    }
    final idx = List<int>.generate(chunks.length, (i) => i);
    idx.sort((a, b) => scores[b].compareTo(scores[a]));
    return idx.take(k).map((i) => chunks[i]).toList();
  }
}
