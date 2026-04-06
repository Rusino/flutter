// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart';
import 'package:web_engine_tester/golden_tester.dart';

import '../common/test_initialization.dart';
import '../ui/utils.dart';

const int count = 10;
const int perf_count = 1000;

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

typedef AsyncAction<R> = Future<R> Function();

Future<R> timeActionAsync<R>(String name, AsyncAction<R> action) async {
  if (!Profiler.isBenchmarkMode) {
    return action();
  } else {
    final stopwatch = Stopwatch()..start();
    final R result = await action();
    stopwatch.stop();
    Profiler.instance.benchmark(name, stopwatch.elapsedMicroseconds.toDouble());
    return result;
  }
}

class MockPainter extends CanvasKitPainter {}

class MockLayout extends TextLayout {
  MockLayout(super.paragraph);
}

class MockPaint extends PaintParagraph {
  MockPaint(super.paragraph);
}

class MockWebParagraph extends WebParagraph {
  MockWebParagraph(super.paragraphStyle, super.spans, super.text) {
    setup();
  }

  @override
  void setup({TextLayout? layout, TextPaint? paint, CanvasKitPainter? painter}) {
    super.setup(
      layout: layout ?? MockLayout(this),
      paint: paint ?? MockPaint(this),
      painter: painter ?? MockPainter(),
    );
  }
}

class MockWebParagraphBuilder extends WebParagraphBuilder {
  MockWebParagraphBuilder(ParagraphStyle paragraphStyle) : super(paragraphStyle);

  @override
  WebParagraph produceParagraph(
    WebParagraphStyle paragraphStyle,
    List<ParagraphSpan> spans,
    String text,
  ) {
    return MockWebParagraph(paragraphStyle, spans, text);
  }
}

Future<void> testMain() async {
  WebParagraphProfiler.register();
  setUpUnitTests(withImplicitView: true, setUpTestViewDimensions: false);

  test(
    'Make sure the paragraph layout/paint cache and reuse the cached results',
    () async {
      WebParagraphProfiler.reset();
      final recorder = PictureRecorder();
      const region = Rect.fromLTWH(0, 0, 1000, 1000);

      final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
      final textStyle = TextStyle(color: const Color(0xFF000000), fontSize: 20);
      const text1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      const text2 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

      // Layout/paint different paragraphs to see that they are cached
      for (var i = 0; i < count; i++) {
        final builder = MockWebParagraphBuilder(arialStyle);
        builder.pushStyle(textStyle);
        builder.addText("ABC${(i + 1).toString().padLeft(3, '0')}$text2");
        final paragraph = builder.build() as MockWebParagraph;

        timeAction(i == 0 ? 'nocache_layout_first' : 'nocache_layout', () {
          paragraph.layout(const ParagraphConstraints(width: 1000));
        });
        final canvas = Canvas(recorder, region);
        canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        await timeActionAsync(i == 0 ? 'nocache_paint_first' : 'nocache_paint', () async {
          canvas.drawParagraph(paragraph, const Offset(20, 20));
          await drawPictureUsingCurrentRenderer(
            recorder.endRecording(),
          ); // This is a hack to make sure the canvas is flushed
        });
        if (paragraph.refCount != 2) {
          throw Exception(
            'Expected refCount == 2 for the paragraph, but got ${paragraph.refCount}',
          );
        }
        if (paragraph.painter.refCount != 2) {
          throw Exception(
            'Expected refCount == 2 for the painter (image cache), but got ${paragraph.painter.refCount}',
          );
        }
      }
      if (cache.size != count) {
        throw Exception('Expected $count paragraphs in cache, but got ${cache.size}');
      }

      {
        // Layout/paint the same paragraph multiple times to see the effect of caching
        for (var i = 0; i < count; i++) {
          final builder = MockWebParagraphBuilder(arialStyle);
          builder.pushStyle(textStyle);
          builder.addText('abc000$text1');
          final paragraph = builder.build() as MockWebParagraph;
          timeAction(i == 0 ? 'cache_layout_first' : 'cache_layout', () {
            paragraph.layout(const ParagraphConstraints(width: 1000));
          });
          final canvas = Canvas(recorder, region);
          canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
          await timeActionAsync(i == 0 ? 'cache_paint_first' : 'cache_paint', () async {
            canvas.drawParagraph(paragraph, const Offset(20, 20));
            await drawPictureUsingCurrentRenderer(
              recorder.endRecording(),
            ); // This is a hack to make sure the canvas is flushed
          });
          // We dispose of the paragraph here but it will remain alive in cache.
          // This is to make sure that the cache is working and not creating new paragraphs.
          paragraph.dispose();
          if (paragraph.refCount != 1) {
            throw Exception(
              'Expected refCount == 1 for the paragraph, but got ${paragraph.refCount}',
            );
          }
          if (paragraph.painter.refCount != 1) {
            throw Exception(
              'Expected refCount == 1 for the painter (image cache), but got ${paragraph.painter.refCount}',
            );
          }
        }
      }
      if (cache.size != count + 1) {
        throw Exception('01 Expected ${count + 1} paragraphs in cache, but got ${cache.size}');
      }

      cache.clear();
      if (cache.size != 0) {
        throw Exception('04 Expected 0 paragraphs in cache, but got ${cache.size}');
      }

      await matchGoldenFile('cached_paragraph_functionality.png', region: region);

      WebParagraphProfiler.log();
    },
    timeout: Timeout.none,
    solo: false,
  );

  test(
    'Measure performance of caching paragraph layout/paint',
    () async {
      WebParagraphProfiler.reset();
      final recorder = PictureRecorder();
      const region = Rect.fromLTWH(0, 0, 1000, 1000);

      final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
      final textStyle = TextStyle(color: const Color(0xFF000000), fontSize: 20);
      const text1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      const text2 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

      // Layout/paint different paragraphs so they are cached
      for (var i = 0; i < perf_count; i++) {
        final builder = MockWebParagraphBuilder(arialStyle);
        builder.pushStyle(textStyle);
        builder.addText("ABC${(i + 1).toString().padLeft(3, '0')}$text2");
        final paragraph = builder.build() as MockWebParagraph;

        timeAction('layout', () {
          paragraph.layout(const ParagraphConstraints(width: 1000));
        });
        final canvas = Canvas(recorder, region);
        canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        await timeActionAsync('paint', () async {
          canvas.drawParagraph(paragraph, const Offset(20, 20));
          await drawPictureUsingCurrentRenderer(
            recorder.endRecording(),
          ); // This is a hack to make sure the canvas is flushed
        });
      }

      await timeActionAsync('cache_clear', () async {
        cache.clear();
      });
      await matchGoldenFile('caching_paragraph_performance.png', region: region);

      WebParagraphProfiler.log();
    },
    timeout: Timeout.none,
    solo: false,
  );

  test(
    'Measure performance of paragraph layout/paint with and without cache',
    () async {
      WebParagraphProfiler.reset();
      final recorder = PictureRecorder();
      const region = Rect.fromLTWH(0, 0, 1000, 1000);

      final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
      final textStyle = TextStyle(color: const Color(0xFF000000), fontSize: 20);
      const text1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      const text2 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

      {
        // Layout/paint the same paragraph multiple times to see the effect of caching
        for (var i = 0; i < perf_count; i++) {
          final builder = MockWebParagraphBuilder(arialStyle);
          builder.pushStyle(textStyle);
          builder.addText('abc000$text1');
          final paragraph = builder.build() as MockWebParagraph;
          timeAction('no_cache_layout', () {
            paragraph.layout(const ParagraphConstraints(width: 1000));
          });
          final canvas = Canvas(recorder, region);
          canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
          await timeActionAsync('no_cache_paint', () async {
            canvas.drawParagraph(paragraph, const Offset(20, 20));
            await drawPictureUsingCurrentRenderer(
              recorder.endRecording(),
            ); // This is a hack to make sure the canvas is flushed
          });
          // We dispose of the paragraph here but it will remain alive in cache.
          // This is to make sure that the cache is working and not creating new paragraphs.
          paragraph.dispose();
          // We also clear the cache here to see the effect of not having cache.
          cache.clear();
        }
      }
      cache.clear();
      {
        // Layout/paint the same paragraph multiple times to see the effect of caching
        for (var i = 0; i < perf_count; i++) {
          final builder = MockWebParagraphBuilder(arialStyle);
          builder.pushStyle(textStyle);
          builder.addText('abc000$text1');
          final paragraph = builder.build() as MockWebParagraph;
          timeAction('cache_layout', () {
            paragraph.layout(const ParagraphConstraints(width: 1000));
          });
          final canvas = Canvas(recorder, region);
          canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
          await timeActionAsync('cache_paint', () async {
            canvas.drawParagraph(paragraph, const Offset(20, 20));
            await drawPictureUsingCurrentRenderer(
              recorder.endRecording(),
            ); // This is a hack to make sure the canvas is flushed
          });
          // We dispose of the paragraph here but it will remain alive in cache.
          // This is to make sure that the cache is working and not creating new paragraphs.
          paragraph.dispose();
        }
      }

      await matchGoldenFile('cached_paragraph_performance.png', region: region);

      WebParagraphProfiler.log();
    },
    timeout: Timeout.none,
    solo: false,
  );
  test(
    'Measure caching cost for multiple paragraphs',
    () async {
      WebParagraphProfiler.reset();
      final recorder = PictureRecorder();
      const region = Rect.fromLTWH(0, 0, 1000, 1000);

      final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
      final textStyle = TextStyle(color: const Color(0xFF000000), fontSize: 20);
      const text1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      const text2 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

      // Layout/paint different paragraphs to see that they are cached
      for (var n = 0; n < 3; n++) {
        for (var i = 0; i < perf_count; i++) {
          final builder = MockWebParagraphBuilder(arialStyle);
          builder.pushStyle(textStyle);
          builder.addText("ABC${(i + 1).toString().padLeft(3, '0')}$text2$n");
          final paragraph = builder.build() as MockWebParagraph;

          timeAction('nocache_layout$n', () {
            paragraph.layout(const ParagraphConstraints(width: 1000));
          });
          final canvas = Canvas(recorder, region);
          canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
          await timeActionAsync('nocache_paint$n', () async {
            canvas.drawParagraph(paragraph, const Offset(20, 20));
            await drawPictureUsingCurrentRenderer(
              recorder.endRecording(),
            ); // This is a hack to make sure the canvas is flushed
          });
        }
      }

      await matchGoldenFile('cached_paragraph_functionality.png', region: region);

      WebParagraphProfiler.log();
    },
    timeout: Timeout.none,
    solo: false,
  );
}
