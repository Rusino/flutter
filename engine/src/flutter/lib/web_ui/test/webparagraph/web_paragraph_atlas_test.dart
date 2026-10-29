// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart';

import '../common/test_initialization.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

Future<void> testMain() async {
  const region = Rect.fromLTWH(0, 0, 600, 600);
  setUpUnitTests();

  setUp(() {
    WebParagraphAtlas.instance.debugForceFallbackUpload = false;
    WebParagraphAtlas.instance.reset();
  });

  tearDown(() {
    WebParagraphAtlas.instance.debugForceFallbackUpload = false;
    WebParagraphAtlas.instance.reset();
  });

  WebParagraph buildParagraph(
    String text, {
    double fontSize = 20,
    Color color = const Color(0xFFFF0000),
    Color? backgroundColor,
    TextDecoration? decoration,
    List<Shadow>? shadows,
    double maxWidth = 300,
  }) {
    final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Arial', fontSize: fontSize));
    Paint? bgPaint;
    if (backgroundColor != null) {
      bgPaint = Paint()..color = backgroundColor;
    }
    builder.pushStyle(
      TextStyle(
        color: color,
        fontSize: fontSize,
        background: bgPaint,
        decoration: decoration,
        shadows: shadows,
      ),
    );
    builder.addText(text);
    final paragraph = builder.build() as WebParagraph;
    paragraph.layout(ParagraphConstraints(width: maxWidth));
    return paragraph;
  }

  test('packs multiple paragraphs onto a shared AtlasPage without slot overlap', () {
    expect(
      WebParagraphAtlas.instance.resolveTargetSurface(),
      CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
    );
    if (CanvasKitRenderer.instance.isSoftware) {
      return;
    }
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final paragraphs = <WebParagraph>[
        for (int i = 0; i < 24; i++)
          buildParagraph(
            'Atlas item #$i',
            fontSize: 14 + (i % 4) * 3.0,
            color: Color(0xFF000000 | ((i * 37) & 0xFFFFFF)),
          ),
      ];

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);
      for (var i = 0; i < paragraphs.length; i++) {
        paragraphs[i].paint(canvas, Offset(8.0, i * 22.0));
      }
      final Picture picture = recorder.endRecording();
      final Image snapshot = picture.toImageSync(320, 560);
      snapshot.dispose();
      picture.dispose();

      expect(WebParagraphAtlas.instance.debugPageCount, 1);

      final slots = <AtlasParagraphSlot>[];
      for (final paragraph in paragraphs) {
        expect(paragraph.debugRasterizeCount, 1);
        final painter = paragraph.debugPainter as CanvasKitPainter;
        expect(painter.hasCache, isTrue);
        expect(painter.debugAtlasSlot, isNotNull);
        slots.add(painter.debugAtlasSlot!);
      }

      // Every pair of slots on the same page must preserve at least a 2px gutter gap.
      for (var i = 0; i < slots.length; i++) {
        expect(identical(slots[i].page, slots.first.page), isTrue);
        final Rect inflatedA = slots[i].sourceRect.inflate(
          WebParagraphAtlas.gutter.toDouble() - 0.01,
        );
        for (int j = i + 1; j < slots.length; j++) {
          final Rect inflatedB = slots[j].sourceRect.inflate(
            WebParagraphAtlas.gutter.toDouble() - 0.01,
          );
          expect(inflatedA.overlaps(inflatedB), isFalse);
        }
      }

      // Subsequent frame at scrolled fractional offsets reuses existing slots with zero uploads.
      final int uploadsBeforeScroll = WebParagraphAtlas.instance.debugSubImageUploadCount;
      final scrollRecorder = PictureRecorder();
      final scrollCanvas = Canvas(scrollRecorder, region);
      for (var i = 0; i < paragraphs.length; i++) {
        paragraphs[i].paint(scrollCanvas, Offset(8.35, i * 22.0 - 11.75));
        expect(paragraphs[i].debugRasterizeCount, 1);
      }
      final Picture scrollPicture = scrollRecorder.endRecording();
      final Image scrollSnapshot = scrollPicture.toImageSync(320, 560);
      scrollSnapshot.dispose();
      scrollPicture.dispose();

      expect(WebParagraphAtlas.instance.debugSubImageUploadCount, uploadsBeforeScroll);

      for (final paragraph in paragraphs) {
        paragraph.dispose();
      }
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('renders non-empty crisp pixels and preserves premultiplied alpha via atlas', () async {
    expect(
      WebParagraphAtlas.instance.resolveTargetSurface(),
      CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
    );
    if (CanvasKitRenderer.instance.isSoftware) {
      return;
    }
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      for (final forceFallback in <bool>[false, true]) {
        WebParagraphAtlas.instance.reset();
        WebParagraphAtlas.instance.debugForceFallbackUpload = forceFallback;

        final WebParagraph solidRed = buildParagraph(
          'MMMM',
          fontSize: 36,
          decoration: TextDecoration.underline,
          shadows: const <Shadow>[
            Shadow(color: Color(0x800000FF), offset: Offset(2, 2), blurRadius: 3),
          ],
          maxWidth: 220,
        );
        final WebParagraph translucentRed = buildParagraph(
          'MMMM',
          fontSize: 36,
          color: const Color(0x80FF0000),
          maxWidth: 220,
        );

        const width = 240;
        const height = 160;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
        // Fill upper half with opaque white and lower half with opaque green.
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 240, 80),
          Paint()..color = const Color(0xFFFFFFFF),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 80, 240, 80),
          Paint()..color = const Color(0xFF00FF00),
        );
        solidRed.paint(canvas, const Offset(16, 12));
        translucentRed.paint(canvas, const Offset(16, 92));

        final Picture picture = recorder.endRecording();
        final Image image = picture.toImageSync(width, height);
        final ByteData? byteData = await image.toByteData();
        expect(byteData, isNotNull);
        final Uint8List rgba = byteData!.buffer.asUint8List();

        var redInkPixels = 0;
        var shadowBluePixels = 0;
        var blendedYellowishPixels = 0;

        for (var y = 0; y < 80; y++) {
          for (var x = 0; x < width; x++) {
            final int idx = (y * width + x) * 4;
            final int r = rgba[idx];
            final int g = rgba[idx + 1];
            final int b = rgba[idx + 2];
            final int a = rgba[idx + 3];
            expect(a, 255);
            if (r > 200 && g < 60 && b < 60) {
              redInkPixels++;
            }
            if (b > r + 20 && b > g + 20) {
              shadowBluePixels++;
            }
          }
        }

        // Far corner outside paragraph bounds must remain untouched pure white.
        expect(rgba[0], 255);
        expect(rgba[1], 255);
        expect(rgba[2], 255);
        expect(rgba[3], 255);

        for (var y = 80; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final int idx = (y * width + x) * 4;
            final int r = rgba[idx];
            final int g = rgba[idx + 1];
            final int b = rgba[idx + 2];
            final int a = rgba[idx + 3];
            expect(a, 255);
            // 50% red over opaque green blends to ~ (128, 127, 0).
            if (r > 90 && r < 170 && g > 90 && g < 170 && b < 30) {
              blendedYellowishPixels++;
            }
          }
        }

        expect(redInkPixels, greaterThan(50));
        expect(shadowBluePixels, greaterThan(10));
        expect(blendedYellowishPixels, greaterThan(50));

        image.dispose();
        picture.dispose();
        solidRed.dispose();
        translucentRed.dispose();
      }
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('recycles LRU atlas page when exceeding maxPages and invalidates evicted slots', () {
    expect(
      WebParagraphAtlas.instance.resolveTargetSurface(),
      CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
    );
    if (CanvasKitRenderer.instance.isSoftware) {
      return;
    }
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      // Build tall paragraphs (~1150px high) so each requires its own 2048x2048 AtlasPage.
      final String tallText = List<String>.filled(26, 'Tall atlas eviction line').join('\n');
      final paragraphs = <WebParagraph>[
        for (int i = 0; i < WebParagraphAtlas.maxPages + 1; i++)
          buildParagraph('$tallText #$i', fontSize: 36, maxWidth: 1200),
      ];

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1400, 1400));

      for (var i = 0; i < WebParagraphAtlas.maxPages; i++) {
        expect(paragraphs[i].height, greaterThan(1050));
        expect(paragraphs[i].height, lessThan(1900));
        paragraphs[i].paint(canvas, Offset.zero);
        expect(paragraphs[i].debugRasterizeCount, 1);
      }
      expect(WebParagraphAtlas.instance.debugPageCount, WebParagraphAtlas.maxPages);

      // Touch paragraphs[0] so paragraphs[1] becomes the least-recently-used page.
      paragraphs[0].paint(canvas, const Offset(4, 4));
      expect(paragraphs[0].debugRasterizeCount, 1);

      // Painting the 5th tall paragraph recycles paragraphs[1]'s page within maxPages.
      paragraphs[WebParagraphAtlas.maxPages].paint(canvas, Offset.zero);
      expect(WebParagraphAtlas.instance.debugPageCount, WebParagraphAtlas.maxPages);
      expect(paragraphs[0].debugPainter.hasCache, isTrue);
      expect(paragraphs[1].debugPainter.hasCache, isFalse);

      // Re-painting the evicted paragraph cleanly re-rasterizes it onto the next LRU page.
      paragraphs[1].paint(canvas, Offset.zero);
      expect(paragraphs[1].debugRasterizeCount, 2);
      expect(paragraphs[1].debugPainter.hasCache, isTrue);

      recorder.endRecording().dispose();
      for (final paragraph in paragraphs) {
        paragraph.dispose();
      }
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('falls back to standalone image for oversized paragraphs and survives rasterizer reset', () {
    expect(
      WebParagraphAtlas.instance.resolveTargetSurface(),
      CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
    );
    if (CanvasKitRenderer.instance.isSoftware) {
      return;
    }
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(3.0);

      // At DPR 3.0, width ~900 logical px -> ~2700 physical px (> maxSlotDimension 2046).
      final WebParagraph oversized = buildParagraph(
        List<String>.filled(40, 'Wide').join(' '),
        fontSize: 28,
        maxWidth: 950,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 400));
      oversized.paint(canvas, Offset.zero);

      final oversizedPainter = oversized.debugPainter as CanvasKitPainter;
      expect(oversizedPainter.debugAtlasSlot, isNull);
      expect(oversizedPainter.hasCache, isTrue);
      expect(oversized.debugRasterizeCount, 1);

      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);
      final WebParagraph normal = buildParagraph('Context reset check', fontSize: 22);
      normal.paint(canvas, const Offset(10, 80));
      final normalPainter = normal.debugPainter as CanvasKitPainter;
      expect(normalPainter.debugAtlasSlot, isNotNull);
      expect(normalPainter.hasCache, isTrue);
      expect(normal.debugRasterizeCount, 1);

      // Rotation preserves effective scale and reuses the atlas slot.
      canvas.save();
      canvas.rotate(math.pi / 6);
      normal.paint(canvas, const Offset(10, 80));
      canvas.restore();
      expect(normal.debugRasterizeCount, 1);
      recorder.endRecording().dispose();

      // Resetting the rasterizer tears down the GL context and invalidates cached atlas slots.
      CanvasKitRenderer.instance.debugResetRasterizer();
      expect(WebParagraphAtlas.instance.debugPageCount, 0);
      expect(normalPainter.hasCache, isFalse);

      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2, region);
      normal.paint(canvas2, const Offset(10, 80));
      final Picture picture2 = recorder2.endRecording();
      final Image snapshot2 = picture2.toImageSync(300, 150);
      expect(normal.debugRasterizeCount, 2);
      expect(normalPainter.hasCache, isTrue);

      snapshot2.dispose();
      picture2.dispose();
      oversized.dispose();
      normal.dispose();
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test(
    'evicting an atlas page mid-frame or with a retained Picture preserves earlier pixels',
    () async {
      expect(
        WebParagraphAtlas.instance.resolveTargetSurface(),
        CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
      );
      if (CanvasKitRenderer.instance.isSoftware) {
        return;
      }
      final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
      try {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

        final String tallText = List<String>.filled(
          26,
          'Atlas eviction pixel preservation',
        ).join('\n');
        final WebParagraph redTall = buildParagraph('$tallText red', fontSize: 36, maxWidth: 1200);
        final blues = <WebParagraph>[
          for (int i = 0; i < WebParagraphAtlas.maxPages; i++)
            buildParagraph(
              '$tallText blue $i',
              fontSize: 36,
              color: const Color(0xFF0000FF),
              maxWidth: 1200,
            ),
        ];

        const width = 400;
        const height = 200;
        const rect = Rect.fromLTWH(0, 0, 400, 200);

        // Part A: Single Picture recording where earlier paragraph is evicted mid-frame by subsequent paragraphs.
        final singleRecorder = PictureRecorder();
        final singleCanvas = Canvas(singleRecorder, rect);
        singleCanvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
        redTall.paint(singleCanvas, const Offset(10, 10));

        for (var i = 0; i < blues.length; i++) {
          blues[i].paint(singleCanvas, const Offset(200, 10));
        }
        expect(WebParagraphAtlas.instance.debugPageCount, WebParagraphAtlas.maxPages);

        final Picture singlePicture = singleRecorder.endRecording();
        final Image singleImage = singlePicture.toImageSync(width, height);
        final ByteData? singleData = await singleImage.toByteData();
        expect(singleData, isNotNull);
        final Uint8List singleRgba = singleData!.buffer.asUint8List();

        var leftRedCount = 0;
        var rightBlueCount = 0;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final int idx = (y * width + x) * 4;
            final int r = singleRgba[idx];
            final int g = singleRgba[idx + 1];
            final int b = singleRgba[idx + 2];
            if (x < 180 && r > 200 && g < 60 && b < 60) {
              leftRedCount++;
            }
            if (x >= 200 && b > 200 && r < 60 && g < 60) {
              rightBlueCount++;
            }
          }
        }
        expect(leftRedCount, greaterThan(30));
        expect(rightBlueCount, greaterThan(30));

        singleImage.dispose();
        singlePicture.dispose();

        // Part B: Retained Picture whose atlas page is evicted by later independent draw calls.
        final retainedRecorder = PictureRecorder();
        final retainedCanvas = Canvas(retainedRecorder, rect);
        retainedCanvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
        redTall.paint(retainedCanvas, const Offset(10, 10));
        final Picture retainedPic = retainedRecorder.endRecording();

        // Painting the blues again forces redTall's page to be evicted while retainedPic is still alive.
        final dummyRecorder = PictureRecorder();
        final dummyCanvas = Canvas(dummyRecorder, rect);
        for (var i = 0; i < blues.length; i++) {
          blues[i].paint(dummyCanvas, Offset.zero);
        }
        dummyRecorder.endRecording().dispose();

        // Compose retainedPic onto a new surface and snapshot.
        final composeRecorder = PictureRecorder();
        final composeCanvas = Canvas(composeRecorder, rect);
        composeCanvas.drawPicture(retainedPic);
        final Picture composedPic = composeRecorder.endRecording();
        final Image composedImage = composedPic.toImageSync(width, height);
        final ByteData? composedData = await composedImage.toByteData();
        expect(composedData, isNotNull);
        final Uint8List composedRgba = composedData!.buffer.asUint8List();

        var composedRedCount = 0;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < 180; x++) {
            final int idx = (y * width + x) * 4;
            final int r = composedRgba[idx];
            final int g = composedRgba[idx + 1];
            final int b = composedRgba[idx + 2];
            if (r > 200 && g < 60 && b < 60) {
              composedRedCount++;
            }
          }
        }
        expect(composedRedCount, greaterThan(30));

        composedImage.dispose();
        composedPic.dispose();
        retainedPic.dispose();

        expect(WebParagraphAtlas.instance.debugRetiredPageCount, 0);

        redTall.dispose();
        for (final blue in blues) {
          blue.dispose();
        }
      } finally {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
      }
    },
  );

  test(
    'invalidates cached atlas slots on debugOverrideRasterizer and surface context recreation',
    () {
      expect(
        WebParagraphAtlas.instance.resolveTargetSurface(),
        CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
      );
      if (CanvasKitRenderer.instance.isSoftware) {
        return;
      }
      final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
      try {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

        final WebParagraph paragraph = buildParagraph('Rasterizer reset invariant', fontSize: 24);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, region);
        paragraph.paint(canvas, const Offset(10, 10));
        final painter = paragraph.debugPainter as CanvasKitPainter;
        expect(painter.hasCache, isTrue);
        recorder.endRecording().dispose();

        // debugOverrideRasterizer resets the singleton WebParagraphAtlas and invalidates cached slots.
        CanvasKitRenderer.instance.debugOverrideRasterizer(CanvasKitRenderer.instance.rasterizer);
        expect(WebParagraphAtlas.instance.debugPageCount, 0);
        expect(painter.hasCache, isFalse);

        // Re-painting re-creates the atlas on the new rasterizer.
        final recorder2 = PictureRecorder();
        final canvas2 = Canvas(recorder2, region);
        paragraph.paint(canvas2, const Offset(10, 10));
        expect(painter.hasCache, isTrue);
        recorder2.endRecording().dispose();

        // Surface disposal invalidates bound atlas slots.
        final CkOffscreenSurface? surface = WebParagraphAtlas.instance.resolveTargetSurface();
        expect(surface, isNotNull);
        surface!.dispose();
        expect(painter.hasCache, isFalse);

        CanvasKitRenderer.instance.debugResetRasterizer();
        paragraph.dispose();
      } finally {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
      }
    },
  );

  test('restores 2D context state when paintToCanvas2D throws and leaves page usable', () async {
    expect(
      WebParagraphAtlas.instance.resolveTargetSurface(),
      CanvasKitRenderer.instance.isSoftware ? isNull : isNotNull,
    );
    if (CanvasKitRenderer.instance.isSoftware) {
      return;
    }
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final CkOffscreenSurface surface = WebParagraphAtlas.instance.resolveTargetSurface()!;
      expect(
        () => WebParagraphAtlas.instance.rasterizeIntoSlot(
          surface: surface,
          width: 80,
          height: 40,
          effectiveScaleX: 1.0,
          effectiveScaleY: 1.0,
          paintToCanvas2D: (DomCanvasRenderingContext2D ctx) {
            ctx.translate(500, 500);
            throw StateError('Simulated painter exception.');
          },
        ),
        throwsStateError,
      );

      // Subsequent legitimate paragraph painted onto the same page renders at correct origin.
      final WebParagraph normal = buildParagraph('Clean state after throw', fontSize: 24);
      const width = 300;
      const height = 100;
      const rect = Rect.fromLTWH(0, 0, 300, 100);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, rect);
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
      normal.paint(canvas, const Offset(12, 12));
      final Picture picture = recorder.endRecording();
      final Image image = picture.toImageSync(width, height);
      final ByteData? data = await image.toByteData();
      expect(data, isNotNull);
      final Uint8List rgba = data!.buffer.asUint8List();

      var redCount = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final int idx = (y * width + x) * 4;
          final int r = rgba[idx];
          final int g = rgba[idx + 1];
          final int b = rgba[idx + 2];
          if (r > 200 && g < 60 && b < 60) {
            redCount++;
          }
        }
      }
      expect(redCount, greaterThan(30));

      image.dispose();
      picture.dispose();
      normal.dispose();
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });
}
