import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/premium/data/billing_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

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
        _selected = plans.where((p) => p.term == PlanTerm.yearly).firstOrNull ??
            plans.firstOrNull;
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
          ? 'Tu Premium está activo.'
          : 'No encontré una compra activa en esta cuenta de Google.'),
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
                      'Avanza en tu viaje sin esperar al día siguiente y habla '
                      'con el tutor todo el mes.',
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium,
                    ),
                    const SizedBox(height: Insets.xl),
                    const _Comparison(),
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
    final monthly =
        plans.where((pl) => pl.term == PlanTerm.monthly).firstOrNull;
    final lifetime = _selected?.term == PlanTerm.lifetime;
    return [
      Text('ELIGE CUÁNTO TIEMPO', style: AppTheme.eyebrow(context)),
      const SizedBox(height: Insets.sm),
      for (final plan in plans) ...[
        _PlanCard(
          plan: plan,
          monthly: monthly,
          selected: identical(plan, _selected),
          onTap: () => setState(() => _selected = plan),
        ),
        const SizedBox(height: Insets.sm),
      ],
      const SizedBox(height: Insets.md),
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
            : Text(lifetime ? 'Comprar para siempre' : 'Suscribirme'),
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
        'Todos los planes dan el mismo Premium. Las suscripciones se renuevan '
        'solas hasta que las canceles en Google Play › Pagos y '
        'suscripciones, y siguen activas hasta el final del periodo pagado. '
        'El plan de por vida se paga una vez.',
        textAlign: TextAlign.center,
        style: context.texts.bodySmall,
      ),
    ];
  }
}

/// What Premium adds, row by row, against what stays free.
class _Comparison extends StatelessWidget {
  const _Comparison();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = [
      (
        Icons.route_rounded,
        'Lecciones del viaje',
        '${PathRepository.freeStopsPerDay} al día',
        'Sin límite',
      ),
      (
        Icons.record_voice_over_rounded,
        'Tutor por voz',
        '${UsageLimits.freeTutor.inMinutes} min de prueba',
        '${UsageLimits.premiumTutorPerMonth.inMinutes} min al mes',
      ),
      (
        Icons.healing_rounded,
        'Repaso de tus errores',
        '—',
        'Incluido',
      ),
      (
        Icons.translate_rounded,
        'Traductor y repaso con IA',
        '${UsageLimits.freeAiPerDay} al día',
        '${UsageLimits.premiumAiPerDay} al día',
      ),
      (
        Icons.ac_unit_rounded,
        'Congeladores de racha',
        'Hasta ${ProgressRepository.maxFreezes}',
        'Hasta ${ProgressRepository.premiumMaxFreezes}',
      ),
      (
        Icons.auto_stories_rounded,
        'Palabra del día, repasos y práctica',
        'Sin límite',
        'Sin límite',
      ),
    ];
    final head = context.texts.labelMedium;
    return AppCard(
      padding:
          const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.md),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                  width: 84,
                  child:
                      Text('Gratis', textAlign: TextAlign.center, style: head)),
              SizedBox(
                width: 92,
                child: Text('Premium',
                    textAlign: TextAlign.center,
                    style: head?.copyWith(
                        color: p.gold, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          for (final (icon, title, free, premium) in rows) ...[
            Divider(height: Insets.lg, color: p.border),
            Row(
              children: [
                Icon(icon, size: 18, color: p.textSecondary),
                const SizedBox(width: Insets.sm),
                Expanded(child: Text(title, style: context.texts.bodyMedium)),
                SizedBox(
                  width: 84,
                  child: Text(free,
                      textAlign: TextAlign.center,
                      style: context.texts.bodySmall),
                ),
                SizedBox(
                  width: 92,
                  child: Text(premium,
                      textAlign: TextAlign.center,
                      style: context.texts.labelLarge
                          ?.copyWith(color: p.textPrimary)),
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

  /// "Ahorras 40 %" for the yearly plan, against paying monthly.
  String? get _saving {
    final m = monthly;
    if (plan.term != PlanTerm.yearly || m == null || m.rawPrice <= 0) {
      return null;
    }
    final percent = (1 - plan.rawPrice / (m.rawPrice * 12)) * 100;
    return percent >= 5 ? 'Ahorras ${percent.round()} %' : null;
  }

  String? get _tag => switch (plan.term) {
        PlanTerm.weekly => 'Para probar',
        PlanTerm.yearly => 'El más elegido',
        PlanTerm.lifetime => 'Pago único',
        PlanTerm.monthly => null,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final saving = _saving;
    final tag = _tag;
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
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg, vertical: Insets.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: selected ? p.gold : Colors.transparent,
                width: 2,
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
                      Row(
                        children: [
                          Text(plan.term.labelEs,
                              style: context.texts.titleMedium),
                          if (tag != null) ...[
                            const SizedBox(width: Insets.sm),
                            Pill(
                                label: tag,
                                tone: plan.term == PlanTerm.yearly
                                    ? p.gold
                                    : p.textSecondary,
                                dense: true),
                          ],
                        ],
                      ),
                      Text('${plan.price} ${plan.term.perEs}',
                          style: context.texts.bodySmall),
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
