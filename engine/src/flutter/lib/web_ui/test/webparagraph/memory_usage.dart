// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe'; // Required for .getProperty() and .isA<>

int getTrueMemoryUsage() {
  // 1. globalContext is already a JSObject, so .getProperty works here.
  // We use .toJS to convert the string key.
  final JSAny? performanceAny = globalContext.getProperty('performance'.toJS);

  // 2. Check if 'performance' exists and is an Object (not null/undefined/primitive)
  if (performanceAny != null && performanceAny.isA<JSObject>()) {
    final performance = performanceAny as JSObject;

    // 3. Access 'memory'
    final JSAny? memoryAny = performance.getProperty('memory'.toJS);

    if (memoryAny != null && memoryAny.isA<JSObject>()) {
      final memory = memoryAny as JSObject;

      // 4. Access 'totalJSHeapSize'
      final JSAny? totalHeapAny = memory.getProperty('totalJSHeapSize'.toJS);

      // 5. Check if it is a Number and convert
      if (totalHeapAny != null && totalHeapAny.isA<JSNumber>()) {
        return (totalHeapAny as JSNumber).toDartInt;
      }
    }
  }

  return 0; // Fallback
}
