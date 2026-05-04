import 'package:flutter/material.dart';

class MetricsSection extends StatefulWidget {
  const MetricsSection({super.key});

  @override
  State<MetricsSection> createState() => _MetricsSectionState();
}

class _MetricsSectionState extends State<MetricsSection> {
  bool _showXRay = true;
  final String _sampleText = 'Precision layout via Chromium Text Clusters API. '
      'Every glyph and cluster is measured with sub-pixel accuracy.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'This mode visualizes the underlying metrics that WebParagraph provides to Flutter.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            Switch(
              value: _showXRay,
              onChanged: (v) => setState(() => _showXRay = v),
              activeColor: Colors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: _showXRay
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, 200),
                      painter: _MetricsPainter(
                        text: _sampleText,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                )
              : Text(
                  _sampleText,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }
}

class _MetricsPainter extends CustomPainter {
  final String text;
  final TextStyle style;

  _MetricsPainter({required this.text, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width);
    textPainter.paint(canvas, Offset.zero);

    // Draw bounding boxes for each character/cluster
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fillPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < text.length; i++) {
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );

      for (final box in boxes) {
        final rect = box.toRect();
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MetricsPainter oldDelegate) =>
      text != oldDelegate.text || style != oldDelegate.style;
}
