import 'package:flutter/material.dart';

class CustomFontsSection extends StatelessWidget {
  const CustomFontsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          'Custom Asset Fonts',
          'WebParagraph isn\'t just for system fonts. It seamlessly handles custom .ttf/.otf assets loaded via pubspec.yaml.',
        ),
        const SizedBox(height: 40),
        _buildFontSample(
          'Homemade Apple (Cursive)',
          'The quick brown fox jumps over the lazy dog.',
          'HomemadeApple',
        ),
        const SizedBox(height: 20),
        _buildFontSample(
          'Monospace (System)',
          'void main() => print("WebParagraph is awesome!");',
          'monospace',
        ),
        const SizedBox(height: 20),
        _buildFontSample(
          'Serif (System)',
          'A classic serif font rendered via the browser\'s native engine.',
          'serif',
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.05),
        border: Border.all(color: Colors.cyan.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.font_download_outlined, color: Colors.cyan, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSample(String label, String text, String fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white24,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 28,
              fontFamily: fontFamily,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
