# Paragraph Cache Demo & Performance Benchmark

An interactive diagnostic suite and performance benchmark for Flutter Web paragraph rendering and caching.

## Features

1. **Visual Blur & Subpixel Difference Analyzer**
   * Real-time side-by-side text rendering vs. spatial difference heatmap.
   * Visualizes subpixel phase distortions in Neon Magenta and Electric Yellow when textures are reused across phase shifts during motion vs. settled states.
   * Interactive 1s timer ticker, 60 FPS motion stepper, velocity sliders, and strategy toggles.

2. **Scroll Performance Benchmark Suite**
   * **Test 1:** 100 Short Texts (10 chars each, all unique).
   * **Test 2:** 100 Medium Texts (100 chars each, all unique).
   * **Test 3:** Large Texts (25 unique blocks, 1000 chars each).
   * 5-second hardware benchmark collecting mean frame times, UI build duration, GPU raster time, p95/p99 latency, and dropped frame counts.
   * Multi-mode comparison scorecard table.

## Running on Flutter Web

```bash
flutter run -d chrome
```

Toggle between CanvasKit WebParagraph and SkParagraph using URL query parameters:
* `http://localhost:<port>/?wp` (WebParagraph)
* `http://localhost:<port>/?ck` (SkParagraph)
