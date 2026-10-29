import 'package:flutter/material.dart';

/// Reusable section title header for structured multi-part forms and cards.
class SectionHeaderLabel extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final Color? iconColor;

  const SectionHeaderLabel({
    super.key,
    required this.title,
    this.leadingIcon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (leadingIcon == null) {
      return Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Row(
      children: [
        Icon(
          leadingIcon,
          size: 18,
          color: iconColor ?? Colors.indigo,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}

