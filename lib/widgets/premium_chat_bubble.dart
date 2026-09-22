import 'package:flutter/material.dart';
import 'glass_container.dart';

/// Drop-in replacement for whatever widget currently renders one message
/// in home_screen.dart's message list.
class PremiumChatBubble extends StatelessWidget {
  const PremiumChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.imagePath,
  });

  final String text;
  final bool isUser;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    // User messages get the signal-blue accent; assistant replies stay
    // neutral glass so the accent still means one thing.
    final accent = isUser ? scheme.primary : null;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: GlassContainer(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePath!,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}