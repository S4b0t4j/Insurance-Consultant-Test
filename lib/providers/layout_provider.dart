import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewLayout { grid, newspaper, list }

enum CardDensity { minimal, standard, rich }

class LayoutProvider extends ChangeNotifier {
  static const _layoutKey = 'view_layout_v1';
  static const _densityKey = 'card_density_v1';
  static const _sidebarKey = 'sidebar_collapsed_v1';

  ViewLayout _layout = ViewLayout.grid;
  CardDensity _density = CardDensity.minimal;
  bool _sidebarCollapsed = false;

  ViewLayout get layout => _layout;
  CardDensity get density => _density;
  bool get sidebarCollapsed => _sidebarCollapsed;

  LayoutProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutIdx = prefs.getInt(_layoutKey);
    if (layoutIdx != null && layoutIdx < ViewLayout.values.length) {
      _layout = ViewLayout.values[layoutIdx];
    }
    final densityIdx = prefs.getInt(_densityKey);
    if (densityIdx != null && densityIdx < CardDensity.values.length) {
      _density = CardDensity.values[densityIdx];
    }
    _sidebarCollapsed = prefs.getBool(_sidebarKey) ?? false;
    notifyListeners();
  }

  Future<void> setLayout(ViewLayout layout) async {
    _layout = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_layoutKey, layout.index);
    notifyListeners();
  }

  Future<void> setDensity(CardDensity density) async {
    _density = density;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_densityKey, density.index);
    notifyListeners();
  }

  Future<void> toggleSidebar() async {
    _sidebarCollapsed = !_sidebarCollapsed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarKey, _sidebarCollapsed);
    notifyListeners();
  }
}
