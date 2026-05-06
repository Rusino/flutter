// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import '../canvaskit/canvaskit_api.dart';
import '../canvaskit/image.dart';
import '../dom.dart';
import 'debug.dart';
import 'layout.dart';
import 'paint.dart';

/// Abstracts the interface for painting text clusters, shadows, and decorations.
abstract class Painter {
  Painter();

  /// Draws the previously filled on Canvas2D text cluster
  void drawTextCluster(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect);

  /// Draws the previously filled on Canvas2D text cluster shadow
  void drawShadowCluster(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect);

  /// Draws the background directly on canvas
  void drawBackground(ui.Canvas canvas, TextBlock block, ui.Rect sourceRect, ui.Rect targetRect);

  /// Draws the previously filled on Canvas2D text decorations
  void drawDecorations(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect);

  void drawParagraph(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect);

  void resetCache();
  bool hasCache();
  num cacheWidth();
  num cacheHeight();

  static double epsilon = 0.001;

  /// Adjust the _paintCanvas scale based on device pixel ratio
  /// With and height are already multiplied by device pixel ratio
  void resizePaintCanvas(double devicePixelRatio, double width, double height) {
    // Since the output canvas is zoomed by device pixel ratio,
    // we need to adjust our paint canvas accordingly to avoid pixelation
    // that would happen if we didn't resize it.
    if (((currentDevicePixelRatio ?? 1.0) - devicePixelRatio).abs() > epsilon) {
      if (currentDevicePixelRatio != null) {
        // We need to reset the scale transform
        print('resizePaintCanvas: restore the context to unscaled state');
        paintContext.restore(); // Restore to unscaled state
        currentDevicePixelRatio = null;
      }
      // We need to rescale the scale transform whenever the device pixel ratio changes
      print('resizePaintCanvas: apply new scale for devicePixelRatio $devicePixelRatio');
      paintContext.scale(devicePixelRatio, devicePixelRatio);
      paintContext.save();
      currentDevicePixelRatio = devicePixelRatio;
      print('resizePaintCanvas: reset cache when DPR changes to $devicePixelRatio');
      resetCache();
    } else if (hasCache() &&
        (cacheWidth() - width.ceilToDouble()).abs() > Painter.epsilon &&
        (cacheHeight() - height.ceilToDouble()).abs() > Painter.epsilon) {
      // Cached image size changed; we need to reset the cache to avoid keeping the old image in memory
      print('resizePaintCanvas: reset cache when its size does not match the required size');
      resetCache();
    }

    if (paintCanvas.width == width.ceilToDouble() && paintCanvas.height == height.ceilToDouble()) {
      // We don't need to resize canvas if the requested size has not changed
      // (At this point it could have been changed for another paragraph only)
      print('resizePaintCanvas: no resize needed for $width x $height @ $devicePixelRatio');
    } else {
      print(
        'resizePaintCanvas: ${paintCanvas.width} x ${paintCanvas.height} => $width x $height @ $devicePixelRatio',
      );
      paintCanvas.width = width.ceilToDouble();
      paintCanvas.height = height.ceilToDouble();
    }
  }
}

class CanvasKitPainter extends Painter {
  CkImage? _singleImageCache;

  @override
  void drawBackground(ui.Canvas canvas, LineBlock block, ui.Rect sourceRect, ui.Rect targetRect) {
    // We need to snap the block edges because Skia draws rectangles with subpixel accuracy
    // and we end up with overlaps (this is only a problem when colors have transparency)
    // or gaps between blocks (which looks unacceptable - vertical lines between blocks).
    // Whether we snap to floor or ceil is irrelevant as long as we are consistent on both sides
    // (and will possibly have problems when glyph boundaries are outside of advance rectangles)
    final snappedRect = ui.Rect.fromLTRB(
      targetRect.left.roundToDouble(),
      targetRect.top.roundToDouble(),
      targetRect.right.roundToDouble(),
      targetRect.bottom.roundToDouble(),
    );
    canvas.drawRect(snappedRect, block.style.background!);
  }

  @override
  void drawDecorations(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect) {
    throw UnimplementedError('Decoration drawing is not implemented yet');
  }

  @override
  void drawShadowCluster(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect) {
    throw UnimplementedError('Shadow drawing is not implemented yet');
  }

  @override
  void drawTextCluster(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect) {
    throw UnimplementedError('Text cluster drawing is not implemented yet');
  }

  @override
  void drawParagraph(ui.Canvas canvas, ui.Rect sourceRect, ui.Rect targetRect) {
    // We should have resized the small canvas before calling this method
    if ((sourceRect.width - paintCanvas.width!).abs() > Painter.epsilon ||
        (sourceRect.height - paintCanvas.height!).abs() > Painter.epsilon) {
      assert(
        false,
        'ERROR: resizePaintCanvas needed: '
        'canvas=${paintCanvas.width}x${paintCanvas.height} vs bounds=${sourceRect.width}x${sourceRect.height}',
      );
      print(
        'ERROR: canvas ${paintCanvas.width}x${paintCanvas.height} has not been resized for ${sourceRect.width}x${sourceRect.height}',
      );
    }

    // We need to reset the cache before drawing if the size of the paragraph has changed to avoid keeping the old image in memory
    if (_singleImageCache != null &&
        ((sourceRect.width != _singleImageCache!.width) ||
            (sourceRect.height != _singleImageCache!.height))) {
      assert(
        false,
        'ERROR: cache has not been reset: '
        'canvas=${paintCanvas.width}x${paintCanvas.height} vs bounds=${sourceRect.width}x${sourceRect.height}',
      );
      print(
        'ERROR: cache has not been reset: '
        'canvas=${paintCanvas.width}x${paintCanvas.height} vs bounds=${sourceRect.width}x${sourceRect.height}',
      );
    }

    if (_singleImageCache == null) {
      final DomImageData imageData = paintContext.getImageData(
        0,
        0,
        sourceRect.width.ceil(),
        sourceRect.height.ceil(),
      );

      final imageInfo = SkImageInfo(
        alphaType: canvasKit.AlphaType.Unpremul,
        colorType: canvasKit.ColorType.RGBA_8888,
        colorSpace: SkColorSpaceSRGB,
        width: sourceRect.width,
        height: sourceRect.height,
      );
      final SkImage? skImage = canvasKit.MakeImage(
        imageInfo,
        Uint8List.view(imageData.data.buffer),
        4 * sourceRect.width,
      );

      // Transfer the buffer from the small canvas
      // This is synchronous and returns the handle immediately
      //final DomImageBitmap bitmap = paintCanvas.transferToImageBitmap();
      //final SkImage? skImage = canvasKit.MakeLazyImageFromImageBitmap(bitmap, true);

      if (skImage == null) {
        throw Exception('Failed to convert text image bitmap to an SkImage.');
      }
      _singleImageCache = CkImage(skImage);
    } else {
      print(
        'drawParagraph: using cached image for sourceRect ${sourceRect.width}x${sourceRect.height}',
      );
    }

    canvas.drawImageRect(
      _singleImageCache!,
      sourceRect,
      targetRect,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  @override
  void resetCache() {
    if (_singleImageCache != null) {
      _singleImageCache!.dispose();
      _singleImageCache = null;
    }
    if (hasCache()) {
      WebParagraphDebug.error('ERROR: resetCache');
    }
  }

  @override
  bool hasCache() {
    return _singleImageCache != null;
  }

  @override
  num cacheHeight() {
    return _singleImageCache != null ? _singleImageCache!.height : 0.0;
  }

  @override
  num cacheWidth() {
    return _singleImageCache != null ? _singleImageCache!.width : 0.0;
  }
}
