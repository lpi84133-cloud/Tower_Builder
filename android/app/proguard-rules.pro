# Flutter's embedding is reached reflectively from the generated registrant.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ExoPlayer (pulled in by the audio plugin) resolves renderers by name.
-dontwarn com.google.android.exoplayer2.**
-keep class com.google.android.exoplayer2.** { *; }
