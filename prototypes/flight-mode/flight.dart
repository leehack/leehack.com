import 'dart:js_interop';

import 'package:llamadart/llamadart.dart';

@JS('finderPrepare')
external set finderPrepare(JSFunction callback);

void main() {
  finderPrepare = ((JSArray<JSString> documents, JSString modelUrl) {
    return _prepare(documents.toDart.map((text) => text.toDart).toList(), modelUrl.toDart).toJS;
  }).toJS;
}

Future<JSFunction> _prepare(List<String> documents, String modelUrl) async {
  final engine = await LlamaEngine.load(
    LlamaModel(ModelSource.parse(modelUrl)),
    params: const ModelParams(contextSize: 512, batchSize: 512, microBatchSize: 512),
  );
  try {
    final catalog = await engine.embedBatch(documents);
    return ((JSString query) => _rank(engine, catalog, query.toDart).toJS).toJS;
  } catch (_) {
    await engine.dispose();
    rethrow;
  }
}

Future<JSArray<JSNumber>> _rank(LlamaEngine engine, List<List<double>> catalog, String query) async {
  final question = await engine.embed('Represent this sentence for searching relevant passages: $query');
  final matches = [
    for (var index = 0; index < catalog.length; index++) (index: index, score: _similarity(question, catalog[index])),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return matches.take(5).map((match) => match.index.toJS).toList().toJS;
}

double _similarity(List<double> a, List<double> b) {
  var score = 0.0;
  for (var index = 0; index < a.length; index++) {
    score += a[index] * b[index];
  }
  return score;
}
