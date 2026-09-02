import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const ParagraphCacheDemoApp());
}

class ParagraphCacheDemoApp extends StatelessWidget {
  const ParagraphCacheDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paragraph Cache: Performance Benchmark & Visual Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const MainDemoScreen(),
    );
  }
}

class MainDemoScreen extends StatefulWidget {
  const MainDemoScreen({super.key});

  @override
  State<MainDemoScreen> createState() => _MainDemoScreenState();
}

enum AppTab {
  visualBlurAnalyzer, // Visual demonstration of blurry text when ignoring subpixels + difference heatmap
  benchmarkSuite, // Performance measurement (100 Short, 100 Medium, Large Texts)
}

enum BenchmarkMode {
  short100, // 100 short texts (10 characters each, all unique)
  medium100, // 100 medium texts (100 characters each, all unique)
  largeTexts, // 25 uniquely generated 1000-character blocks
}

enum TrackingStrategy {
  consecutiveFrameSequence, // Engine Fix: Frame gap <= 2
  legacyPaintCount, // Legacy: Ignores frame gap (causes blurring on slow ticks)
}

class BenchmarkReport {
  BenchmarkReport({
    required this.mode,
    required this.duration,
    required this.totalFrames,
    required this.averageFps,
    required this.averageBuildMs,
    required this.averageRasterMs,
    required this.averageTotalMs,
    required this.p95TotalMs,
    required this.p99TotalMs,
    required this.worstFrameMs,
    required this.droppedFrames,
    required this.droppedFrameRatio,
    required this.scrollSpeed,
  });

  final BenchmarkMode mode;
  final Duration duration;
  final int totalFrames;
  final double averageFps;
  final double averageBuildMs;
  final double averageRasterMs;
  final double averageTotalMs;
  final double p95TotalMs;
  final double p99TotalMs;
  final double worstFrameMs;
  final int droppedFrames;
  final double droppedFrameRatio;
  final double scrollSpeed;
}

class _MainDemoScreenState extends State<MainDemoScreen>
    with SingleTickerProviderStateMixin {
  AppTab _currentTab = AppTab.visualBlurAnalyzer;
  BenchmarkMode _benchmarkMode = BenchmarkMode.short100;
  TrackingStrategy _strategy = TrackingStrategy.consecutiveFrameSequence;

  late final ScrollController _benchmarkScrollController;
  late final AnimationController _animController;

  // Discrete Ticker State
  Timer? _tickerTimer;
  bool _isTickerRunning = false;
  int _tickCount = 0;

  // Scrolling State
  bool _is60FpsScrolling = false;
  double _scrollSpeed = 600.0; // px/s
  DateTime? _lastScrollTickTime;

  // Frame Sequence & State Tracking
  int _simulatedFrameNumber = 100;
  int? _lastFrameNumber;
  double _offsetY = 0.0;
  double? _lastOffsetY;
  bool _wasMoving = false;
  int _cachedBin = 0;
  int _rasterizeCount = 1;
  bool _lastFrameWasScrolling = false;

  // Live Performance Metrics
  final ListQueue<FrameTiming> _timingHistory = ListQueue<FrameTiming>(250);
  final List<FrameTiming> _benchmarkSampleBuffer = [];
  bool _isBenchmarking = false;
  int _benchmarkSecondsRemaining = 0;
  Timer? _benchmarkCountdownTimer;

  final Map<BenchmarkMode, BenchmarkReport> _reportsByMode = {};
  BenchmarkReport? _lastBenchmarkReport;

  double _liveFps = 60.0;
  double _liveBuildMs = 0.0;
  double _liveRasterMs = 0.0;
  double _liveTotalMs = 0.0;
  int _totalDroppedFrames = 0;

  // Visual Analysis (Heatmap & Smear Analyzer)
  ui.Image? _diffHeatmap;
  int _distortedPixelCount = 0;
  bool _isCrisp = true;

  // Datasets
  late final List<String> _shortTexts100;
  late final List<String> _mediumTexts100;
  late final List<String> _largeTextsList;
  late ui.Paragraph _diagnosticParagraph;

  @override
  void initState() {
    super.initState();
    _initDatasets();
    _diagnosticParagraph = _buildDiagnosticParagraph();
    _benchmarkScrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onContinuousScrollTick);

    // Subscribe to Flutter engine frame timings
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAnalysis();
    });
  }

  void _initDatasets() {
    // 1. 100 Short Texts (exact 10 characters each, all 100 unique)
    _shortTexts100 = List.generate(100, (i) {
      final String id = i.toString().padLeft(3, '0');
      switch (i % 4) {
        case 0:
          return 'O=S=$id===';
        case 1:
          return '8888_$id==';
        case 2:
          return 'SSSS_$id--';
        default:
          return '0000_$id++';
      }
    });

    // 2. 100 Medium Texts (exact 100 characters each, all 100 unique)
    _mediumTexts100 = List.generate(100, (i) {
      final String id = i.toString().padLeft(3, '0');
      final String prefix =
          'ITEM#$id: [O=S=O=S= 8888 0000] Medium Text Block for paragraph cache render latency test ';
      final String full = prefix.padRight(100, '=');
      return full.length >= 100 ? full.substring(0, 100) : full;
    });

    // 3. Unique Large Texts (25 unique blocks, each exactly 1000 characters, no repeats)
    _largeTextsList = List.generate(25, (i) {
      final String id = i.toString().padLeft(3, '0');
      final StringBuffer sb = StringBuffer();
      sb.write(
        'LARGE TEXT BLOCK #$id (EXACT 1000 CHARACTERS UNIQUE PAYLOAD):\n',
      );
      sb.write(
        '========================================================================================\n',
      );
      sb.write(
        'Section 1 (Block $id): The Flutter Engine uses paragraph caching to optimize text rendering.\n',
      );
      sb.write(
        'Section 2 (Block $id): Subpixel antialiasing uses discrete phase bins [0, 0.25), [0.25, 0.5).\n',
      );
      sb.write(
        'Section 3 (Block $id): During active scrolling, textures are reused across subpixel shifts.\n',
      );
      sb.write(
        'Section 4 (Block $id): O S O S O S === === === OOOO SSSS 8888 0000 === === === $id\n',
      );
      sb.write(
        'Section 5 (Block $id): High-density typography stress test measuring SkImage allocation.\n',
      );
      sb.write(
        'Section 6 (Block $id): Testing context extraction overhead with large multi-line paragraphs.\n',
      );
      sb.write(
        'Section 7 (Block $id): Performance metrics verify mean frame time, p95 latency, dropped frames.\n',
      );
      sb.write(
        'Section 8 (Block $id): O=S=O=S= 8888 0000 ==== ++++ **** %%%% #### @@@@ !!!! $id\n',
      );
      sb.write(
        'Section 9 (Block $id): End of large text block payload for unique benchmark verification $id.\n',
      );
      final String fullStr = sb.toString();
      return fullStr.length >= 1000
          ? fullStr.substring(0, 1000)
          : fullStr.padRight(1000, '=');
    });
  }

  ui.Paragraph _buildDiagnosticParagraph() {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: 'Roboto',
        fontSize: 36,
        fontWeight: FontWeight.w900,
      ),
    );
    builder.pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)));
    builder.addText('O S O S O S === === ===\n');
    builder.pushStyle(
      ui.TextStyle(color: const Color(0xFF00E5FF), fontFamily: 'monospace'),
    );
    builder.addText('====================\n');
    builder.pushStyle(
      ui.TextStyle(color: const Color(0xFFE6EDF3), fontFamily: 'Roboto'),
    );
    builder.addText('OOOO SSSS 8888 0000 ===');
    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: 680));
    return p;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted) return;

    for (final timing in timings) {
      _timingHistory.addLast(timing);
      if (_timingHistory.length > 200) {
        _timingHistory.removeFirst();
      }

      if (_isBenchmarking) {
        _benchmarkSampleBuffer.add(timing);
      }

      final double totalMs = timing.totalSpan.inMicroseconds / 1000.0;
      if (totalMs > 16.67) {
        _totalDroppedFrames++;
      }
    }

    _updateLiveMetrics();
  }

  void _updateLiveMetrics() {
    if (_timingHistory.isEmpty) return;

    double sumBuild = 0;
    double sumRaster = 0;
    double sumTotal = 0;

    for (final t in _timingHistory) {
      sumBuild += t.buildDuration.inMicroseconds / 1000.0;
      sumRaster += t.rasterDuration.inMicroseconds / 1000.0;
      sumTotal += t.totalSpan.inMicroseconds / 1000.0;
    }

    final int count = _timingHistory.length;
    final double avgTotal = sumTotal / count;

    setState(() {
      _liveBuildMs = sumBuild / count;
      _liveRasterMs = sumRaster / count;
      _liveTotalMs = avgTotal;
      _liveFps = avgTotal > 0 ? (1000.0 / avgTotal).clamp(0.0, 120.0) : 60.0;
    });
  }

  int _calculateBin(double offset) {
    final double frac = offset - offset.floorToDouble();
    return (frac * 4).floor() % 4;
  }

  void _processFrame({
    required double newOffset,
    required int frameAdvance,
    bool runFullDiff = false,
  }) {
    _simulatedFrameNumber += frameAdvance;
    final int currentFrame = _simulatedFrameNumber;

    const double motionEpsilon = 0.001;
    const double maxInitialMotionDelta = 100.0;

    final double delta = _lastOffsetY != null
        ? (newOffset - _lastOffsetY!).abs()
        : 0.0;
    final bool hasDelta = _lastOffsetY != null && delta > motionEpsilon;

    bool isScrolling;
    if (_strategy == TrackingStrategy.consecutiveFrameSequence) {
      final bool isConsecutive =
          _lastFrameNumber != null && (currentFrame - _lastFrameNumber! <= 2);
      final bool canInitiateMotion =
          isConsecutive && delta <= maxInitialMotionDelta;
      isScrolling = hasDelta && _wasMoving && isConsecutive;
      _wasMoving = hasDelta && (isScrolling || canInitiateMotion);
    } else {
      final bool canInitiateMotion = delta <= maxInitialMotionDelta;
      isScrolling = hasDelta && _wasMoving;
      _wasMoving = hasDelta && (isScrolling || canInitiateMotion);
    }

    final int currentBin = _calculateBin(newOffset);

    if (!isScrolling) {
      if (currentBin != _cachedBin) {
        _cachedBin = currentBin;
        _rasterizeCount++;
      }
    }

    setState(() {
      _tickCount++;
      _offsetY = newOffset;
      _lastOffsetY = newOffset;
      _lastFrameNumber = currentFrame;
      _lastFrameWasScrolling = isScrolling;
    });

    if (runFullDiff || _currentTab == AppTab.visualBlurAnalyzer) {
      _runAnalysis();
    }
  }

  void _onDiscreteTimerTick() {
    final double nextOffset = (_offsetY + 0.50) % 200.0;
    _processFrame(
      newOffset: nextOffset,
      frameAdvance: 60,
      runFullDiff: true,
    ); // 60 frames = 1 second
  }

  /// Single step in 60 FPS mode (+0.25px to next phase bin on consecutive frame)
  void _onStep60FpsFrame() {
    final double nextOffset = (_offsetY + 0.25) % 200.0;
    _processFrame(newOffset: nextOffset, frameAdvance: 1, runFullDiff: true);
  }

  void _onContinuousScrollTick() {
    if (!_is60FpsScrolling) return;

    final now = DateTime.now();
    if (_lastScrollTickTime != null) {
      final double dt =
          now.difference(_lastScrollTickTime!).inMicroseconds / 1000000.0;
      final double step = _scrollSpeed * dt;

      if (_currentTab == AppTab.benchmarkSuite &&
          _benchmarkScrollController.hasClients) {
        double nextListOffset = _benchmarkScrollController.offset + step;
        if (nextListOffset >=
            _benchmarkScrollController.position.maxScrollExtent) {
          nextListOffset = 0.0;
          _benchmarkScrollController.jumpTo(0.0);
        } else {
          _benchmarkScrollController.jumpTo(nextListOffset);
        }
      }

      final double nextDiagOffset = (_offsetY + step) % 200.0;
      _processFrame(
        newOffset: nextDiagOffset,
        frameAdvance: 1,
        runFullDiff: _currentTab == AppTab.visualBlurAnalyzer,
      );
    }
    _lastScrollTickTime = now;
  }

  void _start1sTicker() {
    _stop60FpsScroll();
    setState(() {
      _isTickerRunning = true;
    });
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _onDiscreteTimerTick();
    });
  }

  void _stop1sTicker() {
    setState(() {
      _isTickerRunning = false;
    });
    _tickerTimer?.cancel();
  }

  void _start60FpsScroll([double? speed]) {
    if (speed != null) {
      _scrollSpeed = speed;
    }
    _stop1sTicker();
    setState(() {
      _is60FpsScrolling = true;
      _lastScrollTickTime = DateTime.now();
    });
    _animController.repeat();
  }

  void _stop60FpsScroll() {
    setState(() {
      _is60FpsScrolling = false;
      _lastScrollTickTime = null;
    });
    _animController.stop();
    _runAnalysis();
  }

  void _runBenchmark() {
    if (_isBenchmarking) return;

    _benchmarkSampleBuffer.clear();
    setState(() {
      _isBenchmarking = true;
      _benchmarkSecondsRemaining = 5;
    });

    _start60FpsScroll(_scrollSpeed);

    _benchmarkCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) return;
      setState(() {
        _benchmarkSecondsRemaining--;
      });

      if (_benchmarkSecondsRemaining <= 0) {
        timer.cancel();
        _completeBenchmark(const Duration(seconds: 5));
      }
    });
  }

  void _completeBenchmark(Duration duration) {
    _stop60FpsScroll();

    if (_benchmarkSampleBuffer.isEmpty) {
      setState(() {
        _isBenchmarking = false;
      });
      return;
    }

    final samples = List<FrameTiming>.from(_benchmarkSampleBuffer);
    final int totalFrames = samples.length;

    double sumBuild = 0;
    double sumRaster = 0;
    double sumTotal = 0;
    double worstMs = 0;
    int dropped = 0;
    final List<double> totalTimes = [];

    for (final t in samples) {
      final double bMs = t.buildDuration.inMicroseconds / 1000.0;
      final double rMs = t.rasterDuration.inMicroseconds / 1000.0;
      final double tMs = t.totalSpan.inMicroseconds / 1000.0;

      sumBuild += bMs;
      sumRaster += rMs;
      sumTotal += tMs;
      totalTimes.add(tMs);

      if (tMs > worstMs) worstMs = tMs;
      if (tMs > 16.67) dropped++;
    }

    totalTimes.sort();
    final double p95 =
        totalTimes[(totalTimes.length * 0.95).floor().clamp(
          0,
          totalTimes.length - 1,
        )];
    final double p99 =
        totalTimes[(totalTimes.length * 0.99).floor().clamp(
          0,
          totalTimes.length - 1,
        )];
    final double avgTotal = sumTotal / totalFrames;
    final double avgFps = avgTotal > 0
        ? (1000.0 / avgTotal).clamp(0.0, 120.0)
        : 60.0;

    final report = BenchmarkReport(
      mode: _benchmarkMode,
      duration: duration,
      totalFrames: totalFrames,
      averageFps: avgFps,
      averageBuildMs: sumBuild / totalFrames,
      averageRasterMs: sumRaster / totalFrames,
      averageTotalMs: avgTotal,
      p95TotalMs: p95,
      p99TotalMs: p99,
      worstFrameMs: worstMs,
      droppedFrames: dropped,
      droppedFrameRatio: (dropped / totalFrames) * 100.0,
      scrollSpeed: _scrollSpeed,
    );

    setState(() {
      _isBenchmarking = false;
      _reportsByMode[_benchmarkMode] = report;
      _lastBenchmarkReport = report;
    });

    _showReportDialog(report);
  }

  void _showReportDialog(BenchmarkReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Colors.cyanAccent),
            const SizedBox(width: 8),
            Text(
              '${_getModeTitle(report.mode)} Scorecard (5s)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportMetricRow(
                'Test Configuration',
                _getModeSubtitle(report.mode),
              ),
              _buildReportMetricRow(
                'Duration & Speed',
                '${report.duration.inSeconds}s at ${report.scrollSpeed.toStringAsFixed(0)} px/s',
              ),
              _buildReportMetricRow(
                'Total Frames Collected',
                '${report.totalFrames} frames',
              ),
              const Divider(color: Colors.white24, height: 16),
              _buildReportMetricRow(
                'Average FPS',
                '${report.averageFps.toStringAsFixed(1)} FPS',
                highlight: true,
              ),
              _buildReportMetricRow(
                'Average Frame Total',
                '${report.averageTotalMs.toStringAsFixed(2)} ms',
              ),
              _buildReportMetricRow(
                'Average Raster (GPU)',
                '${report.averageRasterMs.toStringAsFixed(2)} ms',
                highlight: true,
              ),
              _buildReportMetricRow(
                'Average Build (UI)',
                '${report.averageBuildMs.toStringAsFixed(2)} ms',
              ),
              const Divider(color: Colors.white24, height: 16),
              _buildReportMetricRow(
                '95th Percentile Latency',
                '${report.p95TotalMs.toStringAsFixed(2)} ms',
              ),
              _buildReportMetricRow(
                '99th Percentile Latency',
                '${report.p99TotalMs.toStringAsFixed(2)} ms',
              ),
              _buildReportMetricRow(
                'Worst Frame Spike',
                '${report.worstFrameMs.toStringAsFixed(2)} ms',
              ),
              _buildReportMetricRow(
                'Dropped Frames (>16.6ms)',
                '${report.droppedFrames} (${report.droppedFrameRatio.toStringAsFixed(1)}%)',
                isAlert: report.droppedFrames > 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComparativeSummaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.purpleAccent, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.compare_arrows, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text(
              '3-Mode Performance Comparison',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.all(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Colors.white10),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Metric',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '100 Short\n(10 char)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '100 Medium\n(100 char)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Large Texts\n(1000 char)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildComparisonTableRow(
                  'Average FPS',
                  (r) => '${r.averageFps.toStringAsFixed(1)} FPS',
                ),
                _buildComparisonTableRow(
                  'Total Frame (ms)',
                  (r) => '${r.averageTotalMs.toStringAsFixed(2)} ms',
                ),
                _buildComparisonTableRow(
                  'Raster Time (ms)',
                  (r) => '${r.averageRasterMs.toStringAsFixed(2)} ms',
                ),
                _buildComparisonTableRow(
                  'p95 Frame (ms)',
                  (r) => '${r.p95TotalMs.toStringAsFixed(2)} ms',
                ),
                _buildComparisonTableRow(
                  'Dropped Frames',
                  (r) =>
                      '${r.droppedFrames} (${r.droppedFrameRatio.toStringAsFixed(1)}%)',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.purpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildComparisonTableRow(
    String metric,
    String Function(BenchmarkReport r) extract,
  ) {
    String valFor(BenchmarkMode m) {
      final r = _reportsByMode[m];
      return r != null ? extract(r) : 'N/A';
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            metric,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            valFor(BenchmarkMode.short100),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.cyanAccent,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            valFor(BenchmarkMode.medium100),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.amberAccent,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            valFor(BenchmarkMode.largeTexts),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.greenAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportMetricRow(
    String label,
    String value, {
    bool highlight = false,
    bool isAlert = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isAlert
                  ? Colors.redAccent
                  : (highlight ? Colors.tealAccent : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getModeTitle(BenchmarkMode mode) {
    switch (mode) {
      case BenchmarkMode.short100:
        return 'Test 1: 100 Short Texts';
      case BenchmarkMode.medium100:
        return 'Test 2: 100 Medium Texts';
      case BenchmarkMode.largeTexts:
        return 'Test 3: Unique Large Texts';
    }
  }

  String _getModeSubtitle(BenchmarkMode mode) {
    switch (mode) {
      case BenchmarkMode.short100:
        return '100 unique items × 10 characters each';
      case BenchmarkMode.medium100:
        return '100 unique items × 100 characters each';
      case BenchmarkMode.largeTexts:
        return '25 unique blocks × 1000 characters each';
    }
  }

  void _reset() {
    _stop1sTicker();
    _stop60FpsScroll();
    setState(() {
      _offsetY = 0.0;
      _tickCount = 0;
      _simulatedFrameNumber = 100;
      _lastFrameNumber = null;
      _lastOffsetY = null;
      _wasMoving = false;
      _cachedBin = 0;
      _rasterizeCount = 1;
      _lastFrameWasScrolling = false;
    });
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    const int w = 700;
    const int h = 220;
    final double fracY = _offsetY - _offsetY.floorToDouble();

    // 1. Settled Ground Truth at current subpixel phase
    final settledRecorder = ui.PictureRecorder();
    final settledCanvas = ui.Canvas(settledRecorder);
    settledCanvas.drawColor(const Color(0xFF010409), ui.BlendMode.src);
    settledCanvas.drawParagraph(
      _diagnosticParagraph,
      const ui.Offset(20.0, 20.0),
    );
    final settledPicture = settledRecorder.endRecording();
    final settledImage = await settledPicture.toImage(w, h);
    final settledBytes = (await settledImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();

    // 2. Active Frame Texture (If scrolling, simulates GPU bilinear sampling of Origin texture)
    final Uint8List activeBytes;
    if (_lastFrameWasScrolling) {
      final originRecorder = ui.PictureRecorder();
      final originCanvas = ui.Canvas(originRecorder);
      originCanvas.drawColor(const Color(0xFF010409), ui.BlendMode.src);
      originCanvas.drawParagraph(
        _diagnosticParagraph,
        const ui.Offset(20.0, 20.0),
      );
      final originPicture = originRecorder.endRecording();
      final originImage = await originPicture.toImage(w, h);
      final originBytes = (await originImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();

      final Uint8List resampled = Uint8List(w * h * 4);
      for (int y = 0; y < h; y++) {
        final int prevY = y > 0 ? y - 1 : 0;
        for (int x = 0; x < w; x++) {
          final int idx = (y * w + x) * 4;
          final int prevIdx = (prevY * w + x) * 4;

          for (int c = 0; c < 3; c++) {
            final double val =
                (1.0 - fracY) * originBytes[idx + c] +
                fracY * originBytes[prevIdx + c];
            resampled[idx + c] = val.clamp(0.0, 255.0).toInt();
          }
          resampled[idx + 3] = 255;
        }
      }
      activeBytes = resampled;
    } else {
      activeBytes = settledBytes;
    }

    // 3. Spatially-Aligned Difference Heatmap
    final Uint8List diffPixels = Uint8List(w * h * 4);
    int distortedCount = 0;

    for (int i = 0; i < w * h; i++) {
      final int idx = i * 4;
      final int rDiff = (activeBytes[idx] - settledBytes[idx]).abs();
      final int gDiff = (activeBytes[idx + 1] - settledBytes[idx + 1]).abs();
      final int bDiff = (activeBytes[idx + 2] - settledBytes[idx + 2]).abs();

      final int maxDiff = rDiff > gDiff
          ? (rDiff > bDiff ? rDiff : bDiff)
          : (gDiff > bDiff ? gDiff : bDiff);

      if (maxDiff > 3) {
        distortedCount++;
        if (maxDiff > 35) {
          diffPixels[idx] = 255;
          diffPixels[idx + 1] = 255;
          diffPixels[idx + 2] = 0;
          diffPixels[idx + 3] = 255;
        } else {
          diffPixels[idx] = 255;
          diffPixels[idx + 1] = (maxDiff * 4).clamp(0, 120);
          diffPixels[idx + 2] = 200;
          diffPixels[idx + 3] = 255;
        }
      } else {
        diffPixels[idx] = 13;
        diffPixels[idx + 1] = 17;
        diffPixels[idx + 2] = 23;
        diffPixels[idx + 3] = 255;
      }
    }

    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromPixels(
      diffPixels,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final ui.Image heatmap = await completer.future;

    if (mounted) {
      setState(() {
        _diffHeatmap = heatmap;
        _distortedPixelCount = distortedCount;
        _isCrisp = distortedCount < 30;
      });
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _benchmarkCountdownTimer?.cancel();
    _tickerTimer?.cancel();
    _animController.dispose();
    _benchmarkScrollController.dispose();
    _diagnosticParagraph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fracY = _offsetY - _offsetY.floorToDouble();
    final int currentBin = _calculateBin(_offsetY);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paragraph Cache Analysis & Benchmark'),
        backgroundColor: const Color(0xFF161B22),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildLiveMetricBadge(
                  'FPS',
                  _liveFps.toStringAsFixed(1),
                  _liveFps >= 55 ? Colors.tealAccent : Colors.amberAccent,
                ),
                const SizedBox(width: 8),
                _buildLiveMetricBadge(
                  'Total',
                  '${_liveTotalMs.toStringAsFixed(1)}ms',
                  _liveTotalMs < 16.7 ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                _buildLiveMetricBadge(
                  'Raster',
                  '${_liveRasterMs.toStringAsFixed(1)}ms',
                  Colors.cyanAccent,
                ),
                const SizedBox(width: 8),
                _buildLiveMetricBadge(
                  'Dropped',
                  '$_totalDroppedFrames',
                  _totalDroppedFrames > 0 ? Colors.pinkAccent : Colors.white54,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Main Tab Navigation Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFF090D12),
            child: Row(
              children: [
                _buildMainTabButton(
                  '🔍 Visual Blur & Subpixel Difference Analyzer',
                  AppTab.visualBlurAnalyzer,
                  Colors.tealAccent,
                ),
                const SizedBox(width: 10),
                _buildMainTabButton(
                  '📊 Scroll Performance Benchmark (100 Short/Med/Large)',
                  AppTab.benchmarkSuite,
                  Colors.purpleAccent,
                ),
              ],
            ),
          ),

          // 2. Control Strip (Actions for current tab)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFF161B22),
            child: _currentTab == AppTab.visualBlurAnalyzer
                ? _buildVisualAnalyzerControls(currentBin)
                : _buildBenchmarkControls(),
          ),

          // 3. Real-Time Frame Latency Sparkline Graph
          Container(
            height: 32,
            width: double.infinity,
            color: const Color(0xFF090D12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Text(
                  'Latency Timeline (16.6ms Target):',
                  style: TextStyle(fontSize: 10, color: Colors.white54),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 26),
                    painter: _FrameLatencyGraphPainter(
                      timings: _timingHistory.toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Main Viewport (Visual Blur Analyzer OR Benchmark Feed)
          Expanded(
            child: _currentTab == AppTab.visualBlurAnalyzer
                ? _buildVisualAnalyzerViewport(fracY, currentBin)
                : _buildBenchmarkViewport(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabButton(String label, AppTab tab, Color activeColor) {
    final bool isSelected = _currentTab == tab;
    return ElevatedButton(
      onPressed: () {
        if (_is60FpsScrolling) {
          _stop60FpsScroll();
        }
        setState(() {
          _currentTab = tab;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? activeColor : const Color(0xFF1E2630),
        foregroundColor: isSelected ? Colors.black : Colors.white70,
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: isSelected ? activeColor : Colors.white24),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  /// Controls for Visual Blur Analyzer Tab
  Widget _buildVisualAnalyzerControls(int currentBin) {
    return Row(
      children: [
        // 1s Ticker
        ElevatedButton.icon(
          onPressed: _isTickerRunning ? _stop1sTicker : _start1sTicker,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isTickerRunning
                ? Colors.deepOrangeAccent
                : Colors.tealAccent.shade400,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: Icon(_isTickerRunning ? Icons.pause : Icons.timer),
          label: Text(
            _isTickerRunning ? 'Pause 1s Ticker' : '▶ Start 1s Ticker',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),

        // Step 1 Discrete Tick
        ElevatedButton.icon(
          onPressed: _onDiscreteTimerTick,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigoAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.skip_next, size: 16),
          label: const Text(
            'Step 1s Tick (+60 frames)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),

        // Step 1 60 FPS Frame
        ElevatedButton.icon(
          onPressed: _onStep60FpsFrame,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.motion_photos_on, size: 16),
          label: const Text(
            'Step 60 FPS Frame (+1 frame)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),

        // 60 FPS Scroll Toggle
        ElevatedButton.icon(
          onPressed: _is60FpsScrolling
              ? _stop60FpsScroll
              : () => _start60FpsScroll(300.0),
          style: ElevatedButton.styleFrom(
            backgroundColor: _is60FpsScrolling
                ? Colors.deepOrangeAccent
                : Colors.purpleAccent.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: Icon(
            _is60FpsScrolling ? Icons.pause : Icons.fast_forward,
            size: 16,
          ),
          label: Text(
            _is60FpsScrolling ? 'Stop 60 FPS' : '60 FPS Scroll Demo',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),

        IconButton(
          onPressed: _reset,
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          tooltip: 'Reset State',
        ),
        const Spacer(),

        // Strategy Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _strategy == TrackingStrategy.consecutiveFrameSequence
                ? Colors.green.shade900.withValues(alpha: 0.6)
                : Colors.pink.shade900.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _strategy == TrackingStrategy.consecutiveFrameSequence
                  ? Colors.greenAccent
                  : Colors.pinkAccent,
            ),
          ),
          child: DropdownButton<TrackingStrategy>(
            value: _strategy,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1E2630),
            items: const [
              DropdownMenuItem(
                value: TrackingStrategy.consecutiveFrameSequence,
                child: Text(
                  'Engine Fix: Consecutive Frame Tracking',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
              DropdownMenuItem(
                value: TrackingStrategy.legacyPaintCount,
                child: Text(
                  'Legacy Option 2: Pure Paint-Count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent,
                  ),
                ),
              ),
            ],
            onChanged: (newStrat) {
              if (newStrat != null) {
                setState(() {
                  _strategy = newStrat;
                });
                _runAnalysis();
              }
            },
          ),
        ),
      ],
    );
  }

  /// Controls for Benchmark Suite Tab
  Widget _buildBenchmarkControls() {
    return Column(
      children: [
        // Mode Selector Buttons
        Row(
          children: [
            const Text(
              'Benchmark Mode:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 10),
            _buildBenchmarkSubTab(
              'Test 1: 100 Short (10ch)',
              BenchmarkMode.short100,
              Colors.cyanAccent,
            ),
            const SizedBox(width: 8),
            _buildBenchmarkSubTab(
              'Test 2: 100 Medium (100ch)',
              BenchmarkMode.medium100,
              Colors.amberAccent,
            ),
            const SizedBox(width: 8),
            _buildBenchmarkSubTab(
              'Test 3: Large Texts (1000ch)',
              BenchmarkMode.largeTexts,
              Colors.greenAccent,
            ),
            const Spacer(),
            if (_reportsByMode.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _showComparativeSummaryDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(Icons.table_chart, size: 14),
                label: const Text(
                  'Compare Reports',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Velocity Slider & Actions
        Row(
          children: [
            const Text(
              'Scroll Speed:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Slider(
                value: _scrollSpeed,
                min: 100.0,
                max: 6000.0,
                divisions: 59,
                label: '${_scrollSpeed.toStringAsFixed(0)} px/s',
                activeColor: Colors.cyanAccent,
                onChanged: (val) {
                  setState(() {
                    _scrollSpeed = val;
                  });
                },
              ),
            ),
            Text(
              '${_scrollSpeed.toStringAsFixed(0)} px/s',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            _buildSpeedPresetButton('Slow (300)', 300.0),
            _buildSpeedPresetButton('Normal (800)', 800.0),
            _buildSpeedPresetButton('Fast (2000)', 2000.0),
            _buildSpeedPresetButton('Fling (5000)', 5000.0),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isBenchmarking ? null : _runBenchmark,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              icon: _isBenchmarking
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.timer, size: 16),
              label: Text(
                _isBenchmarking
                    ? 'Testing (${_benchmarkSecondsRemaining}s)...'
                    : '▶ Run 5s Benchmark',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBenchmarkSubTab(
    String label,
    BenchmarkMode mode,
    Color activeColor,
  ) {
    final bool isSelected = _benchmarkMode == mode;
    return ElevatedButton(
      onPressed: () {
        if (_is60FpsScrolling) {
          _stop60FpsScroll();
        }
        setState(() {
          _benchmarkMode = mode;
        });
        if (_benchmarkScrollController.hasClients) {
          _benchmarkScrollController.jumpTo(0.0);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? activeColor : const Color(0xFF1E2630),
        foregroundColor: isSelected ? Colors.black : Colors.white70,
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: isSelected ? activeColor : Colors.white24),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  /// Viewport for Visual Blur Analyzer Tab
  Widget _buildVisualAnalyzerViewport(double fracY, int currentBin) {
    return Column(
      children: [
        // Status & Diagnostic Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          color: const Color(0xFF0D1117),
          child: Row(
            children: [
              Icon(
                _isCrisp ? Icons.check_circle : Icons.warning_amber_rounded,
                color: _isCrisp ? Colors.greenAccent : Colors.pinkAccent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isCrisp
                      ? '100% Crisp Settled State: Native FreeType/Canvas2D subpixel hinting is active.'
                      : 'Subpixel Bilinear Blurring Active: Texture reused across subpixel phase mismatch ($_distortedPixelCount distorted contour pixels)!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isCrisp ? Colors.greenAccent : Colors.pinkAccent,
                  ),
                ),
              ),
              _buildDiagnosticPill(
                'Frame #',
                '$_simulatedFrameNumber',
                Colors.white70,
              ),
              const SizedBox(width: 6),
              _buildDiagnosticPill(
                'Offset Y',
                '${_offsetY.toStringAsFixed(2)} px (Frac: ${fracY.toStringAsFixed(2)})',
                Colors.cyanAccent,
              ),
              const SizedBox(width: 6),
              _buildDiagnosticPill(
                'Phase Bin',
                'Bin $currentBin',
                Colors.tealAccent,
              ),
              const SizedBox(width: 6),
              _buildDiagnosticPill(
                'Rasterize Count',
                '$_rasterizeCount',
                Colors.amberAccent,
              ),
            ],
          ),
        ),

        // Split Viewport: Live Render (Top) vs. Difference Heatmap (Bottom)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Top View: Live Rendered Paragraph
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF010409),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DemoParagraphPainter(
                              paragraph: _diagnosticParagraph,
                              offsetY: _offsetY,
                              isScrolling: _lastFrameWasScrolling,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              _lastFrameWasScrolling
                                  ? 'REUSING OLD TEXTURE (BLURRED / 60 FPS MOTION)'
                                  : 'FRESH RASTERIZE (100% CRISP)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _lastFrameWasScrolling
                                    ? Colors.pinkAccent
                                    : Colors.greenAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Bottom View: Spatially-Aligned Difference Heatmap
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF010409),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCrisp
                            ? Colors.greenAccent.withValues(alpha: 0.6)
                            : Colors.pinkAccent.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (_diffHeatmap != null)
                          Center(
                            child: RawImage(
                              image: _diffHeatmap!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  color: const Color(0xFF0D1117),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Dark: 0 Error (Identical)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 10,
                                  height: 10,
                                  color: Colors.pinkAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Neon Magenta/Yellow: Bilinear Smear Distortion (${_distortedPixelCount}px)',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Viewport for Benchmark Suite Tab
  Widget _buildBenchmarkViewport() {
    switch (_benchmarkMode) {
      case BenchmarkMode.short100:
        return ListView.builder(
          controller: _benchmarkScrollController,
          itemCount: _shortTexts100.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$index',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _shortTexts100[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Text(
                    '10 chars',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            );
          },
        );
      case BenchmarkMode.medium100:
        return ListView.builder(
          controller: _benchmarkScrollController,
          itemCount: _mediumTexts100.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MEDIUM ITEM #$index',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Exact 100 Characters (Unique)',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mediumTexts100[index],
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: Color(0xFFE6EDF3),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      case BenchmarkMode.largeTexts:
        return ListView.builder(
          controller: _benchmarkScrollController,
          itemCount: _largeTextsList.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LARGE PAYLOAD BLOCK #$index',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                      const Text(
                        'Exact 1000 Characters (Unique Generated)',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _largeTextsList[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: Color(0xFFC9D1D9),
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _buildDiagnosticPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedPresetButton(String label, double speed) {
    final bool isSelected = (_scrollSpeed - speed).abs() < 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _scrollSpeed = speed;
          });
          if (_is60FpsScrolling) {
            _start60FpsScroll(speed);
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? Colors.cyanAccent : Colors.white70,
          side: BorderSide(
            color: isSelected ? Colors.cyanAccent : Colors.white24,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _DemoParagraphPainter extends CustomPainter {
  _DemoParagraphPainter({
    required this.paragraph,
    required this.offsetY,
    required this.isScrolling,
  });

  final ui.Paragraph paragraph;
  final double offsetY;
  final bool isScrolling;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawParagraph(paragraph, Offset(20.0, 40.0));
  }

  @override
  bool shouldRepaint(covariant _DemoParagraphPainter oldDelegate) {
    return oldDelegate.offsetY != offsetY ||
        oldDelegate.isScrolling != isScrolling;
  }
}

class _FrameLatencyGraphPainter extends CustomPainter {
  _FrameLatencyGraphPainter({required this.timings});

  final List<FrameTiming> timings;

  @override
  void paint(Canvas canvas, Size size) {
    if (timings.isEmpty) return;

    final targetPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    const double maxMs = 35.0;
    final double targetY = size.height * (1.0 - (16.67 / maxMs));
    canvas.drawLine(
      Offset(0, targetY),
      Offset(size.width, targetY),
      targetPaint,
    );

    final double stepX = size.width / math.max(1, timings.length - 1);
    final greenPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0;
    final yellowPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.0;
    final redPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.5;

    for (int i = 0; i < timings.length; i++) {
      final double totalMs = timings[i].totalSpan.inMicroseconds / 1000.0;
      final double x = i * stepX;
      final double barHeight = (totalMs / maxMs).clamp(0.0, 1.0) * size.height;
      final double y = size.height - barHeight;

      final Paint barPaint = totalMs <= 16.67
          ? greenPaint
          : (totalMs <= 33.33 ? yellowPaint : redPaint);

      canvas.drawLine(Offset(x, size.height), Offset(x, y), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrameLatencyGraphPainter oldDelegate) => true;
}
