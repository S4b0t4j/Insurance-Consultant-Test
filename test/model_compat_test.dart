import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_public_sector/services/report/claude_http.dart';

/// Haiku 4.5 returns 400 for `output_config.effort` and does not support the
/// dynamic-filtering web-search tool; Sonnet/Opus accept both. Two models
/// coexist in this app now (ClaudeHttp.model for high-frequency calls,
/// ClaudeHttp.deepModel for research()/synthesize()), and every request
/// builder sets `effort` unconditionally, so the adaptation happens once
/// inside ClaudeHttp keyed off each request's own `model` field. If that
/// shim breaks, the affected stage fails at runtime with no compile-time
/// signal — hence this test.
void main() {
  test('the two models actually differ in what they support', () {
    // If this ever fails, every test below still passes but proves
    // nothing — both models would take the same code path by coincidence.
    expect(ClaudeHttp.modelSupportsEffort(ClaudeHttp.model), isFalse);
    expect(ClaudeHttp.modelSupportsEffort(ClaudeHttp.deepModel), isTrue);
  });

  group('effort stripping keys off the request\'s own model, not a global', () {
    test('dropped for a Haiku body, kept for a deepModel body', () {
      final haikuOut = ClaudeHttp.adaptToModel({
        'model': ClaudeHttp.model,
        'output_config': {'effort': 'high'},
      });
      expect(haikuOut.containsKey('output_config'), isFalse,
          reason: 'effort was the only key, so output_config should go too');

      final deepOut = ClaudeHttp.adaptToModel({
        'model': ClaudeHttp.deepModel,
        'output_config': {'effort': 'high'},
      });
      expect(deepOut['output_config'], {'effort': 'high'});
    });

    test('structured-output format survives on both models', () {
      final schema = {
        'type': 'json_schema',
        'schema': {'type': 'object'},
      };
      for (final m in [ClaudeHttp.model, ClaudeHttp.deepModel]) {
        final out = ClaudeHttp.adaptToModel({
          'model': m,
          'output_config': {'effort': 'low', 'format': schema},
        });
        expect((out['output_config'] as Map)['format'], schema,
            reason: '$m: dropping format breaks every JSON-returning stage');
      }
    });

    test('the caller\'s body is not mutated', () {
      final body = {
        'model': ClaudeHttp.model,
        'output_config': {'effort': 'high'},
      };
      ClaudeHttp.adaptToModel(body);
      expect((body['output_config'] as Map)['effort'], 'high',
          reason: 'stages reuse their body maps across pause_turn retries');
    });

    test('a missing model field falls back to ClaudeHttp.model\'s rules', () {
      final out = ClaudeHttp.adaptToModel({
        'output_config': {'effort': 'high'},
      });
      expect(out.containsKey('output_config'),
          ClaudeHttp.modelSupportsEffort(ClaudeHttp.model));
    });

    test('bodies without output_config pass through untouched', () {
      final body = {'model': ClaudeHttp.model, 'max_tokens': 42};
      expect(ClaudeHttp.adaptToModel(body), body);
    });
  });

  test('web-search tool version is valid for each model', () {
    // web_search_20260209 requires Opus 4.6+/Sonnet 4.6+; older and smaller
    // models must use the basic variant or the request is rejected.
    expect(ClaudeHttp.webSearchTypeFor(ClaudeHttp.model), 'web_search_20250305');
    expect(ClaudeHttp.webSearchTypeFor(ClaudeHttp.deepModel),
        'web_search_20260209');
  });
}
