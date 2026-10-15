import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:french_pass/core/config/app_channel.dart';
import 'package:french_pass/core/services/storage_service.dart';

/// How long a plan lasts. Every plan unlocks the same Premium.
enum PlanTerm {
  weekly('Semanal', 'por semana'),
  monthly('Mensual', 'por mes'),
  yearly('Anual', 'por año'),
  lifetime('De por vida', 'un solo pago');

  final String labelEs;
  final String perEs;
  const PlanTerm(this.labelEs, this.perEs);
}

/// One way to pay for Premium, as Google Play sells it.
class PremiumPlan {
  final GooglePlayProductDetails details;
  final PlanTerm term;

  const PremiumPlan(this.details, this.term);

  /// Localised by Play, e.g. "US$ 4,99" or "COP 12.900".
  String get price => details.price;

  /// The price in micros, to compare plans.
  double get rawPrice => details.rawPrice;
}

/// Premium, sold on Google Play as a subscription (weekly, monthly or
/// yearly base plans) or as a one-time lifetime purchase.
///
/// Play is the source of truth: on start the app asks it for active
/// purchases, and keeps the last answer so Premium still works offline.
/// The GitHub build is never sold (it isn't on Play) and counts as Premium;
/// strangers who install it can't reach the AI anyway, because App Check
/// only accepts the debug tokens the developer registered.
class BillingService {
  /// Subscription id in Play Console, with three base plans.
  static const productId = 'premium';
  static const weeklyPlan = 'semanal';
  static const monthlyPlan = 'mensual';
  static const yearlyPlan = 'anual';

  /// One-time (non-consumable) in-app product.
  static const lifetimeId = 'premium_vida';

  static const _ids = {productId, lifetimeId};

  final StorageService _storage;
  BillingService(this._storage);

  final ValueNotifier<bool> isPremium = ValueNotifier(false);

  /// A purchase is waiting on the payment method (cash, bank transfer).
  final ValueNotifier<bool> pending = ValueNotifier(false);

  bool _storeAvailable = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// False on devices without Google Play, and on the GitHub build.
  bool get canBuy => _storeAvailable;

  Future<void> init() async {
    if (AppChannel.isGithub) {
      isPremium.value = true;
      return;
    }
    isPremium.value = _storage.getBool(StorageKeys.premiumCached) ?? false;
    try {
      final store = InAppPurchase.instance;
      _storeAvailable = await store.isAvailable();
      if (!_storeAvailable) return;
      _sub = store.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('BillingService stream: $e'),
      );
      await refresh();
    } catch (e) {
      debugPrint('BillingService.init failed: $e');
    }
  }

  /// Asks Play which purchases are active right now: a live subscription
  /// or the lifetime product. Keeps the cached answer if Play can't be
  /// reached.
  Future<void> refresh() async {
    if (!_storeAvailable) return;
    try {
      final android = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await android.queryPastPurchases();
      if (response.error != null) return;
      final mine =
          response.pastPurchases.where((p) => _ids.contains(p.productID));
      for (final purchase in mine) {
        await _acknowledge(purchase);
      }
      await _setPremium(mine.any((p) => p.status == PurchaseStatus.purchased));
    } catch (e) {
      debugPrint('BillingService.refresh failed: $e');
    }
  }

  /// The plans Play offers, shortest first and lifetime last. Empty if Play
  /// can't be reached or nothing is set up in Play Console yet.
  Future<List<PremiumPlan>> plans() async {
    if (!_storeAvailable) return const [];
    final response = await InAppPurchase.instance.queryProductDetails(_ids);
    final plans = <PremiumPlan>[];
    for (final product in response.productDetails) {
      if (product is! GooglePlayProductDetails) continue;
      if (product.id == lifetimeId) {
        plans.add(PremiumPlan(product, PlanTerm.lifetime));
        continue;
      }
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      if (index == null || offers == null) continue;
      final offer = offers[index];
      // Base plans only; promotional offers would show up as duplicates.
      if (offer.offerId != null) continue;
      final term = switch (offer.basePlanId) {
        weeklyPlan => PlanTerm.weekly,
        monthlyPlan => PlanTerm.monthly,
        yearlyPlan => PlanTerm.yearly,
        _ => null,
      };
      if (term != null) plans.add(PremiumPlan(product, term));
    }
    plans.sort((a, b) => a.term.index.compareTo(b.term.index));
    return plans;
  }

  /// Opens Play's purchase sheet. The result arrives on the purchase
  /// stream, which updates [isPremium].
  Future<bool> buy(PremiumPlan plan) => InAppPurchase.instance.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: plan.details,
          // Subscriptions name their base plan's offer; a one-time product
          // has none.
          offerToken:
              plan.term == PlanTerm.lifetime ? null : plan.details.offerToken,
        ),
      );

  Future<void> restore() => refresh();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!_ids.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          pending.value = false;
          await _setPremium(true);
        case PurchaseStatus.pending:
          pending.value = true;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          pending.value = false;
      }
      await _acknowledge(purchase);
    }
  }

  /// Play refunds a purchase that isn't acknowledged within three days.
  Future<void> _acknowledge(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await InAppPurchase.instance.completePurchase(purchase);
    } catch (e) {
      debugPrint('BillingService could not acknowledge: $e');
    }
  }

  Future<void> _setPremium(bool value) async {
    isPremium.value = value;
    await _storage.setBool(StorageKeys.premiumCached, value);
  }

  Future<void> dispose() async => _sub?.cancel();
}
