# JCG Fitness ProGuard Rules
# Keep Flutter & plugin classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep generated annotation classes
-keep class * extends com.google.gson.annotations.* { *; }

# Supabase
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.client.** { *; }
-keepclassmembers class * {
  @com.google.api.client.util.Key <fields>;
}

# GoRouter / Navigation
-keep class go_router.** { *; }
-keepclassmembers class * {
  @dart._named <fields>;
}

# SQLite / sqflite
-keep class net.sqlcipher.** { *; }
-keep class org.sqlite.** { *; }

# WorkManager
-keep class androidx.work.** { *; }
-keepclassmembers class * extends androidx.work.Worker {
    <init>(...);
}

# Camera
-keep class androidx.camera.** { *; }
-keep class io.flutter.plugins.camera.** { *; }

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Prevent stripping of platform channel message classes
-keep class * extends io.flutter.plugin.common.StandardMessageCodec { *; }
-keep class * extends io.flutter.plugin.common.JSONMessageCodec { *; }

# Flutter includes an optional Play Store deferred-components integration in
# the Android embedding. JCG ships a single APK and does not use deferred
# components, so the Play Core types are intentionally absent. Suppress only
# these optional references so release R8 can optimize the rest of the app.
-dontwarn com.google.android.play.core.**
