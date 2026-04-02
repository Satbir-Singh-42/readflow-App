import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/document.dart';
import '../theme/app_theme.dart';

class ReaderSettingsSheet extends StatefulWidget {
  final ReadingTheme currentTheme;
  final ScrollMode currentScrollMode;
  final double currentFontSize;
  final double currentBrightness;
  final bool hideMargins;
  final bool keepScreenAwake;
  final bool showTtsToggle;
  final bool isTtsEnabled;
  final ValueChanged<ReadingTheme> onThemeChanged;
  final ValueChanged<ScrollMode> onScrollModeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<bool> onHideMarginsChanged;
  final ValueChanged<bool> onKeepScreenAwakeChanged;
  final ValueChanged<bool>? onTtsToggled;

  const ReaderSettingsSheet({
    super.key,
    required this.currentTheme,
    required this.currentScrollMode,
    required this.currentFontSize,
    required this.currentBrightness,
    required this.hideMargins,
    required this.keepScreenAwake,
    this.showTtsToggle = true,
    this.isTtsEnabled = false,
    required this.onThemeChanged,
    required this.onScrollModeChanged,
    required this.onFontSizeChanged,
    required this.onBrightnessChanged,
    required this.onHideMarginsChanged,
    required this.onKeepScreenAwakeChanged,
    this.onTtsToggled,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late ReadingTheme _theme;
  late ScrollMode _scrollMode;
  late double _fontSize;
  late double _brightness;
  late bool _hideMargins;
  late bool _keepScreenAwake;
  late bool _isTtsEnabled;

  @override
  void initState() {
    super.initState();
    _theme = widget.currentTheme;
    _scrollMode = widget.currentScrollMode;
    _fontSize = widget.currentFontSize;
    _brightness = widget.currentBrightness;
    _hideMargins = widget.hideMargins;
    _keepScreenAwake = widget.keepScreenAwake;
    _isTtsEnabled = widget.isTtsEnabled;
  }

  void _setKeepScreenAwake(bool value) async {
    setState(() => _keepScreenAwake = value);
    widget.onKeepScreenAwakeChanged(value);
    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Scroll Mode Section
            _buildSectionTitle('View Mode'),
            const SizedBox(height: 12),
            _buildScrollModeSelector(),
            const SizedBox(height: 24),

            // Brightness Section
            _buildSectionTitle('Brightness'),
            const SizedBox(height: 12),
            _buildBrightnessSlider(),
            const SizedBox(height: 24),

            // Theme Section
            _buildSectionTitle('Theme'),
            const SizedBox(height: 12),
            _buildThemeSelector(),
            const SizedBox(height: 24),

            // Font Size Section
            _buildSectionTitle('Font Size'),
            const SizedBox(height: 12),
            _buildFontSizeControl(),
            const SizedBox(height: 24),

            // Toggle Options
            _buildToggleOption(
              icon: Icons.margin_rounded,
              label: 'Hide Margins',
              value: _hideMargins,
              onChanged: (v) {
                setState(() => _hideMargins = v);
                widget.onHideMarginsChanged(v);
              },
            ),
            const SizedBox(height: 12),
            _buildToggleOption(
              icon: Icons.phone_android_rounded,
              label: 'Keep Screen Awake',
              value: _keepScreenAwake,
              onChanged: _setKeepScreenAwake,
            ),
            if (widget.showTtsToggle) ...[
              const SizedBox(height: 12),
              _buildToggleOption(
                icon: Icons.volume_up_rounded,
                label: 'Text to Speech',
                value: _isTtsEnabled,
                onChanged: (v) {
                  setState(() => _isTtsEnabled = v);
                  widget.onTtsToggled?.call(v);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildScrollModeSelector() {
    return Row(
      children: [
        _ScrollModeButton(
          icon: Icons.view_stream_rounded,
          label: 'Vertical\nScroll',
          isSelected: _scrollMode == ScrollMode.vertical,
          onTap: () {
            setState(() => _scrollMode = ScrollMode.vertical);
            widget.onScrollModeChanged(ScrollMode.vertical);
          },
        ),
        const SizedBox(width: 12),
        _ScrollModeButton(
          icon: Icons.view_carousel_rounded,
          label: 'Horizontal\nScroll',
          isSelected: _scrollMode == ScrollMode.horizontal,
          onTap: () {
            setState(() => _scrollMode = ScrollMode.horizontal);
            widget.onScrollModeChanged(ScrollMode.horizontal);
          },
        ),
        const SizedBox(width: 12),
        _ScrollModeButton(
          icon: Icons.menu_book_rounded,
          label: 'Two\nPages',
          isSelected: _scrollMode == ScrollMode.twoPage,
          onTap: () {
            setState(() => _scrollMode = ScrollMode.twoPage);
            widget.onScrollModeChanged(ScrollMode.twoPage);
          },
        ),
      ],
    );
  }

  Widget _buildBrightnessSlider() {
    return Row(
      children: [
        const Icon(
          Icons.brightness_low_rounded,
          color: AppTheme.textSecondary,
          size: 20,
        ),
        Expanded(
          child: Slider(
            value: _brightness,
            min: 0.3,
            max: 1.0,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.bgHighlight,
            onChanged: (v) {
              setState(() => _brightness = v);
              widget.onBrightnessChanged(v);
            },
          ),
        ),
        const Icon(
          Icons.brightness_high_rounded,
          color: AppTheme.textSecondary,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ThemeButton(
          label: 'Day',
          color: const Color(0xFFFAF9F6),
          textColor: const Color(0xFF1A1A2E),
          isSelected: _theme == ReadingTheme.light,
          onTap: () {
            setState(() => _theme = ReadingTheme.light);
            widget.onThemeChanged(ReadingTheme.light);
          },
        ),
        _ThemeButton(
          label: 'Sepia',
          color: const Color(0xFFF4ECD8),
          textColor: const Color(0xFF3D2B1F),
          isSelected: _theme == ReadingTheme.sepia,
          onTap: () {
            setState(() => _theme = ReadingTheme.sepia);
            widget.onThemeChanged(ReadingTheme.sepia);
          },
        ),
        _ThemeButton(
          label: 'Night',
          color: AppTheme.bgDark,
          textColor: AppTheme.textPrimary,
          isSelected: _theme == ReadingTheme.dark,
          onTap: () {
            setState(() => _theme = ReadingTheme.dark);
            widget.onThemeChanged(ReadingTheme.dark);
          },
        ),
      ],
    );
  }

  Widget _buildFontSizeControl() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            final newSize = (_fontSize - 2).clamp(12.0, 32.0);
            setState(() => _fontSize = newSize);
            widget.onFontSizeChanged(newSize);
          },
          icon: const Icon(Icons.text_decrease_rounded),
          color: AppTheme.textSecondary,
        ),
        Expanded(
          child: Slider(
            value: _fontSize,
            min: 12,
            max: 32,
            divisions: 10,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.bgHighlight,
            onChanged: (v) {
              setState(() => _fontSize = v);
              widget.onFontSizeChanged(v);
            },
          ),
        ),
        IconButton(
          onPressed: () {
            final newSize = (_fontSize + 2).clamp(12.0, 32.0);
            setState(() => _fontSize = newSize);
            widget.onFontSizeChanged(newSize);
          },
          icon: const Icon(Icons.text_increase_rounded),
          color: AppTheme.textSecondary,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${_fontSize.round()}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
            inactiveTrackColor: AppTheme.bgHighlight,
            inactiveThumbColor: AppTheme.textHint,
          ),
        ],
      ),
    );
  }
}

class _ScrollModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScrollModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.bgHighlight,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page indicator widget showing current page and total pages
class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color? textColor;
  final Color? backgroundColor;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.textColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.bgCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$currentPage of $totalPages',
        style: TextStyle(
          color: textColor ?? AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Brightness overlay to dim the screen
class BrightnessOverlay extends StatelessWidget {
  final double brightness;
  final Widget child;

  const BrightnessOverlay({
    super.key,
    required this.brightness,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (brightness < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 1.0 - brightness),
              ),
            ),
          ),
      ],
    );
  }
}

/// Helper function to show the reader settings sheet
void showReaderSettingsSheet({
  required BuildContext context,
  required ReadingTheme currentTheme,
  required ScrollMode currentScrollMode,
  required double currentFontSize,
  required double currentBrightness,
  required bool hideMargins,
  required bool keepScreenAwake,
  bool showTtsToggle = true,
  bool isTtsEnabled = false,
  required ValueChanged<ReadingTheme> onThemeChanged,
  required ValueChanged<ScrollMode> onScrollModeChanged,
  required ValueChanged<double> onFontSizeChanged,
  required ValueChanged<double> onBrightnessChanged,
  required ValueChanged<bool> onHideMarginsChanged,
  required ValueChanged<bool> onKeepScreenAwakeChanged,
  ValueChanged<bool>? onTtsToggled,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ReaderSettingsSheet(
      currentTheme: currentTheme,
      currentScrollMode: currentScrollMode,
      currentFontSize: currentFontSize,
      currentBrightness: currentBrightness,
      hideMargins: hideMargins,
      keepScreenAwake: keepScreenAwake,
      showTtsToggle: showTtsToggle,
      isTtsEnabled: isTtsEnabled,
      onThemeChanged: onThemeChanged,
      onScrollModeChanged: onScrollModeChanged,
      onFontSizeChanged: onFontSizeChanged,
      onBrightnessChanged: onBrightnessChanged,
      onHideMarginsChanged: onHideMarginsChanged,
      onKeepScreenAwakeChanged: onKeepScreenAwakeChanged,
      onTtsToggled: onTtsToggled,
    ),
  );
}
