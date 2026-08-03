library;

/// Embeds the VANTAGE entity map, which is a self-contained HTML app served
/// from web/vantage-map.html rather than a Flutter widget.
///
/// The web implementation needs dart:ui_web, which does not exist on the Dart
/// VM — so `flutter test` would fail to compile if this were imported
/// directly. The conditional export keeps the widget tests running.
export 'vantage_view_stub.dart'
    if (dart.library.js_interop) 'vantage_view_web.dart';
