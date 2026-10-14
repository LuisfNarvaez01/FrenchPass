import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/premium/data/billing_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';

/// What Premium includes and how to get it. Prices come from Google Play,
/// already in the learner's currency.
class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final _billing = getIt<BillingService>();
  final _usage = getIt<UsageService>();

  List<PremiumPlan>? _plans;
  PremiumPlan? _selected;
  bool _loadFailed = false;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _billing.isPremium.addListener(_onChange);
    _billing.pending.addListener(_onChange);
    _load();
  }

  @override
  void dispose() {
    _billing.isPremium.removeListener(_onChange);
    _billing.pending.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() => _buying = false);
  }

  Future<void> _load() async {
    if (!_billing.canBuy) {
      setState(() => _plans = const []);
      return;
    }
    setState(() => _loadFailed = false);
    try {
      final plans = await _billing.plans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loadFailed = plans.isEmpty;
        // The yearly plan is the better deal; start there.
        _selected =
            plans.where((p) => p.isYearly).firstOrNull ?? plans.firstOrNull;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _buy() async {
    final plan = _selected;
    if (plan == null) return;
    setState(() => _buying = true);
    try {
      await _billing.buy(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _buying = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo abrir el pago. Inténtalo otra vez.')));
    }
  }

  Future<void> _restore() async {
    await _billing.restore();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_billing.isPremium.value
          ? 'Tu suscripción está activa.'
          : 'No encontré una suscripción activa en esta cuenta de Google.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final premium = _billing.isPremium.value;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'Premium'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.md, Insets.page, Insets.xxxl),
                  children: [
                    const Center(child: MascotSticker(size: 112)),
                    const SizedBox(height: Insets.lg),
                    Text('FrenchPass Premium',
                        textAlign: TextAlign.center,
                        style: context.texts.headlineMedium),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Para hablar con el tutor todo el mes, no solo en la '
                      'prueba.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodySmall,
                    ),
                    const SizedBox(height: Insets.xl),
                    const _Benefits(),
                    const SizedBox(height: Insets.xl),
                    if (premium)
                      _ActiveCard(minutesLeft: _usage.tutorTimeLeft().inMinutes)
                    else
                      ..._purchaseSection(context),
                  ].animate(interval: 40.ms).fadeIn(duration: Motion.base),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _purchaseSection(BuildContext context) {
    final p = context.palette;
    final plans = _plans;
    if (!_billing.canBuy) {
      return const [
        InfoNotice(
          icon: Icons.storefront_outlined,
          message: 'Las compras funcionan en la versión de FrenchPass '
              'instalada desde Google Play.',
        ),
      ];
    }
    if (plans == null) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_loadFailed) return [_PlansError(onRetry: _load)];
    final monthly = plans.where((pl) => !pl.isYearly).firstOrNull;
    return [
      for (final plan in plans) ...[
        _PlanCard(
          plan: plan,
          monthly: monthly,
          selected: identical(plan, _selected),
          onTap: () => setState(() => _selected = plan),
        ),
        const SizedBox(height: Insets.md),
      ],
      const SizedBox(height: Insets.sm),
      ElevatedButton(
        onPressed: _selected == null || _buying || _billing.pending.value
            ? null
            : _buy,
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: _buying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Suscribirme'),
      ),
      if (_billing.pending.value) ...[
        const SizedBox(height: Insets.md),
        InfoNotice(
          icon: Icons.hourglass_top_rounded,
          iconColor: p.warning,
          message: 'Tu pago está pendiente. Premium se activa en cuanto '
              'Google Play lo confirme.',
        ),
      ],
      const SizedBox(height: Insets.sm),
      TextButton(
        onPressed: _restore,
        child: const Text('Ya pagué: restaurar la compra'),
      ),
      const SizedBox(height: Insets.md),
      Text(
        'La suscripción se renueva sola hasta que la canceles en Google Play '
        '› Pagos y suscripciones. Si la cancelas, Premium sigue activo hasta '
        'el final del periodo que pagaste.',
        textAlign: TextAlign.center,
        style: context.texts.bodySmall,
      ),
    ];
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tutorMinutes = UsageLimits.premiumTutorPerMonth.inMinutes;
    final rows = [
      (
        Icons.record_voice_over_rounded,
        '$tutorMinutes minutos al mes con el tutor por voz',
        'Unas quince lecciones de diez minutos.',
      ),
      (
        Icons.translate_rounded,
        'Traductor y repaso frase por frase',
        'Hasta ${UsageLimits.premiumAiPerDay} consultas al día, en vez de '
            '${UsageLimits.freeAiPerDay}.',
      ),
      (
        Icons.auto_stories_rounded,
        'Lo gratuito sigue igual',
        'Palabra del día, quiz, repasos y pronunciación, sin límite.',
      ),
    ];
    return AppCard(
      child: Column(
        children: [
          for (final (i, (icon, title, detail)) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: Insets.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: p.gold, size: 22),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.texts.titleMedium),
                      const SizedBox(height: 2),
                      Text(detail, style: context.texts.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final PremiumPlan? monthly;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.monthly,
    required this.selected,
    required this.onTap,
  });

  /// "Ahorras 33 %" against paying monthly for a year.
  String? get _saving {
    final m = monthly;
    if (!plan.isYearly || m == null || m.details.rawPrice <= 0) return null;
    final percent =
        (1 - plan.details.rawPrice / (m.details.rawPrice * 12)) * 100;
    return percent >= 5 ? 'Ahorras ${percent.round()} %' : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final saving = _saving;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.gold.withValues(alpha: 0.10) : p.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Container(
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: selected ? p.gold : p.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? p.gold : p.textMuted,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.isYearly ? 'Anual' : 'Mensual',
                          style: context.texts.titleMedium),
                      Text(
                        plan.isYearly
                            ? '${plan.price} al año'
                            : '${plan.price} al mes',
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (saving != null)
                  Pill(label: saving, tone: p.good, dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final int minutesLeft;
  const _ActiveCard({required this.minutesLeft});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      accent: true,
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: p.good, size: 26),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tienes Premium', style: context.texts.titleMedium),
                Text(
                  minutesLeft == 1
                      ? 'Te queda 1 minuto con el tutor este mes.'
                      : 'Te quedan $minutesLeft minutos con el tutor este '
                          'mes.',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The plans couldn't be loaded from Play.
class _PlansError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PlansError({required this.onRetry});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No pude cargar los planes de Google Play. Revisa tu conexión.',
              style: context.texts.bodyMedium,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: onRetry, child: const Text('Reintentar')),
            ),
          ],
        ),
      );
}
