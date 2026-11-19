import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The status bar style the engine would apply right now: what Flutter finds
/// in the layer tree at the top centre of the screen, as `RenderView` does
/// after each frame.
SystemUiOverlayStyle? effectiveStatusBarStyle(WidgetTester tester) {
  final view = tester.binding.renderViews.first;
  return view.debugLayer?.find<SystemUiOverlayStyle>(
    Offset(view.size.width / 2, 0),
  );
}

/// Whether [style] draws light (white) status bar icons.
bool hasLightIcons(SystemUiOverlayStyle? style) =>
    style?.statusBarIconBrightness == Brightness.light &&
    style?.statusBarBrightness == Brightness.dark;

/// Whether [style] draws dark status bar icons.
bool hasDarkIcons(SystemUiOverlayStyle? style) =>
    style?.statusBarIconBrightness == Brightness.dark &&
    style?.statusBarBrightness == Brightness.light;
