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

const String smallEnglishFile = 'smallEnglish';
const String mediumEnglishFile = 'mediumEnglish';
const String largeEnglishFile = 'largeEnglish';
const String smallChineseFile = 'smallChinese';
const String mediumChineseFile = 'mediumChinese';
const String largeChineseFile = 'largeChinese';

const String smallEnglishText = 'Abcdef ghijkl mnopqrs tuvwxyz.';
const String smallChineseText = '生活就像一场旅行，不在乎目的地，在乎的是沿途的风景以及心情。';

const String mediumEnglishText =
    'Abcdef ghijkl mnopqrs tuvwxyz. Abcdef ghijkl mnopqrs tuvwxyz. Abcdef ghijkl mnopqrs tuvwxyz.';
const String mediumChineseText =
    '读书不仅能开阔我们的视野，还能丰富我们的内心世界。每一本好书都是一位无声的老师，'
    '耐心地教导我们人生的哲理。在繁忙的生活中，抽出时间阅读，可以让心灵得到片刻的宁静。阅读，让生活变得更好。';

const String largeEnglishText =
    '1 Abcdef ghijkl mnopqrs tuvwxyz. 2 Abcdef ghijkl mnopqrs tuvwxyz. 3 Abcdef ghijkl mnopqrs tuvwxyz. '
    '4 Abcdef ghijkl mnopqrs tuvwxyz. 5 Abcdef ghijkl mnopqrs tuvwxyz. 6 Abcdef ghijkl mnopqrs tuvwxyz. '
    '7 Abcdef ghijkl mnopqrs tuvwxyz. 8 Abcdef ghijkl mnopqrs tuvwxyz. 9 Abcdef ghijkl mnopqrs tuvwxyz. '
    '10 Abcdef ghijkl mnopqrs tuvwxyz. 11 Abcdef ghijkl mnopqrs tuvwxyz. 12 Abcdef ghijkl mnopqrs tuvwxyz. '
    '13 Abcdef ghijkl mnopqrs tuvwxyz. 14 Abcdef ghijkl mnopqrs tuvwxyz. 15 Abcdef ghijkl mnopqrs tuvwxyz. '
    '16 Abcdef ghijkl mnopqrs tuvwxyz. 17 Abcdef ghijkl mnopqrs tuvwxyz. 18 Abcdef ghijkl mnopqrs tuvwxyz. '
    '19 Abcdef ghijkl mnopqrs tuvwxyz. 20 Abcdef ghijkl mnopqrs tuvwxyz. 21 Abcdef ghijkl mnopqrs tuvwxyz. '
    '22 Abcdef ghijkl mnopqrs tuvwxyz. 23 Abcdef ghijkl mnopqrs tuvwxyz. 24 Abcdef ghijkl mnopqrs tuvwxyz. '
    '25 Abcdef ghijkl mnopqrs tuvwxyz. 26 Abcdef ghijkl mnopqrs tuvwxyz. 27 Abcdef ghijkl mnopqrs tuvwxyz. '
    '28 Abcdef ghijkl mnopqrs tuvwxyz. 29 Abcdef ghijkl mnopqrs tuvwxyz. 30 Abcdef ghijkl mnopqrs tuvwxyz. '
    '31 Abcdef ghijkl mnopqrs tuvwxyz. 32 Abcdef ghijkl mnopqrs tuvwxyz. 33 Abcdef ghijkl mnopqrs tuvwxyz. '
    '34 Abcdef ghijkl mnopqrs tuvwxyz. 35 Abcdef ghijkl mnopqrs tuvwxyz. 36 Abcdef ghijkl mnopqrs tuvwxyz. '
    '37 Abcdef ghijkl mnopqrs tuvwxyz. 38 Abcdef ghijkl mnopqrs tuvwxyz. 39 Abcdef ghijkl mnopqrs tuvwxyz. '
    '40 Abcdef ghijkl mnopqrs tuvwxyz. 41 Abcdef ghijkl mnopqrs tuvwxyz. 42 Abcdef ghijkl mnopqrs tuvwxyz. '
    '43 Abcdef ghijkl mnopqrs tuvwxyz. 44 Abcdef ghijkl mnopqrs tuvwxyz. 45 Abcdef ghijkl mnopqrs tuvwxyz. '
    '46 Abcdef ghijkl mnopqrs tuvwxyz. 47 Abcdef ghijkl mnopqrs tuvwxyz. 48 Abcdef ghijkl mnopqrs tuvwxyz. '
    '49 Abcdef ghijkl mnopqrs tuvwxyz. 50 Abcdef ghijkl mnopqrs tuvwxyz. 51 Abcdef ghijkl mnopqrs tuvwxyz. '
    '52 Abcdef ghijkl mnopqrs tuvwxyz. 53 Abcdef ghijkl mnopqrs tuvwxyz. 54 Abcdef ghijkl mnopqrs tuvwxyz. '
    '55 Abcdef ghijkl mnopqrs tuvwxyz. 56 Abcdef ghijkl mnopqrs tuvwxyz. 57 Abcdef ghijkl mnopqrs tuvwxyz. '
    '58 Abcdef ghijkl mnopqrs tuvwxyz. 59 Abcdef ghijkl mnopqrs tuvwxyz. 60 Abcdef ghijkl mnopqrs tuvwxyz. '
    '61 Abcdef ghijkl mnopqrs tuvwxyz. 62 Abcdef ghijkl mnopqrs tuvwxyz. 63 Abcdef ghijkl mnopqrs tuvwxyz. '
    '64 Abcdef ghijkl mnopqrs tuvwxyz. 65 Abcdef ghijkl mnopqrs tuvwxyz. 66 Abcdef ghijkl mnopqrs tuvwxyz. '
    '67 Abcdef ghijkl mnopqrs tuvwxyz. 68 Abcdef ghijkl mnopqrs tuvwxyz. 69 Abcdef ghijkl mnopqrs tuvwxyz. '
    '70 Abcdef ghijkl mnopqrs tuvwxyz. 71 Abcdef ghijkl mnopqrs tuvwxyz. 72 Abcdef ghijkl mnopqrs tuvwxyz. ';

const String largeChineseText =
    '1 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 2 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 3 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '4 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 5 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 6 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '7 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 8 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 9 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '10 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 11 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 12 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '13 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 14 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 15 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '16 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 17 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 18 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '19 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 20 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 21 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '22 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 23 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 24 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '25 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 26 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 27 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '28 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 29 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 30 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '31 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 32 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 33 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '34 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 35 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 36 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '37 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 38 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 39 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '40 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 41 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 42 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '43 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 44 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 45 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '46 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 47 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 48 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '49 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 50 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 51 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '52 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 53 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 54 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '55 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 56 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 57 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '58 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 59 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 60 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '61 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 62 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 63 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '64 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 65 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 66 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '67 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 68 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 69 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 '
    '70 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 71 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 72 春暖花开时节 阳光明媚灿烂 微风拂过绿树林 鸟儿欢快地歌唱。 ';

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

Future<void> testMain() async {
  WebParagraphProfiler.register();
  setUpUnitTests(withImplicitView: true, setUpTestViewDimensions: false);

  Future<void> draw(
    String image,
    String text,
    String testName,
    int countLayouts,
    int countPaints,
  ) async {
    WebParagraphProfiler.reset();
    final recorder = PictureRecorder();
    const region = Rect.fromLTWH(0, 0, 1000, 1000);
    final paragraphs = <Paragraph>[];
    for (var i = 0; i < countLayouts; i++) {
      final Paragraph paragraph = timeAction((i == 0 ? 'build.first' : 'build'), () {
        final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
        final builder = ParagraphBuilder(arialStyle);
        builder.pushStyle(TextStyle(color: const Color(0xFF000000)));
        builder.addText('$text$i');
        return builder.build();
      });
      paragraphs.add(paragraph);
      timeAction((i == 0 ? 'layout.first' : 'layout'), () {
        paragraph.layout(const ParagraphConstraints(width: 1000));
      });
    }
    for (var j = 0; j < countPaints; ++j) {
      for (final paragraph in paragraphs) {
        final canvas = Canvas(recorder, region);
        canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        await timeActionAsync((j == 0 ? 'paint.first' : 'paint'), () async {
          canvas.drawParagraph(paragraph, const Offset(20, 20));
          await drawPictureUsingCurrentRenderer(
            recorder.endRecording(),
          ); // This is a hack to make sure the canvas is flushed
        });
      }
    }

    await matchGoldenFile('$image.png', region: region);
    WebParagraphProfiler.log();
  }

  test(
    'Dummy test to warm up GPU',
    () async {
      await draw('dummyText', 'Dummy text', 'Dummy text', 1, 1);
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint small English text',
    () async {
      await draw(smallEnglishFile, smallEnglishText, 'Small text', 10, 100);
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint small Chinese text',
    () async {
      await draw(smallChineseFile, smallChineseText, 'Small text', 10, 100);
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint medium English text',
    () async {
      await draw(mediumEnglishFile, mediumEnglishText, 'Medium text', 10, 100);
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint medium Chinese text',
    () async {
      await draw(mediumChineseFile, mediumChineseText, 'Medium text', 10, 100);
    },
    timeout: Timeout.none,
    skip: false,
  );
  /*
  test(
    'Build/Layout/Paint large text3',
    () async {
      await draw(
        'largeText',
        'Abcdef ghijkl mnopqrs tuvwxyz1. Abcdef ghijkl mnopqrs tuvwxyz2. Abcdef ghijkl mnopqrs tuvwxyz3. '
            'Abcdef ghijkl mnopqrs tuvwxyz4. Abcdef ghijkl mnopqrs tuvwxyz5. Abcdef ghijkl mnopqrs tuvwxyz6. '
            'Abcdef ghijkl mnopqrs tuvwxyz7. Abcdef ghijkl mnopqrs tuvwxyz8. Abcdef ghijkl mnopqrs tuvwxyz9.',
        'Large text',
        10,
        100,
      );
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint large text6',
    () async {
      await draw(
        'largeText',
        '1Abcdef ghijkl mnopqrs tuvwxyz. 2Abcdef ghijkl mnopqrs tuvwxyz. 3Abcdef ghijkl mnopqrs tuvwxyz. '
            '4Abcdef ghijkl mnopqrs tuvwxyz. 5Abcdef ghijkl mnopqrs tuvwxyz. 6Abcdef ghijkl mnopqrs tuvwxyz. '
            '7Abcdef ghijkl mnopqrs tuvwxyz. 8Abcdef ghijkl mnopqrs tuvwxyz. 9Abcdef ghijkl mnopqrs tuvwxyz. '
            '10Abcdef ghijkl mnopqrs tuvwxyz. 11Abcdef ghijkl mnopqrs tuvwxyz. 12Abcdef ghijkl mnopqrs tuvwxyz. '
            '13Abcdef ghijkl mnopqrs tuvwxyz. 14Abcdef ghijkl mnopqrs tuvwxyz. 15Abcdef ghijkl mnopqrs tuvwxyz. '
            '16Abcdef ghijkl mnopqrs tuvwxyz. 17Abcdef ghijkl mnopqrs tuvwxyz. 18Abcdef ghijkl mnopqrs tuvwxyz',
        'Large text',
        10,
        100,
      );
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint large text12',
    () async {
      await draw(
        'largeText',
        'Abcdef ghijkl mnopqrs tuvwxyz.1 Abcdef ghijkl mnopqrs tuvwxyz.2 Abcdef ghijkl mnopqrs tuvwxyz.3 '
            'Abcdef ghijkl mnopqrs tuvwxyz.4 Abcdef ghijkl mnopqrs tuvwxyz.5 Abcdef ghijkl mnopqrs tuvwxyz.6 '
            'Abcdef ghijkl mnopqrs tuvwxyz.7 Abcdef ghijkl mnopqrs tuvwxyz.8 Abcdef ghijkl mnopqrs tuvwxyz.9 '
            'Abcdef ghijkl mnopqrs tuvwxyz.10 Abcdef ghijkl mnopqrs tuvwxyz.11 Abcdef ghijkl mnopqrs tuvwxyz.12 '
            'Abcdef ghijkl mnopqrs tuvwxyz.13 Abcdef ghijkl mnopqrs tuvwxyz.14 Abcdef ghijkl mnopqrs tuvwxyz.15  '
            'Abcdef ghijkl mnopqrs tuvwxyz.16 Abcdef ghijkl mnopqrs tuvwxyz.17 Abcdef ghijkl mnopqrs tuvwxyz.18 '
            'Abcdef ghijkl mnopqrs tuvwxyz.19 Abcdef ghijkl mnopqrs tuvwxyz.20 Abcdef ghijkl mnopqrs tuvwxyz.21 '
            'Abcdef ghijkl mnopqrs tuvwxyz.22 Abcdef ghijkl mnopqrs tuvwxyz.23 Abcdef ghijkl mnopqrs tuvwxyz.24 '
            'Abcdef ghijkl mnopqrs tuvwxyz.25 Abcdef ghijkl mnopqrs tuvwxyz.26 Abcdef ghijkl mnopqrs tuvwxyz.27 ',
        'Large text',
        10,
        100,
      );
    },
    timeout: Timeout.none,
    skip: false,
  );
*/

  test(
    'Build/Layout/Paint large English text',
    () async {
      await draw(largeEnglishFile, largeEnglishText, 'Large text', 10, 100);
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Build/Layout/Paint large Chinese text',
    () async {
      await draw(largeChineseFile, largeChineseText, 'Large text', 10, 100);
    },
    timeout: Timeout.none,
    skip: false,
  );

  test(
    'Paint text by sizes',
    () async {
      WebParagraphProfiler.reset();
      final recorder = PictureRecorder();
      const region = Rect.fromLTWH(0, 0, 1000, 1000);
      for (var textSize = 10; textSize < 1000; textSize += (textSize == 10 ? 40 : 50)) {
        final Paragraph paragraph = timeAction('build$textSize', () {
          final arialStyle = ParagraphStyle(fontFamily: 'Roboto', fontSize: 20);
          final builder = ParagraphBuilder(arialStyle);
          builder.pushStyle(TextStyle(color: const Color(0xFF000000)));
          builder.addText('0123456789' * (textSize ~/ 10));
          return builder.build();
        });
        timeAction('layout$textSize', () {
          paragraph.layout(const ParagraphConstraints(width: 1000));
        });
        final canvas = Canvas(recorder, region);
        canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        await timeActionAsync('paint$textSize', () async {
          canvas.drawParagraph(paragraph, const Offset(20, 20));
          await drawPictureUsingCurrentRenderer(
            recorder.endRecording(),
          ); // This is a hack to make sure the canvas is flushed
        });
      }

      await matchGoldenFile('textSize.png', region: region);
      WebParagraphProfiler.log();
    },
    timeout: Timeout.none,
    skip: true,
  );
}
