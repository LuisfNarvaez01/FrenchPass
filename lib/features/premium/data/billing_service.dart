import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:french_pass/core/config/app_channel.dart';
import 'package:french_pass/core/services/storage_service.dart';

/// One way to pay for Premium, as Google Play sells it.
class PremiumPlan {
  final GooglePlayProductDetails details;

  /// "mensual" or "anual": the base plan id in Play Console.
  final String basePlanId;

  const PremiumPlan(this.details, this.basePlanId);

  bool get isYearly => basePlanId == BillingService.yearlyPlan;

  /// Localised by Play, e.g. "US$ 4,99" or "COP 12.900".
  String get price => details.price;
}

/// Premium, sold as a Google Play subscription.
///
/// Play is the source of truth: on start the app asks it for active
/// subscriptions, and keeps the last answer so Premium still works offline.
/// The GitHub build is never sold (it isn't on Play) and counts as Premium;
/// strangers who install it can't reach the AI anyway, because App Check
/// only accepts the debug tokens the developer registered.
class BillingService {
  /// Subscription id in Play Console, with two base plans.
  static const productId = 'premium';
  static const monthlyPlan = 'mensual';
  static const yearlyPlan = 'anual';

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

  /// Asks Play which subscriptions are active right now. Keeps the cached
  /// answer if Play can't be reached.
  Future<void> refresh() async {
    if (!_storeAvailable) return;
    try {
      final android = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await android.queryPastPurchases();
      if (response.error != null) return;
      final mine =
          response.pastPurchases.where((p) => p.productID == productId);
      for (final purchase in mine) {
        await _acknowledge(purchase);
      }
      await _setPremium(mine.any((p) => p.status == PurchaseStatus.purchased));
    } catch (e) {
      debugPrint('BillingService.refresh failed: $e');
    }
  }

  /// The plans Play offers, monthly first. Empty if Play can't be reached
  /// or the subscription isn't set up in Play Console yet.
  Future<List<PremiumPlan>> plans() async {
    if (!_storeAvailable) return const [];
    final response =
        await InAppPurchase.instance.queryProductDetails({productId});
    final plans = <PremiumPlan>[];
    for (final product in response.productDetails) {
      if (product is! GooglePlayProductDetails) continue;
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      if (index == null || offers == null) continue;
      final offer = offers[index];
      // Base plans only; promotional offers would show up as duplicates.
      if (offer.offerId != null) continue;
      plans.add(PremiumPlan(product, offer.basePlanId));
    }
    plans.sort((a, b) => a.isYearly == b.isYearly ? 0 : (a.isYearly ? 1 : -1));
    return plans;
  }

  /// Opens Play's purchase sheet. The result arrives on the purchase
  /// stream, which updates [isPremium].
  Future<bool> buy(PremiumPlan plan) => InAppPurchase.instance.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: plan.details,
          offerToken: plan.details.offerToken,
        ),
      );

  Future<void> restore() => refresh();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
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
