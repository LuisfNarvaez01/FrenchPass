import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/categories/presentation/pages/categories_page.dart'
    show WordRow;
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Every word in one category, filterable by CEFR level.
class CategoryWordsPage extends StatefulWidget {
  final String categoryKey;
  const CategoryWordsPage({super.key, required this.categoryKey});

  @override
  State<CategoryWordsPage> createState() => _CategoryWordsPageState();
}

class _CategoryWordsPageState extends State<CategoryWordsPage> {
  CefrLevel? _levelFilter;

  @override
  Widget build(BuildContext context) {
    final category = WordCategoryExtension.parse(widget.categoryKey);

    if (category == null) {
      return Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: EmptyState(
              icon: Icons.category_outlined,
              title: 'Categoría desconocida',
              message: 'Vuelve al catálogo y elige otra.',
              actionLabel: 'Al catálogo',
              onAction: () => context.go('/categories'),
            ),
          ),
        ),
      );
    }

    final all = getIt<WordRepository>().byCategory(category);
    final cards = getIt<ProgressRepository>().loadCards();
    final levelsPresent = (all.map((w) => w.level).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index)));
    final words = (_levelFilter == null
        ? all
        : all.where((w) => w.level == _levelFilter).toList())
      ..sort((a, b) {
        final byLevel = a.level.index.compareTo(b.level.index);
        return byLevel != 0 ? byLevel : a.french.compareTo(b.french);
      });

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              AppSliverBar(
                title: Row(
                  children: [
                    TopicBadge(
                      icon: category.icon,
                      tone: category.toneIn(context.palette),
                      size: 32,
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(category.labelEs,
                          style: context.texts.titleLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),

              // Level filter lives in one row above the list.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.sm, Insets.page, Insets.lg),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceTag(
                          label: 'Todos · ${all.length}',
                          selected: _levelFilter == null,
                          onTap: () => setState(() => _levelFilter = null),
                        ),
                        for (final level in levelsPresent) ...[
                          const SizedBox(width: Insets.sm),
                          ChoiceTag(
                            label: level.label,
                            selected: _levelFilter == level,
                            onTap: () => setState(() => _levelFilter = level),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (words.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Nada en este nivel',
                    message: 'Prueba con otro nivel de la categoría.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, 0, Insets.page, Insets.xxxl),
                  sliver: SliverToBoxAdapter(
                    child: RowGroup(
                      children: [
                        for (final w in words)
                          WordRow(word: w, card: cards[w.id]),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
