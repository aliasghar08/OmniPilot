import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Reusable rounded brand icon widget displaying the OmniPilot launcher artwork.
class AppBrandIcon extends StatelessWidget {
  final double size;
  final double borderRadius;

  const AppBrandIcon({
    super.key,
    this.size = 32,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        AppConstants.appIconAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: size * 0.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }
}
