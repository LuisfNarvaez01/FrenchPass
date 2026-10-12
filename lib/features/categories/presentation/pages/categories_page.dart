import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _words = getIt<WordRepository>();
  final _progress = getIt<ProgressRepository>();
  final _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final favorites = _progress.loadFavorites();
    final searching = _query.trim().isNotEmpty;
    final results = searching ? _words.search(_query) : const <Word>[];

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.page, Insets.xl, Insets.page, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogo', style: context.texts.headlineLarge),
                    const SizedBox(height: Insets.xs),
                    Text(
                      '${_words.all.length} palabras · '
                      '${WordCategory.values.length} categorías · A1–C2',
                      style: context.texts.bodyMedium,
                    ),
                    const SizedBox(height: Insets.xl),
                    _SearchField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
            ),
            if (searching)
              _WordSliverList(words: results, emptyQuery: _query)
            else ...[
              if (favorites.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.page, Insets.xl, Insets.page, 0),
                    child: AppCard(
                      accent: true,
                      onTap: () => _openFavorites(favorites),
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_rounded, color: p.gold, size: 22),
                          const SizedBox(width: Insets.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tus palabras guardadas',
                                    style: context.texts.titleMedium),
                                Text(
                                  '${favorites.length} '
                                  '${favorites.length == 1 ? 'palabra' : 'palabras'}',
                                  style: context.texts.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: p.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.page, Insets.xl, Insets.page, Insets.xxxl),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Insets.md,
                    crossAxisSpacing: Insets.md,
                    childAspectRatio: 1.08,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: WordCategory.values.length,
                    (context, i) {
                      final category = WordCategory.values[i];
                      return _CategoryTile(
                        category: category,
                        count: _words.countForCategory(category),
                      )
                          .animate()
                          .fadeIn(delay: (30 * i).ms, duration: Motion.base)
                          .slideY(begin: 0.08, end: 0);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openFavorites(Set<String> favorites) {
    final words = favorites.map(_words.byId).whereType<Word>().toList()
      ..sort((a, b) => a.french.compareTo(b.french));

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WordListScaffold(
          title: 'Guardadas',
          subtitle: '${words.length} palabras',
          words: words,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: context.texts.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Buscar en francés o español…',
        hintStyle: context.texts.bodyMedium?.copyWith(color: p.textMuted),
        prefixIcon: Icon(Icons.search_rounded, color: p.textMuted, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: p.textMuted),
                tooltip: 'Limpiar',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: Insets.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: p.gold),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final WordCategory category;
  final int count;

  const _CategoryTile({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = category.toneIn(p);
    return AppCard(
      onTap: () => context.push('/category/${category.key}'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Stack(
          children: [
            // The same icon, oversized and cropped by the corner: gives each
            // tile its own silhouette at a glance.
            Positioned(
              right: -18,
              bottom: -22,
              child: IgnorePointer(
                child: Icon(category.icon,
                    size: 104, color: tone.withValues(alpha: 0.08)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TopicBadge(icon: category.icon, tone: tone),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.labelEs,
                        style: context.texts.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('$count palabras',
                          style: context.texts.labelSmall
                              ?.copyWith(color: tone, letterSpacing: 0.2)),
                    ],
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

/// Shared word row + list, reused by search results, category pages and
/// favourites.
class WordRow extends StatelessWidget {
  final Word word;
  const WordRow({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => context.push('/word/${word.id}'),
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md),
      child: Row(
        children: [
          TopicBadge(
            icon: word.category.icon,
            tone: word.category.toneIn(p),
            size: 34,
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.french, style: context.texts.titleMedium),
                const SizedBox(height: 2),
                Text(
                  word.translationEs,
                  style: context.texts.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Pill(label: word.level.label, tone: p.terracotta, dense: true),
          const SizedBox(width: Insets.sm),
          Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
        ],
      ),
    );
  }
}

class _WordSliverList extends StatelessWidget {
  final List<Word> words;
  final String emptyQuery;

  const _WordSliverList({required this.words, required this.emptyQuery});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Sin resultados',
          message: 'Nada coincide con «$emptyQuery».',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.xl, Insets.page, Insets.xxxl),
      sliver: SliverList.separated(
        itemCount: words.length,
        separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
        itemBuilder: (context, i) => WordRow(word: words[i]),
      ),
    );
  }
}

/// Full-screen list used for favourites.
class _WordListScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Word> words;

  const _WordListScaffold({
    required this.title,
    required this.subtitle,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              AppSliverBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: context.texts.titleLarge),
                    Text(subtitle, style: context.texts.labelSmall),
                  ],
                ),
              ),
              if (words.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Nada guardado aún',
                    message:
                        'Toca "Guardar" en una palabra para tenerla a mano.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.sm, Insets.page, Insets.xxxl),
                  sliver: SliverList.separated(
                    itemCount: words.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Insets.sm),
                    itemBuilder: (context, i) => WordRow(word: words[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
