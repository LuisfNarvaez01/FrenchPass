# Flutter plugins reached through reflection / platform channels.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# flutter_local_notifications serializes scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn com.dexterous.**
