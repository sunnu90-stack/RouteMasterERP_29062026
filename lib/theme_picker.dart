import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(appThemeProvider);
    final config = ThemeHelper.getConfig(activeTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: config.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AppThemeType>(
            showSelectedIcon: false,
            selected: {activeTheme},
            segments: const [
              ButtonSegment<AppThemeType>(
                value: AppThemeType.light,
                icon: Icon(Icons.light_mode_rounded, size: 18),
                label: Text('Skyline'),
              ),
              ButtonSegment<AppThemeType>(
                value: AppThemeType.dark,
                icon: Icon(Icons.nights_stay_rounded, size: 18),
                label: Text('Midnight'),
              ),
            ],
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return config.primaryTextColor;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return config.highlightColor;
                }
                return config.cardColor;
              }),
              side: WidgetStatePropertyAll(
                BorderSide(color: config.cardBorder),
              ),
            ),
            onSelectionChanged: (selection) {
              ref.read(appThemeProvider.notifier).setTheme(selection.first);
            },
          ),
        ),
      ],
    );
  }
}
