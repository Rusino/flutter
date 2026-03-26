// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ui/ui.dart' as ui;
import '../../engine.dart';

class ParagraphKey {
  ParagraphKey({required this.text, required this.paragraphStyle, required this.textSpans});

  final String text;
  final WebParagraphStyle paragraphStyle;
  final List<ParagraphSpan> textSpans;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ParagraphKey &&
        other.text == text &&
        other.paragraphStyle == paragraphStyle &&
        listEquals(other.textSpans, textSpans);
  }

  @override
  String toString() {
    return 'ParagraphKey{text: $text, paragraphStyle: $paragraphStyle, textSpans: ${textSpans.map((span) => span.toString()).join(', ')}}';
  }

  @override
  int get hashCode => Object.hash(text, paragraphStyle, Object.hashAll(textSpans));
}

class ParagraphCache {
  final Map<ParagraphKey, ui.Paragraph> _storage = {};

  ui.Paragraph? get(ParagraphKey key) {
    return _storage[key];
  }

  bool has(ParagraphKey key) {
    return _storage.keys.contains(key);
  }

  void put(ParagraphKey key, ui.Paragraph paragraph) {
    _storage[key] = paragraph;
  }
}

class SmartParagraphCache {
  SmartParagraphCache();
  final int maxMemoryBytes = 50 * 1024 * 1024;
  int _currentUsage = 0;

  final Map<ParagraphKey, WebParagraph> _cache = {};

  WebParagraph? get(ParagraphKey key) {
    final WebParagraph? paragraph = _cache[key];

    if (paragraph != null) {
      // CRITICAL: Increment refCount before returning!
      // Now RefCount = 2 (1 for Cache, 1 for You)
      paragraph.retain();
    }

    return paragraph;
  }

  void add(ParagraphKey key, WebParagraph paragraph) {
    if (_cache.containsKey(key)) {
      return;
    }

    // TODO(jlavrova): implement a method that evaluates the memory usage for a paragraph
    final int newSize = paragraph.text.length * 100;
    if (newSize > maxMemoryBytes) {
      print('newSize > maxMemoryBytes: $newSize > $maxMemoryBytes');
      return;
    }

    while (_currentUsage + newSize > maxMemoryBytes) {
      if (_cache.isEmpty) {
        break;
      }

      ParagraphKey? victimKey;
      var maxSizeFound = -1;
      for (final MapEntry<ParagraphKey, WebParagraph> entry in _cache.entries) {
        final int size = entry.value.text.length * 100;
        if (size > maxSizeFound) {
          maxSizeFound = size;
          victimKey = entry.key;
        }
      }
      if (victimKey != null) {
        _evict(victimKey);
      }
    }

    _cache[key] = paragraph;
    _cache[key]!.retain(); // Cache retains the paragraph, so refCount = 2 (1 for Cache, 1 for You)
    _currentUsage += newSize;
  }

  void _evict(ParagraphKey key) {
    print('${_cache.length} Evicted from cache: $key');
    final WebParagraph? p = _cache.remove(key);
    if (p != null) {
      _currentUsage -= p.text.length * 100;
      p.dispose();
    }
  }

  void clear() {
    for (final WebParagraph p in _cache.values) {
      p.dispose();
    }
    _cache.clear();
    _currentUsage = 0;
  }

  int get size => _cache.length;
}
