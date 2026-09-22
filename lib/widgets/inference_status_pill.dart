import 'package:flutter/material.dart';

/// Small pill for the app bar / chat header that shows which backend is
/// currently answering — swap for whatever bool/enum
/// ChatController.shouldUseRemote exposes.
class InferenceStatusPill extends StatelessWidget {
  const InferenceStatusPill({
    super.key,
    required this.usingRemote,
    this.modelLabel,
  });

  /// true  -> answering via the laptop's Ollama/GPU relay (brass)
  /// false -> answering on-device, CPU-local (signal-blue)
  final bool usingRemote;
  final String? modelLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = usingRemote ? scheme.secondary : scheme.primary;
    final label = modelLabel ?? (usingRemote ? 'Laptop GPU' : 'On device');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}