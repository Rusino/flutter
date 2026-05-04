import 'package:flutter/material.dart';

class PolyglotSection extends StatefulWidget {
  const PolyglotSection({super.key});

  @override
  State<PolyglotSection> createState() => _PolyglotSectionState();
}

class _PolyglotSectionState extends State<PolyglotSection> {
  int _currentIndex = 0;

  static const List<(_LanguageSample, String)> _samples = [
    (
      _LanguageSample('Arabic',
          'اللغة العربية هي لغة سامية وهي أكثر اللغات السامية انتشاراً في العالم.',
          isRtl: true),
      'Middle East'
    ),
    (
      _LanguageSample(
          'Hebrew', 'שלום, איך אתה מרגיש היום? זהו הדגמה של טקסט בעברית.',
          isRtl: true),
      'Middle East'
    ),
    (
      _LanguageSample(
          'Hindi', 'नमस्ते, आप कैसे हैं? यह वेब पैराग્રાફ का एक उदाहरण है।'),
      'South Asia'
    ),
    (
      _LanguageSample(
          'Bengali', 'নমস্কার, আপনি কেমন আছেন? এটি একটি বহুভাষিক প্রদর্শন।'),
      'South Asia'
    ),
    (
      _LanguageSample('Tamil',
          'வணக்கம், நீங்கள் எப்படி இருக்கிறீர்கள்? ಇದು ஒரு தமிழ் உரை.'),
      'South Asia'
    ),
    (
      _LanguageSample('Telugu', 'నమస్కారం, మీరు ఎలా ఉన్నారు? ఇది తెలుగు వచనం.'),
      'South Asia'
    ),
    (
      _LanguageSample('Kannada', 'ನಮಸ್ಕಾರ, ನೀವು ಹೇಗಿದ್ದೀರಿ? ఇది ಕನ್ನಡ ಪಠ್ಯ.'),
      'South Asia'
    ),
    (
      _LanguageSample('Thai',
          'สวัสดีครับ คุณเป็นอย่างไรบ้าง? นี่คือตัวอย่างข้อความภาษาไทย'),
      'SE Asia'
    ),
    (
      _LanguageSample(
          'Khmer', 'សួស្តី តើអ្នកសុខสប្បាយជាទេ? នេះគឺជាអត្ថបទខ្មែរ।'),
      'SE Asia'
    ),
    (
      _LanguageSample('Lao', 'ສະບາຍດີ, ເຈົ້າເປັນແນວໃດ? ນີ້ແມ່ນຕົວຢ່າງພາສາລາວ.'),
      'SE Asia'
    ),
    (
      _LanguageSample(
          'Burmese', 'မင်္ဂလာပါ၊ သင်နေကောင်းလား। ဤသည်မှာ မြန်မာစာသားဖြစ်သည်။'),
      'SE Asia'
    ),
    (
      _LanguageSample(
          'Tibetan', 'བཀྲ་ཤིས་བདེ་ལེགས། ཁྱེད་རང་སྐུ་གཟུགས་བདེ་པོ་ཡིན་པས།'),
      'Central Asia'
    ),
    (
      _LanguageSample('Amharic', 'ሰላም፣ እንደምን ነህ? ይህ የአማርኛ ጽሑፍ ማሳያ ነው።'),
      'Africa'
    ),
    (
      _LanguageSample(
          'Georgian', 'გამარჯობა, როგორ ხართ? ეს არის ქართული ტექსტის ნიმუში.'),
      'Caucasus'
    ),
    (
      _LanguageSample(
          'Armenian', 'Բարև, ինչպես եք: Սա հայերեն տեքստի նմուշ է:'),
      'Caucasus'
    ),
    (
      _LanguageSample('Japanese', 'こんにちは、元気ですか？これは WebParagraph のデモです।'),
      'East Asia'
    ),
    (_LanguageSample('Korean', '안녕하세요, 어떻게 지내세요? 이것은 한국어 데모입니다.'), 'East Asia'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _samples.length,
      initialIndex: _currentIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Zero Font Downloads',
            'In WebParagraph mode, switching between these tabs triggers NO network requests for fonts. In Normal CanvasKit, each new script will download some fallback fonts, and tofu boxes will be rendered temporarily.',
          ),
          const SizedBox(height: 24),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorColor: Colors.cyan,
            labelColor: Colors.cyan,
            unselectedLabelColor: Colors.white24,
            onTap: (index) => setState(() => _currentIndex = index),
            tabs: _samples
                .map((s) => Tab(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.$1.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(s.$2,
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.white10)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: _buildSampleView(_samples[_currentIndex].$1),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.05),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.cyan, size: 20),
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
            style: const TextStyle(height: 1.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleView(_LanguageSample sample) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          sample.text,
          textAlign: sample.isRtl ? TextAlign.right : TextAlign.left,
          textDirection: sample.isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(
            fontSize: 32,
            height: 1.5,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _LanguageSample {
  final String name;
  final String text;
  final bool isRtl;

  const _LanguageSample(this.name, this.text, {this.isRtl = false});
}
