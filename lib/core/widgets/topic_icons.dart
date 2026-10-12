import 'package:flutter/material.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Drawn icons for categories and tutor lessons, from one family (Material
/// Rounded/Outlined), in place of the emoji they used to carry.
extension WordCategoryIcon on WordCategory {
  IconData get icon => switch (this) {
        WordCategory.dailyLife => Icons.wb_twilight_rounded,
        WordCategory.food => Icons.bakery_dining_outlined,
        WordCategory.travel => Icons.flight_takeoff_rounded,
        WordCategory.business => Icons.work_outline_rounded,
        WordCategory.emotions => Icons.favorite_border_rounded,
        WordCategory.technology => Icons.devices_outlined,
        WordCategory.nature => Icons.eco_outlined,
        WordCategory.culture => Icons.theater_comedy_outlined,
        WordCategory.health => Icons.healing_outlined,
        WordCategory.home => Icons.chair_outlined,
        WordCategory.conversation => Icons.chat_bubble_outline_rounded,
      };

  /// Alternates the two brand hues so a grid of tiles has rhythm without
  /// borrowing the status colours.
  Color toneIn(AppPalette p) => index.isEven ? p.gold : p.terracotta;
}

extension LessonIcon on Lesson {
  IconData get icon => switch (id) {
        'presentarse' => Icons.waving_hand_outlined,
        'cafe' => Icons.local_cafe_outlined,
        'direcciones' => Icons.explore_outlined,
        'panaderia' => Icons.bakery_dining_outlined,
        'hotel' => Icons.hotel_outlined,
        'restaurante' => Icons.restaurant_outlined,
        'compras' => Icons.checkroom_outlined,
        'tren' => Icons.train_outlined,
        'farmacia' => Icons.medication_outlined,
        'aficiones' => Icons.palette_outlined,
        'planes' => Icons.event_outlined,
        'entrevista' => Icons.work_outline_rounded,
        _ => Icons.forum_outlined,
      };
}

/// An icon on a softly tinted rounded square -- the slot the emoji used to
/// fill, at the same footprint.
class TopicBadge extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final double size;

  const TopicBadge({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: size * 0.5, color: tone),
    );
  }
}
