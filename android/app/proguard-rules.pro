# Flutter ProGuard & R8 Rules for Release APK

# Keep SQFlite & SQLite C-bindings
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.sqflite.** { *; }

# Keep Geolocator & Location Services
-keep class com.baseflow.geolocator.** { *; }
-keep class io.flutter.plugins.geolocator.** { *; }

# Keep Flutter Foreground Task Plugin Services
-keep class com.pravera.flutter_foreground_task.** { *; }
-keepclassmembers class com.pravera.flutter_foreground_task.** { *; }

# Keep Battery Plus & Device Info Plus
-keep class dev.fluttercommunity.plus.** { *; }

# Keep Firebase & Cloud Firestore
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Preserve Flutter VM Entry Points for Background Processing
-keepclassmembers class * {
    @pragma('vm:entry-point') *;
}

# Preserve Data Models Serialization
-keep class com.locationpoc.app.models.** { *; }
