import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_public_sector/services/report/claude_http.dart';

/// Haiku 4.5 returns 400 for `output_config.effort` and does not support the
/// dynamic-filtering web-search tool, while Opus/Sonnet accept both. Every
/// request builder in the pipeline sets `effort` unconditionally, so the
/// adaptation happens once inside ClaudeHttp. If that shim breaks, the whole
/// Risk Desk swarm and the radar's timer-driven triage scan fail at runtime
/// with no compile-time signal — hence this test.
void main() {
  final haiku = ClaudeHttp.model.startsWith('claude-haiku');

  group('effort stripping matches the selected model', () {
    test('output_config.effort is dropped only when unsupported', () {
      final out = ClaudeHttp.adaptToModel({
        'model': ClaudeHttp.model,
        'max_tokens': 100,
        'output_config': {'effort': 'high'},
      });

      if (haiku) {
        expect(out.containsKey('output_config'), isFalse,
            reason: 'effort was the only key, so output_config should go too');
      } else {
        expect(out['output_config'], {'effort': 'high'});
      }
    });

    test('structured-output format survives (Haiku supports it)', () {
      final schema = {
        'type': 'json_schema',
        'schema': {'type': 'object'},
      };
      final out = ClaudeHttp.adaptToModel({
        'output_config': {'effort': 'low', 'format': schema},
      });

      expect((out['output_config'] as Map)['format'], schema,
          reason: 'dropping format would break every JSON-returning stage');
      expect((out['output_config'] as Map).containsKey('effort'), !haiku);
    });

    test('the caller\'s body is not mutated', () {
      final body = {
        'output_config': {'effort': 'high'},
      };
      ClaudeHttp.adaptToModel(body);
      expect((body['output_config'] as Map)['effort'], 'high',
          reason: 'stages reuse their body maps across pause_turn retries');
    });

    test('bodies without output_config pass through untouched', () {
      final body = {'model': ClaudeHttp.model, 'max_tokens': 42};
      expect(ClaudeHttp.adaptToModel(body), body);
    });
  });

  test('web-search tool version is valid for the selected model', () {
    // web_search_20260209 requires Opus 4.6+/Sonnet 4.6+; older and smaller
    // models must use the basic variant or the request is rejected.
    expect(ClaudeHttp.webSearchType,
        haiku ? 'web_search_20250305' : 'web_search_20260209');
  });
}
