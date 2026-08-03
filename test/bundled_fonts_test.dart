import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app must never fetch fonts from fonts.gstatic.com at runtime — Marsh
/// networks block Google CDNs, and a missing font renders the whole UI
/// textless. `GoogleFonts.config.allowRuntimeFetching = false` in main.dart
/// turns that failure into a thrown exception, so every weight the theme asks
/// for has to exist in google_fonts/ as `<Family>-<Variant>.ttf` (the name
/// google_fonts resolves assets by).
void main() {
  // google_fonts' own weight -> filename mapping.
  const variantOf = {
    'w100': 'Thin',
    'w200': 'ExtraLight',
    'w300': 'Light',
    'w400': 'Regular',
    'w500': 'Medium',
    'w600': 'SemiBold',
    'w700': 'Bold',
    'w800': 'ExtraBold',
    'w900': 'Black',
  };

  // Material's own text themes are built on w400/w500, and interTextTheme
  // restyles them, so those two are required even where we never name them.
  const alwaysNeeded = {
    'Inter': ['w400', 'w500'],
  };

  /// Every `GoogleFonts.<family>(... fontWeight: FontWeight.wNNN ...)` call in
  /// lib/, as family -> weights. A call with no fontWeight means w400.
  Map<String, Set<String>> scanUsage() {
    final usage = <String, Set<String>>{};
    final call = RegExp(r'GoogleFonts\.([a-z][a-zA-Z0-9]*)\s*\(');
    final weight = RegExp(r'fontWeight:\s*FontWeight\.(w[1-9]00)');

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        // interTextTheme(...) still means the Inter family.
        final name =
            m.group(1)!.replaceFirst(RegExp(r'TextTheme$'), '');
        final family = name[0].toUpperCase() + name.substring(1);

        // Scan only as far as this call's matching close paren.
        var depth = 0, end = src.length;
        for (var i = m.end - 1; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
        final args = src.substring(m.end, end);
        usage
            .putIfAbsent(family, () => {})
            .add(weight.firstMatch(args)?.group(1) ?? 'w400');
      }
    }
    for (final e in alwaysNeeded.entries) {
      if (usage.containsKey(e.key)) usage[e.key]!.addAll(e.value);
    }
    return usage;
  }

  test('every Google font weight used in lib/ is bundled in google_fonts/', () {
    final usage = scanUsage();
    expect(usage, isNotEmpty, reason: 'scan found no GoogleFonts.* calls');

    final missing = <String>[];
    for (final entry in usage.entries) {
      for (final w in entry.value) {
        final path = 'google_fonts/${entry.key}-${variantOf[w]}.ttf';
        if (!File(path).existsSync()) missing.add(path);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Bundled font files are missing, so these weights would be '
          'fetched from fonts.gstatic.com at runtime — and with '
          'allowRuntimeFetching=false they throw instead of rendering:\n'
          '  ${missing.join('\n  ')}\n'
          'Download each from https://fonts.gstatic.com/s/a/<hash>.ttf using '
          'the hash in the google_fonts package, and drop it in google_fonts/.',
    );
  });

  test('pubspec ships the google_fonts/ asset folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains(RegExp(r'^\s*-\s*google_fonts/\s*$', multiLine: true)),
      isTrue,
      reason: 'pubspec.yaml must list `- google_fonts/` under flutter.assets, '
          'or the bundled font files never make it into the build.',
    );
  });

  test('main.dart disables runtime font fetching', () {
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('allowRuntimeFetching = false'),
      reason: 'Without this the app silently falls back to the network and '
          'renders no text on CDN-blocked networks.',
    );
  });
}
