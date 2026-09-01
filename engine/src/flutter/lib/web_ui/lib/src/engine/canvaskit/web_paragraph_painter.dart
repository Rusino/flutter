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
  }) : binX = _subpixelPhaseBin(canvas2dShift.dx * effectiveScaleX),
       binY = _subpixelPhaseBin(canvas2dShift.dy * effectiveScaleY);

  static const double _scaleEpsilon = 0.001;

  final EngineImage image;
  final double effectiveScaleX;
  final double effectiveScaleY;
  final ui.Offset canvas2dShift;
  final int binX;
  final int binY;

  /// Checks if the cached image scale matches the requested effective scales within [_scaleEpsilon].
  bool matchesScale({required double effectiveScaleX, required double effectiveScaleY}) {
    return (this.effectiveScaleX - effectiveScaleX).abs() < _scaleEpsilon &&
        (this.effectiveScaleY - effectiveScaleY).abs() < _scaleEpsilon;
  }

  /// Quantizes the physical subpixel shift into one of 4 discrete phase bins:
  /// - Bin 0: `[0.0, 0.25)`
  /// - Bin 1: `[0.25, 0.50)`
  /// - Bin 2: `[0.50, 0.75)`
  /// - Bin 3: `[0.75, 1.00)`
  ///
  /// This 2-bit subpixel quantization aligns with standard font rasterizers (such as Skia and FreeType)
  /// which bin subpixel glyph phases in 1/4 physical pixel increments.
  static int _subpixelPhaseBin(double physicalShift) {
    return (physicalShift * 4).floor() % 4;
  }

  /// Checks if the scale matches and both the cached and requested subpixel shifts fall into
  /// the same discrete phase bin (`[0, 0.25)`, `[0.25, 0.5)`, `[0.5, 0.75)`, or `[0.75, 1.0)`).
  ///
  /// When static text moves by an integer number of physical pixels or stays within the same
  /// 1/4-pixel bin, the cached raster image can be reused with zero loss in visual sharpness.
  bool matchesSubpixelPhase({
    required double effectiveScaleX,
    required double effectiveScaleY,
    required ui.Offset canvas2dShift,
  }) {
    if (!matchesScale(effectiveScaleX: effectiveScaleX, effectiveScaleY: effectiveScaleY)) {
      return false;
    }
    final int currentBinX = _subpixelPhaseBin(canvas2dShift.dx * effectiveScaleX);
    final int currentBinY = _subpixelPhaseBin(canvas2dShift.dy * effectiveScaleY);

    return binX == currentBinX && binY == currentBinY;
  }
}

class CanvasKitPainter extends WebParagraphPainter {
  CanvasKitPainter(super.paragraph);

  _ParagraphCacheEntry? _cacheEntry;
  ui.Offset? _lastOffset;
  int? _lastFrameNumber;
  bool _wasMoving = false;

  @override
  @visibleForTesting
  int debugRasterizeCount = 0;

  @visibleForTesting
  static int debugTotalRasterizeCount = 0;

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
    // Detect confirmed active scrolling across consecutive frames.
    // - Uses ui.PlatformDispatcher.instance.frameData.frameNumber to track frame sequence.
    // - On consecutive frames (frame gap <= 2), motion is continuous.
    // - If frames are not consecutive (e.g. slow 1-second timer ticks), isConsecutive is false,
    //   forcing strict subpixel bin matching so text is 100% crisp at rest.
    // - On the first frame moving from rest (_wasMoving is false or not consecutive), only shifts
    //   <= maxInitialMotionDelta (100px) can initiate motion; larger jumps are treated as teleports.
    // - Once active motion is confirmed (_wasMoving && isConsecutive), high-velocity flings (> 100px)
    //   are permitted without dropping frames.
    const motionEpsilon = 0.001;
    const maxInitialMotionDelta = 100.0;

    final int currentFrame = ui.PlatformDispatcher.instance.frameData.frameNumber;
    final int frameGap = _lastFrameNumber != null ? currentFrame - _lastFrameNumber! : -1;
    final bool isConsecutive = frameGap == 1 || frameGap == 2;

    final double deltaX = _lastOffset != null ? (offset.dx - _lastOffset!.dx).abs() : 0.0;
    final double deltaY = _lastOffset != null ? (offset.dy - _lastOffset!.dy).abs() : 0.0;
    final bool hasDelta = _lastOffset != null && (deltaX > motionEpsilon || deltaY > motionEpsilon);

    // Shifts <= 100px on consecutive frames from rest can initiate motion; larger jumps (> 100px) or non-consecutive ticks are discrete.
    final bool canInitiateMotion =
        isConsecutive && deltaX <= maxInitialMotionDelta && deltaY <= maxInitialMotionDelta;
    final bool isScrolling = hasDelta && _wasMoving && isConsecutive;
    _wasMoving = hasDelta && (isScrolling || canInitiateMotion);
    _lastOffset = offset;
    _lastFrameNumber = currentFrame;

    // Check cache matching:
    // 1. Scale must always match (DPR or canvas matrix scale changes invalidate the cache).
    // 2. If isScrolling is true (confirmed multi-frame motion), scale matching is sufficient.
    // 3. Otherwise (static text, first jump, or settling), both X and Y subpixel phases must fall
    //    in the same 1/4-pixel bin ([0, 0.25), [0.25, 0.5), [0.5, 0.75), [0.75, 1.0)).
    var drawSourceRect = sourceRect;
    var drawTargetRect = targetRect;

    final _ParagraphCacheEntry? cacheEntry = _cacheEntry;
    if (cacheEntry != null) {
      final bool cacheMatches =
          cacheEntry.matchesScale(
            effectiveScaleX: effectiveScaleX,
            effectiveScaleY: effectiveScaleY,
          ) &&
          (isScrolling ||
              cacheEntry.matchesSubpixelPhase(
                effectiveScaleX: effectiveScaleX,
                effectiveScaleY: effectiveScaleY,
                canvas2dShift: canvas2dShift,
              ));

      if (!cacheMatches) {
        clearCache();
      } else {
        final double width = cacheEntry.image.width.toDouble();
        final double height = cacheEntry.image.height.toDouble();
        drawSourceRect = ui.Rect.fromLTWH(0, 0, width, height);
        drawTargetRect = ui.Rect.fromLTWH(
          offset.dx - cacheEntry.canvas2dShift.dx,
          offset.dy - cacheEntry.canvas2dShift.dy,
          width / effectiveScaleX,
          height / effectiveScaleY,
        );
      }
    }

    if (!hasCache) {
      debugRasterizeCount++;
      debugTotalRasterizeCount++;
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
      drawSourceRect,
      drawTargetRect,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }
}
