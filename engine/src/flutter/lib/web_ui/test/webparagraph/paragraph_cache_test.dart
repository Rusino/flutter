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
  const region = Rect.fromLTWH(0, 0, 500, 500);
  setUpUnitTests();

  test('WebParagraph matches 2D subpixel phase and renders 1:1 in physical pixels', () {
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      for (final dpr in <double>[1.0, 1.5, 2.0, 2.5]) {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(dpr);

        final arialStyle = WebParagraphStyle(fontFamily: 'Arial', fontSize: 50);
        final builder = WebParagraphBuilder(arialStyle);
        builder.pushStyle(WebTextStyle(color: const Color(0xFF000000)));
        builder.addText('Subpixel aligned text');
        final WebParagraph paragraph = builder.build();
        paragraph.layout(const ParagraphConstraints(width: double.infinity));

        const offset = Offset(10.25, 20.75); // Subpixel offset in logical coordinates

        // Verify that 2D subpixel fractional phases on Canvas2D (source) match target offset fractional phases
        final (Rect sourceRect, Rect targetRect, Offset canvas2dShift) = calculateParagraphForTest(
          paragraph,
          offset,
          dpr,
        );

        // Verify sourceRect dimensions are exact integers in physical pixels
        expect(sourceRect.width % 1.0, 0.0);
        expect(sourceRect.height % 1.0, 0.0);

        // Verify targetRect in logical units matches sourceRect physical dimensions when scaled by dpr
        expect(targetRect.width * dpr, closeTo(sourceRect.width, 1e-5));
        expect(targetRect.height * dpr, closeTo(sourceRect.height, 1e-5));

        final double targetPhysicalX = offset.dx * dpr;
        final double targetFracX = targetPhysicalX - targetPhysicalX.floorToDouble();
        final double sourcePhysicalShiftX = canvas2dShift.dx * dpr;
        final double sourceFracX = sourcePhysicalShiftX - sourcePhysicalShiftX.floorToDouble();
        expect(sourceFracX, closeTo(targetFracX, 0.0001));

        final double targetPhysicalY = offset.dy * dpr;
        final double targetFracY = targetPhysicalY - targetPhysicalY.floorToDouble();
        final double sourcePhysicalShiftY = canvas2dShift.dy * dpr;
        final double sourceFracY = sourcePhysicalShiftY - sourcePhysicalShiftY.floorToDouble();
        expect(sourceFracY, closeTo(targetFracY, 0.0001));
      }
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraph calculateParagraph with transform scales and translations', () {
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);
      const dpr = 1.0;
      final arialStyle = WebParagraphStyle(fontFamily: 'Arial', fontSize: 20);
      final builder = WebParagraphBuilder(arialStyle);
      builder.pushStyle(WebTextStyle(color: const Color(0xFF000000)));
      builder.addText('Test scaling and translation');
      final WebParagraph paragraph = builder.build();
      paragraph.layout(const ParagraphConstraints(width: 200));

      const offset = Offset(10.35, 20.65);

      // Matrix with scale 1.5x, 2.0y and translation (30.25, 40.75)
      final transform = Float64List.fromList(<double>[
        1.5,
        0.0,
        0.0,
        0.0,
        0.0,
        2.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        30.25,
        40.75,
        0.0,
        1.0,
      ]);

      final (Rect sourceRect, Rect targetRect, Offset canvas2dShift) = calculateParagraphForTest(
        paragraph,
        offset,
        dpr,
        transform,
      );

      const double effectiveScaleX = dpr * 1.5;
      const double effectiveScaleY = dpr * 2.0;

      // Verify sourceRect dimensions are exact integers in physical pixels
      expect(sourceRect.width % 1.0, 0.0);
      expect(sourceRect.height % 1.0, 0.0);

      // Verify targetRect logical size corresponds to sourceRect / effectiveScale
      expect(targetRect.width * effectiveScaleX, closeTo(sourceRect.width, 1e-5));
      expect(targetRect.height * effectiveScaleY, closeTo(sourceRect.height, 1e-5));

      // Verify physical subpixel alignment with translation taken into account
      final double physicalOffsetX = offset.dx * effectiveScaleX + 30.25 * dpr;
      final double targetFracX = physicalOffsetX - physicalOffsetX.floorToDouble();
      final double sourcePhysicalShiftX = canvas2dShift.dx * effectiveScaleX;
      final double sourceFracX = sourcePhysicalShiftX - sourcePhysicalShiftX.floorToDouble();
      expect(sourceFracX, closeTo(targetFracX, 0.0001));

      final double physicalOffsetY = offset.dy * effectiveScaleY + 40.75 * dpr;
      final double targetFracY = physicalOffsetY - physicalOffsetY.floorToDouble();
      final double sourcePhysicalShiftY = canvas2dShift.dy * effectiveScaleY;
      final double sourceFracY = sourcePhysicalShiftY - sourcePhysicalShiftY.floorToDouble();
      expect(sourceFracY, closeTo(targetFracY, 0.0001));
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter dual-mode cache policy for static vs scrolling text', () async {
    // -------------------------------------------------------------------------------------------------------------------------------------------------
    // Dual-mode Cache Test Matrix (pinned dpr = 1.0):
    // | Case | Frame # | State / Intent                                | Offset           | Bin   | Frame Gap | hasDelta | _wasMoving | isScrolling | Count | Action & Rationale                                                                      |
    // |:----:|:-------:|:----------------------------------------------|:-----------------|:-----:|:---------:|:--------:|:----------:|:-----------:|:-----:|:----------------------------------------------------------------------------------------|
    // |  1   |   100   | Initial Paint                                 | (10.1, 20.1)     | Bin 0 |    N/A    |  false   |   false    |    false    | 0->1  | Rasterize #1 (Bin 0): Empty cache in Frame 100.                                         |
    // |  2   |   100   | Static: Identical offset                      | (10.1, 20.1)     | Bin 0 |     0     |  false   |   false    |    false    | 1->1  | Cache Hit: Same offset, exact Bin 0 match.                                              |
    // |  3a  |   101   | Static: Shift + fractional shift (same bin)   | (60.12, 70.12)   | Bin 0 |     1     |   true   |   false    |    false    | 1->1  | Cache Hit: Δ=50px, but 0.12 is in same Bin 0 [0.0, 0.25). Starts motion (_wasMoving=t). |
    // |  3b  |   102   | Static: Settle at rest                        | (60.12, 70.12)   | Bin 0 |     1     |  false   |    true    |    false    | 1->1  | Cache Hit (Settled): Settled at rest; matches Bin 0; resets _wasMoving=false.          |
    // |  4   |   103   | Scroll Seq 1: Frame 1 (Move to Bin 1)         | (60.35, 70.35)   | Bin 1 |     1     |   true   |   false    |    false    | 1->2  | Rasterize #2 (Bin 1): First move from rest, Bin 1 != Bin 0. Starts motion (_wasMoving=t)|
    // |  5   |   104   | Scroll Seq 1: Frame 2 (Move to Bin 2)         | (60.6, 70.6)     | Bin 2 |     1     |   true   |    true    |    true     | 2->2  | Cache Hit: Confirmed scrolling -> reuses cache across bin change to preserve 60/120 FPS.|
    // |  6   |   105   | Scroll Seq 1: Frame 3 (Move to Bin 3)         | (60.85, 70.85)   | Bin 3 |     1     |   true   |    true    |    true     | 2->2  | Cache Hit: Confirmed scrolling -> continues cache reuse.                                 |
    // |  7   |   106   | Scroll Seq 1: Settle in Different Bin         | (60.85, 70.85)   | Bin 3 |     1     |  false   |    true    |    false    | 2->3  | Rasterize #3 (Bin 3): Stopped (delta=0). Settled Bin 3 != cached Bin 1 -> redraw once. |
    // |  8   |   107   | Scroll Seq 2: Frame 1 (Move to Bin 0)         | (10.1, 20.1)     | Bin 0 |     1     |   true   |   false    |    false    | 3->4  | Rasterize #4 (Bin 0): First move from rest, Bin 0 != Bin 3. Starts motion (_wasMoving=t)|
    // |  9   |   108   | Scroll Seq 2: Frame 2 (Move within Bin 0)     | (10.2, 20.2)     | Bin 0 |     1     |   true   |    true    |    true     | 4->4  | Cache Hit: Confirmed scrolling -> reuses cache. Offset also in Bin 0.                   |
    // |  10  |   109   | Scroll Seq 2: Settle in Same Bin              | (10.2, 20.2)     | Bin 0 |     1     |  false   |    true    |    false    | 4->4  | Cache Hit (Settled): Stopped (delta=0). Settled Bin 0 == cached Bin 0 -> reuse cache!   |
    // -------------------------------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Dual-mode Caching Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // =========================================================================
      // SECTION 1: Static Cases
      // =========================================================================

      // -------------------------------------------------------------------------
      // Case 1: Initial paint at Frame 100, Offset(10.1, 20.1)
      // - Current count: 0 (no cache exists yet).
      // - Offset fractional parts: dx=0.1, dy=0.1 -> maps to Bin 0 [0.0, 0.25).
      // - Expected: Must rasterize a new SkImage cache entry for Bin 0. Count becomes 1.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(100);
      expect(painter.debugRasterizeCount, 0);
      painter.paint(canvas, const Offset(10.1, 20.1));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // -------------------------------------------------------------------------
      // Case 2: Re-paint at identical Offset(10.1, 20.1) in Frame 100
      // - Current count: 1 (cached at Bin 0).
      // - Offset: delta = 0, exact subpixel bin match (Bin 0 == Bin 0).
      // - Expected: Clean cache hit. Count stays 1.
      // -------------------------------------------------------------------------
      expect(painter.debugRasterizeCount, 1);
      painter.paint(canvas, const Offset(10.1, 20.1));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // -------------------------------------------------------------------------
      // Case 3a: Frame 101 -> Shift with slight fractional difference within 100px limit, same Bin 0: Offset(60.12, 70.12)
      // - Current count: 1 (cached at Bin 0).
      // - Offset: delta = 50.02 px (<= 100.0 px). Fractional parts: dx=0.12, dy=0.12 -> still in Bin 0 [0.0, 0.25).
      // - First move from rest (_wasMoving = false -> isScrolling = false).
      // - Subpixel phase check: current Bin 0 matches cached Bin 0.
      // - Expected: Reuses cache because both fall in Bin 0. Count stays 1. Starts motion (_wasMoving = true).
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(101);
      expect(painter.debugRasterizeCount, 1);
      painter.paint(canvas, const Offset(60.12, 70.12));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // -------------------------------------------------------------------------
      // Case 3b: Frame 102 -> Settle at rest at Offset(60.12, 70.12)
      // - Current count: 1 (cached at Bin 0).
      // - Delta = 0 -> static/settled mode (isScrolling = false, _wasMoving resets to false).
      // - Subpixel phase check: Bin 0 matches cached Bin 0.
      // - Expected: Reuses cache upon settling. Count stays 1.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(102);
      expect(painter.debugRasterizeCount, 1);
      painter.paint(canvas, const Offset(60.12, 70.12));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // =========================================================================
      // SECTION 2: Scrolling Sequence 1 (Settling in a different subpixel bin)
      // =========================================================================

      // -------------------------------------------------------------------------
      // Case 4: Frame 103 -> First move to Bin 1 at Offset(60.35, 70.35)
      // - Current count: 1 (cached at Bin 0).
      // - Offset fractional parts: dx=0.35, dy=0.35 -> maps to Bin 1 [0.25, 0.50).
      // - First move from rest (_wasMoving is false -> isScrolling is false).
      // - Subpixel phase check: Bin 1 != cached Bin 0.
      // - Expected: Phase bin mismatch forces re-rasterization for Bin 1. Count becomes 2. Starts motion (_wasMoving = true).
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(103);
      expect(painter.debugRasterizeCount, 1);
      painter.paint(canvas, const Offset(60.35, 70.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // -------------------------------------------------------------------------
      // Case 5: Frame 104 -> Second scrolling move in sequence to Bin 2 at Offset(60.6, 70.6)
      // - Current count: 2 (cached at Bin 1).
      // - Delta = 0.25 px. _wasMoving is true, frameGap = 1 -> isScrolling evaluates to true (confirmed active scrolling).
      // - Expected: Active scrolling disregards subpixel bin change (Bin 2 vs Bin 1) to preserve 60/120 FPS. Count stays 2.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(104);
      expect(painter.debugRasterizeCount, 2);
      painter.paint(canvas, const Offset(60.6, 70.6));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // -------------------------------------------------------------------------
      // Case 6: Frame 105 -> Third scrolling move in sequence to Bin 3 at Offset(60.85, 70.85)
      // - Current count: 2 (cached at Bin 1).
      // - Delta = 0.25 px. _wasMoving is true, frameGap = 1 -> isScrolling is true.
      // - Expected: Continuous scrolling continues to reuse scale-matched cache. Count stays 2.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(105);
      expect(painter.debugRasterizeCount, 2);
      painter.paint(canvas, const Offset(60.85, 70.85));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // -------------------------------------------------------------------------
      // Case 7: Frame 106 -> Scroll sequence 1 stops / settles at Offset(60.85, 70.85)
      // - Current count: 2 (cached at Bin 1).
      // - Delta = 0 -> isScrolling is false, _wasMoving resets to false.
      // - Settled subpixel phase check: current position is Bin 3, but cached image is Bin 1.
      // - Expected: Settled phase bin mismatch forces re-rasterization for Bin 3 (100% crisp static text). Count becomes 3.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(106);
      expect(painter.debugRasterizeCount, 2);
      painter.paint(canvas, const Offset(60.85, 70.85));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // =========================================================================
      // SECTION 3: Scrolling Sequence 2 (Settling in the same subpixel bin)
      // =========================================================================

      // -------------------------------------------------------------------------
      // Case 8: Frame 107 -> First move of sequence 2 from rest to Bin 0 at Offset(10.1, 20.1)
      // - Current count: 3 (cached at Bin 3).
      // - Delta = 50.75 px (<= 100.0 px). Fractional parts: dx=0.1, dy=0.1 -> maps to Bin 0 [0.0, 0.25).
      // - First move from rest (_wasMoving is false -> isScrolling is false).
      // - Subpixel phase check: Bin 0 != cached Bin 3.
      // - Expected: Phase bin mismatch forces re-rasterization for Bin 0. Count becomes 4. Starts motion (_wasMoving = true).
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(107);
      expect(painter.debugRasterizeCount, 3);
      painter.paint(canvas, const Offset(10.1, 20.1));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);

      // -------------------------------------------------------------------------
      // Case 9: Frame 108 -> Second scrolling move in sequence 2 to Offset(10.2, 20.2) (still in Bin 0)
      // - Current count: 4 (cached at Bin 0).
      // - Delta = 0.1 px. _wasMoving is true, frameGap = 1 -> isScrolling is true (confirmed active scrolling).
      // - Fractional parts: dx=0.2, dy=0.2 (falls in same Bin 0).
      // - Expected: Active scrolling reuses scale-matched cache. Count stays 4.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(108);
      expect(painter.debugRasterizeCount, 4);
      painter.paint(canvas, const Offset(10.2, 20.2));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);

      // -------------------------------------------------------------------------
      // Case 10: Frame 109 -> Scroll sequence 2 stops / settles at Offset(10.2, 20.2)
      // - Current count: 4 (cached at Bin 0).
      // - Delta = 0 -> isScrolling is false, _wasMoving resets to false.
      // - Settled subpixel phase check: current position is in Bin 0, which matches cached Bin 0 (from Case 8).
      // - Expected: Settled phase matches cached bin -> reuses cache without redrawing! Count stays 4.
      // -------------------------------------------------------------------------
      FrameService.instance.debugSetFrameNumber(109);
      expect(painter.debugRasterizeCount, 4);
      painter.paint(canvas, const Offset(10.2, 20.2));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
      FrameService.instance.debugResetFrameData();
    }
  });

  test('WebParagraphPainter static cache policy across different device pixel ratios', () async {
    // -------------------------------------------------------------------------------------------------------------------------
    // Static DPR Test Matrix:
    // | Step | DPR | Logical Offset   | Physical Offset  | Physical Bin  | Delta from prior | Count | Action & Rationale                                                   |
    // |:----:|:---:|:----------------:|:----------------:|:-------------:|:----------------:|:-----:|:---------------------------------------------------------------------|
    // |  1a  | 1.0 | (10.0, 20.0)     | (10.0, 20.0)     | Bin 0 [0,.25) |       N/A        | 0->1  | Rasterize #1 (DPR 1.0, Bin 0): Empty cache.                          |
    // |  1b  | 1.0 | (10.0, 20.0)     | (10.0, 20.0)     | Bin 0 [0,.25) |       0.0        | 1->1  | Cache Hit: Same offset and DPR.                                      |
    // |  2a  | 1.0 | (10.1, 20.1)     | (10.1, 20.1)     | Bin 0 [0,.25) |       0.1        | 1->1  | Cache Hit (Same Bin 0): Physical fraction 0.10 is in Bin 0.          |
    // |  2b  | 1.0 | (10.1, 20.1)     | (10.1, 20.1)     | Bin 0 [0,.25) |       0.0        | 1->1  | Cache Hit (Settled): Settled at Bin 0.                               |
    // |  3a  | 1.0 | (10.35, 20.35)   | (10.35, 20.35)   | Bin 1 [.25,.5)|       0.25       | 1->2  | Rasterize #2 (DPR 1.0, Bin 1): Physical fraction 0.35 -> Bin 1 != 0. |
    // |  3b  | 1.0 | (10.35, 20.35)   | (10.35, 20.35)   | Bin 1 [.25,.5)|       0.0        | 2->2  | Cache Hit (Settled): Settled at Bin 1.                               |
    // |  4a  | 2.0 | (10.35, 20.35)   | (20.7, 40.7)     | Bin 2 [.5,.75)|    0.0 (offset)  | 2->3  | Rasterize #3 (DPR 2.0, Bin 2): Scale mismatch (1.0 != 2.0).          |
    // |  4b  | 2.0 | (10.35, 20.35)   | (20.7, 40.7)     | Bin 2 [.5,.75)|       0.0        | 3->3  | Cache Hit (Settled): Settled at DPR 2.0, Bin 2.                      |
    // |  5a  | 2.0 | (10.85, 20.85)   | (21.7, 41.7)     | Bin 2 [.5,.75)|     0.5 (log)    | 3->3  | Cache Hit (Same Bin 2): Logical Δ=0.5 -> Physical Δ=1.0 -> Bin 2.    |
    // |  5b  | 2.0 | (10.85, 20.85)   | (21.7, 41.7)     | Bin 2 [.5,.75)|       0.0        | 3->3  | Cache Hit (Settled): Settled at Bin 2.                               |
    // |  6a  | 2.0 | (10.95, 20.95)   | (21.9, 41.9)     | Bin 3 [.75,1) |     0.1 (log)    | 3->4  | Rasterize #4 (DPR 2.0, Bin 3): Physical fraction 0.90 -> Bin 3 != 2. |
    // |  6b  | 2.0 | (10.95, 20.95)   | (21.9, 41.9)     | Bin 3 [.75,1) |       0.0        | 4->4  | Cache Hit (Settled): Settled at Bin 3.                               |
    // |  7a  | 1.5 | (10.0, 20.0)     | (15.0, 30.0)     | Bin 0 [0,.25) |       N/A        | 4->5  | Rasterize #5 (DPR 1.5, Bin 0): Scale mismatch (2.0 != 1.5).          |
    // |  7b  | 1.5 | (10.0, 20.0)     | (15.0, 30.0)     | Bin 0 [0,.25) |       0.0        | 5->5  | Cache Hit (Settled): Settled at DPR 1.5, Bin 0.                      |
    // |  8a  | 1.5 | (10.2, 20.2)     | (15.3, 30.3)     | Bin 1 [.25,.5)|     0.2 (log)    | 5->6  | Rasterize #6 (DPR 1.5, Bin 1): Physical fraction 0.30 -> Bin 1 != 0. |
    // |  8b  | 1.5 | (10.2, 20.2)     | (15.3, 30.3)     | Bin 1 [.25,.5)|       0.0        | 6->6  | Cache Hit (Settled): Settled at Bin 1.                               |
    // |  9a  | 1.5 | (10.25, 20.25)   | (15.375, 30.375) | Bin 1 [.25,.5)|    0.05 (log)    | 6->6  | Cache Hit (Same Bin 1): Physical fraction 0.375 is in Bin 1.         |
    // |  9b  | 1.5 | (10.25, 20.25)   | (15.375, 30.375) | Bin 1 [.25,.5)|       0.0        | 6->6  | Cache Hit (Settled): Settled at Bin 1.                               |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Static DPR Caching Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // =======================================================================
      // PART 1: DPR = 1.0
      // =======================================================================
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      // Step 1a/1b: Initial paint at Offset(10.0, 20.0) -> Bin 0 [0.0, 0.25)
      expect(painter.debugRasterizeCount, 0);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 2a/2b: Shift to Offset(10.1, 20.1) -> physical fraction 0.10 is in same Bin 0
      painter.paint(canvas, const Offset(10.1, 20.1));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      painter.paint(canvas, const Offset(10.1, 20.1));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 3a/3b: Shift to Offset(10.35, 20.35) -> physical fraction 0.35 is in Bin 1 [0.25, 0.50)
      painter.paint(canvas, const Offset(10.35, 20.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      painter.paint(canvas, const Offset(10.35, 20.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // =======================================================================
      // PART 2: DPR = 2.0 (Scale mismatch invalidates cache)
      // =======================================================================
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(2.0);

      // Step 4a/4b: Same logical Offset(10.35, 20.35) at DPR 2.0 -> physical (20.7, 40.7) in Bin 2
      painter.paint(canvas, const Offset(10.35, 20.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      painter.paint(canvas, const Offset(10.35, 20.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 5a/5b: Shift by +0.5 logical px -> physical offset (21.7, 41.7) (+1.0 physical px, same Bin 2)
      painter.paint(canvas, const Offset(10.85, 20.85));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      painter.paint(canvas, const Offset(10.85, 20.85));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 6a/6b: Shift to Offset(10.95, 20.95) -> physical offset (21.9, 41.9) in Bin 3 [0.75, 1.0)
      painter.paint(canvas, const Offset(10.95, 20.95));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);

      painter.paint(canvas, const Offset(10.95, 20.95));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);

      // =======================================================================
      // PART 3: DPR = 1.5 (Scale mismatch invalidates cache)
      // =======================================================================
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.5);

      // Step 7a/7b: Offset(10.0, 20.0) at DPR 1.5 -> physical (15.0, 30.0) in Bin 0 [0.0, 0.25)
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 5);

      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 5);

      // Step 8a/8b: Shift to Offset(10.2, 20.2) -> physical (15.3, 30.3) in Bin 1 [0.25, 0.50)
      painter.paint(canvas, const Offset(10.2, 20.2));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 6);

      painter.paint(canvas, const Offset(10.2, 20.2));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 6);

      // Step 9a/9b: Shift to Offset(10.25, 20.25) -> physical (15.375, 30.375) in same Bin 1 [0.25, 0.50)
      painter.paint(canvas, const Offset(10.25, 20.25));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 6);

      painter.paint(canvas, const Offset(10.25, 20.25));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 6);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test(
    'WebParagraphPainter consecutive frame tracking distinguishes 60 FPS scrolling from slow discrete ticks',
    () {
      // -------------------------------------------------------------------------------------------------------------------------------------------------
      // Frame Sequence & Velocity Test Matrix (pinned dpr = 1.0):
      // | Step | Frame # | Logical Offset   | Bin   | Frame Gap | hasDelta | _wasMoving | isScrolling | Count | Action & Rationale                                                   |
      // |:----:|:-------:|:----------------:|:-----:|:---------:|:--------:|:----------:|:-----------:|:-----:|:---------------------------------------------------------------------|
      // |  1   |   100   | (10.1, 20.1)     | Bin 0 |    N/A    |  false   |   false    |    false    | 0->1  | Rasterize #1 (Bin 0): Empty cache.                                   |
      // |  2   |   101   | (10.35, 20.35)   | Bin 1 |     1     |   true   |   false    |    false    | 1->2  | Rasterize #2 (Bin 1): First move from rest, Bin 1 != Bin 0. Motion t.|
      // |  3   |   102   | (10.6, 20.6)     | Bin 2 |     1     |   true   |    true    |    true     | 2->2  | Cache Hit: Consecutive frame motion active -> reuses cache at 60 FPS.|
      // |  4   |   103   | (160.85, 20.85)  | Bin 3 |     1     |   true   |    true    |    true     | 2->2  | Cache Hit: High-velocity fling (150px) allowed during active motion. |
      // |  5   |   163   | (160.1, 20.1)    | Bin 0 |    60     |   true   |   false    |    false    | 2->3  | Rasterize #3 (Bin 0): 1s tick (gap=60 > 2) forces crisp static settle|
      // |  6   |   164   | (500.35, 20.35)  | Bin 1 |     1     |   true   |   false    |    false    | 3->4  | Rasterize #4 (Bin 1): Teleport from rest (>100px) rejects motion.    |
      // |  7   |   165   | (500.35, 20.35)  | Bin 1 |     1     |  false   |   false    |    false    | 4->4  | Cache Hit (Settled): Settled at rest; matches cached Bin 1.          |
      // -------------------------------------------------------------------------------------------------------------------------------------------------
      final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
      try {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

        final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
        builder.addText('Frame Sequence Test');
        final paragraph = builder.build() as WebParagraph;
        paragraph.layout(const ParagraphConstraints(width: 300));

        final painter = CanvasKitPainter(paragraph);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, region);

        // -------------------------------------------------------------------------
        // Step 1: Initial paint at Frame 100, Offset(10.1, 20.1) -> Rasterize #1 (Bin 0)
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(100);
        painter.paint(canvas, const Offset(10.1, 20.1));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 1);

        // -------------------------------------------------------------------------
        // Step 2: Frame 101 (Consecutive frame N+1) -> Move to Bin 1 at Offset(10.35, 20.35)
        // - First move from rest (_wasMoving = false -> isScrolling = false).
        // - Bin 1 != Bin 0 -> Rasterize #2 for Bin 1. Starts motion (_wasMoving = true).
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(101);
        painter.paint(canvas, const Offset(10.35, 20.35));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 2);

        // -------------------------------------------------------------------------
        // Step 3: Frame 102 (Consecutive frame N+1) -> Continuous 60 FPS scroll to Bin 2 at Offset(10.6, 20.6)
        // - Frame gap = 1 <= 2 and _wasMoving = true -> isScrolling = true.
        // - Loose cache matching -> Clean Cache Hit! (Count stays 2)
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(102);
        painter.paint(canvas, const Offset(10.6, 20.6));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 2);

        // -------------------------------------------------------------------------
        // Step 4: Frame 103 (Consecutive frame N+1) -> High-velocity fling jump of 150px to Offset(160.85, 20.85)
        // - Confirmed active motion (_wasMoving && isConsecutive) -> High velocity allowed -> Clean Cache Hit! (Count stays 2)
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(103);
        painter.paint(canvas, const Offset(160.85, 20.85));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 2);

        // -------------------------------------------------------------------------
        // Step 5: Frame 163 (Non-consecutive frame gap of 60 frames = 1s later) -> Slow timer tick to Offset(160.1, 20.1)
        // - Frame gap = 60 > 2 -> isConsecutive = false -> isScrolling = false!
        // - Strict subpixel bin matching detects Bin 0 != cached Bin 1 -> forces Rasterize #3 for 100% crisp text!
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(163);
        painter.paint(canvas, const Offset(160.1, 20.1));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 3);

        // -------------------------------------------------------------------------
        // Step 6: Frame 164 (Consecutive frame N+1) -> Large discrete jump / teleport from rest of 340px to Offset(500.35, 20.35)
        // - Starting from rest (_wasMoving = false) with delta > 100px (canInitiateMotion = false).
        // - Motion is rejected -> isScrolling = false, _wasMoving stays false.
        // - Strict subpixel phase check detects Bin 1 != cached Bin 0 -> forces Rasterize #4 (crisp static teleport).
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(164);
        painter.paint(canvas, const Offset(500.35, 20.35));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 4);

        // -------------------------------------------------------------------------
        // Step 7: Frame 165 -> Settled at rest at Offset(500.35, 20.35)
        // - Delta = 0, exact Bin 1 match -> Clean Cache Hit! (Count stays 4)
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(165);
        painter.paint(canvas, const Offset(500.35, 20.35));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 4);
      } finally {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
        FrameService.instance.debugResetFrameData();
      }
    },
  );

  test('WebParagraph sourceRect includes antialiasing safety padding to prevent glyph clipping', () {
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      for (final dpr in <double>[1.0, 1.5, 2.0]) {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(dpr);

        final arialStyle = WebParagraphStyle(fontFamily: 'Arial', fontSize: 32);
        final builder = WebParagraphBuilder(arialStyle);
        builder.pushStyle(WebTextStyle(color: const Color(0xFF000000)));
        builder.addText('Typography glyph test with descenders: gy_j');
        final WebParagraph paragraph = builder.build();
        paragraph.layout(const ParagraphConstraints(width: double.infinity));

        const offset = Offset(15.35, 25.65);
        final (Rect sourceRect, Rect targetRect, Offset canvas2dShift) = calculateParagraphForTest(
          paragraph,
          offset,
          dpr,
        );

        final double shiftPhysicalX = canvas2dShift.dx * dpr;
        final double shiftPhysicalY = canvas2dShift.dy * dpr;

        // Verify that physical sourceRect dimensions match (shift + paintBounds + kAntialiasingPadding).ceilToDouble()
        final double expectedPhysicalWidth =
            (shiftPhysicalX + paragraph.paintBounds.right * dpr + 2.0).ceilToDouble();
        final double expectedPhysicalHeight =
            (shiftPhysicalY + paragraph.paintBounds.bottom * dpr + 2.0).ceilToDouble();

        expect(sourceRect.width, expectedPhysicalWidth);
        expect(sourceRect.height, expectedPhysicalHeight);
      }
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter validates horizontal and vertical subpixel phase bins independently', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // 2D Axis Test Matrix (pinned dpr = 1.0):
    // | Step | Logical Offset   | Bin X | Bin Y | Description                                          | Count | Action & Rationale                                                   |
    // |:----:|:----------------:|:-----:|:-----:|:-----------------------------------------------------|:-----:|:---------------------------------------------------------------------|
    // |  1   | (10.10, 20.10)   | Bin 0 | Bin 0 | Initial Paint                                        | 0->1  | Rasterize #1 (Bin 0,0): Empty cache.                                 |
    // |  2   | (10.10, 20.10)   | Bin 0 | Bin 0 | Settled at rest                                      | 1->1  | Cache Hit: Same offset.                                              |
    // |  3   | (10.35, 20.10)   | Bin 1 | Bin 0 | Shift ONLY X to Bin 1 (Y stays Bin 0)                | 1->2  | Rasterize #2 (Bin 1,0): Horizontal bin mismatch forces redraw.       |
    // |  4   | (10.35, 20.10)   | Bin 1 | Bin 0 | Settled at rest                                      | 2->2  | Cache Hit (Settled): Settled at Bin (1,0).                           |
    // |  5   | (10.35, 20.60)   | Bin 1 | Bin 2 | Shift ONLY Y to Bin 2 (X stays Bin 1)                | 2->3  | Rasterize #3 (Bin 1,2): Vertical bin mismatch forces redraw.         |
    // |  6   | (10.35, 20.60)   | Bin 1 | Bin 2 | Settled at rest                                      | 3->3  | Cache Hit (Settled): Settled at Bin (1,2).                           |
    // |  7   | (10.38, 20.62)   | Bin 1 | Bin 2 | Shift both within same bins: X in Bin 1, Y in Bin 2  | 3->3  | Cache Hit: Both axes fall within cached phase bins.                  |
    // |  8   | (10.38, 20.62)   | Bin 1 | Bin 2 | Settled at rest                                      | 3->3  | Cache Hit (Settled): Settled at same phase bins.                     |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('2D Subpixel Axes Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1 & 2: Initial paint and settle at Bin (0, 0)
      expect(painter.debugRasterizeCount, 0);
      painter.paint(canvas, const Offset(10.10, 20.10));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      painter.paint(canvas, const Offset(10.10, 20.10));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 3 & 4: Shift ONLY X to Bin 1 (10.35) -> Bin (1, 0)
      painter.paint(canvas, const Offset(10.35, 20.10));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      painter.paint(canvas, const Offset(10.35, 20.10));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // Step 5 & 6: Shift ONLY Y to Bin 2 (20.60) -> Bin (1, 2)
      painter.paint(canvas, const Offset(10.35, 20.60));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      painter.paint(canvas, const Offset(10.35, 20.60));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 7 & 8: Small shift keeping both X (0.38) and Y (0.62) inside Bin 1 and Bin 2
      painter.paint(canvas, const Offset(10.38, 20.62));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      painter.paint(canvas, const Offset(10.38, 20.62));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter invalidates cache when canvas transform scale changes', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Canvas Transform Scale Invalidation Matrix (pinned dpr = 1.0):
    // | Step | Canvas Scale | Logical Offset | Effective Scale | Cached Scale | Count | Action & Rationale                                                   |
    // |:----:|:------------:|:--------------:|:---------------:|:------------:|:-----:|:---------------------------------------------------------------------|
    // |  1   | 1.0x         | (10.0, 20.0)   | (1.0x, 1.0x)    |     N/A      | 0->1  | Rasterize #1 (Scale 1.0x): Initial paint, empty cache.               |
    // |  2   | 1.0x         | (10.0, 20.0)   | (1.0x, 1.0x)    | (1.0x, 1.0x) | 1->1  | Cache Hit: Same scale and offset.                                    |
    // |  3   | 1.25x        | (10.0, 20.0)   | (1.25x, 1.25x)  | (1.0x, 1.0x) | 1->2  | Rasterize #2 (Scale 1.25x): Scale mismatch (1.0 != 1.25) invalidates.|
    // |  4   | 1.25x        | (10.0, 20.0)   | (1.25x, 1.25x)  | (1.25x,1.25x)| 2->2  | Cache Hit: Reuses 1.25x cache.                                       |
    // |  5   | 0.75x        | (10.0, 20.0)   | (0.75x, 0.75x)  | (1.25x,1.25x)| 2->3  | Rasterize #3 (Scale 0.75x): Scale mismatch (1.25 != 0.75) invalidates.|
    // |  6   | 0.75x        | (10.0, 20.0)   | (0.75x, 0.75x)  | (0.75x,0.75x)| 3->3  | Cache Hit: Reuses 0.75x cache.                                       |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Scale Zoom Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1 & 2: Paint at identity scale (1.0x)
      canvas.save();
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);
      canvas.restore();

      // Step 3 & 4: Zoom to 1.25x scale -> Scale mismatch invalidates cache
      canvas.save();
      canvas.scale(1.25, 1.25);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);
      canvas.restore();

      // Step 5 & 6: Zoom to 0.75x scale -> Scale mismatch invalidates cache
      canvas.save();
      canvas.scale(0.75, 0.75);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);
      canvas.restore();
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter clearCache resets cache and forces fresh rasterization', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Explicit clearCache() Test Matrix:
    // | Step | Action                               | hasCache | Count | Action & Rationale                                                   |
    // |:----:|:-------------------------------------|:--------:|:-----:|:---------------------------------------------------------------------|
    // |  1   | Initial Paint at (10.0, 20.0)        |   true   | 0->1  | Rasterize #1: Initial paint creates SkImage cache entry.              |
    // |  2   | Call painter.clearCache()            |  false   | 1->1  | Cache Cleared: Disposes SkImage and sets cache entry to null.        |
    // |  3   | Repaint at identical (10.0, 20.0)    |   true   | 1->2  | Rasterize #2: Empty cache forces fresh rasterization.                 |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('ClearCache Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1: Initial paint
      expect(painter.hasCache, isFalse);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 2: Explicitly clear cache
      painter.clearCache();
      expect(painter.hasCache, isFalse);

      // Step 3: Paint again at identical offset -> Forces fresh rasterization
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter handles negative offsets and phase binning correctly', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Negative Offsets Test Matrix (pinned dpr = 1.0):
    // | Step | Logical Offset   | Floor Offset     | Fractional Phase | Bin   | Count | Action & Rationale                                                   |
    // |:----:|:----------------:|:----------------:|:----------------:|:-----:|:-----:|:---------------------------------------------------------------------|
    // |  1a  | (-5.90, -10.90)  | (-6.0, -11.0)    | (0.10, 0.10)     | Bin 0 | 0->1  | Rasterize #1 (Bin 0): Empty cache, negative fraction maps to Bin 0.  |
    // |  1b  | (-5.90, -10.90)  | (-6.0, -11.0)    | (0.10, 0.10)     | Bin 0 | 1->1  | Cache Hit (Settled): Settled at identical negative offset.           |
    // |  2a  | (-5.65, -10.65)  | (-6.0, -11.0)    | (0.35, 0.35)     | Bin 1 | 1->2  | Rasterize #2 (Bin 1): First move from rest, Bin 1 != Bin 0.          |
    // |  2b  | (-5.65, -10.65)  | (-6.0, -11.0)    | (0.35, 0.35)     | Bin 1 | 2->2  | Cache Hit (Settled): Settled at Bin 1; resets _wasMoving = false.    |
    // |  3a  | (-5.35, -10.35)  | (-6.0, -11.0)    | (0.65, 0.65)     | Bin 2 | 2->3  | Rasterize #3 (Bin 2): First move from rest, Bin 2 != Bin 1.          |
    // |  3b  | (-5.35, -10.35)  | (-6.0, -11.0)    | (0.65, 0.65)     | Bin 2 | 3->3  | Cache Hit (Settled): Settled at Bin 2; resets _wasMoving = false.    |
    // |  4a  | (-5.15, -10.15)  | (-6.0, -11.0)    | (0.85, 0.85)     | Bin 3 | 3->4  | Rasterize #4 (Bin 3): First move from rest, Bin 3 != Bin 2.          |
    // |  4b  | (-5.15, -10.15)  | (-6.0, -11.0)    | (0.85, 0.85)     | Bin 3 | 4->4  | Cache Hit (Settled): Settled at Bin 3; resets _wasMoving = false.    |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Negative Offset Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1a: Initial paint at Offset(-5.90, -10.90) -> Bin 0 [0.0, 0.25)
      // Fractional phase: -5.9 - (-5.9).floor() = -5.9 - (-6.0) = 0.10 -> Bin 0
      expect(painter.debugRasterizeCount, 0);
      painter.paint(canvas, const Offset(-5.9, -10.9));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 1b: Settle at rest at identical Offset(-5.90, -10.90) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(-5.9, -10.9));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 2a: Shift to Offset(-5.65, -10.65) -> frac 0.35 -> Bin 1 [0.25, 0.50)
      painter.paint(canvas, const Offset(-5.65, -10.65));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // Step 2b: Settle at rest at Offset(-5.65, -10.65) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(-5.65, -10.65));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // Step 3a: Shift to Offset(-5.35, -10.35) -> frac 0.65 -> Bin 2 [0.50, 0.75)
      painter.paint(canvas, const Offset(-5.35, -10.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 3b: Settle at rest at Offset(-5.35, -10.35) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(-5.35, -10.35));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 4a: Shift to Offset(-5.15, -10.15) -> frac 0.85 -> Bin 3 [0.75, 1.00)
      painter.paint(canvas, const Offset(-5.15, -10.15));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);

      // Step 4b: Settle at rest at Offset(-5.15, -10.15) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(-5.15, -10.15));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 4);

      // Verify calculateParagraphForTest with negative offset
      final (Rect sourceRect, Rect targetRect, Offset canvas2dShift) = calculateParagraphForTest(
        paragraph,
        const Offset(-5.65, -10.25),
        1.0,
      );
      expect(sourceRect.width % 1.0, 0.0);
      expect(sourceRect.height % 1.0, 0.0);
      expect(targetRect.width, closeTo(sourceRect.width, 1e-5));
      expect(targetRect.height, closeTo(sourceRect.height, 1e-5));
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter respects exact subpixel bin boundaries and floating-point edge transitions', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Subpixel Bin Boundaries & Epsilon Test Matrix (pinned dpr = 1.0):
    // | Step | Logical Offset   | Fractional Phase | Target Bin   | Count | Action & Rationale                                                   |
    // |:----:|:----------------:|:----------------:|:------------:|:-----:|:---------------------------------------------------------------------|
    // |  1a  | (10.0000, 20.0)  | 0.0000           | Bin 0 [0,.25)| 0->1  | Rasterize #1 (Bin 0): Exact lower boundary 0.0 starts Bin 0.         |
    // |  1b  | (10.0000, 20.0)  | 0.0000           | Bin 0 [0,.25)| 1->1  | Cache Hit (Settled): Settled at Bin 0; resets _wasMoving = false.    |
    // |  2a  | (10.2499, 20.24) | 0.2499           | Bin 0 [0,.25)| 1->1  | Cache Hit: Upper epsilon 0.2499 stays in Bin 0.                      |
    // |  2b  | (10.2499, 20.24) | 0.2499           | Bin 0 [0,.25)| 1->1  | Cache Hit (Settled): Settled at Bin 0; resets _wasMoving = false.    |
    // |  3a  | (10.2500, 20.25) | 0.2500           | Bin 1 [.25,.5)| 1->2  | Rasterize #2 (Bin 1): Exact boundary 0.25 switches to Bin 1.         |
    // |  3b  | (10.2500, 20.25) | 0.2500           | Bin 1 [.25,.5)| 2->2  | Cache Hit (Settled): Settled at Bin 1; resets _wasMoving = false.    |
    // |  4a  | (10.4999, 20.49) | 0.4999           | Bin 1 [.25,.5)| 2->2  | Cache Hit: Upper epsilon 0.4999 stays in Bin 1.                      |
    // |  4b  | (10.4999, 20.49) | 0.4999           | Bin 1 [.25,.5)| 2->2  | Cache Hit (Settled): Settled at Bin 1; resets _wasMoving = false.    |
    // |  5a  | (10.5000, 20.50) | 0.5000           | Bin 2 [.5,.75)| 2->3  | Rasterize #3 (Bin 2): Exact boundary 0.50 switches to Bin 2.         |
    // |  5b  | (10.5000, 20.50) | 0.5000           | Bin 2 [.5,.75)| 3->3  | Cache Hit (Settled): Settled at Bin 2; resets _wasMoving = false.    |
    // |  6a  | (10.7499, 20.74) | 0.7499           | Bin 2 [.5,.75)| 3->3  | Cache Hit: Upper epsilon 0.7499 stays in Bin 2.                      |
    // |  6b  | (10.7499, 20.74) | 0.7499           | Bin 2 [.5,.75)| 3->3  | Cache Hit (Settled): Settled at Bin 2; resets _wasMoving = false.    |
    // |  7a  | (10.7500, 20.75) | 0.7500           | Bin 3 [.75,1)| 3->4  | Rasterize #4 (Bin 3): Exact boundary 0.75 switches to Bin 3.         |
    // |  7b  | (10.7500, 20.75) | 0.7500           | Bin 3 [.75,1)| 4->4  | Cache Hit (Settled): Settled at Bin 3; resets _wasMoving = false.    |
    // |  8a  | (10.9999, 20.99) | 0.9999           | Bin 3 [.75,1)| 4->4  | Cache Hit: Upper epsilon 0.9999 stays in Bin 3.                      |
    // |  8b  | (10.9999, 20.99) | 0.9999           | Bin 3 [.75,1)| 4->4  | Cache Hit (Settled): Settled at Bin 3; resets _wasMoving = false.    |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Bin Boundary Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1a: Exactly 0.0 -> Bin 0 [0.0, 0.25) -> Initial paint
      expect(painter.debugRasterizeCount, 0);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.debugRasterizeCount, 1);

      // Step 1b: Settle at rest at Offset(10.0, 20.0) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.debugRasterizeCount, 1);

      // Step 2a: 0.2499 -> Inside same Bin 0 -> Cache hit (upper epsilon)
      painter.paint(canvas, const Offset(10.2499, 20.2499));
      expect(painter.debugRasterizeCount, 1);

      // Step 2b: Settle at rest at Offset(10.2499, 20.2499) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.2499, 20.2499));
      expect(painter.debugRasterizeCount, 1);

      // Step 3a: Exact boundary 0.25 -> Bin 1 [0.25, 0.50) -> Rasterize #2
      painter.paint(canvas, const Offset(10.25, 20.25));
      expect(painter.debugRasterizeCount, 2);

      // Step 3b: Settle at rest at Offset(10.25, 20.25) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.25, 20.25));
      expect(painter.debugRasterizeCount, 2);

      // Step 4a: 0.4999 -> Inside same Bin 1 -> Cache hit (upper epsilon)
      painter.paint(canvas, const Offset(10.4999, 20.4999));
      expect(painter.debugRasterizeCount, 2);

      // Step 4b: Settle at rest at Offset(10.4999, 20.4999) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.4999, 20.4999));
      expect(painter.debugRasterizeCount, 2);

      // Step 5a: Exact boundary 0.50 -> Bin 2 [0.50, 0.75) -> Rasterize #3
      painter.paint(canvas, const Offset(10.50, 20.50));
      expect(painter.debugRasterizeCount, 3);

      // Step 5b: Settle at rest at Offset(10.50, 20.50) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.50, 20.50));
      expect(painter.debugRasterizeCount, 3);

      // Step 6a: 0.7499 -> Inside same Bin 2 -> Cache hit (upper epsilon)
      painter.paint(canvas, const Offset(10.7499, 20.7499));
      expect(painter.debugRasterizeCount, 3);

      // Step 6b: Settle at rest at Offset(10.7499, 20.7499) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.7499, 20.7499));
      expect(painter.debugRasterizeCount, 3);

      // Step 7a: Exact boundary 0.75 -> Bin 3 [0.75, 1.00) -> Rasterize #4
      painter.paint(canvas, const Offset(10.75, 20.75));
      expect(painter.debugRasterizeCount, 4);

      // Step 7b: Settle at rest at Offset(10.75, 20.75) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.75, 20.75));
      expect(painter.debugRasterizeCount, 4);

      // Step 8a: 0.9999 -> Inside same Bin 3 -> Cache hit (upper epsilon)
      painter.paint(canvas, const Offset(10.9999, 20.9999));
      expect(painter.debugRasterizeCount, 4);

      // Step 8b: Settle at rest at Offset(10.9999, 20.9999) -> Resets _wasMoving = false
      painter.paint(canvas, const Offset(10.9999, 20.9999));
      expect(painter.debugRasterizeCount, 4);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test(
    'WebParagraphPainter validates motion threshold boundary conditions (100px velocity and frame gap)',
    () {
      // -------------------------------------------------------------------------------------------------------------------------------------------------
      // Motion Threshold Boundary Test Matrix (pinned dpr = 1.0):
      // | Step | Frame # | Offset           | Bin   | Frame Gap | Delta (px) | _wasMoving | isScrolling | Count | Action & Rationale                                       |
      // |:----:|:-------:|:-----------------|:-----:|:---------:|:----------:|:----------:|:-----------:|:-----:|:---------------------------------------------------------|
      // |  1   |   10    | (10.10, 20.10)   | Bin 0 |    N/A    |    N/A     |   false    |    false    | 0->1  | Rasterize #1 (Bin 0): Initial paint from rest.           |
      // |  2   |   12    | (10.35, 20.35)   | Bin 1 |     2     |    0.25    |   false    |    false    | 1->2  | Rasterize #2 (Bin 1): Gap=2 (<=2) starts motion (wasM=t).|
      // |  3   |   14    | (10.60, 20.60)   | Bin 2 |     2     |    0.25    |    true    |    true     | 2->2  | Cache Hit: Gap=2 (<=2) preserves active scrolling.       |
      // |  4   |   17    | (10.85, 20.85)   | Bin 3 |     3     |    0.25    |   false    |    false    | 2->3  | Rasterize #3 (Bin 3): Gap=3 (>2) drops out of motion.    |
      // |  5   |   18    | (110.85, 20.85)  | Bin 3 |     1     |   100.0    |   false    |    false    | 3->3  | Cache Hit: Delta=100.0px (<=100) initiates motion; Bin 3.|
      // |  6   |   19    | (110.85, 20.85)  | Bin 3 |     1     |    0.0     |    true    |    false    | 3->3  | Cache Hit: Settle at rest in Bin 3.                      |
      // |  7   |   20    | (210.95, 20.10)  | Bin 0 |     1     |   100.1    |   false    |    false    | 3->4  | Rasterize #4 (Bin 0): Delta=100.1px (>100) rejects motion|
      // -------------------------------------------------------------------------------------------------------------------------------------------------
      final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
      try {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

        final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
        builder.addText('Threshold Boundaries');
        final paragraph = builder.build() as WebParagraph;
        paragraph.layout(const ParagraphConstraints(width: 300));

        final painter = CanvasKitPainter(paragraph);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, region);

        // Step 1: Initial paint at Frame 10, Offset(10.1, 20.1) -> Rasterize #1 (Bin 0)
        FrameService.instance.debugSetFrameNumber(10);
        painter.paint(canvas, const Offset(10.1, 20.1));
        expect(painter.debugRasterizeCount, 1);

        // Step 2: Frame gap boundary: Gap of exactly 2 frames (Frame 10 -> Frame 12)
        // Allowed as consecutive (gap <= 2). Move to Bin 1 at Offset(10.35, 20.35) -> Starts motion, Rasterize #2.
        FrameService.instance.debugSetFrameNumber(12);
        painter.paint(canvas, const Offset(10.35, 20.35));
        expect(painter.debugRasterizeCount, 2);

        // Step 3: Consecutive active scroll at Frame 14 (gap = 2 <= 2) to Bin 2 -> Cache hit (Count stays 2).
        FrameService.instance.debugSetFrameNumber(14);
        painter.paint(canvas, const Offset(10.6, 20.6));
        expect(painter.debugRasterizeCount, 2);

        // Step 4: Frame gap boundary exceeded: Gap of 3 frames (Frame 14 -> Frame 17) (gap > 2)
        // Drops out of scrolling mode. Offset in Bin 3 -> forces Rasterize #3.
        FrameService.instance.debugSetFrameNumber(17);
        painter.paint(canvas, const Offset(10.85, 20.85));
        expect(painter.debugRasterizeCount, 3);

        // Step 5: Velocity limit from rest boundary: delta = 100.0px (<= 100.0px allowed to initiate motion)
        // At Frame 18 (gap = 1), move dx by 100.0px: (10.85 + 100.0 = 110.85, 20.85) (Bin 3 == cached Bin 3)
        // Delta <= 100px initiates motion (_wasMoving = true). Same bin -> cache hit (Count stays 3).
        FrameService.instance.debugSetFrameNumber(18);
        painter.paint(canvas, const Offset(110.85, 20.85));
        expect(painter.debugRasterizeCount, 3);

        // Step 6: Settle at rest in Bin 3 (delta = 0) -> Resets _wasMoving = false (Count stays 3)
        FrameService.instance.debugSetFrameNumber(19);
        painter.paint(canvas, const Offset(110.85, 20.85));
        expect(painter.debugRasterizeCount, 3);

        // Step 7: Velocity limit from rest exceeded: delta = 100.1px (> 100.0px rejected from rest)
        // From rest (_wasMoving = false), jump to Bin 0 at Offset(210.95, 20.1) -> delta = 100.1px > 100.0px.
        // Rejects motion initiation -> treated as static teleport -> Bin 0 != cached Bin 3 -> forces Rasterize #4.
        FrameService.instance.debugSetFrameNumber(20);
        painter.paint(canvas, const Offset(210.95, 20.1));
        expect(painter.debugRasterizeCount, 4);
      } finally {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
        FrameService.instance.debugResetFrameData();
      }
    },
  );

  test('WebParagraphPainter handles non-uniform canvas scale and complex transforms', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Non-uniform Scale & Complex Transform Test Matrix (pinned dpr = 1.0):
    // | Step | Canvas Scale (X, Y) | Effective Scale | Cached Scale | Count | Action & Rationale                                          |
    // |:----:|:-------------------:|:---------------:|:------------:|:-----:|:------------------------------------------------------------|
    // |  1   |     (1.0, 1.0)      |   (1.0, 1.0)    |     N/A      | 0->1  | Rasterize #1 (1.0x, 1.0x): Initial paint, empty cache.       |
    // |  2   |     (1.5, 0.8)      |   (1.5, 0.8)    |  (1.0, 1.0)  | 1->2  | Rasterize #2 (1.5x, 0.8x): Non-uniform scale mismatch.      |
    // |  3   |     (1.5, 0.8)      |   (1.5, 0.8)    |  (1.5, 0.8)  | 2->2  | Cache Hit: Same non-uniform scale matches cache.            |
    // |  4   |     (0.8, 1.5)      |   (0.8, 1.5)    |  (1.5, 0.8)  | 2->3  | Rasterize #3 (0.8x, 1.5x): Inverted ratio scale mismatch.   |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Non-uniform Scale Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1: Paint at identity scale (1.0, 1.0)
      canvas.save();
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);
      canvas.restore();

      // Step 2: Non-uniform scale (1.5x, 0.8y) -> Scale mismatch invalidates cache
      canvas.save();
      canvas.scale(1.5, 0.8);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // Step 3: Repaint at same non-uniform scale (1.5x, 0.8y) -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);
      canvas.restore();

      // Step 4: Non-uniform scale with different ratio (0.8x, 1.5y) -> Invalidation
      canvas.save();
      canvas.scale(0.8, 1.5);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);
      canvas.restore();
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraph handles empty text paragraph gracefully', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Empty Paragraph Test Matrix (pinned dpr = 1.0):
    // | Step | Text Content | Layout Constraints | Offset       | Count | Action & Rationale                                          |
    // |:----:|:------------:|:------------------:|:------------:|:-----:|:------------------------------------------------------------|
    // |  1   |      ""      |    width: 300.0    | (10.0, 20.0) |  <=1  | Rasterize / Skip: Gracefully handles 0-length paragraph.    |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.debugRasterizeCount, lessThanOrEqualTo(1));
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter combines device pixel ratio with canvas transform scaling', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Combined DPR & Canvas Transform Scale Matrix (pinned dpr = 2.0):
    // | Step | DPR | Canvas Scale | Effective Scale | Cached Scale | Count | Action & Rationale                                                   |
    // |:----:|:---:|:------------:|:---------------:|:------------:|:-----:|:---------------------------------------------------------------------|
    // |  1   | 2.0 |     1.0x     |      2.0x       |     N/A      | 0->1  | Rasterize #1 (Eff. Scale 2.0x): Initial paint with DPR 2.0.          |
    // |  2   | 2.0 |     1.0x     |      2.0x       |     2.0x     | 1->1  | Cache Hit: Matches effective scale 2.0x.                             |
    // |  3   | 2.0 |     1.5x     |      3.0x       |     2.0x     | 1->2  | Rasterize #2 (Eff. Scale 3.0x): Effective scale mismatch (2.0!=3.0). |
    // |  4   | 2.0 |     1.5x     |      3.0x       |     3.0x     | 2->2  | Cache Hit: Matches effective scale 3.0x.                             |
    // |  5   | 2.0 |     0.5x     |      1.0x       |     3.0x     | 2->3  | Rasterize #3 (Eff. Scale 1.0x): Effective scale mismatch (3.0!=1.0). |
    // |  6   | 2.0 |     0.5x     |      1.0x       |     1.0x     | 3->3  | Cache Hit: Matches effective scale 1.0x.                             |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(2.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('DPR + Scale Interplay Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1: Initial paint at DPR 2.0, identity canvas scale (1.0x) -> Effective scale = 2.0x
      canvas.save();
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 2: Repaint at same effective scale (2.0x) -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);
      canvas.restore();

      // Step 3: Zoom canvas to 1.5x at DPR 2.0 -> Effective scale = 3.0x -> Invalidation
      canvas.save();
      canvas.scale(1.5, 1.5);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // Step 4: Repaint at same 1.5x canvas scale (effective 3.0x) -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);
      canvas.restore();

      // Step 5: Scale canvas down to 0.5x at DPR 2.0 -> Effective scale = 1.0x -> Invalidation
      canvas.save();
      canvas.scale(0.5, 0.5);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 6: Repaint at same 0.5x canvas scale (effective 1.0x) -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);
      canvas.restore();
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test('WebParagraphPainter maintains isolated motion tracking across multiple painters', () {
    // -------------------------------------------------------------------------------------------------------------------------------------------------
    // Multi-Painter Isolation Matrix (pinned dpr = 1.0):
    // | Step | Frame # | Painter | Offset         | Bin   | Delta | wasMoving | isScrolling | Count | Action & Rationale                                       |
    // |:----:|:-------:|:-------:|:---------------|:-----:|:-----:|:---------:|:-----------:|:-----:|:---------------------------------------------------------|
    // |  1A  |   100   |    A    | (10.10, 20.10) | Bin 0 |  N/A  |   false   |    false    | 0->1  | Rasterize #1 (A): Initial paint for Painter A.           |
    // |  1B  |   100   |    B    | (30.10, 40.10) | Bin 0 |  N/A  |   false   |    false    | 0->1  | Rasterize #1 (B): Initial paint for Painter B.           |
    // |  2A  |   101   |    A    | (10.35, 20.35) | Bin 1 | 0.25  |   false   |    false    | 1->2  | Rasterize #2 (A): Move to Bin 1 starts motion for A.     |
    // |  2B  |   101   |    B    | (30.10, 40.10) | Bin 0 |  0.0  |   false   |    false    | 1->1  | Cache Hit (B): Static B remains at rest in Bin 0.        |
    // |  3A  |   102   |    A    | (10.60, 20.60) | Bin 2 | 0.25  |   true    |    true     | 2->2  | Cache Hit (A): Active 60 FPS scroll reuses cache for A.  |
    // |  3B  |   102   |    B    | (30.35, 40.35) | Bin 1 | 0.25  |   false   |    false    | 1->2  | Rasterize #2 (B): First move from rest for B; Bin 1!=0.  |
    // |  4A  |   103   |    A    | (10.60, 20.60) | Bin 2 |  0.0  |   true    |    false    | 2->3  | Rasterize #3 (A): A stops (delta=0), settled Bin 2!=Bin 1|
    // |  4B  |   103   |    B    | (30.60, 40.60) | Bin 2 | 0.25  |   true    |    true     | 2->2  | Cache Hit (B): B actively scrolling across bin change.   |
    // -------------------------------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builderA = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builderA.addText('Paragraph A');
      final paragraphA = builderA.build() as WebParagraph;
      paragraphA.layout(const ParagraphConstraints(width: 300));
      final painterA = CanvasKitPainter(paragraphA);

      final builderB = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builderB.addText('Paragraph B');
      final paragraphB = builderB.build() as WebParagraph;
      paragraphB.layout(const ParagraphConstraints(width: 300));
      final painterB = CanvasKitPainter(paragraphB);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1A: Frame 100 -> Initial paint for Painter A at (10.10, 20.10) (Bin 0)
      FrameService.instance.debugSetFrameNumber(100);
      painterA.paint(canvas, const Offset(10.10, 20.10));
      expect(painterA.hasCache, isTrue);
      expect(painterA.debugRasterizeCount, 1);

      // Step 1B: Frame 100 -> Initial paint for Painter B at (30.10, 40.10) (Bin 0)
      painterB.paint(canvas, const Offset(30.10, 40.10));
      expect(painterB.hasCache, isTrue);
      expect(painterB.debugRasterizeCount, 1);

      // Step 2A: Frame 101 -> Painter A moves to Bin 1 at Offset(10.35, 20.35) -> Starts motion for A
      FrameService.instance.debugSetFrameNumber(101);
      painterA.paint(canvas, const Offset(10.35, 20.35));
      expect(painterA.hasCache, isTrue);
      expect(painterA.debugRasterizeCount, 2);

      // Step 2B: Frame 101 -> Painter B stays static at Offset(30.10, 40.10) -> Cache hit for B
      painterB.paint(canvas, const Offset(30.10, 40.10));
      expect(painterB.hasCache, isTrue);
      expect(painterB.debugRasterizeCount, 1);

      // Step 3A: Frame 102 -> Painter A scrolls to Bin 2 at Offset(10.60, 20.60) -> Active scrolling cache hit for A
      FrameService.instance.debugSetFrameNumber(102);
      painterA.paint(canvas, const Offset(10.60, 20.60));
      expect(painterA.hasCache, isTrue);
      expect(painterA.debugRasterizeCount, 2);

      // Step 3B: Frame 102 -> Painter B first moves to Bin 1 at Offset(30.35, 40.35) -> Starts motion for B
      painterB.paint(canvas, const Offset(30.35, 40.35));
      expect(painterB.hasCache, isTrue);
      expect(painterB.debugRasterizeCount, 2);

      // Step 4A: Frame 103 -> Painter A settles at Offset(10.60, 20.60) (delta = 0, settled Bin 2 != cached Bin 1) -> Rasterize #3 for A
      FrameService.instance.debugSetFrameNumber(103);
      painterA.paint(canvas, const Offset(10.60, 20.60));
      expect(painterA.hasCache, isTrue);
      expect(painterA.debugRasterizeCount, 3);

      // Step 4B: Frame 103 -> Painter B continues active scrolling to Bin 2 at Offset(30.60, 40.60) -> Active scroll cache hit for B
      painterB.paint(canvas, const Offset(30.60, 40.60));
      expect(painterB.hasCache, isTrue);
      expect(painterB.debugRasterizeCount, 2);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
      FrameService.instance.debugResetFrameData();
    }
  });

  test('WebParagraphPainter handles canvas rotation and complex matrix transforms', () {
    // -------------------------------------------------------------------------------------------------------------------------
    // Canvas Rotation & Transform Matrix (pinned dpr = 1.0):
    // | Step | Canvas Transform | Offset       | Physical Offset | Target Bin | Count | Action & Rationale                                                   |
    // |:----:|:----------------:|:------------:|:---------------:|:----------:|:-----:|:---------------------------------------------------------------------|
    // |  1   | Identity (0 rad) | (10.0, 20.0) |  (10.0, 20.0)   |  Bin (0,0) | 0->1  | Rasterize #1 (Scale 1.0x, Bin 0,0): Initial paint, empty cache.      |
    // |  2   | Identity (0 rad) | (10.0, 20.0) |  (10.0, 20.0)   |  Bin (0,0) | 1->1  | Cache Hit: Matches scale 1.0x and Bin (0,0).                         |
    // |  3   | Rotate (π/4 rad) | (10.0, 20.0) | (-7.07, 21.21)  |  Bin (3,0) | 1->2  | Rasterize #2: Transformed origin shifts fraction to Bin (3,0) != (0,0)|
    // |  4   | Rotate (π/4 rad) | (10.0, 20.0) | (-7.07, 21.21)  |  Bin (3,0) | 2->2  | Cache Hit: Matches scale 1.0x and Bin (3,0).                         |
    // |  5   | Rotate (π/2 rad) | (10.0, 20.0) |  (-20.0, 10.0)  |  Bin (0,0) | 2->3  | Rasterize #3: 90° rotation shifts origin fraction back to Bin (0,0).  |
    // |  6   | Identity (0 rad) | (10.0, 20.0) |  (10.0, 20.0)   |  Bin (0,0) | 3->3  | Cache Hit: Restored identity matches cached Scale 1.0x & Bin (0,0)!  |
    // |  7   | Identity (0 rad) | (10.0, 20.0) |  (10.0, 20.0)   |  Bin (0,0) | 3->3  | Cache Hit: Matches identity transform and Bin (0,0).                 |
    // -------------------------------------------------------------------------------------------------------------------------
    final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
    try {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

      final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
      builder.addText('Canvas Rotation Test');
      final paragraph = builder.build() as WebParagraph;
      paragraph.layout(const ParagraphConstraints(width: 300));

      final painter = CanvasKitPainter(paragraph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, region);

      // Step 1: Initial paint at identity transform (0 radians) -> Bin (0, 0)
      canvas.save();
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);

      // Step 2: Repaint at identity transform -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 1);
      canvas.restore();

      // Step 3: Rotate canvas by π/4 (45 degrees) -> Transformed offset shifts to Bin (3, 0) -> Rasterize #2
      canvas.save();
      canvas.rotate(math.pi / 4);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);

      // Step 4: Repaint at same π/4 rotation -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 2);
      canvas.restore();

      // Step 5: Rotate canvas by π/2 (90 degrees) -> Transformed offset (-20.0, 10.0) shifts to Bin (0, 0) -> Rasterize #3
      canvas.save();
      canvas.rotate(math.pi / 2);
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);
      canvas.restore();

      // Step 6: Restore canvas to identity transform -> Offset (10.0, 20.0) has Bin (0, 0) matching cache -> Cache Hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);

      // Step 7: Repaint at identity transform -> Cache hit
      painter.paint(canvas, const Offset(10.0, 20.0));
      expect(painter.hasCache, isTrue);
      expect(painter.debugRasterizeCount, 3);
    } finally {
      EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
    }
  });

  test(
    'WebParagraphPainter does not trigger motion detection when painted multiple times in the same frame',
    () {
      // -------------------------------------------------------------------------------------------------------------------------------------------------
      // Same-Frame Multi-Draw Test Matrix (pinned dpr = 1.0):
      // | Step | Frame # | Logical Offset   | Target Bin | Frame Gap | hasDelta | _wasMoving | isScrolling | Count | Action & Rationale                                                   |
      // |:----:|:-------:|:----------------:|:----------:|:---------:|:--------:|:----------:|:-----------:|:-----:|:---------------------------------------------------------------------|
      // |  1   |   100   | (10.10, 20.10)   |   Bin 0    |    N/A    |  false   |   false    |    false    | 0->1  | Rasterize #1 (Bin 0): Initial draw in Frame 100, empty cache.        |
      // |  2   |   100   | (10.35, 20.35)   |   Bin 1    |     0     |   true   |   false    |    false    | 1->2  | Rasterize #2 (Bin 1): Same frame (gap=0) rejects motion; Bin 1!=Bin 0|
      // |  3   |   101   | (10.10, 20.10)   |   Bin 0    |     1     |   true   |   false    |    false    | 2->3  | Rasterize #3 (Bin 0): First draw in Frame 101, gap=1; Bin 0!=Bin 1.  |
      // |  4   |   101   | (10.35, 20.35)   |   Bin 1    |     0     |   true   |   false    |    false    | 3->4  | Rasterize #4 (Bin 1): Same frame (gap=0) rejects motion; Bin 1!=Bin 0|
      // -------------------------------------------------------------------------------------------------------------------------------------------------
      final double originalDpr = EngineFlutterDisplay.instance.devicePixelRatio;
      try {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(1.0);

        final builder = ParagraphBuilder(ParagraphStyle(fontFamily: 'Roboto', fontSize: 16));
        builder.addText('Same Frame Multi-Draw Test');
        final paragraph = builder.build() as WebParagraph;
        paragraph.layout(const ParagraphConstraints(width: 300));

        final painter = CanvasKitPainter(paragraph);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder, region);

        // -------------------------------------------------------------------------
        // Step 1: Initial draw in Frame 100 at Offset(10.10, 20.10) -> Rasterize #1 (Bin 0)
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(100);
        painter.paint(canvas, const Offset(10.10, 20.10));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 1);

        // -------------------------------------------------------------------------
        // Step 2: Second draw in Frame 100 at Offset(10.35, 20.35) in the SAME frame (gap = 0)
        // - Frame gap = 0 -> isConsecutive = false -> isScrolling = false.
        // - Strict subpixel phase check detects Bin 1 != cached Bin 0 -> forces Rasterize #2.
        // -------------------------------------------------------------------------
        painter.paint(canvas, const Offset(10.35, 20.35));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 2);

        // -------------------------------------------------------------------------
        // Step 3: First draw in Frame 101 at Offset(10.10, 20.10)
        // - Frame gap = 1 -> isConsecutive = true, but _wasMoving was false from previous same-frame draw.
        // - Strict subpixel phase check detects Bin 0 != cached Bin 1 -> forces Rasterize #3 (starts motion).
        // -------------------------------------------------------------------------
        FrameService.instance.debugSetFrameNumber(101);
        painter.paint(canvas, const Offset(10.10, 20.10));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 3);

        // -------------------------------------------------------------------------
        // Step 4: Second draw in Frame 101 at Offset(10.35, 20.35) in the SAME frame (gap = 0)
        // - Frame gap = 0 -> isConsecutive = false -> isScrolling = false.
        // - Strict subpixel phase check detects Bin 1 != cached Bin 0 -> forces Rasterize #4.
        // -------------------------------------------------------------------------
        painter.paint(canvas, const Offset(10.35, 20.35));
        expect(painter.hasCache, isTrue);
        expect(painter.debugRasterizeCount, 4);
      } finally {
        EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(originalDpr);
        FrameService.instance.debugResetFrameData();
      }
    },
  );
}
