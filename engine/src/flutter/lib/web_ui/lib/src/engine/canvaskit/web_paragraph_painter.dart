// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:ui/ui.dart' as ui;

import '../primitives/image.dart';
import '../web_paragraph/painter.dart';
import 'canvaskit_api.dart';
import 'image.dart';

/// Represents a cached rasterized paragraph image along with the effective scale
/// (combining device pixel ratio and canvas matrix scale) and canvas2dShift it was rendered at.
class _ParagraphCacheEntry {
  _ParagraphCacheEntry({
    required this.image,
    required this.effectiveScaleX,
    required this.effectiveScaleY,
    required this.canvas2dShift,
  });

  static const double _epsilon = 0.001;

  final EngineImage image;
  final double effectiveScaleX;
  final double effectiveScaleY;
  final ui.Offset canvas2dShift;

  /// Checks if the cached image scale matches the requested effective scales within [_epsilon].
  bool matchesScale({required double effectiveScaleX, required double effectiveScaleY}) {
    return (this.effectiveScaleX - effectiveScaleX).abs() < _epsilon &&
        (this.effectiveScaleY - effectiveScaleY).abs() < _epsilon;
  }

  /// Checks if both scale and subpixel canvas2dShift match within [_epsilon].
  bool matches({
    required double effectiveScaleX,
    required double effectiveScaleY,
    required ui.Offset canvas2dShift,
  }) {
    return matchesScale(effectiveScaleX: effectiveScaleX, effectiveScaleY: effectiveScaleY) &&
        (this.canvas2dShift.dx - canvas2dShift.dx).abs() < _epsilon &&
        (this.canvas2dShift.dy - canvas2dShift.dy).abs() < _epsilon;
  }
}

class CanvasKitPainter extends WebParagraphPainter {
  CanvasKitPainter(super.paragraph);

  _ParagraphCacheEntry? _cacheEntry;
  ui.Offset? _lastOffset;

  @visibleForTesting
  int debugRasterizeCount = 0;

  @override
  bool get hasCache => _cacheEntry != null;

  @override
  void clearCache() {
    _cacheEntry?.image.dispose();
    _cacheEntry = null;
  }

  @override
  void paintParagraphText(
    ui.Canvas canvas,
    ui.Rect sourceRect,
    ui.Rect targetRect, {
    required ParagraphImageGenerator generateParagraphImage,
    required double effectiveScaleX,
    required double effectiveScaleY,
    required ui.Offset canvas2dShift,
    required ui.Offset offset,
  }) {
    // Detect active scrolling across frames by checking position delta
    const motionEpsilon = 0.001;
    final bool isScrolling =
        _lastOffset != null &&
        ((offset.dx - _lastOffset!.dx).abs() > motionEpsilon ||
            (offset.dy - _lastOffset!.dy).abs() > motionEpsilon);
    _lastOffset = offset;

    // Check cache matching:
    // - While active scrolling: Loose match (scale only) to guarantee 60/120 FPS jank-free scrolling.
    // - When stationary/settled: Strict match (scale + canvas2dShift) to guarantee 100% crisp static text.
    final _ParagraphCacheEntry? cacheEntry = _cacheEntry;
    if (cacheEntry != null) {
      final bool cacheMatches = isScrolling
          ? cacheEntry.matchesScale(
              effectiveScaleX: effectiveScaleX,
              effectiveScaleY: effectiveScaleY,
            )
          : cacheEntry.matches(
              effectiveScaleX: effectiveScaleX,
              effectiveScaleY: effectiveScaleY,
              canvas2dShift: canvas2dShift,
            );

      if (!cacheMatches) {
        clearCache();
      }
    }

    if (!hasCache) {
      debugRasterizeCount++;
      final imageInfo = SkImageInfo(
        alphaType: canvasKit.AlphaType.Unpremul,
        colorType: canvasKit.ColorType.RGBA_8888,
        colorSpace: SkColorSpaceSRGB,
        width: sourceRect.width,
        height: sourceRect.height,
      );
      final Uint8List imageBytes = generateParagraphImage();
      final SkImage? skImage = canvasKit.MakeImage(
        imageInfo,
        imageBytes,
        (4 * sourceRect.width).toInt(),
      );

      if (skImage == null) {
        throw Exception('Failed to convert text image bitmap to an SkImage.');
      }
      _cacheEntry = _ParagraphCacheEntry(
        image: EngineImage(
          CkImageDelegate(skImage),
          skImage.width().toInt(),
          skImage.height().toInt(),
        ),
        effectiveScaleX: effectiveScaleX,
        effectiveScaleY: effectiveScaleY,
        canvas2dShift: canvas2dShift,
      );
    }

    canvas.drawImageRect(
      _cacheEntry!.image,
      sourceRect,
      targetRect,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }
}
