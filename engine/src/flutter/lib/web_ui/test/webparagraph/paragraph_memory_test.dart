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

/*
class MockPainter implements CanvasKitPainter {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
  }

  // Stubs for other methods to satisfy the interface
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLayout implements TextLayout {
  // Stubs
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPaint implements TextPaint {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWebParagraph extends WebParagraph {
  // We expose these purely so your tests can inspect them later
  // (e.g., expect(paragraph.injectedLayout.wasCalled, isTrue))
  final TextLayout injectedLayout;
  final CanvasKitPainter injectedPainter;
  final TextPaint injectedTextPaint;

  // We pass the substituted members directly to the real superclass.
  MockWebParagraph._(this.injectedLayout, this.injectedPainter, this.injectedTextPaint)
    : super(injectedLayout, injectedPainter, injectedTextPaint);

  // A convenient factory to build it for your tests
  factory MockWebParagraph.create({
    TextLayout? layout,
    CanvasKitPainter? painter,
    TextPaint? paint,
  }) {
    // If you don't provide substitutes, we can even provide real ones or spies
    final TextPaint substitutedPaint = paint ?? MockPaint();
    final CanvasKitPainter substitutedPainter = painter ?? MockPainter();
    final TextLayout substitutedLayout = layout ?? MockLayout();

    return MockWebParagraph._(substitutedLayout, substitutedPainter, substitutedPaint);
  }
}
*/
Future<void> testMain() async {
  WebParagraphProfiler.register();
  setUpUnitTests(withImplicitView: true, setUpTestViewDimensions: false);

  test(
    'Make sure the paragraph layout/paint reuse the cached results after the first layout/paint',
    () async {
      WebParagraphProfiler.reset();
      final recorder = PictureRecorder();
      const region = Rect.fromLTWH(0, 0, 1000, 1000);

      final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
      final textStyle = TextStyle(color: const Color(0xFF000000), fontSize: 20);
      const text1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      const text2 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

      {
        // Dummy layout to get Chrome and GPU up and running
        final builder = ParagraphBuilder(arialStyle);
        builder.pushStyle(textStyle);
        builder.addText('Hello World');
        final Paragraph paragraph = builder.build();
        paragraph.layout(const ParagraphConstraints(width: 1000));
        final canvas = Canvas(recorder, region);
        canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        for (var i = 0; i < 100; i++) {
          canvas.drawParagraph(paragraph, const Offset(20, 20));
        }
        await drawPictureUsingCurrentRenderer(recorder.endRecording());
      }

      {
        // Layout/paint the same paragraph multiple times to see the effect of caching
        for (var i = 0; i < 1000; i++) {
          final builder = ParagraphBuilder(arialStyle);
          builder.pushStyle(textStyle);
          builder.addText('abc000$text1');
          final Paragraph paragraph = builder.build();
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
        }
      }

      // Layout/paint different paragraphs to see the effect of no caching
      for (var i = 0; i < 1000; i++) {
        final builder = ParagraphBuilder(arialStyle);
        builder.pushStyle(textStyle);
        builder.addText("ABC${(i + 1).toString().padLeft(3, '0')}$text2");
        final Paragraph paragraph = builder.build();

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
      }

      await matchGoldenFile('cached_paragraph.png', region: region);
      WebParagraphProfiler.log();
    },
    timeout: Timeout.none,
    solo: true,
  );
}
