// lib/features/dictionary/widgets/dictionary_entry_tile.dart

import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

/// A list tile that shows a [DictionaryEntry]'s term and a short
/// excerpt of its definition. Tapping opens the detail view.
class DictionaryEntryTile extends StatelessWidget {
  const DictionaryEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final DictionaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Strong's badge / term label
            Flexible(
              flex: 1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.term,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Definition preview
            Expanded(
              flex: 3,
              child: Text(
                entry.plainText,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
