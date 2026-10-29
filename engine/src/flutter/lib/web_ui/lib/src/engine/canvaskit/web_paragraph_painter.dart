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
import 'surface.dart';
import 'web_paragraph_atlas.dart';

/// Represents a standalone cached rasterized paragraph image used when the shared GPU
/// atlas is unavailable (software mode, multi-surface rasterizer, or oversized paragraphs).
class _ParagraphCacheEntry {
  _ParagraphCacheEntry({
    required this.image,
    required this.effectiveScaleX,
    required this.effectiveScaleY,
  });

  final EngineImage image;
  final double effectiveScaleX;
  final double effectiveScaleY;

  /// Checks if the cached image scale matches the requested effective scales.
  bool matchesScale({required double effectiveScaleX, required double effectiveScaleY}) {
    return AtlasParagraphSlot.matchesAtlasScale(
      this.effectiveScaleX,
      this.effectiveScaleY,
      effectiveScaleX,
      effectiveScaleY,
    );
  }
}

class CanvasKitPainter extends WebParagraphPainter {
  CanvasKitPainter(super.paragraph);

  AtlasParagraphSlot? _atlasSlot;
  _ParagraphCacheEntry? _standaloneEntry;

  /// For a specific paragraph, how many times it was rasterized in the current test.
  @override
  @visibleForTesting
  int debugRasterizeCount = 0;

  /// Exposes the currently cached shared-atlas slot for unit testing.
  @visibleForTesting
  AtlasParagraphSlot? get debugAtlasSlot => _atlasSlot;

  @override
  bool get hasCache {
    final AtlasParagraphSlot? slot = _atlasSlot;
    if (slot != null && slot.isValidOnSurface(WebParagraphAtlas.instance.resolveTargetSurface())) {
      return true;
    }
    return _standaloneEntry != null;
  }

  @override
  void clearCache() {
    _atlasSlot = null;
    _standaloneEntry?.image.dispose();
    _standaloneEntry = null;
  }

  @override
  void paintParagraphText(
    ui.Canvas canvas,
    ui.Rect sourceRect,
    ui.Rect targetRect, {
    required ParagraphImageGenerator generateParagraphImage,
    ParagraphCanvas2DPainter? paintToCanvas2D,
    required double effectiveScaleX,
    required double effectiveScaleY,
  }) {
    final int physicalWidth = sourceRect.width.ceil();
    final int physicalHeight = sourceRect.height.ceil();
    final CkOffscreenSurface? atlasSurface = paintToCanvas2D == null
        ? null
        : WebParagraphAtlas.instance.resolveTargetSurface();

    if (atlasSurface != null &&
        physicalWidth <= WebParagraphAtlas.maxSlotDimension &&
        physicalHeight <= WebParagraphAtlas.maxSlotDimension) {
      if (_standaloneEntry != null) {
        _standaloneEntry!.image.dispose();
        _standaloneEntry = null;
      }

      AtlasParagraphSlot? slot = _atlasSlot;
      if (slot != null &&
          !slot.isValidFor(
            surface: atlasSurface,
            effectiveScaleX: effectiveScaleX,
            effectiveScaleY: effectiveScaleY,
          )) {
        slot = null;
        _atlasSlot = null;
      }

      if (slot == null) {
        slot = WebParagraphAtlas.instance.rasterizeIntoSlot(
          surface: atlasSurface,
          width: physicalWidth,
          height: physicalHeight,
          effectiveScaleX: effectiveScaleX,
          effectiveScaleY: effectiveScaleY,
          paintToCanvas2D: paintToCanvas2D!,
        );
        if (slot != null) {
          assert(() {
            debugRasterizeCount++;
            return true;
          }());
          _atlasSlot = slot;
        }
      } else {
        WebParagraphAtlas.instance.markSlotUsed(slot);
      }

      if (slot != null) {
        canvas.drawImageRect(
          slot.page.engineImage,
          slot.sourceRect,
          targetRect,
          ui.Paint()..filterQuality = ui.FilterQuality.none,
        );
        return;
      }
    }

    _atlasSlot = null;
    final _ParagraphCacheEntry? standaloneEntry = _standaloneEntry;
    if (standaloneEntry != null &&
        !standaloneEntry.matchesScale(
          effectiveScaleX: effectiveScaleX,
          effectiveScaleY: effectiveScaleY,
        )) {
      clearCache();
    }

    if (_standaloneEntry == null) {
      assert(() {
        debugRasterizeCount++;
        return true;
      }());
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
      _standaloneEntry = _ParagraphCacheEntry(
        image: EngineImage(
          CkImageDelegate(skImage),
          skImage.width().toInt(),
          skImage.height().toInt(),
        ),
        effectiveScaleX: effectiveScaleX,
        effectiveScaleY: effectiveScaleY,
      );
    }

    canvas.drawImageRect(
      _standaloneEntry!.image,
      sourceRect,
      targetRect,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }
}
