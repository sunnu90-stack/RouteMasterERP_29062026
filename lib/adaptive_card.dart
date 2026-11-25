import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

class AdaptiveCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(appThemeProvider);
    final config = ThemeHelper.getConfig(activeTheme);

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: padding,
      decoration: BoxDecoration(
        color: config.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
        boxShadow: config.shadowOpacity > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: config.shadowOpacity),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: config.primaryTextColor),
        child: IconTheme.merge(
          data: IconThemeData(color: config.primaryTextColor),
          child: child,
        ),
      ),
    );

    return cardContent;
  }
}
