import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// The VANTAGE entity map, embedded as an iframe over the Flutter canvas.
///
/// VANTAGE is a standalone HTML/JS app (three.js globe, cartogram, entity
/// drawer) that already builds to one self-contained file, so hosting it as a
/// static asset and framing it is far cheaper than porting it to Flutter —
/// and it stays independently buildable from vantage-public-sector/.
class VantageView extends StatefulWidget {
  const VantageView({super.key});

  @override
  State<VantageView> createState() => _VantageViewState();
}

class _VantageViewState extends State<VantageView> {
  static const _viewType = 'vantage-map-iframe';
  static bool _registered = false;

  @override
  void initState() {
    super.initState();
    if (!_registered) {
      // The factory is global to the app, so register it exactly once —
      // registering the same view type twice throws.
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => web.HTMLIFrameElement()
          ..src = 'vantage-map.html'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          // Same origin, so the frame can use WebGL and open map links, but
          // it still cannot navigate the top-level page.
          ..setAttribute('sandbox',
              'allow-scripts allow-same-origin allow-popups allow-downloads'),
      );
      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewType);
  }
}
