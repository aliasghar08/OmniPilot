import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Section 7 of the Period Form: Participation & Punctuality Slider.
class ParticipationSliderSection extends StatelessWidget {
  final double participationScore;
  final ValueChanged<double> onChanged;

  const ParticipationSliderSection({
    super.key,
    required this.participationScore,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderLabel(
          title: '7. Participation & Punctuality Score: ${participationScore.round()}%',
          leadingIcon: Icons.stars_outlined,
          iconColor: Colors.indigo,
        ),
        Slider(
          value: participationScore,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${participationScore.round()}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
