import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

bool isWebParagraphEnabled() {
  try {
    // Check if CodeUnits API is present in the loaded CanvasKit.
    // This is the most reliable way to know if the correct variant is actually running.
    final canvaskit = window['flutterCanvasKit'] as JSObject?;
    if (canvaskit != null && canvaskit.has('CodeUnits')) {
      return true;
    }
  } catch (e) {
    // Ignore errors in detection
  }

  return false;
}
