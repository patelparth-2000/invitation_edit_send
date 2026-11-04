import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Grid tile for a saved invitation: thumbnail, name, subtitle, menu.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumb,
    this.onTap,
    this.menu = const [],
    this.onMenuSelected,
  });

  final String title;
  final String subtitle;
  final ImageProvider thumb;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>> menu;
  final ValueChanged<String>? onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                image: true,
                label: '$title invitation image',
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Image(
                    image: thumb,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 36)),
                          SizedBox(height: AppSpacing.xs),
                          Text('Image missing'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.m, top: AppSpacing.xs, bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (menu.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      itemBuilder: (_) => menu,
                      onSelected: onMenuSelected,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
