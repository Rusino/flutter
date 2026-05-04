import 'package:flutter/material.dart';
import 'package:web/web.dart' hide Text;
import 'sections/polyglot_section.dart';
import 'sections/emoji_section.dart';
import 'sections/metrics_section.dart';
import 'sections/custom_fonts_section.dart';
import 'sections/benefits_section.dart';
import 'web_paragraph_detection.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<(_SectionInfo, Widget)> _sections = [
    (
      const _SectionInfo(
        title: 'Polyglot Text',
        subtitle: 'Multi-script layout without fallback fonts',
        icon: Icons.translate,
      ),
      const PolyglotSection(),
    ),
    (
      const _SectionInfo(
        title: 'Native Emojis',
        subtitle: 'High-fidelity platform rendering',
        icon: Icons.emoji_emotions_outlined,
      ),
      const EmojiSection(),
    ),
    (
      const _SectionInfo(
        title: 'Metrics X-Ray',
        subtitle: 'Precision text cluster visualization',
        icon: Icons.biotech_outlined,
      ),
      const MetricsSection(),
    ),
    (
      const _SectionInfo(
        title: 'Asset Fonts',
        subtitle: 'Custom font support in WebParagraph',
        icon: Icons.font_download_outlined,
      ),
      const CustomFontsSection(),
    ),
    (
      const _SectionInfo(
        title: 'The Benefits',
        subtitle: 'Engine architecture & payload size',
        icon: Icons.speed_outlined,
      ),
      const BenefitsSection(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(context),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  backgroundColor:
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                  title: Text(
                    _sections[_selectedIndex].$1.title.toUpperCase(),
                    style: const TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  bottom: isMobile
                      ? PreferredSize(
                          preferredSize: const Size.fromHeight(60),
                          child: _buildMobileTabs(),
                        )
                      : null,
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(32.0),
                  sliver: SliverToBoxAdapter(
                    child: _sections[_selectedIndex].$2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = isWebParagraphEnabled();
    final supportsTextClusters = browserSupportsTextClusters();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(
            right:
                BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
        // color: const Color(0xFF0F0F0F),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WEB\nPARAGRAPH',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEMO APP',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      isEnabled: isEnabled,
                      supportsTextClusters: supportsTextClusters,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ModeButton(
                      label: 'Normal CK',
                      active: !isEnabled,
                      onPressed: () => _toggleMode('ck'),
                    ),
                    const SizedBox(width: 8),
                    _ModeButton(
                      label: 'WebParagraph',
                      active: isEnabled,
                      onPressed: () => _toggleMode('wp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final info = _sections[index].$1;
                final isSelected = _selectedIndex == index;
                return ListTile(
                  onTap: () => setState(() => _selectedIndex = index),
                  leading: Icon(
                    info.icon,
                    size: 20,
                    color: isSelected ? Colors.cyan : Colors.white38,
                  ),
                  title: Text(
                    info.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white38,
                    ),
                  ),
                  subtitle: Text(
                    info.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.cyan.withValues(alpha: 0.7)
                          : Colors.white12,
                    ),
                  ),
                  selected: isSelected,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMode(String mode) {
    final uri = Uri.parse(window.location.href);
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

  Widget _buildMobileTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_sections.length, (index) {
          final info = _sections[index].$1;
          final isSelected = _selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(info.title),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedIndex = index);
              },
              selectedColor: Colors.cyan.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.cyan : Colors.white38,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? null : onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              active ? Colors.cyan.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: active ? Colors.cyan.withValues(alpha: 0.5) : Colors.white10,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isEnabled;
  final bool supportsTextClusters;

  const _StatusBadge({
    required this.isEnabled,
    required this.supportsTextClusters,
  });

  @override
  Widget build(BuildContext context) {
    final color = isEnabled
        ? Colors.green
        : (supportsTextClusters ? Colors.orange : Colors.red);
    final label = isEnabled
        ? 'ENABLED'
        : (supportsTextClusters ? 'DISABLED' : 'NOT SUPPORTED');

    return Tooltip(
      message: isEnabled
          ? 'WebParagraph is active'
          : (supportsTextClusters
              ? 'Browser supports WebParagraph but it is not enabled'
              : 'Browser does not support Text Clusters API'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _SectionInfo {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
