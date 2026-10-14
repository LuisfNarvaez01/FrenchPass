import 'package:flutter/services.dart';

/// Which build is running: the Google Play one or the developer's GitHub
/// one. Set by `flutter build --flavor play|github`; see the product
/// flavors in android/app/build.gradle.
abstract final class AppChannel {
  /// The GitHub build updates itself from GitHub Releases and uses App
  /// Check's debug provider; the Play build does neither.
  static bool get isGithub => appFlavor == 'github';

  static bool get isPlay => !isGithub;
}
