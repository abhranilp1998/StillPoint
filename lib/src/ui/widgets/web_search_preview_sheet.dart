import 'package:flutter/material.dart';

Future<void> showWebSearchPreviewSheet(
  BuildContext context, {
  required String title,
  required String query,
  required Future<bool> Function() onOpen,
  String? body,
}) {
  final launcherContext = context;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body ??
                'This will open your browser outside Stillpoint with the search below.',
            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
              color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(query),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Stay here'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final opened = await onOpen();
                  if (!launcherContext.mounted || opened) return;
                  ScaffoldMessenger.of(launcherContext).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the browser right now.'),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Search the web'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
