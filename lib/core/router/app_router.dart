import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/shell/main_shell.dart';
import 'package:french_pass/features/categories/presentation/pages/categories_page.dart';
import 'package:french_pass/features/categories/presentation/pages/category_words_page.dart';
import 'package:french_pass/features/progress/presentation/pages/progress_page.dart';
import 'package:french_pass/features/pronunciation/presentation/pages/pronunciation_practice_page.dart';
import 'package:french_pass/features/quiz/presentation/pages/quiz_page.dart';
import 'package:french_pass/features/settings/presentation/pages/settings_page.dart';
import 'package:french_pass/features/tutor/presentation/pages/tutor_page.dart';
import 'package:french_pass/features/tutor/presentation/pages/tutor_session_page.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';
import 'package:french_pass/features/word_of_the_day/presentation/pages/home_page.dart';
import 'package:french_pass/features/word_of_the_day/presentation/pages/word_detail_page.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) =>
                _fade(state, const HomePage()),
          ),
          GoRoute(
            path: '/tutor',
            name: 'tutor',
            pageBuilder: (context, state) =>
                _fade(state, const TutorPage()),
          ),
          GoRoute(
            path: '/quiz',
            name: 'quiz',
            pageBuilder: (context, state) =>
                _fade(state, const QuizPage()),
          ),
          GoRoute(
            path: '/categories',
            name: 'categories',
            pageBuilder: (context, state) =>
                _fade(state, const CategoriesPage()),
          ),
          GoRoute(
            path: '/progress',
            name: 'progress',
            pageBuilder: (context, state) =>
                _fade(state, const ProgressPage()),
          ),
        ],
      ),

      // Settings left the tab bar to make room for the tutor; it opens from
      // the gear on Home and from the tutor's "set up your key" prompts.
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/tutor/:lessonId',
        name: 'tutor-session',
        builder: (context, state) =>
            TutorSessionPage(lessonId: state.pathParameters['lessonId']!),
      ),

      // ── Full-screen routes (outside the tab shell) ────────────────────────
      GoRoute(
        path: '/category/:key',
        name: 'category-words',
        builder: (context, state) => CategoryWordsPage(
          categoryKey: state.pathParameters['key']!,
        ),
      ),
      GoRoute(
        path: '/word/:id',
        name: 'word-detail',
        builder: (context, state) =>
            WordDetailPage(wordId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'practice',
            name: 'pronunciation-practice',
            builder: (context, state) {
              // `extra` is lost on a cold restart of a deep link, so fall back
              // to resolving the word from the path parameter.
              final extra = state.extra;
              return PronunciationPracticePage(
                word: extra is Word ? extra : null,
                wordId: state.pathParameters['id']!,
              );
            },
          ),
        ],
      ),
    ],
  );

  /// Tab switches cross-fade rather than slide — the tabs are siblings, not a
  /// stack, so lateral motion would imply a hierarchy that isn't there.
  static CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, _, child) => FadeTransition(
          opacity: CurveTween(curve: Curves.easeOut).animate(animation),
          child: child,
        ),
      );
}
