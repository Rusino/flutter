import 'package:flutter/material.dart';

class BenefitsSection extends StatelessWidget {
  const BenefitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Under the Hood: Why WebParagraph Matters',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'By refactoring the text layout system to use the browser\'s native Text Clusters API, we achieve significant improvements in both performance and bundle size.',
          style: TextStyle(fontSize: 16, color: Colors.white60, height: 1.5),
        ),
        const SizedBox(height: 48),
        _buildBenefitCard(
          'Smaller Bundle Size',
          'Removed HarfBuzz, Freetype, and custom Brotli decoders from the engine. This reduces the initial WASM/JS payload significantly.',
          Icons.unarchive_outlined,
          '~2MB Reduction',
        ),
        const SizedBox(height: 24),
        _buildBenefitCard(
          'Zero Font Downloads',
          'Eliminated the need for heavy fallback font bundles (like Noto Sans) to render non-latin scripts. The browser handles it natively.',
          Icons.cloud_off_outlined,
          'Up to 10MB saved',
        ),
        const SizedBox(height: 24),
        _buildBenefitCard(
          'Native Performance',
          'Layout calculations are now performed by the browser\'s highly optimized C++ engine instead of being emulated in WASM/JS.',
          Icons.bolt_outlined,
          'Faster TTI',
        ),
        const SizedBox(height: 24),
        _buildBenefitCard(
          'Better OS Integration',
          'Text selection, accessibility, and native context menus work more seamlessly with the platform\'s expected behavior.',
          Icons.integration_instructions_outlined,
          'Improved A11y',
        ),
      ],
    );
  }

  Widget _buildBenefitCard(String title, String description, IconData icon, String metric) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.cyan, size: 28),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        metric,
                        style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
