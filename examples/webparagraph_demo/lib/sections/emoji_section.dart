import 'package:flutter/material.dart';

class EmojiSection extends StatelessWidget {
  const EmojiSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          'Platform-Native Emojis',
          'WebParagraph leverages the browser\'s ability to render native system emojis. No more generic, low-resolution bundled emoji sets.',
        ),
        const SizedBox(height: 40),
        _buildGrid('Modern Emojis', [
          '🫨', '🫠', '🫡', '🫣', '🫤', '🫥', '🫧', '🪪', '🫦', '🫶', '🫰', '🦾'
        ]),
        const SizedBox(height: 40),
        _buildGrid('ZWJ Sequences', [
          '👨‍👩‍👧‍👦', '👩‍❤️‍👨', '🏳️‍🌈', '🏳️‍⚧️', '🏃‍♀️', '🕵️‍♂️', '👮‍♀️', '🧑‍🎨', '🧑‍🚀'
        ]),
        const SizedBox(height: 40),
        _buildGrid('Flags & Objects', [
          '🇺🇳', '🇪🇺', '🏴‍☠️', '🏁', '🧶', '🧵', '🧷', '🧹', '🧺', '🧻', '🧼', '🧽'
        ]),
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
              const Icon(Icons.emoji_emotions_outlined, color: Colors.cyan, size: 20),
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

  Widget _buildGrid(String label, List<String> emojis) {
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
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: emojis.map((e) => _buildEmojiBox(e)).toList(),
        ),
      ],
    );
  }

  Widget _buildEmojiBox(String emoji) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 32),
      ),
    );
  }
}
