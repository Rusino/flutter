import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web/web.dart' hide Text;
import 'web_paragraph_detection.dart';

void main() {
  runApp(const SubpixelMotionApp());
}

class SubpixelMotionApp extends StatelessWidget {
  const SubpixelMotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subpixel Snapping & Motion Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFB300),
          surface: Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
      ),
      home: const MotionAnalyzerScreen(),
    );
  }
}

class MotionAnalyzerScreen extends StatefulWidget {
  const MotionAnalyzerScreen({super.key});

  @override
  State<MotionAnalyzerScreen> createState() => _MotionAnalyzerScreenState();
}

class _MotionAnalyzerScreenState extends State<MotionAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleMode(String mode) {
    final Uri uri = Uri.parse(window.location.href);
    final newParams = Map<String, String>.from(uri.queryParameters);
    if (mode == 'ck') {
      newParams.remove('wp');
      newParams['ck'] = '';
    } else {
      newParams.remove('ck');
      newParams['wp'] = '';
    }
    window.location.href = uri.replace(queryParameters: newParams).toString();
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final Uri uri = Uri.base;
    final bool isRequestedWp = !uri.queryParameters.containsKey('ck');
    final bool isActuallyWp = isWebParagraphEnabled();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subpixel Snapping: Continuous vs Natural Bin 0 (fract = 0.0)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          // Mode Switcher Buttons (matches webparagraph_demo)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeBtn(
                  label: 'WebParagraph (?wp)',
                  icon: Icons.speed,
                  active: isRequestedWp,
                  color: const Color(0xFF00E676),
                  onPressed: () => _toggleMode('wp'),
                ),
                const SizedBox(width: 4),
                _buildModeBtn(
                  label: 'SkParagraph (?ck)',
                  icon: Icons.text_snippet,
                  active: !isRequestedWp,
                  color: const Color(0xFFBA68C8),
                  onPressed: () => _toggleMode('ck'),
                ),
              ],
            ),
          ),
          // Live status badge detected via CanvasKit API
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActuallyWp ? const Color(0xFF004D40) : const Color(0xFF4A148C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActuallyWp ? const Color(0xFF00E676) : const Color(0xFFBA68C8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActuallyWp ? const Color(0xFF00E676) : const Color(0xFFBA68C8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActuallyWp ? 'LIVE: WebParagraph' : 'LIVE: SkParagraph (CanvasKit)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'DPR: ${dpr.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.touch_app, size: 22), text: 'Slow Trackpad Drag'),
            Tab(icon: Icon(Icons.pinch, size: 22), text: 'Two-Finger Pinch Zoom'),
            Tab(
                icon: Icon(Icons.fingerprint, size: 22),
                text: 'Holding Finger on Screen (360° Tremor)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SlowTrackpadDragTab(),
          TwoFingerPinchZoomTab(),
          HoldingFingerOnScreenTab(),
        ],
      ),
    );
  }

  Widget _buildModeBtn({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: active ? color.withAlpha(50) : Colors.white10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: active ? color : Colors.white24, width: active ? 1.5 : 1.0),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: active ? color : Colors.white70),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: active ? color : Colors.white70,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper: Large Instruction Banner
// -----------------------------------------------------------------------------

Widget buildInstructionBanner(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    color: const Color(0xFF1E293B),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 28, color: Color(0xFF38BDF8)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HOW TO REPRODUCE YOURSELF & WHAT TO LOOK FOR:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Helper: Panel Header Badge
// -----------------------------------------------------------------------------

Widget buildPanelHeader({
  required String title,
  required String subtitle,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: color.withAlpha(35),
      border: Border(bottom: BorderSide(color: color.withAlpha(120), width: 1.5)),
    ),
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: TextStyle(
              fontSize: 13,
              color: color.withAlpha(220),
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Tab 1: Slow Trackpad Drag (Combines plain text, highlights, and underlines)
// Left: Continuous float stream (arbitrary subpixel fractions)
// Right: Natural integer physical steps (fractional part == 0.0)
// -----------------------------------------------------------------------------

class SlowTrackpadDragTab extends StatefulWidget {
  const SlowTrackpadDragTab({super.key});

  @override
  State<SlowTrackpadDragTab> createState() => _SlowTrackpadDragTabState();
}

class _SlowTrackpadDragTabState extends State<SlowTrackpadDragTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Left side: continuous floating-point position
  double _posLeft = 0.0;
  double _speed = 0.04; // logical pixels per frame
  bool _isPlaying = true;
  bool _vertical = true;

  // Right side: advances strictly by whole integer physical pixels (fract == 0.0)
  double _posRightPhys = 0.0;
  double _accumulatorPhys = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _controller.repeat();
  }

  void _tick() {
    if (!_isPlaying) {
      return;
    }
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    setState(() {
      // Left side advances continuously
      _posLeft = (_posLeft + _speed) % 400.0;

      // Right side accumulates until a whole physical pixel is reached,
      // so _posRightPhys ALWAYS has fractional part == 0.0!
      _accumulatorPhys += _speed * dpr;
      while (_accumulatorPhys >= 1.0) {
        _posRightPhys = (_posRightPhys + 1.0) % (400.0 * dpr);
        _accumulatorPhys -= 1.0;
      }
      while (_accumulatorPhys <= -1.0) {
        _posRightPhys = (_posRightPhys - 1.0) % (400.0 * dpr);
        _accumulatorPhys += 1.0;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.of(context).devicePixelRatio;

    // Left physical coordinate and its fractional part
    final double physLeft = _posLeft * dpr;
    final double fractLeft = physLeft - physLeft.floorToDouble();

    // Right physical coordinate (strictly integer, fract == 0.0)
    final double posRightLogical = _posRightPhys / dpr;
    final double fractRight = _posRightPhys - _posRightPhys.floorToDouble();

    return Column(
      children: [
        buildInstructionBanner(
          'Slowly slide two fingers on your laptop trackpad or mouse wheel, or drag directly inside either panel.\n'
          '• LEFT: Continuous subpixel crawl (engine rounds to bin 0, causing the 1px hitch every few frames).\n'
          '• RIGHT: Movement advances strictly by whole physical pixels (fract = 0.000, exact bin 0).\n'
          '• HIGHLIGHTS & UNDERLINES: Notice that background rects and underlines remain 100% seamlessly locked '
          'to the text on both sides without gaps or tearing.',
        ),
        _buildControlPanel(dpr, physLeft, fractLeft, _posRightPhys, fractRight),
        Expanded(
          child: Row(
            children: [
              // Left: Continuous float offsets
              Expanded(
                child: _buildScrollColumn(
                  title: 'Continuous Motion (Arbitrary Fractions)',
                  subtitle: 'Physical fract: ${fractLeft.toStringAsFixed(3)}',
                  color: const Color(0xFF00E5FF),
                  logicalPos: _posLeft,
                  dpr: dpr,
                  onDragDelta: (delta) {
                    setState(() {
                      _isPlaying = false;
                      _posLeft += delta;
                    });
                  },
                ),
              ),
              const VerticalDivider(color: Colors.white24, width: 2),
              // Right: Natural integer physical steps (fract == 0.0)
              Expanded(
                child: _buildScrollColumn(
                  title: 'Natural Integer Steps (Fract = 0.000)',
                  subtitle: 'Physical fract: ${fractRight.toStringAsFixed(3)} (Natural Bin 0)',
                  color: const Color(0xFFFFB300),
                  logicalPos: posRightLogical,
                  dpr: dpr,
                  onDragDelta: (delta) {
                    setState(() {
                      _isPlaying = false;
                      // When dragging manually, snap step to whole physical pixels
                      _accumulatorPhys += delta * dpr;
                      while (_accumulatorPhys >= 1.0) {
                        _posRightPhys += 1.0;
                        _accumulatorPhys -= 1.0;
                      }
                      while (_accumulatorPhys <= -1.0) {
                        _posRightPhys -= 1.0;
                        _accumulatorPhys += 1.0;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(
    double dpr,
    double physLeft,
    double fractLeft,
    double physRight,
    double fractRight,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF212121),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => setState(() => _isPlaying = !_isPlaying),
              ),
              IconButton(
                icon: const Icon(Icons.fast_rewind),
                tooltip: 'Reverse',
                onPressed: () => setState(() => _speed = -_speed),
              ),
              const SizedBox(width: 12),
              Text(
                'Speed: ${_speed.toStringAsFixed(3)} px/f (${(_speed * 60).toStringAsFixed(1)} px/s)',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
              Expanded(
                child: Slider(
                  value: _speed.abs(),
                  min: 0.005,
                  divisions: 100,
                  onChanged: (v) => setState(() => _speed = _speed < 0 ? -v : v),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true, label: Text('Vertical', style: TextStyle(fontSize: 13))),
                  ButtonSegment(
                      value: false, label: Text('Horizontal', style: TextStyle(fontSize: 13))),
                ],
                selected: {_vertical},
                onSelectionChanged: (s) => setState(() => _vertical = s.first),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Single Step: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
              _stepBtn(-1.0 / dpr, '-1 DevPx'),
              _stepBtn(-0.1, '-0.10 LgPx'),
              const Spacer(),
              _stepBtn(0.1, '+0.10 LgPx'),
              _stepBtn(1.0 / dpr, '+1 DevPx'),
              const SizedBox(width: 16),
              _hudBadge(
                'Left Phys',
                '${physLeft.toStringAsFixed(2)} (fract: ${fractLeft.toStringAsFixed(2)})',
                color: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              _hudBadge(
                'Right Phys',
                '${physRight.toStringAsFixed(1)} (fract: ${fractRight.toStringAsFixed(3)})',
                color: const Color(0xFFFFB300),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(double delta, String label) {
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
        ),
        onPressed: () {
          setState(() {
            _isPlaying = false;
            _posLeft += delta;
            _posRightPhys += (delta * dpr).roundToDouble();
          });
        },
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _hudBadge(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color ?? Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollColumn({
    required String title,
    required String subtitle,
    required Color color,
    required double logicalPos,
    required double dpr,
    required ValueChanged<double> onDragDelta,
  }) {
    return Column(
      children: [
        buildPanelHeader(title: title, subtitle: subtitle, color: color),
        Expanded(
          child: GestureDetector(
            onPanUpdate: (details) {
              onDragDelta(_vertical ? -details.delta.dy : -details.delta.dx);
            },
            child: ColoredBox(
              color: const Color(0xFF181818),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SubpixelGridPainter(
                        offset: logicalPos,
                        vertical: _vertical,
                        dpr: dpr,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _vertical ? 24 : -logicalPos,
                    top: _vertical ? -logicalPos : 24,
                    right: _vertical ? 24 : null,
                    bottom: _vertical ? null : 24,
                    child: _buildTextContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 24; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$i',
                      style: const TextStyle(
                          fontSize: 17, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                if (i % 4 == 0)
                  Text(
                    'Plain text row #$i with normal layout',
                    style: const TextStyle(fontSize: 30),
                  )
                else if (i % 4 == 1)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Text with ', style: TextStyle(fontSize: 30)),
                        TextSpan(
                          text: 'Teal Alpha Background #$i',
                          style: TextStyle(
                            fontSize: 30,
                            backgroundColor: Colors.teal.withAlpha(150),
                            color: Colors.white,
                          ),
                        ),
                        const TextSpan(text: ' seamless', style: TextStyle(fontSize: 30)),
                      ],
                    ),
                  )
                else if (i % 4 == 2)
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Syntax ', style: TextStyle(fontSize: 30)),
                        TextSpan(
                          text: ' Solid Yellow Highlight ',
                          style: TextStyle(
                            fontSize: 30,
                            backgroundColor: Color(0xFFFFD600),
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: ' blocks', style: TextStyle(fontSize: 30)),
                      ],
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Underlined row #$i with decorations',
                          style: const TextStyle(
                            fontSize: 30,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.redAccent,
                            decorationThickness: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 2: Two-Finger Pinch Zoom
// Left: Continuous float zoom (font hinting continuously recalcs, glyphs wobble)
// Right: Discrete scale steps (e.g. 1.0x, 1.25x, 1.5x... holds steady, 100% stable)
// -----------------------------------------------------------------------------

class TwoFingerPinchZoomTab extends StatefulWidget {
  const TwoFingerPinchZoomTab({super.key});

  @override
  State<TwoFingerPinchZoomTab> createState() => _TwoFingerPinchZoomTabState();
}

class _TwoFingerPinchZoomTabState extends State<TwoFingerPinchZoomTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoomController;
  double _scaleLeft = 1.0;
  double _baseScale = 1.0;
  bool _isAutoZoom = true;
  double _zoomSpeed = 0.0006; // continuous scale delta per frame
  double _stepSize = 0.25; // discrete step increment on the right

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _zoomController.repeat();
  }

  void _tick() {
    if (!_isAutoZoom) {
      return;
    }
    setState(() {
      _scaleLeft += _zoomSpeed;
      if (_scaleLeft > 1.8) {
        _scaleLeft = 1.8;
        _zoomSpeed = -_zoomSpeed.abs();
      } else if (_scaleLeft < 0.8) {
        _scaleLeft = 0.8;
        _zoomSpeed = _zoomSpeed.abs();
      }
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scaleRight = ((_scaleLeft / _stepSize).round() * _stepSize).clamp(0.75, 2.0);

    return Column(
      children: [
        buildInstructionBanner(
          'Pinch with two fingers on your trackpad or touchscreen, or let auto-zoom breathe slowly.\n'
          '• LEFT (Continuous Float): Scale changes continuously on every frame. WebParagraph must re-rasterize '
          'the font via Canvas2D on every frame, causing browser font hinting to wobble individual glyph widths.\n'
          '• RIGHT (Discrete Steps): Scale holds steady at discrete steps (e.g. 1.0x, 1.25x, 1.5x). '
          'Between steps, the scale is constant—cache is preserved and text is 100% rock-solid without any wobbling.',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF212121),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filled(
                    icon: Icon(_isAutoZoom ? Icons.pause : Icons.play_arrow),
                    onPressed: () => setState(() => _isAutoZoom = !_isAutoZoom),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continuous: ${_scaleLeft.toStringAsFixed(4)}x',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Discrete: ${scaleRight.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _scaleLeft,
                      min: 0.5,
                      max: 2.2,
                      divisions: 500,
                      onChanged: (v) {
                        setState(() {
                          _isAutoZoom = false;
                          _scaleLeft = v;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<double>(
                    value: _stepSize,
                    underline: const SizedBox.shrink(),
                    dropdownColor: const Color(0xFF2A2A2A),
                    items: const [
                      DropdownMenuItem(
                          value: 0.20, child: Text('Step: 0.20x', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 0.25, child: Text('Step: 0.25x', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 0.50, child: Text('Step: 0.50x', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _stepSize = val);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Quick Jump (Discrete): ',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                  for (final step in [0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          minimumSize: Size.zero,
                          side: BorderSide(
                            color: (scaleRight - step).abs() < 0.01
                                ? const Color(0xFFFFB300)
                                : Colors.white24,
                            width: (scaleRight - step).abs() < 0.01 ? 1.5 : 1.0,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isAutoZoom = false;
                            _scaleLeft = step;
                          });
                        },
                        child: Text(
                          '${step.toStringAsFixed(2)}x',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: (scaleRight - step).abs() < 0.01
                                ? const Color(0xFFFFB300)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onScaleStart: (_) {
              _isAutoZoom = false;
              _baseScale = _scaleLeft;
            },
            onScaleUpdate: (details) {
              setState(() {
                _scaleLeft = (_baseScale * details.scale).clamp(0.5, 2.2);
              });
            },
            child: Row(
              children: [
                // Left: Continuous float scale
                Expanded(
                  child: Column(
                    children: [
                      buildPanelHeader(
                        title: 'Continuous Scale (Arbitrary Floats)',
                        subtitle:
                            'Scale: ${_scaleLeft.toStringAsFixed(4)}x (re-rasterizes each frame)',
                        color: const Color(0xFF00E5FF),
                      ),
                      Expanded(
                        child: Center(
                          child: _buildZoomCard(
                            scale: _scaleLeft,
                            alignment: Alignment.center,
                            color: const Color(0xFF00E5FF),
                            label: 'Continuous Float Zoom',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(color: Colors.white24, width: 2),
                // Right: Discrete step scale (rock-solid between steps)
                Expanded(
                  child: Column(
                    children: [
                      buildPanelHeader(
                        title: 'Discrete Scale Steps (Rock-Solid)',
                        subtitle:
                            'Step: ${scaleRight.toStringAsFixed(2)}x (holds steady, zero wobble)',
                        color: const Color(0xFFFFB300),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 32, top: 32),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: _buildZoomCard(
                              scale: scaleRight,
                              alignment: Alignment.topLeft,
                              color: const Color(0xFFFFB300),
                              label: 'Discrete Step: ${scaleRight.toStringAsFixed(2)}x',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomCard({
    required double scale,
    required Alignment alignment,
    required Color color,
    required String label,
  }) {
    return Transform.scale(
      scale: scale,
      alignment: alignment,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border.all(color: color, width: 2.0),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 14, height: 14, color: color),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            const Text(
              'The quick brown fox jumps over the lazy dog. '
              'Observe whether text baselines hop relative to the border.',
              style: TextStyle(fontSize: 24, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final word in ['Crisp', 'Device', 'Pixels', '1:1'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      word,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 3: Holding Finger on Screen (360° Tremor & Physiological Oscillation)
// Left: Smooth Subpixel 2D Motion (fluid orbital gliding via subpixel filtering)
// Right: Bin 0 Integer Snapping (abrupt 2D stair-step pops across ±0.5 thresholds)
// -----------------------------------------------------------------------------

enum TremorPattern { orbit360, figure8, horizontal, vertical }

class HoldingFingerOnScreenTab extends StatefulWidget {
  const HoldingFingerOnScreenTab({super.key});

  @override
  State<HoldingFingerOnScreenTab> createState() => _HoldingFingerOnScreenTabState();
}

class _HoldingFingerOnScreenTabState extends State<HoldingFingerOnScreenTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _oscController;
  double _amplitudePhysical = 0.75; // physical pixels (oscillates across ±0.5 boundary)
  double _frequency = 0.75; // Hz
  double _t = 0.0;
  TremorPattern _pattern = TremorPattern.orbit360;

  @override
  void initState() {
    super.initState();
    _oscController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _oscController.repeat();
  }

  void _tick() {
    setState(() {
      _t += (1.0 / 60.0) * _frequency;
    });
  }

  @override
  void dispose() {
    _oscController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final double rad = _t * 2 * math.pi;

    // Calculate 360° 2D physical tremor offsets
    var deltaPhysX = 0.0;
    var deltaPhysY = 0.0;

    switch (_pattern) {
      case TremorPattern.orbit360:
        deltaPhysX = math.cos(rad) * _amplitudePhysical;
        deltaPhysY = math.sin(rad) * _amplitudePhysical;
      case TremorPattern.figure8:
        deltaPhysX = math.cos(rad) * _amplitudePhysical;
        deltaPhysY = math.sin(rad * 2) * _amplitudePhysical;
      case TremorPattern.horizontal:
        deltaPhysX = math.sin(rad) * _amplitudePhysical;
        deltaPhysY = 0.0;
      case TremorPattern.vertical:
        deltaPhysX = 0.0;
        deltaPhysY = math.sin(rad) * _amplitudePhysical;
    }

    // Left side: Smooth 2D Subpixel Motion
    final double logicalLeftX = deltaPhysX / dpr;
    final double logicalLeftY = deltaPhysY / dpr;

    // Right side: Bin 0 Integer Snapping (snaps to nearest integer physical pixel)
    final double snapPhysX = deltaPhysX.roundToDouble();
    final double snapPhysY = deltaPhysY.roundToDouble();
    final double logicalRightX = snapPhysX / dpr;
    final double logicalRightY = snapPhysY / dpr;
    final bool isRightPopped = snapPhysX != 0.0 || snapPhysY != 0.0;

    return Column(
      children: [
        buildInstructionBanner(
          'Rest your finger lightly on a touchscreen or trackpad (physiological tremor oscillates in 360°).\n'
          '• LEFT (Smooth Subpixel): Moves continuously in 2D with floating subpixel precision. Notice the fluid, gentle orbital gliding.\n'
          '• RIGHT (Bin 0 Integer Snapping): Position is snapped to integer physical pixels. '
          'Notice how it freezes at (0, 0), then abruptly pops by 1 full pixel diagonally, horizontally, or vertically when crossing the ±0.5px line!\n'
          '• RADAR SCOPE: Look at the 2D radar below each panel to see the exact 360° trajectory and threshold crossing in real time.',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF212121),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Tremor Radius: ${_amplitudePhysical.toStringAsFixed(2)} devPx',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Slider(
                      value: _amplitudePhysical,
                      min: 0.2,
                      max: 2.0,
                      divisions: 36,
                      onChanged: (v) => setState(() => _amplitudePhysical = v),
                    ),
                  ),
                  Text(
                    'Frequency: ${_frequency.toStringAsFixed(2)} Hz',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Slider(
                      value: _frequency,
                      min: 0.2,
                      max: 2.5,
                      divisions: 23,
                      onChanged: (v) => setState(() => _frequency = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Tremor Motion Pattern: ',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(width: 8),
                  SegmentedButton<TremorPattern>(
                    segments: const [
                      ButtonSegment(
                          value: TremorPattern.orbit360,
                          label: Text('360° Circular Orbit', style: TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: TremorPattern.figure8,
                          label: Text('360° Figure-8', style: TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: TremorPattern.horizontal,
                          label: Text('Horizontal Only', style: TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: TremorPattern.vertical,
                          label: Text('Vertical Only', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_pattern},
                    onSelectionChanged: (s) => setState(() => _pattern = s.first),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left: Smooth 2D Subpixel Motion
              Expanded(
                child: Column(
                  children: [
                    buildPanelHeader(
                      title: 'Smooth 2D Subpixel Motion (Subpixel Easing)',
                      subtitle:
                          'X: ${deltaPhysX >= 0 ? '+' : ''}${deltaPhysX.toStringAsFixed(2)}px, Y: ${deltaPhysY >= 0 ? '+' : ''}${deltaPhysY.toStringAsFixed(2)}px',
                      color: const Color(0xFF00E5FF),
                    ),
                    Expanded(
                      child: Center(
                        child: _buildTremorColumn(
                          offset: Offset(logicalLeftX, logicalLeftY),
                          title: 'Smooth 360° Orbit',
                          physX: deltaPhysX,
                          physY: deltaPhysY,
                          color: const Color(0xFF00E5FF),
                          isSmoothSubpixel: true,
                          radarPhysX: deltaPhysX,
                          radarPhysY: deltaPhysY,
                          amplitude: _amplitudePhysical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(color: Colors.white24, width: 2),
              // Right: Bin 0 Integer Snapping
              Expanded(
                child: Column(
                  children: [
                    buildPanelHeader(
                      title: 'Bin 0 Integer Snapping (Abrupt 1px Jumps)',
                      subtitle: isRightPopped
                          ? 'POP: [${snapPhysX.toStringAsFixed(0)}, ${snapPhysY.toStringAsFixed(0)}] px'
                          : 'FROZEN AT: [0, 0] px',
                      color: isRightPopped ? Colors.amberAccent : const Color(0xFFFFB300),
                    ),
                    Expanded(
                      child: Center(
                        child: _buildTremorColumn(
                          offset: Offset(logicalRightX, logicalRightY),
                          title: 'Integer Snapped (Bin 0)',
                          physX: snapPhysX,
                          physY: snapPhysY,
                          color: const Color(0xFFFFB300),
                          isSmoothSubpixel: false,
                          radarPhysX: snapPhysX,
                          radarPhysY: snapPhysY,
                          amplitude: _amplitudePhysical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTremorColumn({
    required Offset offset,
    required String title,
    required double physX,
    required double physY,
    required Color color,
    required bool isSmoothSubpixel,
    required double radarPhysX,
    required double radarPhysY,
    required double amplitude,
  }) {
    Widget cardContent = Container(
      width: 500,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: color.withAlpha(200), width: 2.0),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 14, color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Text(
            isSmoothSubpixel
                ? 'Phys Offset: (${physX >= 0 ? '+' : ''}${physX.toStringAsFixed(2)}, ${physY >= 0 ? '+' : ''}${physY.toStringAsFixed(2)}) px'
                : 'Snapped: (${physX >= 0 ? '+' : ''}${physX.toStringAsFixed(0)}, ${physY >= 0 ? '+' : ''}${physY.toStringAsFixed(0)}) devPx',
            style:
                const TextStyle(fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'The quick brown fox jumps over the lazy dog. '
            'Watch the border and text closely against the crosshairs.',
            style: TextStyle(fontSize: 20, height: 1.4),
          ),
        ],
      ),
    );

    if (isSmoothSubpixel) {
      // Composited layer preserves subpixel antialiasing transform during translation
      cardContent = RepaintBoundary(child: cardContent);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 2D Radar Display showing the 360° subpixel orbit and threshold
        Container(
          width: 130,
          height: 130,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(120), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withAlpha(30), blurRadius: 10),
            ],
          ),
          child: CustomPaint(
            painter: SubpixelRadarPainter(
              physX: radarPhysX,
              physY: radarPhysY,
              amplitude: amplitude,
              color: color,
              isSmooth: isSmoothSubpixel,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Reference stationary hairline marker
        Container(
          width: 500,
          height: 2,
          color: Colors.redAccent.withAlpha(150),
        ),
        const SizedBox(height: 12),
        // Translated card
        Transform.translate(
          offset: offset,
          child: cardContent,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Helper: 2D Subpixel Radar Scope Painter
// -----------------------------------------------------------------------------

class SubpixelRadarPainter extends CustomPainter {
  SubpixelRadarPainter({
    required this.physX,
    required this.physY,
    required this.amplitude,
    required this.color,
    required this.isSmooth,
  });

  final double physX;
  final double physY;
  final double amplitude;
  final Color color;
  final bool isSmooth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 1 physical pixel = 35 screen pixels on this radar magnification
    const scale = 35.0;

    // Crosshairs
    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);

    // ±0.5px Rounding threshold box (red dashed border)
    final thresholdPaint = Paint()
      ..color = Colors.redAccent.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final thresholdRect = Rect.fromCenter(
      center: center,
      width: 1.0 * scale,
      height: 1.0 * scale,
    );
    canvas.drawRect(thresholdRect, thresholdPaint);

    // Orbit path outline
    final orbitPaint = Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, amplitude * scale, orbitPaint);

    // Position dot
    final dotPos = Offset(center.dx + physX * scale, center.dy + physY * scale);
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (isSmooth) {
      // Smooth circular dot
      canvas.drawCircle(dotPos, 6.0, dotPaint);
      final glowPaint = Paint()
        ..color = color.withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotPos, 10.0, glowPaint);
    } else {
      // Stepped square marker (pops across integer positions)
      canvas.drawRect(Rect.fromCenter(center: dotPos, width: 12, height: 12), dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SubpixelRadarPainter oldDelegate) =>
      oldDelegate.physX != physX ||
      oldDelegate.physY != physY ||
      oldDelegate.amplitude != amplitude;
}

// -----------------------------------------------------------------------------
// Helper: Subpixel Grid Painter
// -----------------------------------------------------------------------------

class SubpixelGridPainter extends CustomPainter {
  SubpixelGridPainter({
    required this.offset,
    required this.vertical,
    required this.dpr,
  });

  final double offset;
  final bool vertical;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.cyan.withAlpha(40)
      ..strokeWidth = 1.0 / dpr;

    const logicalStep = 40.0;
    if (vertical) {
      for (double y = 0; y < size.height; y += logicalStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else {
      for (double x = 0; x < size.width; x += logicalStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SubpixelGridPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.vertical != vertical;
}
