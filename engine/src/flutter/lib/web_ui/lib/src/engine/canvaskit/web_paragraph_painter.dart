// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import '../primitives/image.dart';
import '../web_paragraph/painter.dart';
import 'canvaskit_api.dart';
import 'image.dart';

class _ParagraphCacheKey {
  const _ParagraphCacheKey({
    required this.devicePixelRatio,
    required this.scaleX,
    required this.scaleY,
  });

  final double devicePixelRatio;
  final double scaleX;
  final double scaleY;

  bool matches({required double devicePixelRatio, required double scaleX, required double scaleY}) {
    return this.devicePixelRatio == devicePixelRatio &&
        this.scaleX == scaleX &&
        this.scaleY == scaleY;
  }
}

class CanvasKitPainter extends WebParagraphPainter {
  CanvasKitPainter(super.paragraph);

  EngineImage? _singleImageCache;
  _ParagraphCacheKey? _lastCacheKey;

  @override
  bool get hasCache => _singleImageCache != null;

  @override
  void clearCache() {
    _singleImageCache?.dispose();
    _singleImageCache = null;
    _lastCacheKey = null;
  }

  @override
  void paintParagraphText(
    ui.Canvas canvas,
    ui.Rect sourceRect,
    ui.Rect targetRect, {
    required ParagraphImageGenerator generateParagraphImage,
    required ui.Offset canvas2dShift,
    required double scaleX,
    required double scaleY,
  }) {
    final double dpr = ui.window.devicePixelRatio;
    if (_lastCacheKey == null ||
        !_lastCacheKey!.matches(devicePixelRatio: dpr, scaleX: scaleX, scaleY: scaleY)) {
      clearCache();
      _lastCacheKey = _ParagraphCacheKey(devicePixelRatio: dpr, scaleX: scaleX, scaleY: scaleY);
    }

    if (!hasCache) {
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
      _singleImageCache = EngineImage(
        CkImageDelegate(skImage),
        skImage.width().toInt(),
        skImage.height().toInt(),
      );
    }

    canvas.drawImageRect(
      _singleImageCache!,
      sourceRect,
      targetRect,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }
}
